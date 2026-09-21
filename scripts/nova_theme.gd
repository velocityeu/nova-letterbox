class_name NovaTheme
extends RefCounted

## Runtime Theme built from NovaColors. Applied on the main scene so
## any future Label / Panel picks up the locked palette and Barlow.


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font = NovaFonts.REGULAR
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", NovaColors.COPPER)
	theme.set_color("font_color", "Button", NovaColors.MIST)
	theme.set_stylebox("panel", "Panel", panel(3, 0.75))
	theme.set_stylebox("panel", "PanelContainer", panel(3, 0.75))
	return theme


## Custom panels. StyleBox.draw() takes a CanvasItem on 4.3 and a RID on 4.7,
## so the shell paints with draw calls that stay valid across that range.
static func paint_panel(canvas: CanvasItem, rect: Rect2, radius: float = 4.0, border_alpha: float = 0.72, fill: Color = NovaColors.CHARCOAL_ELEVATED) -> void:
	var border := NovaColors.COPPER
	border.a = border_alpha
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r < 1.5:
		canvas.draw_rect(rect, fill, true)
		canvas.draw_rect(rect, border, false, 1.0, true)
		return
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	canvas.draw_rect(Rect2(x + r, y, w - r * 2.0, h), fill, true)
	canvas.draw_rect(Rect2(x, y + r, r, h - r * 2.0), fill, true)
	canvas.draw_rect(Rect2(x + w - r, y + r, r, h - r * 2.0), fill, true)
	canvas.draw_circle(Vector2(x + r, y + r), r, fill)
	canvas.draw_circle(Vector2(x + w - r, y + r), r, fill)
	canvas.draw_circle(Vector2(x + r, y + h - r), r, fill)
	canvas.draw_circle(Vector2(x + w - r, y + h - r), r, fill)
	var width := 1.25
	canvas.draw_line(Vector2(x + r, y), Vector2(x + w - r, y), border, width, true)
	canvas.draw_line(Vector2(x + r, y + h), Vector2(x + w - r, y + h), border, width, true)
	canvas.draw_line(Vector2(x, y + r), Vector2(x, y + h - r), border, width, true)
	canvas.draw_line(Vector2(x + w, y + r), Vector2(x + w, y + h - r), border, width, true)
	canvas.draw_arc(Vector2(x + r, y + r), r, PI, PI * 1.5, 10, border, width, true)
	canvas.draw_arc(Vector2(x + w - r, y + r), r, PI * 1.5, TAU, 10, border, width, true)
	canvas.draw_arc(Vector2(x + w - r, y + h - r), r, 0.0, PI * 0.5, 10, border, width, true)
	canvas.draw_arc(Vector2(x + r, y + h - r), r, PI * 0.5, PI, 10, border, width, true)


static func panel(radius: int = 3, border_alpha: float = 0.7) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = NovaColors.CHARCOAL_ELEVATED
	var border := NovaColors.COPPER
	border.a = border_alpha
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
