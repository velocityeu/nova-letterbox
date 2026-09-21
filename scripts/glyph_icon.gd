@tool
class_name GlyphIcon
extends Control

enum Kind {
	WIFI,
	ETHERNET,
	LOCK,
	THERMO,
	DISK,
	CHIP,
	MEMORY,
	PI,
	ROUTER,
	GLOBE,
	SIGNAL,
	DOT,
}

@export var kind: Kind = Kind.WIFI:
	set(value):
		kind = value
		queue_redraw()

@export var glyph_color: Color = NovaPalette.COPPER:
	set(value):
		glyph_color = value
		queue_redraw()

## Bars lit on SIGNAL icons, 0–4.
@export var level: int = 4:
	set(value):
		level = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_kind(self, kind, Rect2(Vector2.ZERO, size), glyph_color, level)


static func draw_kind(canvas: CanvasItem, icon_kind: Kind, rect: Rect2, color: Color, bars: int = 4) -> void:
	match icon_kind:
		Kind.WIFI:
			_wifi(canvas, rect, color)
		Kind.ETHERNET:
			_ethernet(canvas, rect, color)
		Kind.LOCK:
			_lock(canvas, rect, color)
		Kind.THERMO:
			_thermo(canvas, rect, color)
		Kind.DISK:
			_disk(canvas, rect, color)
		Kind.CHIP:
			_chip(canvas, rect, color)
		Kind.MEMORY:
			_memory(canvas, rect, color)
		Kind.PI:
			_pi(canvas, rect, color)
		Kind.ROUTER:
			_router(canvas, rect, color)
		Kind.GLOBE:
			_globe(canvas, rect, color)
		Kind.SIGNAL:
			_signal(canvas, rect, color, bars)
		Kind.DOT:
			var radius := minf(rect.size.x, rect.size.y) * 0.38
			canvas.draw_circle(rect.get_center(), radius, color)


static func _stroke(rect: Rect2) -> float:
	return maxf(1.25, minf(rect.size.x, rect.size.y) * 0.075)


static func _wifi(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var origin := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.78)
	canvas.draw_circle(origin, width * 0.85, color)
	var radii: Array[float] = [
		rect.size.x * 0.20,
		rect.size.x * 0.36,
		rect.size.x * 0.52,
	]
	for radius in radii:
		canvas.draw_arc(origin, radius, deg_to_rad(200), deg_to_rad(340), 18, color, width, true)


static func _ethernet(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var body := Rect2(
		rect.position + rect.size * Vector2(0.18, 0.22),
		rect.size * Vector2(0.64, 0.46)
	)
	_round_rect(canvas, body, 2.0, color, width)
	var pin_y := body.position.y + body.size.y * 0.62
	var pin_w := body.size.x * 0.12
	var gap := body.size.x * 0.08
	var start_x := body.position.x + body.size.x * 0.18
	for i in 3:
		var pin := Rect2(Vector2(start_x + i * (pin_w + gap), pin_y), Vector2(pin_w, body.size.y * 0.22))
		canvas.draw_rect(pin, color, true)


static func _lock(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var body := Rect2(
		rect.position + rect.size * Vector2(0.22, 0.46),
		rect.size * Vector2(0.56, 0.38)
	)
	_round_rect(canvas, body, 2.0, color, width)
	var center := Vector2(rect.get_center().x, body.position.y)
	canvas.draw_arc(center, rect.size.x * 0.20, deg_to_rad(180), deg_to_rad(360), 16, color, width, true)


static func _thermo(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var bulb_c := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.74)
	var bulb_r := rect.size.x * 0.16
	canvas.draw_circle(bulb_c, bulb_r, color)
	var stem := Rect2(
		Vector2(bulb_c.x - width * 0.65, rect.position.y + rect.size.y * 0.16),
		Vector2(width * 1.3, bulb_c.y - bulb_r * 0.4 - (rect.position.y + rect.size.y * 0.16))
	)
	canvas.draw_rect(stem, color, true)
	canvas.draw_circle(Vector2(bulb_c.x, rect.position.y + rect.size.y * 0.16), width * 0.65, color)


static func _disk(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var body := Rect2(rect.position + rect.size * Vector2(0.12, 0.28), rect.size * Vector2(0.76, 0.46))
	_round_rect(canvas, body, 3.0, color, width)
	canvas.draw_line(
		Vector2(body.position.x + 3, body.position.y + body.size.y * 0.38),
		Vector2(body.end.x - 3, body.position.y + body.size.y * 0.38),
		color,
		width,
		true
	)


static func _chip(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var body := Rect2(rect.position + rect.size * Vector2(0.28, 0.28), rect.size * Vector2(0.44, 0.44))
	_round_rect(canvas, body, 2.0, color, width)
	var pins := 2
	for i in pins:
		var t := (i + 1) / float(pins + 1)
		var y := body.position.y + body.size.y * t
		var x := body.position.x + body.size.x * t
		canvas.draw_line(Vector2(rect.position.x + rect.size.x * 0.12, y), Vector2(body.position.x, y), color, width, true)
		canvas.draw_line(Vector2(body.end.x, y), Vector2(rect.end.x - rect.size.x * 0.12, y), color, width, true)
		canvas.draw_line(Vector2(x, rect.position.y + rect.size.y * 0.12), Vector2(x, body.position.y), color, width, true)
		canvas.draw_line(Vector2(x, body.end.y), Vector2(x, rect.end.y - rect.size.y * 0.12), color, width, true)


static func _memory(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var board := Rect2(rect.position + rect.size * Vector2(0.16, 0.30), rect.size * Vector2(0.68, 0.40))
	_round_rect(canvas, board, 2.0, color, width)
	for i in 4:
		var x := board.position.x + board.size.x * ((i + 1) / 5.0)
		canvas.draw_line(
			Vector2(x, board.position.y + width),
			Vector2(x, board.end.y - width),
			color,
			maxf(1.0, width * 0.7),
			true
		)


static func _pi(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var center := rect.get_center()
	var arm := rect.size * 0.28
	var points: Array[Vector2] = [
		center + Vector2(-arm.x, -arm.y * 0.15),
		center + Vector2(arm.x, -arm.y * 0.55),
		center + Vector2(arm.x * 0.15, arm.y),
	]
	for point in points:
		canvas.draw_line(center, point, color, width, true)
	canvas.draw_circle(center, width * 1.15, color)
	for point in points:
		canvas.draw_arc(point, width * 1.35, 0, TAU, 12, color, width, true)


static func _router(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.30
	canvas.draw_arc(center, radius, 0, TAU, 24, color, width, true)
	var d := radius * 0.48
	canvas.draw_line(center + Vector2(-d, -d), center + Vector2(d, d), color, width, true)
	canvas.draw_line(center + Vector2(-d, d), center + Vector2(d, -d), color, width, true)


static func _globe(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.34
	canvas.draw_arc(center, radius, 0, TAU, 28, color, width, true)
	canvas.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, width, true)
	canvas.draw_arc(center, radius * 0.55, deg_to_rad(90), deg_to_rad(270), 16, color, width, true)
	canvas.draw_arc(center, radius * 0.55, deg_to_rad(-90), deg_to_rad(90), 16, color, width, true)


static func _signal(canvas: CanvasItem, rect: Rect2, color: Color, bars: int) -> void:
	var count := 4
	var gap := rect.size.x * 0.08
	var bar_w := (rect.size.x - gap * (count - 1)) / count
	var dim := Color(color.r, color.g, color.b, 0.28)
	for i in count:
		var h := rect.size.y * (0.35 + 0.2 * i)
		var x := rect.position.x + i * (bar_w + gap)
		var y := rect.end.y - h
		var fill := color if i < bars else dim
		canvas.draw_rect(Rect2(Vector2(x, y), Vector2(bar_w, h)), fill, true)


static func _round_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color, width: float) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	canvas.draw_line(Vector2(x + r, y), Vector2(x + w - r, y), color, width, true)
	canvas.draw_line(Vector2(x + w, y + r), Vector2(x + w, y + h - r), color, width, true)
	canvas.draw_line(Vector2(x + w - r, y + h), Vector2(x + r, y + h), color, width, true)
	canvas.draw_line(Vector2(x, y + h - r), Vector2(x, y + r), color, width, true)
	canvas.draw_arc(Vector2(x + r, y + r), r, deg_to_rad(180), deg_to_rad(270), 8, color, width, true)
	canvas.draw_arc(Vector2(x + w - r, y + r), r, deg_to_rad(270), deg_to_rad(360), 8, color, width, true)
	canvas.draw_arc(Vector2(x + w - r, y + h - r), r, 0, deg_to_rad(90), 8, color, width, true)
	canvas.draw_arc(Vector2(x + r, y + h - r), r, deg_to_rad(90), deg_to_rad(180), 8, color, width, true)
