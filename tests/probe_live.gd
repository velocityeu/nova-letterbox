extends Node

## Headless check that the autoload is reading this Linux host, not the old demo strings.


func _ready() -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 6.5
	timer.timeout.connect(_finish)
	timer.autostart = true
	add_child(timer)


func _finish() -> void:
	var data: Dictionary = Telemetry.snapshot()
	print("SNAPSHOT ", JSON.stringify(data))
	var failed := _check(data)
	print("PROBE_RESULT failed=", failed)
	get_tree().quit(failed)


func _check(data: Dictionary) -> int:
	var failed := 0
	var loc := str(data.get("loc_ip", ""))
	var pub := str(data.get("pub_ip", ""))
	var router := str(data.get("router_ip", ""))
	var iface := str(data.get("iface", ""))
	if iface.is_empty():
		failed += _bad("default iface")
	if loc.is_empty():
		failed += _bad("local ip")
	if router.is_empty():
		failed += _bad("gateway")
	if pub.is_empty() or pub == "203.0.113.42":
		failed += _bad("public ip " + pub)
	if not bool(data.get("wifi_connected", false)) and str(data.get("ssid", "")) == "NovaLab_5G":
		failed += _bad("demo ssid")
	var ram := float(data.get("ram", -1.0))
	if ram < 0.0 or ram > 1.0:
		failed += _bad("ram")
	var disk := float(data.get("disk", -1.0))
	if disk < 0.0 or disk > 1.0:
		failed += _bad("disk")
	var cpu := float(data.get("cpu", -1.0))
	if cpu < 0.0 or cpu > 1.0:
		failed += _bad("cpu")
	var ping := float(data.get("ping_ms", -1.0))
	if ping <= 0.0 or ping > 2000.0:
		failed += _bad("ping")
	var samples: Array = data.get("throughput", [])
	if samples.size() < 2:
		failed += _bad("sparkline samples")
	for sample in samples:
		if float(sample) < 0.0:
			failed += _bad("negative throughput")
			break
	if not bool(data.get("wifi_connected", false)):
		if str(data.get("ssid", "")) != "":
			failed += _bad("ssid while disconnected")
	if bool(data.get("temp_available", false)):
		if float(data.get("temp_c", -1.0)) < 0.0:
			failed += _bad("pi temp")
	return failed


func _bad(label: String) -> int:
	print("PROBE_FAIL ", label)
	return 1
