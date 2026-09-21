@tool
extends Control

## Complete letterbox. Positions are in a 1920×480 design space, scaled to fit
## the live viewport so the ping dial and the disk card stay on screen.

const Metrics = preload("res://scripts/linux_metrics.gd")
const DESIGN := Vector2(1920, 480)
const _WEEKDAYS: PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const _MONTHS: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

func _ready() -> void:
	_style()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_tick_clock()
	if Engine.is_editor_hint():
		call_deferred("_layout")
		return
	($Ping as DialGauge).readout_decimals = 1
	Telemetry.updated.connect(_apply)
	_apply()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick_clock)
	add_child(timer)
	call_deferred("_layout")


func _style() -> void:
	($Chrome as Panel).add_theme_stylebox_override("panel", NovaTheme.frame_style())
	($ClockPanel as Panel).add_theme_stylebox_override("panel", NovaTheme.card_style())
	($VpnPanel as Panel).add_theme_stylebox_override("panel", NovaTheme.badge_style())
	($Ribbon as Panel).add_theme_stylebox_override("panel", NovaTheme.card_style())
	for card in [$WifiCard, $EthCard, $TempCard, $DiskCard]:
		(card as Panel).add_theme_stylebox_override("panel", NovaTheme.card_style())
	($RibbonMask as ColorRect).color = NovaPalette.BG
	($MarkLineL as ColorRect).color = NovaPalette.COPPER_DEEP
	($MarkLineR as ColorRect).color = NovaPalette.COPPER_DEEP

	NovaTheme.style_label($Wordmark, NovaTheme.tracked(NovaTheme.LIGHT, 12), 26, NovaPalette.COPPER_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	NovaTheme.style_label($ClockTime, NovaTheme.tracked(NovaTheme.SEMIBOLD, 0), 26, NovaPalette.AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	NovaTheme.style_label($ClockDate, NovaTheme.tracked(NovaTheme.REGULAR, 0), 13, NovaPalette.COPPER_SOFT, HORIZONTAL_ALIGNMENT_CENTER)

	var kicker := NovaTheme.tracked(NovaTheme.MEDIUM, 1)
	NovaTheme.style_label($PubCap, kicker, 11, NovaPalette.STEEL_DIM)
	NovaTheme.style_label($LocCap, kicker, 11, NovaPalette.STEEL_DIM)
	NovaTheme.style_label($PubVal, NovaTheme.tracked(NovaTheme.MEDIUM, 0), 16, NovaPalette.CREAM)
	NovaTheme.style_label($LocVal, NovaTheme.tracked(NovaTheme.MEDIUM, 0), 16, NovaPalette.CREAM)
	NovaTheme.style_label($VpnKicker, kicker, 11, NovaPalette.STEEL)
	NovaTheme.style_label($VpnState, NovaTheme.tracked(NovaTheme.SEMIBOLD, 1), 13, NovaPalette.AMBER)

	NovaTheme.style_label($ClusterCap, kicker, 12, NovaPalette.COPPER_SOFT)
	for cap in [$DownloadCap, $UploadCap, $PingCap]:
		NovaTheme.style_label(cap, kicker, 13, NovaPalette.COPPER_SOFT, HORIZONTAL_ALIGNMENT_CENTER)

	NovaTheme.style_label($RibbonCap, kicker, 12, NovaPalette.COPPER_SOFT)

	NovaTheme.style_label($WifiTitle, kicker, 13, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label($WifiSsid, NovaTheme.tracked(NovaTheme.MEDIUM, 0), 16, NovaPalette.CREAM)
	NovaTheme.style_label($WifiBand, NovaTheme.REGULAR, 13, NovaPalette.STEEL)
	NovaTheme.style_label($WifiRssi, NovaTheme.tracked(NovaTheme.MEDIUM, 0), 13, NovaPalette.AMBER)

	NovaTheme.style_label($EthTitle, kicker, 13, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label($EthRate, NovaTheme.tracked(NovaTheme.SEMIBOLD, 0), 20, NovaPalette.CREAM)
	NovaTheme.style_label($EthLink, NovaTheme.REGULAR, 13, NovaPalette.STEEL)

	NovaTheme.style_label($TempTitle, kicker, 13, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label($TempVal, NovaTheme.tracked(NovaTheme.SEMIBOLD, 0), 18, NovaPalette.CREAM)
	NovaTheme.style_label($DiskTitle, kicker, 13, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label($DiskVal, NovaTheme.tracked(NovaTheme.SEMIBOLD, 0), 18, NovaPalette.CREAM)

	for icon in [$VpnIcon, $WifiIcon, $EthIcon, $TempIcon, $DiskIcon]:
		(icon as GlyphIcon).glyph_color = NovaPalette.COPPER_SOFT
	($SignalIcon as GlyphIcon).glyph_color = NovaPalette.AMBER
	($EthDot as GlyphIcon).glyph_color = NovaPalette.AMBER


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if Telemetry.updated.is_connected(_apply):
		Telemetry.updated.disconnect(_apply)


func _apply() -> void:
	var data: Dictionary = Telemetry.snapshot()
	_raise_dial($Download as DialGauge, float(data.get("download_mbps", 0.0)))
	_raise_dial($Upload as DialGauge, float(data.get("upload_mbps", 0.0)))
	var ping := float(data.get("ping_ms", -1.0))
	_raise_dial($Ping as DialGauge, 0.0 if ping < 0.0 else ping)
	var cpu_ring := $Cpu as MiniRing
	var ram_ring := $Ram as MiniRing
	var cpu := float(data.get("cpu", -1.0))
	var ram := float(data.get("ram", -1.0))
	cpu_ring.ratio = 0.0 if cpu < 0.0 else cpu
	ram_ring.ratio = 0.0 if ram < 0.0 else ram
	cpu_ring.caption = "CPU"
	ram_ring.caption = "RAM"
	cpu_ring.icon_kind = GlyphIcon.Kind.CHIP
	ram_ring.icon_kind = GlyphIcon.Kind.MEMORY

	var spark := $Spark as Sparkline
	var samples := PackedFloat32Array()
	var peak := 0.0
	for sample in data.get("throughput", []):
		var mbps_value := float(sample)
		samples.append(mbps_value)
		peak = maxf(peak, mbps_value)
	spark.samples = samples
	spark.y_max = float(Metrics.spark_y_max(peak))
	spark.title = "THROUGHPUT (Mbps)"
	var labels := PackedStringArray()
	for label in data.get("throughput_labels", []):
		labels.append(str(label))
	spark.x_labels = labels

	var loc := _dash(str(data.get("loc_ip", "")))
	var router := _dash(str(data.get("router_ip", "")))
	var pub := _dash(str(data.get("pub_ip", "")))
	var path := $Path as NetworkPath
	path.left_title = "PI"
	path.left_addr = loc
	path.mid_title = "ROUTER"
	path.mid_addr = router
	path.right_title = "INTERNET"
	path.right_addr = pub
	$PubVal.text = pub
	$LocVal.text = loc
	$VpnState.text = "CONNECTED" if bool(data.get("vpn_connected", false)) else "OFFLINE"

	if bool(data.get("wifi_connected", false)):
		var ssid := str(data.get("ssid", ""))
		$WifiSsid.text = ssid if not ssid.is_empty() else "Connected"
		var band := str(data.get("band", ""))
		$WifiBand.text = band if not band.is_empty() else "N/A"
		if bool(data.get("rssi_known", false)):
			$WifiRssi.text = "%d dBm" % int(data.get("rssi_dbm", 0))
		else:
			$WifiRssi.text = "—"
		($SignalIcon as GlyphIcon).level = int(data.get("signal_level", 0))
	else:
		$WifiSsid.text = "Not connected"
		$WifiBand.text = "N/A"
		$WifiRssi.text = "—"
		($SignalIcon as GlyphIcon).level = 0

	var rate := str(data.get("eth_rate", ""))
	var link := str(data.get("eth_link", ""))
	if not bool(data.get("eth_present", false)):
		$EthRate.text = "N/A"
		$EthLink.text = "NO LINK"
	elif rate.is_empty():
		$EthRate.text = "—"
		$EthLink.text = link if not link.is_empty() else "LINK: down"
	else:
		$EthRate.text = rate
		$EthLink.text = link
	($EthDot as GlyphIcon).glyph_color = NovaPalette.AMBER if bool(data.get("eth_up", false)) else NovaPalette.STEEL

	if bool(data.get("temp_available", false)):
		var temp_c := float(data.get("temp_c", 0.0))
		var temp_scale := maxf(float(data.get("temp_scale_c", 85.0)), 1.0)
		$TempVal.text = "%.1f °C" % temp_c
		($TempBar as MeterBar).ratio = clampf(temp_c / temp_scale, 0.0, 1.0)
	else:
		$TempVal.text = "N/A"
		($TempBar as MeterBar).ratio = 0.0

	var disk_ratio := float(data.get("disk", -1.0))
	if disk_ratio < 0.0:
		$DiskVal.text = "N/A"
		($DiskBar as MeterBar).ratio = 0.0
	else:
		$DiskVal.text = str(int(round(disk_ratio * 100.0))) + "%"
		($DiskBar as MeterBar).ratio = disk_ratio


func _dash(text: String) -> String:
	return text if not text.is_empty() else "—"


func _raise_dial(dial: DialGauge, value: float) -> void:
	if value > dial.max_value:
		var scale: Dictionary = Metrics.gauge_scale(value, dial.max_value) as Dictionary
		dial.max_value = float(scale.max)
		dial.major_step = float(scale.major)
		dial.minor_step = float(scale.minor)
		dial.label_step = float(scale.label)
	dial.value = value


func _tick_clock() -> void:
	var now := Time.get_datetime_dict_from_system()
	$ClockTime.text = "%02d:%02d:%02d" % [int(now.hour), int(now.minute), int(now.second)]
	var weekday: int = int(now.weekday)
	var month: int = int(now.month)
	if weekday < 0 or weekday > 6 or month < 1 or month > 12:
		return
	$ClockDate.text = "%s, %d %s %d" % [_WEEKDAYS[weekday], int(now.day), _MONTHS[month - 1], int(now.year)]


func _layout() -> void:
	if size.x < 32.0 or size.y < 32.0:
		return
	var s := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	var origin := (size - DESIGN * s) * 0.5
	var dial := 214.0
	var dial_y := 108.0

	_place($ClockPanel, 16, 12, 236, 58, origin, s)
	_place($ClockTime, 24, 16, 220, 30, origin, s)
	_place($ClockDate, 24, 44, 220, 20, origin, s)

	_place($MarkLineL, 690, 38, 78, 1, origin, s)
	_place($Wordmark, 778, 18, 220, 40, origin, s)
	_place($MarkLineR, 1008, 38, 78, 1, origin, s)

	_place($PubCap, 1120, 16, 180, 14, origin, s)
	_place($PubVal, 1120, 32, 200, 22, origin, s)
	_place($LocCap, 1340, 16, 180, 14, origin, s)
	_place($LocVal, 1340, 32, 220, 22, origin, s)

	_place($VpnPanel, 1724, 12, 180, 58, origin, s)
	_place($VpnIcon, 1738, 28, 24, 24, origin, s)
	_place($VpnKicker, 1770, 18, 120, 16, origin, s)
	_place($VpnState, 1770, 36, 120, 20, origin, s)

	_place($ClusterCap, 20, 78, 480, 16, origin, s)
	_place($DownloadCap, 20, 94, dial, 16, origin, s)
	_place($UploadCap, 20 + dial + 18, 94, dial, 16, origin, s)
	_place($PingCap, DESIGN.x - 20 - dial, 94, dial, 16, origin, s)
	_place($Download, 20, dial_y, dial, dial, origin, s)
	_place($Upload, 20 + dial + 18, dial_y, dial, dial, origin, s)
	_place($Ping, DESIGN.x - 20 - dial, dial_y, dial, dial, origin, s)

	var center_x := 20.0 + dial * 2.0 + 18.0 + 28.0
	var center_r := DESIGN.x - 20.0 - dial - 28.0
	var center_w := center_r - center_x
	_place($Spark, center_x, 74, center_w, 108, origin, s)
	_place($Path, center_x, 184, center_w, 100, origin, s)
	var ring := 92.0
	var rings_x := center_x + center_w * 0.5 - ring - 18.0
	_place($Cpu, rings_x, 286, ring, 76, origin, s)
	_place($Ram, rings_x + ring + 36.0, 286, ring, 76, origin, s)

	_place($Ribbon, 16, 368, DESIGN.x - 32, 100, origin, s)
	_place($RibbonMask, 32, 360, 148, 16, origin, s)
	_place($RibbonCap, 36, 358, 140, 18, origin, s)

	var card_y := 386.0
	var card_h := 72.0
	var gap := 10.0
	var card_w := (DESIGN.x - 32.0 - 24.0 - gap * 3.0) / 4.0
	var card_x := 28.0
	_layout_wifi(card_x, card_y, card_w, card_h, origin, s)
	card_x += card_w + gap
	_layout_eth(card_x, card_y, card_w, card_h, origin, s)
	card_x += card_w + gap
	_layout_temp(card_x, card_y, card_w, card_h, origin, s)
	card_x += card_w + gap
	_layout_disk(card_x, card_y, card_w, card_h, origin, s)

	_scale_fonts(s)


func _layout_wifi(x: float, y: float, w: float, h: float, origin: Vector2, s: float) -> void:
	_place($WifiCard, x, y, w, h, origin, s)
	_place($WifiIcon, x + 12, y + 20, 28, 28, origin, s)
	_place($WifiTitle, x + 48, y + 4, 120, 16, origin, s)
	_place($WifiSsid, x + 48, y + 20, w - 100, 18, origin, s)
	_place($WifiBand, x + 48, y + 38, 100, 14, origin, s)
	_place($WifiRssi, x + 48, y + 52, 120, 16, origin, s)
	_place($SignalIcon, x + w - 52, y + 26, 36, 22, origin, s)


func _layout_eth(x: float, y: float, w: float, h: float, origin: Vector2, s: float) -> void:
	_place($EthCard, x, y, w, h, origin, s)
	_place($EthIcon, x + 12, y + 18, 30, 30, origin, s)
	_place($EthTitle, x + 50, y + 6, 140, 16, origin, s)
	_place($EthDot, x + 150, y + 10, 10, 10, origin, s)
	_place($EthRate, x + 50, y + 24, w - 66, 24, origin, s)
	_place($EthLink, x + 50, y + 50, w - 66, 16, origin, s)


func _layout_temp(x: float, y: float, w: float, h: float, origin: Vector2, s: float) -> void:
	_place($TempCard, x, y, w, h, origin, s)
	_place($TempIcon, x + 12, y + 10, 24, 24, origin, s)
	_place($TempTitle, x + 42, y + 8, 120, 16, origin, s)
	_place($TempVal, x + 42, y + 26, w - 56, 22, origin, s)
	_place($TempBar, x + 12, y + h - 16, w - 24, 8, origin, s)


func _layout_disk(x: float, y: float, w: float, h: float, origin: Vector2, s: float) -> void:
	_place($DiskCard, x, y, w, h, origin, s)
	_place($DiskIcon, x + 12, y + 10, 24, 24, origin, s)
	_place($DiskTitle, x + 42, y + 8, 120, 16, origin, s)
	_place($DiskVal, x + 42, y + 26, w - 56, 22, origin, s)
	_place($DiskBar, x + 12, y + h - 16, w - 24, 8, origin, s)


func _scale_fonts(s: float) -> void:
	var sizes := {
		$Wordmark: 26,
		$ClockTime: 26,
		$ClockDate: 13,
		$PubCap: 11,
		$LocCap: 11,
		$PubVal: 16,
		$LocVal: 16,
		$VpnKicker: 11,
		$VpnState: 13,
		$ClusterCap: 12,
		$DownloadCap: 13,
		$UploadCap: 13,
		$PingCap: 13,
		$RibbonCap: 12,
		$WifiTitle: 13,
		$WifiSsid: 16,
		$WifiBand: 13,
		$WifiRssi: 13,
		$EthTitle: 13,
		$EthRate: 20,
		$EthLink: 13,
		$TempTitle: 13,
		$TempVal: 18,
		$DiskTitle: 13,
		$DiskVal: 18,
	}
	for node in sizes:
		(node as Label).add_theme_font_size_override("font_size", maxi(int(round(float(sizes[node]) * s)), 8))


func _place(node: Control, x: float, y: float, w: float, h: float, origin: Vector2, s: float) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = origin + Vector2(x, y) * s
	node.size = Vector2(w, h) * s
