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
	resized.connect(queue_redraw)


func _draw() -> void:
	if _font == null:
		_font = NovaTheme.tracked(NovaTheme.SEMIBOLD, 0)
		_caption_font = NovaTheme.tracked(NovaTheme.MEDIUM, 1)

	var caption_px := 11
	NovaTheme.draw_centered(self, _caption_font, caption, Vector2(size.x * 0.5, 8), caption_px, NovaPalette.COPPER_SOFT)

	var center := Vector2(size.x * 0.5, 16 + (size.y - 18) * 0.48)
	var radius := minf(size.x * 0.34, (size.y - 24) * 0.42)
	var width := clampf(radius * 0.18, 4.0, 7.0)
	var start := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	draw_arc(center, radius, start, start + sweep, 64, NovaPalette.TRACK, width, true)
	var shown := clampf(ratio, 0.0, 1.0)
	if shown > 0.001:
		draw_arc(center, radius, start, start + sweep * shown, 64, NovaPalette.AMBER, width, true)

	var percent := str(int(round(shown * 100.0))) + "%"
	var percent_px := int(clampf(radius * 0.52, 11, 16))
	NovaTheme.draw_centered(self, _font, percent, center + Vector2(0, -radius * 0.16), percent_px, NovaPalette.CREAM)

	var icon_size := clampf(radius * 0.42, 10, 14)
	GlyphIcon.draw_kind(
		self,
		icon_kind,
		Rect2(center + Vector2(-icon_size * 0.5, radius * 0.22), Vector2(icon_size, icon_size)),
		NovaPalette.COPPER
	)
