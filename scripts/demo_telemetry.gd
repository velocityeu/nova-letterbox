class_name DemoTelemetry
extends RefCounted

## Placeholder numbers for the UI shell.
## These are not read from the network. Public addresses use documentation ranges.


static func simple() -> Dictionary:
	return {
		"download_mbps": 118.0,
		"upload_mbps": 136.0,
		"ping_ms": 29.0,
	}


static func complete() -> Dictionary:
	return {
		"download_mbps": 48.7,
		"upload_mbps": 18.3,
		"ping_ms": 14.0,
		"cpu": 0.23,
		"ram": 0.41,
		"disk": 0.67,
		"temp_c": 52.6,
		# Visual range for the temperature bar. Not a sensor limit.
		"temp_scale_c": 80.0,
		"pub_ip": "203.0.113.42",
		"loc_ip": "192.168.1.101",
		"router_ip": "192.168.1.1",
		"ssid": "NovaLab_5G",
		"band": "5 GHz",
		"rssi_dbm": -42,
		"signal_level": 4,
		"eth_rate": "1G",
		"eth_link": "LINK: 1 Gbps",
		"vpn_connected": true,
		"throughput": [32, 28, 24, 35, 30, 22, 26, 38, 44, 36, 33, 48, 42, 40, 46, 55, 41, 38, 44, 36, 52, 47, 63, 58, 42],
		"throughput_labels": ["10:24:20", "10:24:25", "10:24:30", "10:24:35", "10:24:40"],
	}
