@tool
extends Control

## Simple letterbox. Laid out in a 1920×480 design space and scaled to fit
## so Download, Upload, and Ping stay on screen together.

const Metrics = preload("res://scripts/linux_metrics.gd")
const DESIGN := Vector2(1920, 480)

@onready var _download: DialGauge = $Download
@onready var _upload: DialGauge = $Upload
@onready var _ping: DialGauge = $Ping


func _ready() -> void:
	_style()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	if Engine.is_editor_hint():
		call_deferred("_layout")
		return
	Telemetry.updated.connect(_apply)
	_apply()
	call_deferred("_layout")


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if Telemetry.updated.is_connected(_apply):
		Telemetry.updated.disconnect(_apply)


func _style() -> void:
	($Chrome as Panel).add_theme_stylebox_override("panel", NovaTheme.frame_style())
	NovaTheme.style_label(
		$Wordmark,
		NovaTheme.tracked(NovaTheme.LIGHT, 18),
		30,
		NovaPalette.COPPER_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var caption_font := NovaTheme.tracked(NovaTheme.MEDIUM, 1)
	for node in [$DownloadCaption, $UploadCaption, $PingCaption]:
		NovaTheme.style_label(node, caption_font, 18, NovaPalette.COPPER_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	($Rule as ColorRect).color = Color(0.55, 0.40, 0.28, 1)
	var status_font := NovaTheme.tracked(NovaTheme.REGULAR, 1)
	NovaTheme.style_label($WifiLabel, status_font, 16, NovaPalette.STEEL_LIGHT)
	NovaTheme.style_label($EthLabel, status_font, 16, NovaPalette.STEEL_LIGHT)
	($WifiIcon as GlyphIcon).glyph_color = NovaPalette.COPPER_SOFT
	($EthIcon as GlyphIcon).glyph_color = NovaPalette.COPPER_SOFT


func _apply() -> void:
	var data: Dictionary = Telemetry.snapshot()
	_raise_dial(_download, float(data.get("download_mbps", 0.0)))
	_raise_dial(_upload, float(data.get("upload_mbps", 0.0)))
	var ping := float(data.get("ping_ms", -1.0))
	_raise_dial(_ping, 0.0 if ping < 0.0 else ping)
	var wifi: Label = $WifiLabel
	var eth: Label = $EthLabel
	wifi.text = "Wi-Fi Connected" if bool(data.get("wifi_connected", false)) else "Wi-Fi not connected"
	eth.text = _ethernet_status(data)
	_layout()


func _ethernet_status(data: Dictionary) -> String:
	if not bool(data.get("eth_present", false)):
		return "Ethernet N/A"
	if not bool(data.get("eth_up", false)):
		return "Ethernet down"
	var link := str(data.get("eth_link", ""))
	if link.begins_with("LINK: ") and link != "LINK: up" and link != "LINK: down":
		return "Ethernet " + link.trim_prefix("LINK: ")
	if bool(data.get("eth_up", false)):
		return "Ethernet Link"
	return "Ethernet N/A"


func _raise_dial(dial: DialGauge, value: float) -> void:
	if value > dial.max_value:
		var scale: Dictionary = Metrics.gauge_scale(value, dial.max_value) as Dictionary
		dial.max_value = float(scale.max)
		dial.major_step = float(scale.major)
		dial.minor_step = float(scale.minor)
		dial.label_step = float(scale.label)
	dial.value = value


func _layout() -> void:
	if size.x < 32.0 or size.y < 32.0:
		return
	var s := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	var origin := (size - DESIGN * s) * 0.5
	var dial := 332.0
	var gap := dial * 0.24
	var cluster := dial * 3.0 + gap * 2.0
	var left := (DESIGN.x - cluster) * 0.5
	var dial_y := 46.0

	_place($Wordmark, 0, 10, DESIGN.x, 34, origin, s)
	_place($Download, left, dial_y, dial, dial, origin, s)
	_place($Upload, left + dial + gap, dial_y, dial, dial, origin, s)
	_place($Ping, left + (dial + gap) * 2.0, dial_y, dial, dial, origin, s)
	var cap_y := dial_y + dial + 4.0
	_place($DownloadCaption, left, cap_y, dial, 24, origin, s)
	_place($UploadCaption, left + dial + gap, cap_y, dial, 24, origin, s)
	_place($PingCaption, left + (dial + gap) * 2.0, cap_y, dial, 24, origin, s)

	_place($Rule, left, 414, cluster, 1, origin, s)
	_place($WifiIcon, left, 428, 26, 26, origin, s)
	_place($WifiLabel, left + 34, 424, 280, 32, origin, s)
	var status_px := maxi(int(round(16.0 * s)), 10)
	($EthLabel as Label).add_theme_font_size_override("font_size", status_px)
	var eth_font := ($EthLabel as Label).get_theme_font("font")
	var eth_w := eth_font.get_string_size($EthLabel.text, HORIZONTAL_ALIGNMENT_LEFT, -1, status_px).x / s + 2.0
	_place($EthLabel, left + cluster - eth_w, 424, eth_w, 32, origin, s)
	_place($EthIcon, left + cluster - eth_w - 32.0, 428, 26, 26, origin, s)

	var caption_px := maxi(int(round(18.0 * s)), 10)
	var word_px := maxi(int(round(30.0 * s)), 14)
	for node in [$DownloadCaption, $UploadCaption, $PingCaption]:
		(node as Label).add_theme_font_size_override("font_size", caption_px)
	($Wordmark as Label).add_theme_font_size_override("font_size", word_px)
	($WifiLabel as Label).add_theme_font_size_override("font_size", status_px)
	($EthLabel as Label).add_theme_font_size_override("font_size", status_px)


func _place(node: Control, x: float, y: float, w: float, h: float, origin: Vector2, s: float) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = origin + Vector2(x, y) * s
	node.size = Vector2(w, h) * s
