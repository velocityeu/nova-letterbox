@tool
extends Control

func _draw() -> void:
	if size.x < 80.0 or size.y < 40.0:
		return
	var gap := 12.0
	var card_w := (size.x - gap * 3.0) / 4.0
	for i in 4:
		var rect := Rect2(float(i) * (card_w + gap), 0, card_w, size.y)
		NovaTheme.paint_panel(self, rect, 4.0, 0.7)
		match i:
			0:
				_draw_wifi(rect)
			1:
				_draw_ethernet(rect)
			2:
				_draw_temp(rect)
			3:
				_draw_disk(rect)


func _draw_wifi(rect: Rect2) -> void:
	var origin := rect.position
	var h := rect.size.y
	NovaIcons.wifi(self, origin + Vector2(34, h * 0.46), 0.82, NovaColors.AMBER)
	var label := NovaFonts.variation("medium", 1)
	var strong := NovaFonts.variation("semibold", 0)
	var small := NovaFonts.variation("regular", 0)
	var x := origin.x + 64.0
	NovaFonts.draw_text(self, label, Vector2(x, origin.y + h * 0.24), "Wi-Fi", 12, NovaColors.STEEL)
	NovaFonts.draw_text(self, strong, Vector2(x, origin.y + h * 0.48), DemoTelemetry.WIFI_SSID, 20, NovaColors.MIST)
	NovaFonts.draw_text(self, small, Vector2(x, origin.y + h * 0.68), DemoTelemetry.WIFI_BAND, 13, NovaColors.STEEL)
	NovaFonts.draw_text(self, strong, Vector2(x, origin.y + h * 0.90), "%d dBm" % DemoTelemetry.WIFI_DBM, 15, NovaColors.AMBER)
	NovaIcons.bars(self, origin + Vector2(rect.size.x - 50.0, h * 0.46), 1.05, NovaColors.AMBER, _bars_for_dbm(DemoTelemetry.WIFI_DBM))


func _draw_ethernet(rect: Rect2) -> void:
	var origin := rect.position
	var h := rect.size.y
	NovaIcons.port(self, origin + Vector2(34, h * 0.42), 1.05, NovaColors.AMBER)
	var label := NovaFonts.variation("medium", 1)
	var strong := NovaFonts.variation("semibold", 0)
	var x := origin.x + 64.0
	NovaFonts.draw_text(self, label, Vector2(x, origin.y + h * 0.28), "Ethernet", 13, NovaColors.STEEL)
	NovaFonts.draw_text(self, strong, Vector2(x, origin.y + h * 0.56), DemoTelemetry.ETH_RATE, 24, NovaColors.MIST)
	draw_circle(origin + Vector2(rect.size.x - 28.0, h * 0.42), 4.5, NovaColors.AMBER)
	NovaFonts.draw_text(self, strong, Vector2(x, origin.y + h * 0.88), "LINK: %s" % DemoTelemetry.ETH_LINK, 14, NovaColors.AMBER)


func _draw_temp(rect: Rect2) -> void:
	var origin := rect.position
	var h := rect.size.y
	NovaIcons.thermometer(self, origin + Vector2(32, h * 0.38), 0.95, NovaColors.AMBER)
	var label := NovaFonts.variation("medium", 1)
	var strong := NovaFonts.variation("semibold", 0)
	var x := origin.x + 60.0
	NovaFonts.draw_text(self, label, Vector2(x, origin.y + h * 0.30), "Pi TEMP", 13, NovaColors.STEEL)
	NovaFonts.draw_text(self, strong, Vector2(x, origin.y + h * 0.58), "%.1f °C" % DemoTelemetry.PI_TEMP_C, 24, NovaColors.MIST)
	var frac := clampf(DemoTelemetry.PI_TEMP_C / DemoTelemetry.PI_TEMP_SCALE_C, 0.0, 1.0)
	_bar(rect, frac)


func _draw_disk(rect: Rect2) -> void:
	var origin := rect.position
	var h := rect.size.y
	NovaIcons.disk(self, origin + Vector2(34, h * 0.38), 0.95, NovaColors.AMBER)
	var label := NovaFonts.variation("medium", 1)
	var strong := NovaFonts.variation("semibold", 0)
	var x := origin.x + 64.0
	NovaFonts.draw_text(self, label, Vector2(x, origin.y + h * 0.30), "DISK", 13, NovaColors.STEEL)
	NovaFonts.draw_text(self, strong, Vector2(x, origin.y + h * 0.58), "%d%%" % int(round(DemoTelemetry.DISK_PERCENT)), 24, NovaColors.MIST)
	_bar(rect, clampf(DemoTelemetry.DISK_PERCENT / 100.0, 0.0, 1.0))


func _bars_for_dbm(dbm: int) -> int:
	if dbm >= -50:
		return 4
	if dbm >= -60:
		return 3
	if dbm >= -70:
		return 2
	if dbm >= -80:
		return 1
	return 0


func _bar(rect: Rect2, fraction: float) -> void:
	var y := rect.end.y - 12.0
	var x0 := rect.position.x + 16.0
	var x1 := rect.end.x - 16.0
	draw_line(Vector2(x0, y), Vector2(x1, y), NovaColors.TRACK, 8.0, true)
	var fill := lerpf(x0, x1, fraction)
	if fill - x0 > 1.0:
		draw_line(Vector2(x0, y), Vector2(fill, y), NovaColors.AMBER, 8.0, true)
