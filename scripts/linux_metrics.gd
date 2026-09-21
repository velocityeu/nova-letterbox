class_name LinuxMetrics
extends RefCounted

## Pure parsers for Linux /proc, /sys, and small command outputs.
## File reads go through read_text() because /proc reports a size of 0.


static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var out := PackedByteArray()
	while out.size() < 1048576:
		var chunk := file.get_buffer(4096)
		if chunk.is_empty():
			break
		out.append_array(chunk)
	file.close()
	return out.get_string_from_utf8()


static func parse_proc_net_dev(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		if not line.contains(":"):
			continue
		var parts := line.split(":", false, 1)
		if parts.size() < 2:
			continue
		var name := parts[0].strip_edges()
		if name.is_empty() or name == "face":
			continue
		var nums := parts[1].strip_edges().split(" ", false)
		if nums.size() < 9:
			continue
		if not nums[0].is_valid_int() or not nums[8].is_valid_int():
			continue
		out[name] = {"rx": int(nums[0]), "tx": int(nums[8])}
	return out


static func parse_default_route(text: String) -> Dictionary:
	var best_metric := 2147483647
	var iface := ""
	var gateway := ""
	for raw_line in text.split("\n"):
		var fields := raw_line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.size() < 7:
			continue
		if fields[1] != "00000000":
			continue
		if not fields[6].is_valid_int():
			continue
		var metric := int(fields[6])
		if metric > best_metric:
			continue
		if not iface.is_empty() and metric == best_metric:
			continue
		best_metric = metric
		iface = fields[0]
		gateway = "" if fields[2] == "00000000" else hex_le_ipv4(fields[2])
	return {"iface": iface, "gateway": gateway}


static func hex_le_ipv4(hex: String) -> String:
	var h := hex.strip_edges()
	if h.length() != 8:
		return ""
	return "%d.%d.%d.%d" % [
		h.substr(6, 2).hex_to_int(),
		h.substr(4, 2).hex_to_int(),
		h.substr(2, 2).hex_to_int(),
		h.substr(0, 2).hex_to_int(),
	]


static func parse_proc_stat(text: String) -> Dictionary:
	for line in text.split("\n"):
		if not line.begins_with("cpu "):
			continue
		var fields := line.split(" ", false)
		if fields.size() < 5:
			return {"idle": 0, "total": 0}
		var user := int(fields[1])
		var nice := int(fields[2])
		var system := int(fields[3])
		var idle := int(fields[4])
		var iowait := int(fields[5]) if fields.size() > 5 else 0
		var irq := int(fields[6]) if fields.size() > 6 else 0
		var softirq := int(fields[7]) if fields.size() > 7 else 0
		var steal := int(fields[8]) if fields.size() > 8 else 0
		return {
			"idle": idle + iowait,
			"total": user + nice + system + idle + iowait + irq + softirq + steal,
		}
	return {"idle": 0, "total": 0}


static func cpu_busy_ratio(previous: Dictionary, current: Dictionary) -> float:
	if previous.is_empty() or current.is_empty():
		return -1.0
	if not previous.has("total") or not current.has("total"):
		return -1.0
	var delta_total := int(current.total) - int(previous.total)
	var delta_idle := int(current.idle) - int(previous.idle)
	if delta_total <= 0:
		return -1.0
	return clampf(1.0 - float(delta_idle) / float(delta_total), 0.0, 1.0)


static func parse_meminfo(text: String) -> float:
	var total := -1
	var available := -1
	var free_kb := 0
	var buffers := 0
	var cached := 0
	for line in text.split("\n"):
		var parts := line.split(":", false, 1)
		if parts.size() < 2:
			continue
		var key := parts[0].strip_edges()
		var number := parts[1].strip_edges().split(" ", false)
		if number.is_empty() or not number[0].is_valid_int():
			continue
		var value := int(number[0])
		match key:
			"MemTotal":
				total = value
			"MemAvailable":
				available = value
			"MemFree":
				free_kb = value
			"Buffers":
				buffers = value
			"Cached":
				cached = value
	if total <= 0:
		return -1.0
	var avail := available if available >= 0 else free_kb + buffers + cached
	return clampf(float(total - avail) / float(total), 0.0, 1.0)


static func parse_df_root(text: String) -> float:
	for raw_line in text.split("\n"):
		var fields := raw_line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.is_empty() or fields[fields.size() - 1] != "/":
			continue
		for field in fields:
			if not str(field).ends_with("%"):
				continue
			var number := str(field).trim_suffix("%")
			if number.is_valid_int():
				return clampf(float(number) / 100.0, 0.0, 1.0)
	return -1.0


static func parse_thermal_millic(text: String) -> float:
	var token := text.strip_edges().replace(char(0), "")
	if token.is_empty() or not token.is_valid_int():
		return -1.0
	return float(token) / 1000.0


static func is_raspberry_pi(text: String) -> bool:
	var model := text.replace(char(0), "").strip_edges().to_lower()
	return model.contains("raspberry pi")


static func mbps(delta_bytes: int, seconds: float) -> float:
	if seconds <= 0.0 or delta_bytes <= 0:
		return 0.0
	return float(delta_bytes) * 8.0 / seconds / 1000000.0


static func parse_ping_rtt(text: String) -> float:
	var sample := RegEx.new()
	if sample.compile("time[=<]([0-9]+(?:\\.[0-9]+)?)") == OK:
		var match := sample.search(text)
		if match:
			return float(match.get_string(1))
	var summary := RegEx.new()
	if summary.compile("(?:round-trip|rtt)[^=]*=\\s*[0-9.]+/([0-9.]+)/") == OK:
		var match := summary.search(text)
		if match:
			return float(match.get_string(1))
	return -1.0


static func parse_iw_link(text: String) -> Dictionary:
	var out := {
		"connected": false,
		"ssid": "",
		"freq_mhz": 0,
		"rssi_dbm": 0,
		"rssi_known": false,
	}
	var lower := text.to_lower()
	if lower.contains("not connected") or not lower.contains("connected to"):
		return out
	out.connected = true
	var ssid_re := RegEx.new()
	if ssid_re.compile("(?m)^\\s*SSID:\\s*(.*)\\s*$") == OK:
		var ssid_match := ssid_re.search(text)
		if ssid_match:
			out.ssid = ssid_match.get_string(1).strip_edges()
	var freq_re := RegEx.new()
	if freq_re.compile("(?m)^\\s*freq:\\s*([0-9]+)") == OK:
		var freq_match := freq_re.search(text)
		if freq_match:
			out.freq_mhz = int(freq_match.get_string(1))
	var signal_re := RegEx.new()
	if signal_re.compile("(?m)^\\s*signal:\\s*(-?[0-9]+)") == OK:
		var signal_match := signal_re.search(text)
		if signal_match:
			out.rssi_dbm = int(signal_match.get_string(1))
			out.rssi_known = true
	return out


static func band_from_mhz(freq: int) -> String:
	if freq >= 2400 and freq < 2500:
		return "2.4 GHz"
	if freq >= 4900 and freq < 5925:
		return "5 GHz"
	if freq >= 5925 and freq <= 7125:
		return "6 GHz"
	return ""


static func signal_bars(dbm: int) -> int:
	if dbm >= -50:
		return 4
	if dbm >= -60:
		return 3
	if dbm >= -70:
		return 2
	if dbm >= -80:
		return 1
	return 0


static func parse_proc_wireless(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		if not line.contains(":"):
			continue
		var parts := line.split(":", false, 1)
		var name := parts[0].strip_edges()
		if name.is_empty() or name.begins_with("face") or name.begins_with("Inter"):
			continue
		var fields := parts[1].strip_edges().split(" ", false)
		if fields.size() < 3:
			continue
		var level := str(fields[2]).trim_suffix(".")
		if not level.is_valid_int():
			continue
		out[name] = {"rssi_dbm": int(level)}
	return out


static func is_vpn_iface(name: String) -> bool:
	var lowered := name.to_lower()
	for prefix in [
		"tun", "tap", "wg", "tailscale", "zt", "proton", "nordlynx",
		"awg", "ipsec", "vti", "outline", "mullvad", "warp", "wireguard",
	]:
		if lowered.begins_with(prefix):
			return true
	return false


static func is_wifi_name(name: String) -> bool:
	var lowered := name.to_lower()
	return (
		lowered.begins_with("wlan")
		or lowered.begins_with("wlp")
		or lowered.begins_with("wlo")
		or lowered.begins_with("wlx")
		or lowered.begins_with("wifi")
	)


static func format_link_speed(mbps_value: int) -> Dictionary:
	if mbps_value <= 0:
		return {"rate": "", "detail": ""}
	if mbps_value % 1000 == 0:
		var gigabits := mbps_value / 1000
		return {"rate": "%dG" % gigabits, "detail": "%d Gbps" % gigabits}
	if mbps_value > 1000:
		var text := "%.1f" % (float(mbps_value) / 1000.0)
		return {"rate": text + "G", "detail": text + " Gbps"}
	return {"rate": "%dM" % mbps_value, "detail": "%d Mbps" % mbps_value}


static func parse_ethtool_speed(text: String) -> int:
	var pattern := RegEx.new()
	if pattern.compile("Speed:\\s*([0-9]+)") != OK:
		return -1
	var match := pattern.search(text)
	if match == null:
		return -1
	var speed := int(match.get_string(1))
	return speed if speed > 0 else -1


static func parse_public_ip(body: String) -> String:
	var candidate := ""
	if body.contains("ip="):
		var pattern := RegEx.new()
		if pattern.compile("(?m)^ip=([^\\s]+)\\s*$") == OK:
			var match := pattern.search(body)
			if match:
				candidate = match.get_string(1).strip_edges()
	else:
		candidate = body.strip_edges()
	if _is_ipv4(candidate) or _is_ipv6(candidate):
		return candidate
	return ""


static func gauge_scale(value: float, floor_max: float) -> Dictionary:
	var ceiling := maxf(floor_max, value)
	var tiers: Array[float] = [100.0, 175.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0, 10000.0]
	var chosen := tiers[tiers.size() - 1]
	for tier in tiers:
		if tier + 0.001 >= ceiling:
			chosen = tier
			break
	var major := 25.0
	var minor := 5.0
	var label := 25.0
	if chosen > 175.0 and chosen <= 250.0:
		major = 50.0
		minor = 10.0
		label = 50.0
	elif chosen > 250.0 and chosen <= 500.0:
		major = 100.0
		minor = 25.0
		label = 100.0
	elif chosen > 500.0 and chosen <= 1000.0:
		major = 250.0
		minor = 50.0
		label = 250.0
	elif chosen > 1000.0 and chosen <= 2500.0:
		major = 500.0
		minor = 100.0
		label = 500.0
	elif chosen > 2500.0:
		major = chosen / 4.0
		minor = chosen / 20.0
		label = chosen / 4.0
	return {"max": chosen, "major": major, "minor": minor, "label": label}


static func spark_y_max(peak: float) -> float:
	if peak <= 0.0:
		return 1.0
	var padded := peak * 1.25
	var exponent: float = floor(log(padded) / log(10.0))
	var magnitude: float = pow(10.0, exponent)
	var normalized := padded / magnitude
	var nice := 10.0
	if normalized <= 1.0:
		nice = 1.0
	elif normalized <= 2.0:
		nice = 2.0
	elif normalized <= 5.0:
		nice = 5.0
	return nice * magnitude


static func pick_iface_address(addresses: Array) -> String:
	var ipv6 := ""
	for addr in addresses:
		var ip := ""
		if typeof(addr) == TYPE_STRING:
			ip = str(addr)
		elif typeof(addr) == TYPE_DICTIONARY:
			var row: Dictionary = addr
			ip = str(row.get("address", row.get("ip", "")))
		if _usable_ipv4(ip):
			return ip
		if ipv6.is_empty() and _usable_ipv6(ip):
			ipv6 = ip
	return ipv6


static func _usable_ipv4(ip: String) -> bool:
	if not _is_ipv4(ip):
		return false
	if ip.begins_with("127.") or ip.begins_with("169.254."):
		return false
	return true


static func _usable_ipv6(ip: String) -> bool:
	if not _is_ipv6(ip):
		return false
	var lower := ip.to_lower()
	if lower == "::1" or lower == "0:0:0:0:0:0:0:1":
		return false
	if lower.begins_with("fe80:"):
		return false
	return true


static func _is_ipv4(text: String) -> bool:
	var parts := text.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not str(part).is_valid_int():
			return false
		var value := int(part)
		if value < 0 or value > 255:
			return false
		if str(part).length() > 1 and str(part).begins_with("0"):
			return false
	return true


static func _is_ipv6(text: String) -> bool:
	if text.count(":") < 2:
		return false
	if text.contains(".") or text.contains(" "):
		return false
	var pattern := RegEx.new()
	if pattern.compile("^[0-9A-Fa-f:]+$") != OK:
		return false
	return pattern.search(text) != null
