extends Node

## Live host telemetry for the letterbox. Polls Linux proc/sys on a one-second
## gauge tick. Ping, Wi-Fi queries, disk, and the public-IP lookup are slower.

const Metrics = preload("res://scripts/linux_metrics.gd")

const GAUGE_SEC := 1.0
const PING_SEC := 2.0
const SLOW_SEC := 5.0
const PUBLIC_IP_SEC := 300.0
const PUBLIC_IP_RETRY_SEC := 60.0
const HISTORY_POINTS := 24
const TEMP_SCALE_C := 85.0
const TRACE_URL := "https://1.1.1.1/cdn-cgi/trace"
const IPIFY_URL := "https://api.ipify.org"
const PING_FALLBACK_HOST := "1.1.1.1"

signal updated

var _data: Dictionary = {}
var _download := 0.0
var _upload := 0.0
var _last_ping_ms := -1.0
var _cpu := -1.0
var _ram := -1.0
var _disk := -1.0
var _temp_c := -1.0
var _temp_available := false
var _pub_ip := ""
var _loc_ip := ""
var _router_ip := ""
var _iface := ""
var _wifi_connected := false
var _ssid := ""
var _band := ""
var _rssi_dbm := 0
var _rssi_known := false
var _signal_level := 0
var _eth_present := false
var _eth_up := false
var _eth_rate := ""
var _eth_link := ""
var _vpn_connected := false
var _history: Array[float] = []
var _history_at: Array[String] = []

var _prev_cpu: Dictionary = {}
var _prev_rx := 0
var _prev_tx := 0
var _prev_usec := 0
var _prev_iface := ""
var _counter_ready := false
var _next_slow_msec := 0
var _next_ping_msec := 0
var _next_ip_msec := 0
var _ip_fallback := false
var _stopping := false

var _http: HTTPRequest
var _mutex: Mutex
var _ping_thread: Thread
var _ping_rtt := -1.0
var _ping_done := false
var _tcp: StreamPeerTCP
var _tcp_started_msec := 0


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func _ready() -> void:
	_data = _blank()
	if Engine.is_editor_hint():
		return
	_mutex = Mutex.new()
	_http = HTTPRequest.new()
	_http.timeout = 4.0
	_http.request_completed.connect(_on_public_ip)
	add_child(_http)
	_sample()
	_request_public_ip()
	_maybe_start_ping()
	var timer := Timer.new()
	timer.wait_time = GAUGE_SEC
	timer.autostart = true
	timer.timeout.connect(_on_gauge_tick)
	add_child(timer)


func _exit_tree() -> void:
	_stopping = true
	var thread := _ping_thread
	_ping_thread = null
	if thread != null and thread.is_started():
		thread.wait_to_finish()
	_tcp = null


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _stopping:
		return
	var changed := false
	if _take_finished_ping():
		changed = true
	if _poll_tcp():
		changed = true
	if changed:
		_publish()
		updated.emit()
	_maybe_start_ping()


func _on_gauge_tick() -> void:
	if _stopping:
		return
	_sample()
	if Time.get_ticks_msec() >= _next_ip_msec:
		_request_public_ip()
	updated.emit()


func _sample() -> void:
	var names := _iface_names()
	var route: Dictionary = Metrics.parse_default_route(Metrics.read_text("/proc/net/route"))
	_iface = str(route.get("iface", ""))
	_router_ip = str(route.get("gateway", ""))
	_loc_ip = _address_on(_iface)
	_read_counters()
	_read_cpu()
	_ram = float(Metrics.parse_meminfo(Metrics.read_text("/proc/meminfo")))
	_read_temp()
	_vpn_connected = _vpn_is_up(names)
	var now := Time.get_ticks_msec()
	var slow := now >= _next_slow_msec
	if slow:
		_next_slow_msec = now + int(SLOW_SEC * 1000.0)
		_disk = float(Metrics.parse_df_root(_run("df", PackedStringArray(["-P", "/"]))))
		_read_wifi(names)
	_read_ethernet(names, slow)
	_publish()


func _read_counters() -> void:
	var dev: Dictionary = Metrics.parse_proc_net_dev(Metrics.read_text("/proc/net/dev"))
	var now_usec := Time.get_ticks_usec()
	if not dev.has(_iface):
		_download = 0.0
		_upload = 0.0
		_counter_ready = false
		_prev_iface = _iface
		return
	var row: Dictionary = dev[_iface]
	var rx := int(row.rx)
	var tx := int(row.tx)
	if _counter_ready and _iface == _prev_iface and not _iface.is_empty():
		var seconds := float(now_usec - _prev_usec) / 1000000.0
		_download = float(Metrics.mbps(rx - _prev_rx, seconds))
		_upload = float(Metrics.mbps(tx - _prev_tx, seconds))
		if seconds > 0.0:
			_push_rate(_download)
	else:
		_download = 0.0
		_upload = 0.0
	_prev_rx = rx
	_prev_tx = tx
	_prev_usec = now_usec
	_prev_iface = _iface
	_counter_ready = true


func _read_cpu() -> void:
	var sample: Dictionary = Metrics.parse_proc_stat(Metrics.read_text("/proc/stat"))
	var ratio := float(Metrics.cpu_busy_ratio(_prev_cpu, sample))
	_prev_cpu = sample
	if ratio >= 0.0:
		_cpu = ratio


func _read_temp() -> void:
	var model := _sys("/proc/device-tree/model")
	if model.is_empty():
		model = _sys("/sys/firmware/devicetree/base/model")
	if not Metrics.is_raspberry_pi(model):
		_temp_available = false
		_temp_c = -1.0
		return
	var temp := float(Metrics.parse_thermal_millic(_sys("/sys/class/thermal/thermal_zone0/temp")))
	_temp_available = temp >= 0.0
	_temp_c = temp


func _read_wifi(names: PackedStringArray) -> void:
	var iface := ""
	for name in names:
		if _is_wifi(name):
			iface = name
			break
	_wifi_connected = false
	_ssid = ""
	_band = ""
	_rssi_dbm = 0
	_rssi_known = false
	_signal_level = 0
	if iface.is_empty():
		return
	var parsed: Dictionary = Metrics.parse_iw_link(_run("iw", PackedStringArray(["dev", iface, "link"])))
	if not bool(parsed.connected):
		var ssid := _first_line(_run("iwgetid", PackedStringArray([iface, "--raw"])))
		if _looks_like_ssid(ssid):
			parsed.connected = true
			parsed.ssid = ssid
			parsed.freq_mhz = _freq_from_iwgetid(_run("iwgetid", PackedStringArray([iface, "--freq"])))
	if not bool(parsed.connected):
		var nm := _run("nmcli", PackedStringArray(["-t", "-f", "ACTIVE,SSID,SIGNAL,FREQ", "dev", "wifi", "list", "--rescan", "no"]))
		var from_nm: Dictionary = _parse_nmcli_wifi(nm, iface)
		if bool(from_nm.connected):
			parsed = from_nm
	if not bool(parsed.rssi_known):
		var wireless: Dictionary = Metrics.parse_proc_wireless(Metrics.read_text("/proc/net/wireless"))
		if wireless.has(iface):
			var level := int(wireless[iface].rssi_dbm)
			if level < 0:
				parsed.rssi_dbm = level
				parsed.rssi_known = true
	_wifi_connected = bool(parsed.connected)
	_ssid = str(parsed.ssid)
	_band = str(Metrics.band_from_mhz(int(parsed.freq_mhz)))
	_rssi_known = bool(parsed.rssi_known)
	_rssi_dbm = int(parsed.rssi_dbm)
	if _wifi_connected and _rssi_known:
		_signal_level = int(Metrics.signal_bars(_rssi_dbm))


func _read_ethernet(names: PackedStringArray, allow_ethtool: bool) -> void:
	var iface := ""
	if _is_ethernet(_iface):
		iface = _iface
	else:
		var fallback := ""
		for name in names:
			if not _is_ethernet(name):
				continue
			if fallback.is_empty():
				fallback = name
			if _link_up(name):
				iface = name
				break
		if iface.is_empty():
			iface = fallback
	_eth_present = not iface.is_empty()
	_eth_up = _eth_present and _link_up(iface)
	var speed := -1
	if _eth_present:
		speed = _sys_speed(iface)
		if speed <= 0 and allow_ethtool:
			speed = int(Metrics.parse_ethtool_speed(_run("ethtool", PackedStringArray([iface]))))
	var formatted: Dictionary = Metrics.format_link_speed(speed)
	if not _eth_present:
		_eth_rate = ""
		_eth_link = ""
	elif not _eth_up:
		_eth_rate = ""
		_eth_link = "LINK: down"
	elif str(formatted.rate).is_empty():
		_eth_rate = "UP"
		_eth_link = "LINK: up"
	else:
		_eth_rate = str(formatted.rate)
		_eth_link = "LINK: " + str(formatted.detail)


func _publish() -> void:
	var samples: Array = []
	for value in _history:
		samples.append(value)
	var labels: Array = _span_labels()
	_data = {
		"download_mbps": _download,
		"upload_mbps": _upload,
		"ping_ms": _last_ping_ms,
		"cpu": _cpu,
		"ram": _ram,
		"disk": _disk,
		"temp_c": _temp_c,
		"temp_available": _temp_available,
		"temp_scale_c": TEMP_SCALE_C,
		"pub_ip": _pub_ip,
		"loc_ip": _loc_ip,
		"router_ip": _router_ip,
		"iface": _iface,
		"ssid": _ssid,
		"band": _band,
		"rssi_dbm": _rssi_dbm,
		"rssi_known": _rssi_known,
		"wifi_connected": _wifi_connected,
		"signal_level": _signal_level,
		"eth_present": _eth_present,
		"eth_up": _eth_up,
		"eth_rate": _eth_rate,
		"eth_link": _eth_link,
		"vpn_connected": _vpn_connected,
		"throughput": samples,
		"throughput_labels": labels,
	}


func _push_rate(mbps_value: float) -> void:
	_history.append(mbps_value)
	var now: Dictionary = Time.get_datetime_dict_from_system()
	_history_at.append("%02d:%02d:%02d" % [int(now.hour), int(now.minute), int(now.second)])
	while _history.size() > HISTORY_POINTS:
		_history.remove_at(0)
		_history_at.remove_at(0)


func _span_labels() -> Array:
	var labels: Array = []
	var count := _history_at.size()
	if count == 0:
		return labels
	var slots := mini(5, count)
	if slots == 1:
		labels.append(_history_at[0])
		return labels
	for i in slots:
		var idx := int(round(float(i) * float(count - 1) / float(slots - 1)))
		labels.append(_history_at[idx])
	return labels


func _maybe_start_ping() -> void:
	if _stopping or _ping_thread != null:
		return
	if Time.get_ticks_msec() < _next_ping_msec:
		return
	_next_ping_msec = Time.get_ticks_msec() + int(PING_SEC * 1000.0)
	var thread := Thread.new()
	var err := thread.start(_ping_worker.bind(_router_ip))
	if err != OK:
		_begin_tcp()
		return
	_ping_thread = thread


func _ping_worker(gateway: String) -> void:
	var rtt := -1.0
	if not gateway.is_empty():
		rtt = _icmp(gateway)
	if rtt < 0.0:
		rtt = _icmp(PING_FALLBACK_HOST)
	if _mutex == null:
		return
	_mutex.lock()
	_ping_rtt = rtt
	_ping_done = true
	_mutex.unlock()


func _icmp(host: String) -> float:
	var output: Array = []
	var args := PackedStringArray(["-n", "-c", "1", "-W", "1", host])
	if FileAccess.file_exists("/usr/bin/timeout"):
		var timed := PackedStringArray(["-s", "KILL", "2", "ping"])
		timed.append_array(args)
		OS.execute("timeout", timed, output, true)
	else:
		OS.execute("ping", args, output, true)
	var lines := PackedStringArray()
	for line in output:
		lines.append(str(line))
	return float(Metrics.parse_ping_rtt("\n".join(lines)))


func _take_finished_ping() -> bool:
	if _ping_thread == null or _ping_thread.is_alive():
		return false
	var thread := _ping_thread
	_ping_thread = null
	thread.wait_to_finish()
	_mutex.lock()
	var rtt := _ping_rtt
	var done := _ping_done
	_ping_done = false
	_mutex.unlock()
	if not done:
		return false
	if rtt >= 0.0:
		_last_ping_ms = rtt
		return true
	_begin_tcp()
	return false


func _begin_tcp() -> void:
	if _tcp != null or _stopping:
		return
	var peer := StreamPeerTCP.new()
	var err := peer.connect_to_host(PING_FALLBACK_HOST, 443)
	if err != OK:
		return
	_tcp = peer
	_tcp_started_msec = Time.get_ticks_msec()


func _poll_tcp() -> bool:
	if _tcp == null:
		return false
	_tcp.poll()
	var status := _tcp.get_status()
	var elapsed := Time.get_ticks_msec() - _tcp_started_msec
	if status == StreamPeerTCP.STATUS_CONNECTED:
		_last_ping_ms = float(max(elapsed, 0))
		_tcp.disconnect_from_host()
		_tcp = null
		return true
	if status == StreamPeerTCP.STATUS_ERROR or elapsed > 2000:
		_tcp = null
	return false


func _request_public_ip() -> void:
	if _http == null or _stopping:
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := IPIFY_URL if _ip_fallback else TRACE_URL
	_next_ip_msec = Time.get_ticks_msec() + int(PUBLIC_IP_SEC * 1000.0)
	var err := _http.request(url)
	if err != OK:
		_next_ip_msec = Time.get_ticks_msec() + int(PUBLIC_IP_RETRY_SEC * 1000.0)


func _on_public_ip(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _stopping:
		return
	var ip := str(Metrics.parse_public_ip(body.get_string_from_utf8()))
	var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300 and not ip.is_empty()
	if ok:
		_pub_ip = ip
		_ip_fallback = false
		_next_ip_msec = Time.get_ticks_msec() + int(PUBLIC_IP_SEC * 1000.0)
		_publish()
		updated.emit()
		return
	if not _ip_fallback:
		_ip_fallback = true
		_next_ip_msec = 0
		_request_public_ip()
		return
	_ip_fallback = false
	_next_ip_msec = Time.get_ticks_msec() + int(PUBLIC_IP_RETRY_SEC * 1000.0)


func _iface_names() -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open("/sys/class/net")
	if dir == null:
		return names
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return names


func _is_wifi(name: String) -> bool:
	if name.is_empty():
		return false
	var base := "/sys/class/net/" + name
	if DirAccess.dir_exists_absolute(base + "/wireless"):
		return true
	if DirAccess.dir_exists_absolute(base + "/phy80211"):
		return true
	return Metrics.is_wifi_name(name)


func _is_ethernet(name: String) -> bool:
	if name.is_empty() or name == "lo" or _is_virtual_name(name) or _is_wifi(name) or Metrics.is_vpn_iface(name):
		return false
	if _sys("/sys/class/net/%s/type" % name) != "1":
		return false
	return DirAccess.dir_exists_absolute("/sys/class/net/%s/device" % name)


func _is_virtual_name(name: String) -> bool:
	var lowered := name.to_lower()
	return (
		lowered.begins_with("veth")
		or lowered.begins_with("br-")
		or lowered.begins_with("docker")
		or lowered.begins_with("virbr")
		or lowered.begins_with("dummy")
	)


func _link_up(name: String) -> bool:
	if _sys("/sys/class/net/%s/operstate" % name) == "up":
		return true
	return _sys("/sys/class/net/%s/carrier" % name) == "1"


func _sys_speed(name: String) -> int:
	var raw := _sys("/sys/class/net/%s/speed" % name)
	if not raw.is_valid_int():
		return -1
	var speed := int(raw)
	return speed if speed > 0 else -1


func _vpn_is_up(names: PackedStringArray) -> bool:
	for name in names:
		if not Metrics.is_vpn_iface(name):
			continue
		var flags := _sys("/sys/class/net/%s/flags" % name).trim_prefix("0x")
		if flags.is_empty():
			continue
		if (flags.hex_to_int() & 1) != 0:
			return true
	return false


func _address_on(iface: String) -> String:
	if iface.is_empty():
		return ""
	var ifaces: Array = IP.get_local_interfaces()
	for item in ifaces:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("name", "")) != iface and str(row.get("friendly", "")) != iface:
			continue
		var addresses: Array = row.get("addresses", [])
		return str(Metrics.pick_iface_address(addresses))
	return ""


func _sys(path: String) -> String:
	return Metrics.read_text(path).strip_edges().replace(char(0), "")


func _run(program: String, args: PackedStringArray) -> String:
	var output: Array = []
	if FileAccess.file_exists("/usr/bin/timeout"):
		var timed := PackedStringArray(["-s", "KILL", "2", program])
		timed.append_array(args)
		OS.execute("timeout", timed, output, true)
	else:
		OS.execute(program, args, output, true)
	var lines := PackedStringArray()
	for line in output:
		lines.append(str(line))
	return "\n".join(lines)


func _first_line(text: String) -> String:
	var lines := text.split("\n", false)
	if lines.is_empty():
		return ""
	return lines[0].strip_edges()


func _looks_like_ssid(text: String) -> bool:
	if text.is_empty():
		return false
	var lower := text.to_lower()
	return not (
		lower.contains("not found")
		or lower.contains("no such")
		or lower.contains("failed")
		or lower.contains("not connected")
		or lower.begins_with("usage:")
	)


func _freq_from_iwgetid(text: String) -> int:
	var pattern := RegEx.new()
	if pattern.compile("([0-9]+(?:\\.[0-9]+)?)\\s*GHz") != OK:
		return 0
	var found := pattern.search(text)
	if found == null:
		return 0
	return int(round(float(found.get_string(1)) * 1000.0))


func _parse_nmcli_wifi(text: String, _iface: String) -> Dictionary:
	var out := {
		"connected": false,
		"ssid": "",
		"freq_mhz": 0,
		"rssi_dbm": 0,
		"rssi_known": false,
	}
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if not line.begins_with("yes:"):
			continue
		var fields := line.split(":")
		if fields.size() < 2:
			continue
		out.connected = true
		out.ssid = fields[1]
		if fields.size() >= 4 and fields[3].is_valid_int():
			out.freq_mhz = int(fields[3])
		break
	return out


func _blank() -> Dictionary:
	return {
		"download_mbps": 0.0,
		"upload_mbps": 0.0,
		"ping_ms": -1.0,
		"cpu": -1.0,
		"ram": -1.0,
		"disk": -1.0,
		"temp_c": -1.0,
		"temp_available": false,
		"temp_scale_c": TEMP_SCALE_C,
		"pub_ip": "",
		"loc_ip": "",
		"router_ip": "",
		"iface": "",
		"ssid": "",
		"band": "",
		"rssi_dbm": 0,
		"rssi_known": false,
		"wifi_connected": false,
		"signal_level": 0,
		"eth_present": false,
		"eth_up": false,
		"eth_rate": "",
		"eth_link": "",
		"vpn_connected": false,
		"throughput": [],
		"throughput_labels": [],
	}
