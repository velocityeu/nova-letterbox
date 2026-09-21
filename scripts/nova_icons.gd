class_name NovaIcons
extends RefCounted

## Small geometric icons drawn around `origin` (visual center).


static func wifi(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var dot := origin + Vector2(0, 6.5) * scale
	canvas.draw_circle(dot, 1.7 * scale, color)
	var width := maxf(1.35 * scale, 1.0)
	canvas.draw_arc(dot, 6.2 * scale, deg_to_rad(208), deg_to_rad(332), 16, color, width, true)
	canvas.draw_arc(dot, 11.0 * scale, deg_to_rad(208), deg_to_rad(332), 20, color, width, true)
	canvas.draw_arc(dot, 15.6 * scale, deg_to_rad(208), deg_to_rad(332), 24, color, width, true)


static func monitor(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var s := scale
	canvas.draw_rect(Rect2(origin + Vector2(-11, -9) * s, Vector2(22, 14) * s), color, false, maxf(1.4 * s, 1.0), true)
	canvas.draw_line(origin + Vector2(0, 5) * s, origin + Vector2(0, 9) * s, color, maxf(1.4 * s, 1.0), true)
	canvas.draw_line(origin + Vector2(-6, 9) * s, origin + Vector2(6, 9) * s, color, maxf(1.4 * s, 1.0), true)


static func port(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var s := scale
	canvas.draw_rect(Rect2(origin + Vector2(-9, -9) * s, Vector2(18, 18) * s), color, false, maxf(1.4 * s, 1.0), true)
	canvas.draw_rect(Rect2(origin + Vector2(-4, -1) * s, Vector2(8, 7) * s), color, false, maxf(1.3 * s, 1.0), true)


static func lock(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var s := scale
	canvas.draw_arc(origin + Vector2(0, -2) * s, 5.0 * s, PI, TAU, 16, color, maxf(1.5 * s, 1.0), true)
	canvas.draw_rect(Rect2(origin + Vector2(-6, 0) * s, Vector2(12, 9) * s), color, true)


static func thermometer(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var s := scale
	canvas.draw_line(origin + Vector2(0, -11) * s, origin + Vector2(0, 3) * s, color, maxf(2.2 * s, 1.2), true)
	canvas.draw_circle(origin + Vector2(0, 6) * s, 4.2 * s, color)
	canvas.draw_circle(origin + Vector2(0, 6) * s, 2.0 * s, NovaColors.CHARCOAL_ELEVATED)


static func disk(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var s := scale
	canvas.draw_rect(Rect2(origin + Vector2(-12, -8) * s, Vector2(24, 16) * s), color, false, maxf(1.4 * s, 1.0), true)
	canvas.draw_line(origin + Vector2(-12, -2) * s, origin + Vector2(12, -2) * s, color, maxf(1.1 * s, 1.0), true)
	canvas.draw_circle(origin + Vector2(6, 3) * s, 1.6 * s, color)


static func chip(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var s := scale
	canvas.draw_rect(Rect2(origin + Vector2(-6, -6) * s, Vector2(12, 12) * s), color, false, maxf(1.3 * s, 1.0), true)
	for i in range(-1, 2):
		var y := float(i) * 4.0
		canvas.draw_line(origin + Vector2(-10, y) * s, origin + Vector2(-6, y) * s, color, maxf(1.2 * s, 1.0), true)
		canvas.draw_line(origin + Vector2(6, y) * s, origin + Vector2(10, y) * s, color, maxf(1.2 * s, 1.0), true)


static func ram(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var s := scale
	canvas.draw_rect(Rect2(origin + Vector2(-10, -4) * s, Vector2(20, 10) * s), color, false, maxf(1.3 * s, 1.0), true)
	for i in 4:
		var x := -6.0 + float(i) * 4.0
		canvas.draw_line(origin + Vector2(x, -4) * s, origin + Vector2(x, -8) * s, color, maxf(1.2 * s, 1.0), true)


static func cluster(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var pts: Array[Vector2] = [
		Vector2(-5.5, -3.5), Vector2(5.0, -4.5), Vector2(5.5, 4.0), Vector2(-5.0, 4.5),
	]
	for i in pts.size():
		var a := origin + pts[i] * scale
		var b := origin + pts[(i + 1) % pts.size()] * scale
		canvas.draw_line(a, b, color, maxf(1.1 * scale, 1.0), true)
	for p in pts:
		canvas.draw_circle(origin + p * scale, maxf(1.7 * scale, 1.2), color)


static func cross(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var arm := 3.4 * scale
	canvas.draw_line(origin + Vector2(-arm, -arm), origin + Vector2(arm, arm), color, maxf(1.5 * scale, 1.0), true)
	canvas.draw_line(origin + Vector2(-arm, arm), origin + Vector2(arm, -arm), color, maxf(1.5 * scale, 1.0), true)


static func globe(canvas: CanvasItem, origin: Vector2, scale: float, color: Color) -> void:
	var s := scale
	canvas.draw_line(origin + Vector2(-7.2, 0) * s, origin + Vector2(7.2, 0) * s, color, maxf(1.1 * s, 1.0), true)
	var meridian := PackedVector2Array()
	for i in 14:
		var t := float(i) / 13.0
		var a := lerpf(-PI * 0.5, PI * 0.5, t)
		meridian.append(origin + Vector2(sin(a) * 3.1 * s, -cos(a) * 7.2 * s))
	canvas.draw_polyline(meridian, color, maxf(1.1 * s, 1.0), true)


static func bars(canvas: CanvasItem, origin: Vector2, scale: float, color: Color, lit: int) -> void:
	for i in 4:
		var h := (5.0 + float(i) * 4.0) * scale
		var x := float(i) * 6.0 * scale
		var shade := color if i < lit else Color(color.r, color.g, color.b, 0.28)
		canvas.draw_rect(Rect2(origin + Vector2(x, -h), Vector2(3.2 * scale, h)), shade, true)
