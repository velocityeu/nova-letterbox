extends SceneTree

## Parser fixtures for the Linux telemetry collector. No live network.

const LinuxMetrics = preload("res://scripts/linux_metrics.gd")

var _failed := 0


func _init() -> void:
	_test_default_route()
	_test_net_dev_and_mbps()
	_test_cpu_and_mem()
	_test_df_and_thermal()
	_test_ping()
	_test_wifi()
	_test_vpn_and_link_speed()
	_test_public_ip()
	_test_scales()
	_test_addresses()
	_test_proc_read()
	if _failed > 0:
		print("FAILED ", _failed)
		quit(1)
	print("OK")
	quit(0)


func _test_default_route() -> void:
	var text := """Iface	Destination	Gateway	Flags	RefCnt	Use	Metric	Mask	MTU	Window	IRTT
enp0s3	00000000	01001EAC	0003	0	0	100	00000000	0	0	0
wlan0	00000000	0101A8C0	0003	0	0	50	00000000	0	0	0
docker0	000011AC	00000000	0001	0	0	0	0000FFFF	0	0	0
"""
	var route: Dictionary = LinuxMetrics.parse_default_route(text)
	_eq(route.iface, "wlan0", "lowest metric default iface")
	_eq(route.gateway, "192.168.1.1", "little-endian gateway")
	_eq(LinuxMetrics.hex_le_ipv4("01001EAC"), "172.30.0.1", "cloud gateway bytes")
	var none: Dictionary = LinuxMetrics.parse_default_route("Iface Destination Gateway\n")
	_eq(none.iface, "", "missing default iface")
	_eq(none.gateway, "", "missing default gateway")


func _test_net_dev_and_mbps() -> void:
	var text := """Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 10 1 0 0 0 0 0 0 10 1 0 0 0 0 0 0
enp0s3: 1250000 1 0 0 0 0 0 0 625000 1 0 0 0 0 0 0
"""
	var dev: Dictionary = LinuxMetrics.parse_proc_net_dev(text)
	_eq(int(dev.enp0s3.rx), 1250000, "rx bytes")
	_eq(int(dev.enp0s3.tx), 625000, "tx bytes")
	_eq(LinuxMetrics.mbps(125000, 1.0), 1.0, "125000 bytes/s is 1 Mbps")
	_eq(LinuxMetrics.mbps(0, 0.0), 0.0, "zero interval")


func _test_cpu_and_mem() -> void:
	var stat := "cpu  100 0 50 800 50 0 0 0 0 0\ncpu0 100 0 50 800 50 0 0 0 0 0\n"
	var sample: Dictionary = LinuxMetrics.parse_proc_stat(stat)
	_eq(int(sample.idle), 850, "idle includes iowait")
	_eq(int(sample.total), 1000, "guest columns are not double-counted")
	var busy := LinuxMetrics.cpu_busy_ratio({"idle": 0, "total": 0}, sample)
	_eq(busy, 0.15, "busy ratio")
	_eq(LinuxMetrics.cpu_busy_ratio({}, {}), -1.0, "no baseline")
	var mem := "MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 400 kB\n"
	_eq(LinuxMetrics.parse_meminfo(mem), 0.6, "available-based ram")
	_eq(LinuxMetrics.parse_meminfo("nope"), -1.0, "missing meminfo")


func _test_df_and_thermal() -> void:
	var df := "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/root 100 67 33 67% /\n"
	_eq(LinuxMetrics.parse_df_root(df), 0.67, "root capacity")
	_eq(LinuxMetrics.parse_df_root("not df"), -1.0, "bad df")
	_eq(LinuxMetrics.parse_thermal_millic("52600\n"), 52.6, "milli-C")
	_eq(LinuxMetrics.parse_thermal_millic(""), -1.0, "missing thermal")
	_eq(LinuxMetrics.is_raspberry_pi("Raspberry Pi 5 Model B Rev 1.0" + char(0)), true, "pi model")
	_eq(LinuxMetrics.is_raspberry_pi("QEMU Virtual"), false, "not a pi")


func _test_ping() -> void:
	var ok := "64 bytes from 1.1.1.1: icmp_seq=1 ttl=55 time=2.80 ms\n"
	_eq(LinuxMetrics.parse_ping_rtt(ok), 2.8, "icmp rtt")
	var busy := "round-trip min/avg/max = 14.2/14.2/14.2 ms\n"
	_eq(LinuxMetrics.parse_ping_rtt(busy), 14.2, "busybox summary")
	_eq(LinuxMetrics.parse_ping_rtt("100% packet loss\n"), -1.0, "loss")


func _test_wifi() -> void:
	var link := """Connected to aa:bb:cc:dd:ee:ff (on wlan0)
	SSID: Nova Lab
	freq: 5180
	signal: -67 dBm
	rx bitrate: 866.7 MBit/s
"""
	var parsed: Dictionary = LinuxMetrics.parse_iw_link(link)
	_eq(bool(parsed.connected), true, "iw connected")
	_eq(parsed.ssid, "Nova Lab", "ssid with space")
	_eq(int(parsed.freq_mhz), 5180, "freq")
	_eq(int(parsed.rssi_dbm), -67, "rssi")
	_eq(LinuxMetrics.band_from_mhz(2412), "2.4 GHz", "2.4")
	_eq(LinuxMetrics.band_from_mhz(5180), "5 GHz", "5")
	_eq(LinuxMetrics.band_from_mhz(6055), "6 GHz", "6")
	_eq(LinuxMetrics.band_from_mhz(0), "", "unknown band")
	_eq(LinuxMetrics.signal_bars(-42), 4, "strong")
	_eq(LinuxMetrics.signal_bars(-67), 2, "mid")
	_eq(LinuxMetrics.signal_bars(-90), 0, "weak")
	var down: Dictionary = LinuxMetrics.parse_iw_link("Not connected.\n")
	_eq(bool(down.connected), false, "iw disconnected")
	var proc := "wlan0: 0000   70.  -40.  -256        0      0      0      0      0        0\n"
	var wireless: Dictionary = LinuxMetrics.parse_proc_wireless(proc)
	_eq(int(wireless.wlan0.rssi_dbm), -40, "proc wireless level")


func _test_vpn_and_link_speed() -> void:
	_eq(LinuxMetrics.is_vpn_iface("tun0"), true, "tun")
	_eq(LinuxMetrics.is_vpn_iface("wg0"), true, "wg")
	_eq(LinuxMetrics.is_vpn_iface("tailscale0"), true, "tailscale")
	_eq(LinuxMetrics.is_vpn_iface("ztabc"), true, "zerotier")
	_eq(LinuxMetrics.is_vpn_iface("nordlynx"), true, "nordlynx")
	_eq(LinuxMetrics.is_vpn_iface("enp0s3"), false, "ethernet name")
	_eq(LinuxMetrics.is_vpn_iface("docker0"), false, "docker")
	_eq(LinuxMetrics.is_vpn_iface("lo"), false, "loopback")
	var gbit: Dictionary = LinuxMetrics.format_link_speed(1000)
	_eq(gbit.rate, "1G", "1G rate")
	_eq(gbit.detail, "1 Gbps", "1G detail")
	var fast: Dictionary = LinuxMetrics.format_link_speed(2500)
	_eq(fast.rate, "2.5G", "2.5G rate")
	_eq(fast.detail, "2.5 Gbps", "2.5G detail")
	var unknown: Dictionary = LinuxMetrics.format_link_speed(-1)
	_eq(unknown.rate, "", "unknown speed has no invented rate")
	_eq(LinuxMetrics.parse_ethtool_speed("Speed: 1000Mb/s\nLink detected: yes\n"), 1000, "ethtool speed")
	_eq(LinuxMetrics.parse_ethtool_speed("Link detected: no\n"), -1, "ethtool missing speed")
	_eq(LinuxMetrics.is_wifi_name("wlp2s0"), true, "pci wifi name")
	_eq(LinuxMetrics.is_wifi_name("enp0s3"), false, "ethernet name is not wifi")


func _test_public_ip() -> void:
	_eq(LinuxMetrics.parse_public_ip("ip=203.0.113.42\nts=1\n"), "203.0.113.42", "cloudflare trace")
	_eq(LinuxMetrics.parse_public_ip("  198.51.100.7\n"), "198.51.100.7", "plain ip")
	_eq(LinuxMetrics.parse_public_ip("nope"), "", "reject junk")
	_eq(LinuxMetrics.parse_public_ip("ip=2001:db8::1\n"), "2001:db8::1", "ipv6 trace")


func _test_scales() -> void:
	_eq(float(LinuxMetrics.gauge_scale(40.0, 175.0).max), 175.0, "simple dial keeps its floor")
	_eq(float(LinuxMetrics.gauge_scale(400.0, 175.0).max), 500.0, "dial expands past the mock")
	_eq(float(LinuxMetrics.gauge_scale(40.0, 100.0).max), 100.0, "complete dial keeps its floor")
	_eq(LinuxMetrics.spark_y_max(0.0), 1.0, "idle spark")
	_eq(LinuxMetrics.spark_y_max(80.0), 100.0, "spark headroom")


func _test_addresses() -> void:
	_eq(
		LinuxMetrics.pick_iface_address(["127.0.0.1", "172.30.0.2", "fe80:0:0:0:1:1:1:1"]),
		"172.30.0.2",
		"godot 4.3 address strings"
	)
	_eq(
		LinuxMetrics.pick_iface_address([{"address": "192.168.1.101", "netmask": "255.255.255.0"}]),
		"192.168.1.101",
		"dictionary addresses"
	)
	_eq(LinuxMetrics.pick_iface_address(["127.0.0.1", "0:0:0:0:0:0:0:1"]), "", "loopback only")


func _test_proc_read() -> void:
	var mem := LinuxMetrics.read_text("/proc/meminfo")
	_eq(mem.contains("MemTotal"), true, "/proc read is not truncated")


func _eq(got: Variant, expected: Variant, label: String) -> void:
	if typeof(got) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT:
		if is_equal_approx(float(got), float(expected)):
			return
	elif got == expected:
		return
	_failed += 1
	print("FAIL ", label, " got=", got, " expected=", expected)
