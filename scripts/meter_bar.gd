@tool
class_name MeterBar
extends Control

## 0–1 fill along the bar.
@export var ratio: float = 0.0:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var radius := int(round(size.y * 0.5))
	var track := StyleBoxFlat.new()
	track.bg_color = NovaPalette.TRACK
	track.set_corner_radius_all(radius)
	track.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	if ratio <= 0.001:
		return
	var fill_w := maxf(size.y, size.x * ratio)
	var fill := StyleBoxFlat.new()
	fill.bg_color = NovaPalette.AMBER
	fill.set_corner_radius_all(radius)
	fill.draw(get_canvas_item(), Rect2(Vector2.ZERO, Vector2(minf(fill_w, size.x), size.y)))
