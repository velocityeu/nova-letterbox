@tool
extends Control

## Default letterbox view: wordmark, three dials, link status.


func _ready() -> void:
	_layout()
	_apply_demo()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if get_node_or_null("Download") == null:
		return
	var dial_size := Vector2(400, 340)
	var centers: Array[float] = [320.0, 960.0, 1600.0]
	var dials: Array[Node] = [$Download, $Upload, $Ping]
	for i in dials.size():
		var left := centers[i] - dial_size.x * 0.5
		_place(dials[i] as Control, Rect2(Vector2(left, 52), dial_size))


func _apply_demo() -> void:
	($Download as NovaDial).bind(
		DemoTelemetry.SIMPLE_DOWNLOAD_MBPS, DemoTelemetry.SIMPLE_SCALE_MAX, 25.0, 0,
		"", "DOWNLOAD Mbps", false, ""
	)
	($Upload as NovaDial).bind(
		DemoTelemetry.SIMPLE_UPLOAD_MBPS, DemoTelemetry.SIMPLE_SCALE_MAX, 25.0, 0,
		"", "UPLOAD Mbps", false, ""
	)
	($Ping as NovaDial).bind(
		DemoTelemetry.SIMPLE_PING_MS, DemoTelemetry.SIMPLE_SCALE_MAX, 25.0, 0,
		"", "PING ms", false, ""
	)


func _draw() -> void:
	if size.x < 10.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), NovaColors.CHARCOAL, true)
	var inset := 8.0
	draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0), NovaColors.HAIRLINE, false, 1.0, true)

	var wordmark := NovaFonts.variation("light", 16)
	NovaFonts.draw_centered(self, wordmark, Vector2(size.x * 0.5, 30), "NOVA", 28, NovaColors.COPPER_LIGHT)

	var line_y := 412.0
	draw_line(Vector2(64, line_y), Vector2(size.x - 64, line_y), NovaColors.HAIRLINE, 1.0, true)
	_draw_status(446.0)


func _draw_status(y: float) -> void:
	var font := NovaFonts.variation("regular", 1)
	var text_size := 18
	NovaIcons.wifi(self, Vector2(52, y), 0.72, NovaColors.MIST)
	NovaFonts.draw_centered(self, font, Vector2(168, y), "Wi-Fi Connected", text_size, NovaColors.MIST)

	var eth := "Ethernet Link"
	var eth_w := NovaFonts.width_of(font, eth, text_size)
	var right := size.x - 64.0
	var text_center_x := right - eth_w * 0.5
	NovaFonts.draw_centered(self, font, Vector2(text_center_x, y), eth, text_size, NovaColors.MIST)
	NovaIcons.monitor(self, Vector2(text_center_x - eth_w * 0.5 - 22.0, y), 0.85, NovaColors.MIST)


func _place(node: Control, rect: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
