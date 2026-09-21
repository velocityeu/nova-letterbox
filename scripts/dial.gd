@tool
class_name NovaDial
extends Control

## Copper-bezel rotary gauge. Needles are static until a live source exists.

@export var min_value: float = 0.0
@export var max_value: float = 175.0
@export var major_step: float = 25.0
@export var value: float = 0.0
@export var decimals: int = 0
@export var title_above: String = ""
@export var title_below: String = ""
@export var unit: String = ""
@export var show_center_readout: bool = false
@export_range(180.0, 330.0, 1.0) var sweep_degrees: float = 270.0
@export_range(90.0, 180.0, 1.0) var sweep_start_degrees: float = 135.0


func bind(v: float, scale_max: float, step: float, decimal_places: int, above: String, below: String, center_readout: bool, unit_text: String) -> void:
	min_value = 0.0
	max_value = scale_max
	major_step = step
	value = v
	decimals = decimal_places
	title_above = above
	title_below = below
	show_center_readout = center_readout
	unit = unit_text
	queue_redraw()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var metrics := _metrics()
	var center: Vector2 = metrics.center
	var radius: float = metrics.radius
	var bezel_w := clampf(radius * 0.062, 3.5, 10.0)

	draw_arc(center, radius + bezel_w * 0.35, 0.0, TAU, 96, Color(0, 0, 0, 0.45), bezel_w * 0.85, true)
	draw_arc(center, radius, 0.0, TAU, 128, NovaColors.COPPER_DIM, bezel_w, true)
	draw_arc(center, radius, 0.0, TAU, 128, NovaColors.COPPER, bezel_w * 0.72, true)
	draw_arc(center, radius, deg_to_rad(210.0), deg_to_rad(310.0), 32, NovaColors.COPPER_LIGHT, maxf(bezel_w * 0.28, 1.0), true)

	var face_r := radius - bezel_w * 0.62
	draw_circle(center, face_r, NovaColors.FACE)
	draw_arc(center, face_r - 1.5, 0.0, TAU, 96, Color(NovaColors.COPPER.r, NovaColors.COPPER.g, NovaColors.COPPER.b, 0.28), 1.0, true)

	_draw_ticks(center, face_r)
	_draw_needle(center, face_r, bezel_w)
	_draw_hub(center, radius)
	_draw_readout(center, radius)
	_draw_titles(float(metrics.top), float(metrics.bottom))


func _metrics() -> Dictionary:
	var top := 24.0 if title_above != "" else 2.0
	var bottom := 50.0 if title_below != "" else 4.0
	var bounds := Rect2(2, top, maxf(size.x - 4.0, 8.0), maxf(size.y - top - bottom, 8.0))
	var radius := maxf(minf(bounds.size.x, bounds.size.y) * 0.5 - 1.0, 8.0)
	var center := bounds.position + bounds.size * 0.5
	return {"top": top, "bottom": bottom, "radius": radius, "center": center}


func _draw_ticks(center: Vector2, face_r: float) -> void:
	var step := major_step if major_step > 0.0 else 25.0
	var font := NovaFonts.variation("regular", 0)
	var font_size := 16 if face_r > 110.0 else (12 if face_r > 70.0 else 10)
	var label_r := face_r - font_size - 8.0
	var major_outer := face_r - 5.0
	var count := int(round((max_value - min_value) / step))
	count = clampi(count, 1, 24)
	for i in count + 1:
		var major_value := min_value + step * float(i)
		var angle := _angle_for(major_value)
		_tick(center, angle, major_outer, 11.0 if face_r > 80.0 else 7.0, NovaColors.STEEL, 1.25)
		var label := _format_tick(major_value)
		var at := center + Vector2(cos(angle), sin(angle)) * label_r
		NovaFonts.draw_centered(self, font, at, label, font_size, NovaColors.STEEL)
		if i == count or face_r < 70.0:
			continue
		for m in 4:
			var minor := lerpf(major_value, major_value + step, float(m + 1) / 5.0)
			if minor >= max_value:
				break
			_tick(center, _angle_for(minor), major_outer, 5.0, NovaColors.STEEL_DIM, 1.0)


func _tick(center: Vector2, angle: float, outer: float, length: float, color: Color, width: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	draw_line(center + dir * (outer - length), center + dir * outer, color, width, true)


func _draw_needle(center: Vector2, face_r: float, bezel_w: float) -> void:
	var angle := _angle_for(value)
	var dir := Vector2(cos(angle), sin(angle))
	var normal := Vector2(-dir.y, dir.x)
	var hub_r := clampf(face_r * 0.085, 4.0, 11.0)
	var tip := center + dir * (face_r - bezel_w * 0.2 - 8.0)
	var base := center - dir * hub_r * 0.15
	var half_w := clampf(face_r * 0.02, 1.5, 3.4)
	draw_colored_polygon(PackedVector2Array([
		tip,
		base + normal * half_w,
		base - normal * half_w,
	]), NovaColors.AMBER)


func _draw_hub(center: Vector2, radius: float) -> void:
	var hub_r := clampf(radius * 0.078, 4.5, 12.0)
	draw_circle(center, hub_r, NovaColors.COPPER)
	draw_circle(center, hub_r * 0.58, NovaColors.FACE)
	draw_circle(center, maxf(hub_r * 0.18, 1.2), NovaColors.AMBER)


func _draw_readout(center: Vector2, radius: float) -> void:
	if not show_center_readout:
		return
	var value_font := NovaFonts.variation("semibold", 0)
	var unit_font := NovaFonts.variation("regular", 1)
	var value_size := int(clampf(radius * 0.30, 16, 36))
	var unit_size := int(clampf(radius * 0.13, 10, 15))
	var block := center + Vector2(0, radius * 0.38)
	NovaFonts.draw_centered(self, value_font, block, _format_value(value), value_size, NovaColors.AMBER)
	if unit != "":
		NovaFonts.draw_centered(self, unit_font, block + Vector2(0, value_size * 0.62), unit, unit_size, NovaColors.STEEL)


func _draw_titles(top: float, bottom: float) -> void:
	if title_above != "":
		var above_font := NovaFonts.variation("medium", 2)
		var above_size := 13 if size.y > 220.0 else 11
		NovaFonts.draw_centered(self, above_font, Vector2(size.x * 0.5, top * 0.48), title_above, above_size, NovaColors.MIST)
	if title_below != "":
		var below_font := NovaFonts.variation("medium", 3)
		var below_size := 22 if size.y > 280.0 else 16
		NovaFonts.draw_centered(self, below_font, Vector2(size.x * 0.5, size.y - bottom * 0.42), title_below, below_size, NovaColors.COPPER)


func _angle_for(v: float) -> float:
	var span := max_value - min_value
	var t := 0.0 if is_zero_approx(span) else clampf((v - min_value) / span, 0.0, 1.0)
	return deg_to_rad(sweep_start_degrees + sweep_degrees * t)


func _format_tick(v: float) -> String:
	return str(int(round(v)))


func _format_value(v: float) -> String:
	if decimals <= 0:
		return str(int(round(v)))
	return "%.*f" % [decimals, v]
