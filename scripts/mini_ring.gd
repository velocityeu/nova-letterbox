@tool
extends Control

## CPU / RAM fraction ring. `icon_name` is "chip" or "ram".

@export var percent: float = 0.0
@export var icon_name: String = "chip"


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var band := 26.0
	var radius := maxf(minf(size.x, size.y - band) * 0.5 - 4.0, 8.0)
	var center := Vector2(size.x * 0.5, radius + 4.0)
	var start := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	var width := clampf(radius * 0.16, 4.0, 7.0)
	draw_arc(center, radius, start, start + sweep, 48, NovaColors.TRACK, width, true)
	var t := clampf(percent / 100.0, 0.0, 1.0)
	if t > 0.0:
		draw_arc(center, radius, start, start + sweep * t, 40, NovaColors.AMBER, width, true)
	if icon_name == "ram":
		NovaIcons.ram(self, center, 0.85, NovaColors.AMBER)
	else:
		NovaIcons.chip(self, center, 0.9, NovaColors.AMBER)
	var font := NovaFonts.variation("semibold", 0)
	NovaFonts.draw_centered(self, font, Vector2(center.x, center.y + radius + 16.0), "%d%%" % int(round(percent)), 16, NovaColors.AMBER)
