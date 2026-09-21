@tool
extends Control

const _WEEKDAYS: PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const _MONTHS: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

@onready var _download: DialGauge = $Margin/Body/Mid/Cluster/Pair/Download
@onready var _upload: DialGauge = $Margin/Body/Mid/Cluster/Pair/Upload
@onready var _ping: DialGauge = $Margin/Body/Mid/PingCol/Ping
@onready var _spark: Sparkline = $Margin/Body/Mid/CenterCol/Spark
@onready var _path: NetworkPath = $Margin/Body/Mid/CenterCol/Path
@onready var _cpu: MiniRing = $Margin/Body/Mid/CenterCol/Rings/Cpu
@onready var _ram: MiniRing = $Margin/Body/Mid/CenterCol/Rings/Ram
@onready var _temp_bar: MeterBar = $Margin/Body/Ribbon/TempCard/TempIn/TempBar
@onready var _disk_bar: MeterBar = $Margin/Body/Ribbon/DiskCard/DiskIn/DiskBar


func _ready() -> void:
	_style()
	_apply_demo()
	_tick_clock()
	if Engine.is_editor_hint():
		return
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick_clock)
	add_child(timer)


func _style() -> void:
	($Chrome as Panel).add_theme_stylebox_override("panel", NovaTheme.frame_style())
	($Margin/Body as VBoxContainer).add_theme_constant_override("separation", 4)
	($Margin/Body/Top as HBoxContainer).add_theme_constant_override("separation", 18)
	($Margin/Body/Top/IpRow as HBoxContainer).add_theme_constant_override("separation", 22)
	($Margin/Body/Top/MarkWrap/MarkRow as HBoxContainer).add_theme_constant_override("separation", 12)
	($Margin/Body/Mid as HBoxContainer).add_theme_constant_override("separation", 18)
	($Margin/Body/Mid/Cluster/Pair as HBoxContainer).add_theme_constant_override("separation", 16)
	($Margin/Body/Mid/CenterCol as VBoxContainer).add_theme_constant_override("separation", 2)
	($Margin/Body/Mid/CenterCol/Rings as HBoxContainer).add_theme_constant_override("separation", 28)
	($Margin/Body/Ribbon as HBoxContainer).add_theme_constant_override("separation", 10)
	($Margin/Body/TopRule as ColorRect).color = NovaPalette.BORDER
	for line_path in ["MarkLineL", "MarkLineR"]:
		var line := $Margin/Body/Top/MarkWrap/MarkRow.get_node(line_path) as ColorRect
		line.color = NovaPalette.COPPER_DEEP

	NovaTheme.style_label(
		$Margin/Body/Top/MarkWrap/MarkRow/Wordmark,
		NovaTheme.tracked(NovaTheme.LIGHT, 14),
		26,
		NovaPalette.COPPER_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	NovaTheme.style_label(
		$Margin/Body/Top/ClockCol/ClockTime,
		NovaTheme.tracked(NovaTheme.SEMIBOLD, 0),
		26,
		NovaPalette.AMBER
	)
	NovaTheme.style_label(
		$Margin/Body/Top/ClockCol/ClockDate,
		NovaTheme.tracked(NovaTheme.REGULAR, 0),
		13,
		NovaPalette.STEEL
	)

	var kicker := NovaTheme.tracked(NovaTheme.MEDIUM, 1)
	var value_font := NovaTheme.tracked(NovaTheme.MEDIUM, 0)
	for cap_path in ["PubCol/PubCap", "LocCol/LocCap"]:
		NovaTheme.style_label($Margin/Body/Top/IpRow.get_node(cap_path), kicker, 11, NovaPalette.STEEL_DIM)
	for val_path in ["PubCol/PubVal", "LocCol/LocVal"]:
		NovaTheme.style_label($Margin/Body/Top/IpRow.get_node(val_path), value_font, 16, NovaPalette.CREAM)

	($Margin/Body/Top/Vpn as PanelContainer).add_theme_stylebox_override("panel", NovaTheme.badge_style())
	NovaTheme.style_label($Margin/Body/Top/Vpn/VpnBox/VpnText/VpnKicker, kicker, 11, NovaPalette.STEEL)
	NovaTheme.style_label(
		$Margin/Body/Top/Vpn/VpnBox/VpnText/VpnState,
		NovaTheme.tracked(NovaTheme.SEMIBOLD, 1),
		13,
		NovaPalette.AMBER
	)

	for cap in [
		$Margin/Body/Mid/Cluster/ClusterCap,
		$Margin/Body/Mid/CenterCol/PathCap,
		$Margin/Body/RibbonCap,
	]:
		NovaTheme.style_label(cap, kicker, 12, NovaPalette.COPPER_SOFT)

	_style_card($Margin/Body/Ribbon/WifiCard)
	_style_card($Margin/Body/Ribbon/EthCard)
	_style_card($Margin/Body/Ribbon/TempCard)
	_style_card($Margin/Body/Ribbon/DiskCard)

	var wifi := $Margin/Body/Ribbon/WifiCard/WifiIn
	NovaTheme.style_label(wifi.get_node("WifiText/WifiHead/WifiTitle"), kicker, 13, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label(wifi.get_node("WifiText/Ssid"), value_font, 16, NovaPalette.CREAM)
	NovaTheme.style_label(wifi.get_node("WifiText/Band"), NovaTheme.REGULAR, 13, NovaPalette.STEEL)
	(wifi.get_node("WifiText/WifiHead/SignalIcon") as GlyphIcon).glyph_color = NovaPalette.AMBER

	var eth := $Margin/Body/Ribbon/EthCard/EthIn
	NovaTheme.style_label(eth.get_node("EthText/EthHead/EthTitle"), kicker, 13, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label(eth.get_node("EthText/EthRate"), NovaTheme.tracked(NovaTheme.SEMIBOLD, 0), 18, NovaPalette.CREAM)
	NovaTheme.style_label(eth.get_node("EthText/EthLink"), NovaTheme.REGULAR, 13, NovaPalette.STEEL)
	(eth.get_node("EthText/EthHead/EthDot") as GlyphIcon).glyph_color = NovaPalette.AMBER

	var temp := $Margin/Body/Ribbon/TempCard/TempIn
	NovaTheme.style_label(temp.get_node("TempHead/TempTitle"), kicker, 13, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label(temp.get_node("TempVal"), NovaTheme.tracked(NovaTheme.SEMIBOLD, 0), 18, NovaPalette.CREAM)
	var disk := $Margin/Body/Ribbon/DiskCard/DiskIn
	NovaTheme.style_label(disk.get_node("DiskHead/DiskTitle"), kicker, 13, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label(disk.get_node("DiskVal"), NovaTheme.tracked(NovaTheme.SEMIBOLD, 0), 18, NovaPalette.CREAM)


func _style_card(card: PanelContainer) -> void:
	card.add_theme_stylebox_override("panel", NovaTheme.card_style())


func _apply_demo() -> void:
	var data := DemoTelemetry.complete()
	_download.value = float(data.download_mbps)
	_upload.value = float(data.upload_mbps)
	_ping.value = float(data.ping_ms)
	_cpu.ratio = float(data.cpu)
	_ram.ratio = float(data.ram)
	_cpu.caption = "CPU"
	_ram.caption = "RAM"
	_cpu.icon_kind = GlyphIcon.Kind.CHIP
	_ram.icon_kind = GlyphIcon.Kind.MEMORY

	var samples := PackedFloat32Array()
	for sample in data.throughput:
		samples.append(float(sample))
	_spark.samples = samples
	_spark.y_max = 100.0
	_spark.title = "THROUGHPUT (Mbps)"
	var labels := PackedStringArray()
	for label in data.throughput_labels:
		labels.append(str(label))
	_spark.x_labels = labels

	_path.left_title = "PI"
	_path.left_addr = str(data.loc_ip)
	_path.mid_title = "ROUTER"
	_path.mid_addr = str(data.router_ip)
	_path.right_title = "INTERNET"
	_path.right_addr = str(data.pub_ip)

	$Margin/Body/Top/IpRow/PubCol/PubVal.text = str(data.pub_ip)
	$Margin/Body/Top/IpRow/LocCol/LocVal.text = str(data.loc_ip)
	var vpn_on := bool(data.vpn_connected)
	$Margin/Body/Top/Vpn/VpnBox/VpnText/VpnState.text = "CONNECTED" if vpn_on else "OFFLINE"

	var wifi := $Margin/Body/Ribbon/WifiCard/WifiIn/WifiText
	wifi.get_node("Ssid").text = str(data.ssid)
	wifi.get_node("Band").text = "%s    %d dBm" % [str(data.band), int(data.rssi_dbm)]
	($Margin/Body/Ribbon/WifiCard/WifiIn/WifiText/WifiHead/SignalIcon as GlyphIcon).level = int(data.signal_level)

	var eth := $Margin/Body/Ribbon/EthCard/EthIn/EthText
	eth.get_node("EthRate").text = str(data.eth_rate)
	eth.get_node("EthLink").text = str(data.eth_link)

	var temp_c := float(data.temp_c)
	var temp_scale := maxf(float(data.temp_scale_c), 1.0)
	$Margin/Body/Ribbon/TempCard/TempIn/TempVal.text = "%.1f °C" % temp_c
	_temp_bar.ratio = clampf(temp_c / temp_scale, 0.0, 1.0)
	var disk_ratio := float(data.disk)
	$Margin/Body/Ribbon/DiskCard/DiskIn/DiskVal.text = str(int(round(disk_ratio * 100.0))) + "%"
	_disk_bar.ratio = disk_ratio


func _tick_clock() -> void:
	var now := Time.get_datetime_dict_from_system()
	$Margin/Body/Top/ClockCol/ClockTime.text = "%02d:%02d:%02d" % [int(now.hour), int(now.minute), int(now.second)]
	var weekday: int = int(now.weekday)
	var month: int = int(now.month)
	if weekday < 0 or weekday > 6 or month < 1 or month > 12:
		return
	$Margin/Body/Top/ClockCol/ClockDate.text = "%s, %d %s %d" % [
		_WEEKDAYS[weekday],
		int(now.day),
		_MONTHS[month - 1],
		int(now.year),
	]
