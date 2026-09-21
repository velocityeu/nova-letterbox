@tool
class_name DialGauge
extends Control

## Copper bezel gauge. Angles use Godot's screen space:
## 0° is east and values increase clockwise, so 135° is the lower-left start
## of a 270° sweep that ends at the lower-right.

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

var _regular: Font
var _semibold: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_ensure_fonts()


func _draw() -> void:
	_ensure_fonts()
	var center := size * 0.5
	var extent := minf(size.x, size.y)
	if extent < 8.0:
		return

	var ring_w := clampf(extent * 0.048, 6.0, 14.0)
	var ring_r := extent * 0.5 - ring_w * 0.5 - 1.5
	var face_r := ring_r - ring_w * 0.62

	draw_arc(center + Vector2(0, 2.0), ring_r, 0, TAU, 96, Color(0, 0, 0, 0.45), ring_w, true)
	draw_arc(center, ring_r, 0, TAU, 128, NovaPalette.COPPER, ring_w, true)
	draw_arc(center, ring_r, deg_to_rad(210), deg_to_rad(330), 48, NovaPalette.AMBER_HOT, maxf(1.5, ring_w * 0.22), true)
	draw_circle(center, face_r, NovaPalette.FACE)
	draw_arc(center, face_r - 1.0, 0, TAU, 96, NovaPalette.COPPER_DEEP, 1.25, true)

	var tick_outer := face_r - extent * 0.03
	var major_len := extent * 0.058
	var minor_len := extent * 0.030
	var label_r := tick_outer - major_len - extent * 0.078
	var label_px := int(clampf(extent * 0.055, 9, 15))

	var step := minor_step if minor_step > 0.0 else major_step
	if step > 0.0:
		var v := min_value
		var guard := 0
		while v <= max_value + step * 0.25 and guard < 80:
			var shown := minf(v, max_value)
			var ang := _angle(shown)
			var dir := Vector2.from_angle(ang)
			var major := _on_step(shown, major_step)
			var length := major_len if major else minor_len
			var tick_color := NovaPalette.TICK if major else NovaPalette.TICK_MINOR
			var tick_w := maxf(1.4, extent * 0.008) if major else maxf(1.0, extent * 0.005)
			draw_line(center + dir * (tick_outer - length), center + dir * tick_outer, tick_color, tick_w, true)
			if _on_step(shown, label_step):
				NovaTheme.draw_centered(
					self,
					_regular,
					_format_tick(shown),
					center + dir * label_r,
					label_px,
					NovaPalette.STEEL
				)
			if is_equal_approx(shown, max_value):
				break
			v += step
			guard += 1

	_draw_needle(center, tick_outer - extent * 0.01, extent)
	_draw_hub(center, extent)

	if show_readout:
		var number := _format_readout(value)
		var number_px := int(clampf(extent * 0.112, 13, 26))
		var unit_px := int(clampf(extent * 0.052, 9, 13))
		# Sit in the open lower wedge, clear of the hub and the end ticks.
		var number_at := center + Vector2(0, face_r * 0.38)
		NovaTheme.draw_centered(self, _semibold, number, number_at, number_px, NovaPalette.CREAM)
		if not readout_unit.is_empty():
			NovaTheme.draw_centered(
				self,
				_regular,
				readout_unit,
				number_at + Vector2(0, number_px * 0.62),
				unit_px,
				NovaPalette.STEEL
			)


func _draw_needle(center: Vector2, tip_r: float, extent: float) -> void:
	var dir := Vector2.from_angle(_angle(value))
	var normal := Vector2(-dir.y, dir.x)
	var tip := center + dir * tip_r
	var tail := center - dir * (extent * 0.045)
	var half := maxf(1.6, extent * 0.012)
	draw_colored_polygon(
		PackedVector2Array([tip, tail + normal * half, tail - normal * half]),
		NovaPalette.AMBER
	)


func _draw_hub(center: Vector2, extent: float) -> void:
	var hub := clampf(extent * 0.038, 4.0, 10.0)
	draw_circle(center, hub, NovaPalette.COPPER)
	draw_circle(center, hub * 0.48, NovaPalette.FACE)
	draw_arc(center, hub, 0, TAU, 24, NovaPalette.AMBER_HOT, 1.0, true)


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
