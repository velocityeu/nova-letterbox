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

var _title_font: Font
var _addr_font: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if _title_font == null:
		_title_font = NovaTheme.tracked(NovaTheme.MEDIUM, 1)
		_addr_font = NovaTheme.tracked(NovaTheme.REGULAR, 0)

	var y := size.y * 0.46
	var xs: Array[float] = [size.x * 0.17, size.x * 0.50, size.x * 0.83]
	var x := xs[0]
	while x < xs[2]:
		draw_circle(Vector2(x, y), 1.5, NovaPalette.COPPER_DEEP)
		x += 9.0

	var titles: Array[String] = [left_title, mid_title, right_title]
	var addrs: Array[String] = [left_addr, mid_addr, right_addr]
	var kinds: Array[GlyphIcon.Kind] = [GlyphIcon.Kind.PI, GlyphIcon.Kind.ROUTER, GlyphIcon.Kind.GLOBE]
	for i in 3:
		var point := Vector2(xs[i], y)
		draw_circle(point, 13, NovaPalette.BG)
		draw_arc(point, 13, 0, TAU, 28, NovaPalette.COPPER, 1.4, true)
		GlyphIcon.draw_kind(self, kinds[i], Rect2(point - Vector2(7, 7), Vector2(14, 14)), NovaPalette.AMBER)
		NovaTheme.draw_centered(self, _title_font, titles[i], Vector2(point.x, 9), 11, NovaPalette.COPPER_SOFT)
		NovaTheme.draw_centered(self, _addr_font, addrs[i], Vector2(point.x, size.y - 9), 12, NovaPalette.STEEL)
