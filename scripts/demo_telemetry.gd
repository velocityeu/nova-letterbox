class_name DemoTelemetry
extends RefCounted

## Static design stubs. These match the locked mocks in docs/design/.
## Nothing here talks to the network, the Pi, or a speed test.

const SIMPLE_SCALE_MAX := 175.0
const SIMPLE_DOWNLOAD_MBPS := 132.0
const SIMPLE_UPLOAD_MBPS := 158.0
const SIMPLE_PING_MS := 34.0

const COMPLETE_DOWNLOAD_MBPS := 48.7
const COMPLETE_UPLOAD_MBPS := 18.3
const COMPLETE_PING_MS := 14.0
const COMPLETE_SCALE_MAX := 100.0

const CPU_PERCENT := 23.0
const RAM_PERCENT := 41.0
const PI_TEMP_C := 52.6
const PI_TEMP_SCALE_C := 80.0
const DISK_PERCENT := 67.0

const PUB_IP := "203.0.113.42"
const LOC_IP := "192.168.1.101"
const ROUTER_IP := "192.168.1.1"
const VPN_STATE := "CONNECTED"

const WIFI_SSID := "NovaLab_5G"
const WIFI_BAND := "5 GHz"
const WIFI_DBM := -42
const ETH_RATE := "1G"
const ETH_LINK := "1 Gbps"

const PATH_NAMES: PackedStringArray = ["PI", "ROUTER", "INTERNET"]
const PATH_ADDRS: PackedStringArray = ["192.168.1.101", "192.168.1.1", "203.0.113.42"]
const PATH_ICONS: PackedStringArray = ["cluster", "router", "globe"]

## One sample per second across the sparkline window in the mock.
const THROUGHPUT_MBPS := [
	30.0, 34.0, 28.0, 20.0, 16.0, 26.0, 42.0, 50.0, 40.0, 34.0,
	38.0, 32.0, 36.0, 44.0, 40.0, 34.0, 42.0, 48.0, 41.0, 37.0,
	44.0, 52.0, 46.0, 40.0, 58.0, 66.0, 54.0, 48.0, 70.0, 84.0,
]
const THROUGHPUT_LABELS: PackedStringArray = [
	"10:24:20", "10:24:25", "10:24:30", "10:24:35", "10:24:40",
]

const WEEKDAYS: PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS: PackedStringArray = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]
