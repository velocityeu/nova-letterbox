@tool
class_name NetworkPath
extends Control

@export var left_title: String = "PI":
	set(v):
		left_title = v
		queue_redraw()

@export var left_addr: String = "":
	set(v):
		left_addr = v
		queue_redraw()

@export var mid_title: String = "ROUTER":
	set(v):
		mid_title = v
		queue_redraw()

@export var mid_addr: String = "":
	set(v):
		mid_addr = v
		queue_redraw()

@export var right_title: String = "INTERNET":
	set(v):
		right_title = v
		queue_redraw()

@export var right_addr: String = "":
	set(v):
		right_addr = v
		queue_redraw()

@export var heading: String = "C    NETWORK PATH":
	set(v):
		heading = v
		queue_redraw()

var _title_font: Font
var _addr_font: Font
var _head_font: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	if _title_font == null:
		_title_font = NovaTheme.tracked(NovaTheme.MEDIUM, 1)
		_addr_font = NovaTheme.tracked(NovaTheme.REGULAR, 0)
		_head_font = NovaTheme.tracked(NovaTheme.MEDIUM, 1)

	var box := Rect2(Vector2(0, 8), Vector2(size.x, size.y - 8))
	draw_rect(box, NovaPalette.BG, true)
	_stroke_round(box, 6.0, NovaPalette.BORDER_DIM)

	var head_px := 12
	var head_w := _head_font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, head_px).x + 16.0
	var head_rect := Rect2(Vector2(size.x * 0.5 - head_w * 0.5, 0), Vector2(head_w, 16))
	draw_rect(head_rect, NovaPalette.BG, true)
	NovaTheme.draw_centered(self, _head_font, heading, Vector2(size.x * 0.5, 8), head_px, NovaPalette.COPPER_SOFT)

	var y := box.position.y + box.size.y * 0.40
	var xs: Array[float] = [size.x * 0.18, size.x * 0.50, size.x * 0.82]
	var x := xs[0] + 18.0
	while x < xs[2] - 16.0:
		draw_circle(Vector2(x, y), 1.35, NovaPalette.COPPER)
		x += 8.0

	var titles: Array[String] = [left_title, mid_title, right_title]
	var addrs: Array[String] = [left_addr, mid_addr, right_addr]
	var kinds: Array[GlyphIcon.Kind] = [GlyphIcon.Kind.PI, GlyphIcon.Kind.ROUTER, GlyphIcon.Kind.GLOBE]
	for i in 3:
		var point := Vector2(xs[i], y)
		NovaTheme.draw_centered(self, _title_font, titles[i], Vector2(point.x, y - 22), 11, NovaPalette.COPPER_SOFT)
		draw_circle(point, 12.0, NovaPalette.BG)
		draw_arc(point, 12.0, 0, TAU, 32, NovaPalette.COPPER, 1.4, true)
		GlyphIcon.draw_kind(self, kinds[i], Rect2(point - Vector2(7, 7), Vector2(14, 14)), NovaPalette.AMBER)
		NovaTheme.draw_centered(self, _addr_font, addrs[i], Vector2(point.x, y + 24), 12, NovaPalette.STEEL_LIGHT)


func _stroke_round(rect: Rect2, radius: float, color: Color) -> void:
	var r := radius
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	draw_line(Vector2(x + r, y), Vector2(x + w - r, y), color, 1.0, true)
	draw_line(Vector2(x + w, y + r), Vector2(x + w, y + h - r), color, 1.0, true)
	draw_line(Vector2(x + w - r, y + h), Vector2(x + r, y + h), color, 1.0, true)
	draw_line(Vector2(x, y + h - r), Vector2(x, y + r), color, 1.0, true)
	draw_arc(Vector2(x + r, y + r), r, PI, PI * 1.5, 8, color, 1.0, true)
	draw_arc(Vector2(x + w - r, y + r), r, PI * 1.5, TAU, 8, color, 1.0, true)
	draw_arc(Vector2(x + w - r, y + h - r), r, 0, PI * 0.5, 8, color, 1.0, true)
	draw_arc(Vector2(x + r, y + h - r), r, PI * 0.5, PI, 8, color, 1.0, true)
