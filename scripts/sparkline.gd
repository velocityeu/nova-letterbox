@tool
extends Control

## Static throughput trace from DemoTelemetry. Not a live sampler.


func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return
	var title_font := NovaFonts.variation("medium", 2)
	NovaFonts.draw_centered(self, title_font, Vector2(size.x * 0.5, 11), "THROUGHPUT (Mbps)", 12, NovaColors.STEEL)

	var plot := Rect2(36, 20, maxf(size.x - 48.0, 20.0), maxf(size.y - 40.0, 16.0))
	var samples := DemoTelemetry.THROUGHPUT_MBPS
	if samples.is_empty():
		return

	var axis := NovaFonts.variation("regular", 0)
	for tick in [0, 25, 50, 75, 100]:
		var y := _y_at(plot, float(tick))
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(NovaColors.STEEL.r, NovaColors.STEEL.g, NovaColors.STEEL.b, 0.16), 1.0, true)
		NovaFonts.draw_text(self, axis, Vector2(plot.position.x - 8, y + 3), str(tick), 10, NovaColors.STEEL_DIM, "right")

	var points := PackedVector2Array()
	var last := samples.size() - 1
	for i in samples.size():
		var t := 0.0 if last == 0 else float(i) / float(last)
		var x := lerpf(plot.position.x, plot.end.x, t)
		points.append(Vector2(x, _y_at(plot, samples[i])))

	var fill := points.duplicate()
	fill.append(Vector2(plot.end.x, plot.end.y))
	fill.append(Vector2(plot.position.x, plot.end.y))
	draw_colored_polygon(fill, NovaColors.TRACE_FILL)
	draw_polyline(points, NovaColors.TRACE, 1.7, true)

	var labels := DemoTelemetry.THROUGHPUT_LABELS
	for i in labels.size():
		var t := 0.0 if labels.size() == 1 else float(i) / float(labels.size() - 1)
		var x := lerpf(plot.position.x, plot.end.x, t)
		NovaFonts.draw_text(self, axis, Vector2(x, size.y - 4.0), labels[i], 10, NovaColors.STEEL_DIM, "center")


func _y_at(plot: Rect2, mbps: float) -> float:
	var t := clampf(mbps / 100.0, 0.0, 1.0)
	return lerpf(plot.end.y, plot.position.y, t)
