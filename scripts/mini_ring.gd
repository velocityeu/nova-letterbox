@tool
class_name MiniRing
extends Control

@export var caption: String = "CPU":
	set(v):
		caption = v
		queue_redraw()

## 0–1 fill.
@export var ratio: float = 0.0:
	set(v):
		ratio = v
		queue_redraw()

@export var icon_kind: GlyphIcon.Kind = GlyphIcon.Kind.CHIP:
	set(v):
		icon_kind = v
		queue_redraw()

var _font: Font
var _caption_font: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	if _font == null:
		_font = NovaTheme.tracked(NovaTheme.SEMIBOLD, 0)
		_caption_font = NovaTheme.tracked(NovaTheme.MEDIUM, 1)

	NovaTheme.draw_centered(self, _caption_font, caption, Vector2(size.x * 0.5, 8), 12, NovaPalette.COPPER_SOFT)

	var center := Vector2(size.x * 0.5, 14.0 + (size.y - 16.0) * 0.48)
	var radius := minf(size.x * 0.36, (size.y - 18.0) * 0.42)
	var width := clampf(radius * 0.20, 4.0, 8.0)
	var start := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	draw_arc(center, radius, start, start + sweep, 72, NovaPalette.TRACK, width, true)
	var shown := clampf(ratio, 0.0, 1.0)
	if shown > 0.001:
		draw_arc(center, radius, start, start + sweep * shown, 72, NovaPalette.AMBER, width, true)
		var end := Vector2.from_angle(start + sweep * shown)
		draw_circle(center + end * radius, width * 0.45, NovaPalette.AMBER_HOT)

	var percent := str(int(round(shown * 100.0))) + "%"
	var percent_px := int(clampf(radius * 0.62, 11, 18))
	NovaTheme.draw_centered(self, _font, percent, center + Vector2(0, -radius * 0.08), percent_px, NovaPalette.CREAM)

	var icon_size := clampf(radius * 0.48, 10, 16)
	GlyphIcon.draw_kind(
		self,
		icon_kind,
		Rect2(center + Vector2(-icon_size * 0.5, radius * 0.28), Vector2(icon_size, icon_size)),
		NovaPalette.COPPER_SOFT
	)
