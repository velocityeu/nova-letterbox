@tool
extends Control

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if has_node("Clock"):
		return
	var timer := Timer.new()
	timer.name = "Clock"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(queue_redraw)
	add_child(timer)


func _draw() -> void:
	if size.x < 40.0:
		return
	_draw_clock(Rect2(0, 0, 228, size.y))
	_draw_wordmark()
	_draw_addresses(size.x - 214 - 360)
	_draw_vpn(Rect2(size.x - 206, 0, 206, size.y))


func _draw_clock(rect: Rect2) -> void:
	NovaTheme.paint_panel(self, rect, 2.0, 0.85)
	var now := _now()
	var time_font := NovaFonts.variation("semibold", 1)
	var date_font := NovaFonts.variation("regular", 0)
	var time_text := "%02d:%02d:%02d" % [int(now.hour), int(now.minute), int(now.second)]
	var date_text := "%s, %d %s %d" % [
		DemoTelemetry.WEEKDAYS[int(now.weekday)],
		int(now.day),
		DemoTelemetry.MONTHS[int(now.month) - 1],
		int(now.year),
	]
	NovaFonts.draw_centered(self, time_font, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.36), time_text, 26, NovaColors.AMBER)
	NovaFonts.draw_centered(self, date_font, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.74), date_text, 13, NovaColors.STEEL)


func _draw_wordmark() -> void:
	var font := NovaFonts.variation("light", 14)
	var text := "NOVA"
	var text_w := NovaFonts.width_of(font, text, 26)
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var gap := 12.0
	var line := 48.0
	var y := center.y
	var left := center.x - text_w * 0.5
	draw_line(Vector2(left - gap - line, y), Vector2(left - gap, y), NovaColors.COPPER, 1.25, true)
	draw_line(Vector2(left + text_w + gap, y), Vector2(left + text_w + gap + line, y), NovaColors.COPPER, 1.25, true)
	NovaFonts.draw_centered(self, font, center, text, 26, NovaColors.COPPER_LIGHT)


func _draw_addresses(left: float) -> void:
	var header := NovaFonts.variation("medium", 1)
	var value := NovaFonts.variation("regular", 0)
	var col_w := 168.0
	var headers := ["PUB IP", "LOC IP"]
	var values := [DemoTelemetry.PUB_IP, DemoTelemetry.LOC_IP]
	for i in 2:
		var x := left + float(i) * col_w
		NovaFonts.draw_text(self, header, Vector2(x, 20), headers[i], 12, NovaColors.STEEL)
		NovaFonts.draw_text(self, value, Vector2(x, 42), values[i], 16, NovaColors.AMBER)


func _draw_vpn(rect: Rect2) -> void:
	NovaTheme.paint_panel(self, rect, 6.0, 0.9)
	var center := rect.position + rect.size * 0.5
	NovaIcons.lock(self, center + Vector2(0, -12), 0.85, NovaColors.AMBER)
	var small := NovaFonts.variation("medium", 2)
	var state := NovaFonts.variation("semibold", 1)
	NovaFonts.draw_centered(self, small, center + Vector2(0, 4), "VPN", 11, NovaColors.STEEL)
	NovaFonts.draw_centered(self, state, center + Vector2(0, 18), DemoTelemetry.VPN_STATE, 13, NovaColors.AMBER)


func _now() -> Dictionary:
	if Engine.is_editor_hint():
		return {"hour": 10, "minute": 24, "second": 37, "weekday": 6, "day": 24, "month": 5, "year": 2025}
	return Time.get_datetime_dict_from_system()
