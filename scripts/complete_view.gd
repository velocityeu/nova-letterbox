@tool
extends Control

## Alternate letterbox view: dials plus sparkline, path, rings, and ribbon.

func _ready() -> void:
	_layout()
	_apply_demo()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if get_node_or_null("TopBar") == null:
		return
	_place($TopBar, Rect2(18, 12, 1884, 52))
	_place($Download, Rect2(16, 88, 212, 274))
	_place($Upload, Rect2(232, 88, 212, 274))
	_place($Ping, Rect2(1692, 88, 212, 274))
	_place($Sparkline, Rect2(460, 68, 1212, 116))
	_place($NetworkPath, Rect2(472, 184, 1188, 100))
	_place($Cpu, Rect2(918, 284, 146, 86))
	_place($Ram, Rect2(1076, 284, 146, 86))
	_place($Ribbon, Rect2(16, 372, 1888, 98))


func _apply_demo() -> void:
	($Download as NovaDial).bind(
		DemoTelemetry.COMPLETE_DOWNLOAD_MBPS, DemoTelemetry.COMPLETE_SCALE_MAX, 10.0, 1,
		"DOWNLOAD", "", true, "Mbps"
	)
	($Upload as NovaDial).bind(
		DemoTelemetry.COMPLETE_UPLOAD_MBPS, DemoTelemetry.COMPLETE_SCALE_MAX, 10.0, 1,
		"UPLOAD", "", true, "Mbps"
	)
	($Ping as NovaDial).bind(
		DemoTelemetry.COMPLETE_PING_MS, DemoTelemetry.COMPLETE_SCALE_MAX, 10.0, 0,
		"PING", "", true, "ms"
	)
	var cpu := $Cpu as Control
	cpu.set("percent", DemoTelemetry.CPU_PERCENT)
	cpu.set("icon_name", "chip")
	cpu.queue_redraw()
	var ram := $Ram as Control
	ram.set("percent", DemoTelemetry.RAM_PERCENT)
	ram.set("icon_name", "ram")
	ram.queue_redraw()


func _draw() -> void:
	if size.x < 10.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), NovaColors.CHARCOAL_DEEP, true)
	NovaTheme.paint_panel(self, Rect2(6, 6, size.x - 12, size.y - 12), 10.0, 0.62, NovaColors.CHARCOAL)
	_draw_cluster_label()


func _draw_cluster_label() -> void:
	var mark_font := NovaFonts.variation("semibold", 1)
	var title_font := NovaFonts.variation("medium", 2)
	NovaFonts.draw_text(self, mark_font, Vector2(22, 80), "B", 12, NovaColors.AMBER)
	NovaFonts.draw_text(self, title_font, Vector2(40, 80), "TELEMETRY CLUSTER", 12, NovaColors.STEEL)


func _place(node: Node, rect: Rect2) -> void:
	var control := node as Control
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
