@tool
extends Control

## Pi → router → internet path. Addresses are documentation-range stubs.


func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return
	_draw_heading()
	var y := clampf(size.y * 0.40, 34.0, 44.0)
	var xs: Array[float] = [size.x * 0.17, size.x * 0.50, size.x * 0.83]
	var radii: Array[float] = [13.0, 16.0, 16.0]
	var steps := 36
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x := lerpf(xs[0], xs[2], t)
		var covered := false
		for n in xs.size():
			if absf(x - xs[n]) < radii[n] + 8.0:
				covered = true
				break
		if not covered:
			draw_circle(Vector2(x, y), 1.45, NovaColors.COPPER)

	var name_font := NovaFonts.variation("medium", 1)
	var ip_font := NovaFonts.variation("regular", 0)
	for n in xs.size():
		var p := Vector2(xs[n], y)
		draw_circle(p, radii[n], NovaColors.CHARCOAL)
		draw_arc(p, radii[n], 0.0, TAU, 36, NovaColors.COPPER, 1.5, true)
		_draw_icon(DemoTelemetry.PATH_ICONS[n], p)
		NovaFonts.draw_centered(self, name_font, Vector2(xs[n], y + 28), DemoTelemetry.PATH_NAMES[n], 13, NovaColors.MIST)
		NovaFonts.draw_centered(self, ip_font, Vector2(xs[n], y + 46), DemoTelemetry.PATH_ADDRS[n], 12, NovaColors.STEEL)


func _draw_heading() -> void:
	var mark_font := NovaFonts.variation("semibold", 1)
	var title_font := NovaFonts.variation("medium", 2)
	var mark := "C"
	var title := "NETWORK PATH"
	var mark_w := NovaFonts.width_of(mark_font, mark, 12)
	var title_w := NovaFonts.width_of(title_font, title, 12)
	var left := size.x * 0.5 - (mark_w + 8.0 + title_w) * 0.5
	NovaFonts.draw_text(self, mark_font, Vector2(left, 14), mark, 12, NovaColors.AMBER)
	NovaFonts.draw_text(self, title_font, Vector2(left + mark_w + 8.0, 14), title, 12, NovaColors.STEEL)


func _draw_icon(kind: String, at: Vector2) -> void:
	match kind:
		"cluster":
			NovaIcons.cluster(self, at, 0.85, NovaColors.AMBER)
		"router":
			NovaIcons.cross(self, at, 1.15, NovaColors.AMBER)
		"globe":
			NovaIcons.globe(self, at, 0.95, NovaColors.AMBER)
