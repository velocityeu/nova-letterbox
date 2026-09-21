@tool
class_name Sparkline
extends Control

@export var title: String = "THROUGHPUT (Mbps)":
	set(v):
		title = v
		queue_redraw()

@export var y_max: float = 100.0:
	set(v):
		y_max = v
		queue_redraw()

@export var samples: PackedFloat32Array = PackedFloat32Array():
	set(v):
		samples = v
		queue_redraw()

@export var x_labels: PackedStringArray = PackedStringArray():
	set(v):
		x_labels = v
		queue_redraw()

var _font: Font
var _title_font: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if _font == null:
		_font = NovaTheme.tracked(NovaTheme.REGULAR, 0)
		_title_font = NovaTheme.tracked(NovaTheme.MEDIUM, 1)

	NovaTheme.draw_centered(self, _title_font, title, Vector2(size.x * 0.5, 11), 12, NovaPalette.COPPER_SOFT)

	var plot := Rect2(Vector2(36, 24), Vector2(maxf(8.0, size.x - 48), maxf(8.0, size.y - 46)))
	var grid_steps: Array[float] = [0.25, 0.5, 0.75, 1.0]
	for t in grid_steps:
		var y := plot.position.y + plot.size.y * (1.0 - t)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), NovaPalette.GRID, 1.0, true)
		var label := str(int(round(y_max * t)))
		var label_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string(
			_font,
			Vector2(plot.position.x - label_size.x - 6, y + 4),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			NovaPalette.STEEL_DIM
		)

	if samples.size() >= 2 and y_max > 0.0:
		var points := PackedVector2Array()
		var last := samples.size() - 1
		for i in samples.size():
			var x := plot.position.x + plot.size.x * (float(i) / float(last))
			var y := plot.position.y + plot.size.y * (1.0 - clampf(samples[i] / y_max, 0.0, 1.0))
			points.append(Vector2(x, y))
		var fill := points.duplicate()
		fill.append(Vector2(plot.end.x, plot.end.y))
		fill.append(Vector2(plot.position.x, plot.end.y))
		draw_colored_polygon(fill, Color(NovaPalette.TRACE.r, NovaPalette.TRACE.g, NovaPalette.TRACE.b, 0.14))
		draw_polyline(points, NovaPalette.TRACE, 1.8, true)

	if not x_labels.is_empty():
		var baseline := size.y - 6
		var count := x_labels.size()
		for i in count:
			var x := plot.position.x if count == 1 else lerpf(plot.position.x, plot.end.x, float(i) / float(count - 1))
			var label_size := _font.get_string_size(x_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			var origin := x - label_size.x * 0.5
			origin = clampf(origin, 0.0, maxf(0.0, size.x - label_size.x))
			draw_string(_font, Vector2(origin, baseline), x_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, NovaPalette.STEEL_DIM)
