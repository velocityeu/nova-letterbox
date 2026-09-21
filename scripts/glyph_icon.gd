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

@export var glyph_color: Color = NovaPalette.COPPER_SOFT:
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
	if not resized.is_connected(queue_redraw):
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
			canvas.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.34, color)


static func _stroke(rect: Rect2) -> float:
	return maxf(1.35, minf(rect.size.x, rect.size.y) * 0.07)


static func _wifi(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var origin := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.80)
	canvas.draw_circle(origin, width * 0.72, color)
	var radii: Array[float] = [rect.size.x * 0.22, rect.size.x * 0.38, rect.size.x * 0.54]
	for radius in radii:
		canvas.draw_arc(origin, radius, deg_to_rad(206), deg_to_rad(334), 18, color, width, true)


static func _ethernet(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var body := Rect2(rect.position + rect.size * Vector2(0.22, 0.18), rect.size * Vector2(0.56, 0.50))
	_round_rect(canvas, body, 2.0, color, width)
	var notch := Rect2(
		Vector2(body.position.x + body.size.x * 0.28, body.position.y + body.size.y * 0.55),
		Vector2(body.size.x * 0.44, body.size.y * 0.45)
	)
	canvas.draw_rect(notch, color, false, width)
	var pin_y := body.position.y + body.size.y * 0.28
	for i in 3:
		var x := body.position.x + body.size.x * (0.30 + i * 0.20)
		canvas.draw_line(Vector2(x, pin_y), Vector2(x, pin_y + body.size.y * 0.16), color, width, true)


static func _lock(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var body := Rect2(rect.position + rect.size * Vector2(0.22, 0.46), rect.size * Vector2(0.56, 0.40))
	_round_rect(canvas, body, 2.0, color, width)
	canvas.draw_arc(
		Vector2(rect.get_center().x, body.position.y),
		rect.size.x * 0.18,
		PI,
		TAU,
		16,
		color,
		width,
		true
	)


static func _thermo(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var bulb := rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.74)
	var bulb_r := rect.size.x * 0.16
	canvas.draw_circle(bulb, bulb_r, color)
	var stem := Rect2(
		Vector2(bulb.x - width * 0.7, rect.position.y + rect.size.y * 0.12),
		Vector2(width * 1.4, bulb.y - bulb_r * 0.2 - rect.position.y - rect.size.y * 0.12)
	)
	canvas.draw_rect(stem, color, true)
	canvas.draw_circle(Vector2(bulb.x, rect.position.y + rect.size.y * 0.14), width * 0.7, color)
	var tick_x := bulb.x + width * 1.6
	for i in 3:
		var y := rect.position.y + rect.size.y * (0.28 + i * 0.12)
		canvas.draw_line(Vector2(tick_x, y), Vector2(tick_x + rect.size.x * 0.12, y), color, width * 0.8, true)


static func _disk(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var body := Rect2(rect.position + rect.size * Vector2(0.14, 0.28), rect.size * Vector2(0.72, 0.46))
	_round_rect(canvas, body, 3.0, color, width)
	canvas.draw_line(
		Vector2(body.position.x + 2.0, body.position.y + body.size.y * 0.32),
		Vector2(body.end.x - 2.0, body.position.y + body.size.y * 0.32),
		color,
		width,
		true
	)
	canvas.draw_circle(body.position + Vector2(body.size.x * 0.78, body.size.y * 0.68), width * 0.55, color)


static func _chip(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var body := Rect2(rect.position + rect.size * Vector2(0.28, 0.28), rect.size * Vector2(0.44, 0.44))
	_round_rect(canvas, body, 1.5, color, width)
	for i in 3:
		var t := (i + 1) / 4.0
		var y := body.position.y + body.size.y * t
		var x := body.position.x + body.size.x * t
		canvas.draw_line(Vector2(rect.position.x + rect.size.x * 0.10, y), Vector2(body.position.x, y), color, width, true)
		canvas.draw_line(Vector2(body.end.x, y), Vector2(rect.end.x - rect.size.x * 0.10, y), color, width, true)
		canvas.draw_line(Vector2(x, rect.position.y + rect.size.y * 0.10), Vector2(x, body.position.y), color, width, true)
		canvas.draw_line(Vector2(x, body.end.y), Vector2(x, rect.end.y - rect.size.y * 0.10), color, width, true)


static func _memory(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var board := Rect2(rect.position + rect.size * Vector2(0.12, 0.32), rect.size * Vector2(0.76, 0.38))
	_round_rect(canvas, board, 1.5, color, width)
	for i in 4:
		var x := board.position.x + board.size.x * ((i + 1) / 5.0)
		canvas.draw_line(Vector2(x, board.position.y + 2.0), Vector2(x, board.end.y - 2.0), color, maxf(1.0, width * 0.65), true)


static func _pi(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var center := rect.get_center()
	var arm := minf(rect.size.x, rect.size.y) * 0.28
	canvas.draw_line(center + Vector2(-arm, 0), center + Vector2(arm, 0), color, width, true)
	canvas.draw_line(center + Vector2(0, -arm), center + Vector2(0, arm), color, width, true)
	canvas.draw_circle(center, width * 0.7, color)


static func _router(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var center := rect.get_center()
	var d := minf(rect.size.x, rect.size.y) * 0.22
	canvas.draw_line(center + Vector2(-d, -d), center + Vector2(d, d), color, width, true)
	canvas.draw_line(center + Vector2(-d, d), center + Vector2(d, -d), color, width, true)


static func _globe(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var width := _stroke(rect)
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.36
	canvas.draw_arc(center, radius, 0, TAU, 28, color, width, true)
	canvas.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, width, true)
	canvas.draw_arc(center, radius * 0.55, PI * 0.5, PI * 1.5, 14, color, width, true)
	canvas.draw_arc(center, radius * 0.55, -PI * 0.5, PI * 0.5, 14, color, width, true)


static func _signal(canvas: CanvasItem, rect: Rect2, color: Color, bars: int) -> void:
	var count := 4
	var gap := rect.size.x * 0.10
	var bar_w := (rect.size.x - gap * float(count - 1)) / float(count)
	var dim := Color(color.r, color.g, color.b, 0.28)
	for i in count:
		var h := rect.size.y * (0.28 + 0.24 * float(i))
		var x := rect.position.x + float(i) * (bar_w + gap)
		canvas.draw_rect(Rect2(Vector2(x, rect.end.y - h), Vector2(bar_w, h)), color if i < bars else dim, true)


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
	canvas.draw_arc(Vector2(x + r, y + r), r, PI, PI * 1.5, 6, color, width, true)
	canvas.draw_arc(Vector2(x + w - r, y + r), r, PI * 1.5, TAU, 6, color, width, true)
	canvas.draw_arc(Vector2(x + w - r, y + h - r), r, 0, PI * 0.5, 6, color, width, true)
	canvas.draw_arc(Vector2(x + r, y + h - r), r, PI * 0.5, PI, 6, color, width, true)
