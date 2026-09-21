class_name NovaTheme
extends Object

## Fonts and style boxes built from [NovaPalette].
## The project Theme resource lives at res://themes/nova_theme.tres.

const LIGHT := preload("res://fonts/IBMPlexSans-Light.ttf")
const REGULAR := preload("res://fonts/IBMPlexSans-Regular.ttf")
const MEDIUM := preload("res://fonts/IBMPlexSans-Medium.ttf")
const SEMIBOLD := preload("res://fonts/IBMPlexSans-SemiBold.ttf")

static var _tracked: Dictionary = {}


static func tracked(base: Font, spacing: int) -> Font:
	var key := "%s:%d" % [base.resource_path, spacing]
	if _tracked.has(key):
		return _tracked[key]
	var variation := FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = spacing
	variation.opentype_features = {"tnum": 1}
	_tracked[key] = variation
	return variation


static func style_label(label: Label, font: Font, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


static func flat_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NovaPalette.BG
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	return style


static func frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NovaPalette.BG
	style.border_color = NovaPalette.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


static func card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NovaPalette.CARD
	style.border_color = NovaPalette.BORDER_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NovaPalette.CARD.r, NovaPalette.CARD.g, NovaPalette.CARD.b, 0.92)
	style.border_color = NovaPalette.COPPER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func draw_centered(canvas: CanvasItem, font: Font, text: String, at: Vector2, size: int, color: Color) -> void:
	if font == null or text.is_empty():
		return
	var bounds := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var ascent := font.get_ascent(size)
	var descent := font.get_descent(size)
	var pos := Vector2(at.x - bounds.x * 0.5, at.y + (ascent - descent) * 0.5)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
