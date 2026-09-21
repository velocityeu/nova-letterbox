class_name NovaFonts
extends RefCounted

const LIGHT: Font = preload("res://fonts/Barlow-Light.ttf")
const REGULAR: Font = preload("res://fonts/Barlow-Regular.ttf")
const MEDIUM: Font = preload("res://fonts/Barlow-Medium.ttf")
const SEMIBOLD: Font = preload("res://fonts/Barlow-SemiBold.ttf")

static var _cache: Dictionary = {}


static func variation(which: String, glyph_spacing: int = 0) -> Font:
	var key := "%s:%d" % [which, glyph_spacing]
	if _cache.has(key):
		return _cache[key]
	var base := REGULAR
	match which:
		"light":
			base = LIGHT
		"medium":
			base = MEDIUM
		"semibold":
			base = SEMIBOLD
	var font: Font = base
	if glyph_spacing != 0:
		var varied := FontVariation.new()
		varied.base_font = base
		varied.spacing_glyph = glyph_spacing
		font = varied
	_cache[key] = font
	return font


## `pos.y` is the baseline. `align` is "left", "center", or "right".
static func draw_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, size: int, color: Color, align: String = "left") -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var origin := pos
	if align == "center":
		origin.x -= width * 0.5
	elif align == "right":
		origin.x -= width
	canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func draw_centered(canvas: CanvasItem, font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var ascent := font.get_ascent(size)
	var descent := font.get_descent(size)
	var baseline := center.y + (ascent - descent) * 0.5
	canvas.draw_string(font, Vector2(center.x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func width_of(font: Font, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
