@tool
class_name DialGauge
extends Control

## Copper bezel gauge matched to docs/design.
## Angles: 0° is east, clockwise. A 270° sweep runs from 135° to 45°.

@export var min_value: float = 0.0:
	set(v):
		min_value = v
		queue_redraw()

@export var max_value: float = 100.0:
	set(v):
		max_value = v
		queue_redraw()

@export var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()

@export var major_step: float = 25.0:
	set(v):
		major_step = v
		queue_redraw()

@export var minor_step: float = 5.0:
	set(v):
		minor_step = v
		queue_redraw()

@export var label_step: float = 25.0:
	set(v):
		label_step = v
		queue_redraw()

@export var start_deg: float = 135.0
@export var sweep_deg: float = 270.0
@export var show_readout: bool = false
@export var readout_decimals: int = 0
@export var readout_unit: String = ""

## Complete-view dials use amber ticks and numerals. Simple dials stay steel.
@export var amber_scale: bool = false:
	set(v):
		amber_scale = v
		queue_redraw()

var _regular: Font
var _semibold: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	_ensure_fonts()


func _draw() -> void:
	_ensure_fonts()
	var center := size * 0.5
	var extent := minf(size.x, size.y)
	if extent < 8.0:
		return

	var outer := extent * 0.5 - 1.0
	var bezel_inner := outer * 0.905
	var groove := outer * 0.862
	var tick_outer := outer * 0.842
	var major_len := outer * 0.078
	var minor_len := outer * 0.042
	var label_r := outer * 0.67

	draw_circle(center + Vector2(1.0, extent * 0.014), outer * 0.985, Color(0, 0, 0, 0.38))
	_draw_bezel(center, bezel_inner, outer)
	draw_arc(center, outer - 0.4, 0, TAU, 120, Color(0.08, 0.04, 0.02, 0.9), 1.4, true)
	draw_arc(center, bezel_inner + 0.4, 0, TAU, 100, Color(0.03, 0.015, 0.01, 0.95), 1.5, true)
	draw_circle(center, groove, NovaPalette.FACE)
	draw_arc(center, groove - 1.0, 0, TAU, 80, Color(0, 0, 0, 0.55), maxf(2.0, extent * 0.01), true)

	var major_color := NovaPalette.AMBER if amber_scale else NovaPalette.TICK
	var minor_color := Color(NovaPalette.AMBER.r, NovaPalette.AMBER.g, NovaPalette.AMBER.b, 0.55) if amber_scale else NovaPalette.TICK_MINOR
	var numeral := NovaPalette.AMBER if amber_scale else NovaPalette.STEEL
	var label_px := int(clampf(extent * (0.042 if amber_scale else 0.048), 8, 18))

	var step := minor_step if minor_step > 0.0 else major_step
	if step > 0.0:
		var v := min_value
		var guard := 0
		while v <= max_value + step * 0.25 and guard < 120:
			var shown := minf(v, max_value)
			var ang := _angle(shown)
			var dir := Vector2.from_angle(ang)
			var major := _on_step(shown, major_step)
			var length := major_len if major else minor_len
			var tick_w := maxf(1.7, extent * 0.007) if major else maxf(1.0, extent * 0.0032)
			draw_line(
				center + dir * (tick_outer - length),
				center + dir * tick_outer,
				major_color if major else minor_color,
				tick_w,
				true
			)
			if _on_step(shown, label_step):
				NovaTheme.draw_centered(self, _regular, _format_tick(shown), center + dir * label_r, label_px, numeral)
			if is_equal_approx(shown, max_value):
				break
			v += step
			guard += 1

	_draw_needle(center, tick_outer - major_len * 0.55, extent)
	_draw_hub(center, extent)

	if show_readout:
		var number := _format_readout(value)
		var number_px := int(clampf(extent * 0.115, 12, 32))
		var unit_px := int(clampf(extent * 0.048, 9, 15))
		var number_at := center + Vector2(0, groove * 0.46)
		NovaTheme.draw_centered(self, _semibold, number, number_at, number_px, NovaPalette.CREAM)
		if not readout_unit.is_empty():
			NovaTheme.draw_centered(
				self,
				_regular,
				readout_unit,
				number_at + Vector2(0, number_px * 0.78),
				unit_px,
				NovaPalette.STEEL_LIGHT
			)


func _draw_bezel(center: Vector2, inner: float, outer: float) -> void:
	var segments := 120
	var up := Vector2(0, -1)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		var c0 := _bezel_color(d0, up)
		var c1 := _bezel_color(d1, up)
		var mid := (inner + outer) * 0.5
		draw_polygon(
			PackedVector2Array([
				center + d0 * outer,
				center + d1 * outer,
				center + d1 * mid,
				center + d0 * mid,
			]),
			PackedColorArray([
				c0.darkened(0.28),
				c1.darkened(0.28),
				c1.lightened(0.08),
				c0.lightened(0.08),
			])
		)
		draw_polygon(
			PackedVector2Array([
				center + d0 * mid,
				center + d1 * mid,
				center + d1 * inner,
				center + d0 * inner,
			]),
			PackedColorArray([
				c0.lightened(0.08),
				c1.lightened(0.08),
				c1.darkened(0.22),
				c0.darkened(0.22),
			])
		)
	draw_arc(
		center,
		outer - maxf(1.5, (outer - inner) * 0.18),
		deg_to_rad(206),
		deg_to_rad(334),
		48,
		Color(1.0, 0.92, 0.80, 0.42),
		maxf(1.3, (outer - inner) * 0.14),
		true
	)


func _bezel_color(dir: Vector2, up: Vector2) -> Color:
	var light := clampf(dir.dot(up) * 0.5 + 0.5, 0.0, 1.0)
	light = pow(light, 0.65)
	if light < 0.45:
		return NovaPalette.COPPER_LO.lerp(NovaPalette.COPPER, light / 0.45)
	return NovaPalette.COPPER.lerp(NovaPalette.COPPER_HI, (light - 0.45) / 0.55)


func _draw_needle(center: Vector2, tip_r: float, extent: float) -> void:
	var dir := Vector2.from_angle(_angle(value))
	var normal := Vector2(-dir.y, dir.x)
	var tip := center + dir * tip_r
	var tail := center - dir * (extent * 0.02)
	var half_tail := maxf(1.4, extent * 0.009)
	var shadow := Vector2(0.4, 1.4)
	draw_colored_polygon(
		PackedVector2Array([
			tip + shadow,
			tail + normal * half_tail + shadow,
			tail - normal * half_tail + shadow,
		]),
		Color(0, 0, 0, 0.35)
	)
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			tail + normal * half_tail,
			tail - normal * half_tail,
		]),
		NovaPalette.AMBER
	)
	draw_line(center, tip - dir * (extent * 0.03), NovaPalette.AMBER_HOT, maxf(1.0, extent * 0.0035), true)


func _draw_hub(center: Vector2, extent: float) -> void:
	var hub := clampf(extent * 0.038, 3.2, 13.0)
	draw_circle(center, hub, Color(0.10, 0.07, 0.045))
	draw_arc(center, hub * 0.78, 0, TAU, 28, NovaPalette.COPPER, maxf(1.2, hub * 0.28), true)
	draw_circle(center, hub * 0.34, Color(0.16, 0.11, 0.08))
	draw_arc(center, hub * 0.78, deg_to_rad(210), deg_to_rad(330), 16, NovaPalette.COPPER_HI, 1.1, true)


func _angle(v: float) -> float:
	var span := max_value - min_value
	var t := 0.0 if span == 0.0 else clampf((v - min_value) / span, 0.0, 1.0)
	return deg_to_rad(start_deg + sweep_deg * t)


func _on_step(v: float, step: float) -> bool:
	if step <= 0.0:
		return false
	var k := (v - min_value) / step
	return absf(k - round(k)) < 0.02


func _format_tick(v: float) -> String:
	return str(int(round(v)))


func _format_readout(v: float) -> String:
	if readout_decimals <= 0:
		return str(int(round(v)))
	return ("%." + str(readout_decimals) + "f") % v


func _ensure_fonts() -> void:
	if _regular == null:
		_regular = NovaTheme.tracked(NovaTheme.REGULAR, 0)
		_semibold = NovaTheme.tracked(NovaTheme.SEMIBOLD, 0)
