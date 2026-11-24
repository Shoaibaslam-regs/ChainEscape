class_name ThemeSwatch
extends Button
## One arrow theme in Settings: a metal disc, a gold ring when selected, and
## a padlock with the points needed while it is still locked.

var theme_id: String = ""
var colors: PackedColorArray = PackedColorArray()
var is_locked: bool = false:
	set(value):
		is_locked = value
		queue_redraw()
var is_selected: bool = false:
	set(value):
		is_selected = value
		queue_redraw()


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(96, 96)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.36
	if is_selected:
		draw_arc(center, radius + 8.0, 0.0, TAU, 48, Palette.GOLD, 4.0, true)
	var alpha := 0.35 if is_locked else 1.0
	# A simple top-to-bottom metal look: dark disc, mid band, light highlight.
	draw_circle(center, radius, Color(colors[2], alpha))
	draw_circle(center + Vector2(0, -radius * 0.12), radius * 0.86, Color(colors[1], alpha))
	draw_circle(center + Vector2(-radius * 0.28, -radius * 0.34), radius * 0.28, Color(colors[0], 0.8 * alpha))
	if is_locked:
		var unit := radius / 20.0
		draw_arc(center + Vector2(0, -unit * 3.0), unit * 5.5, PI, TAU, 12, Palette.STEEL_LIGHT, unit * 2.4, true)
		draw_rect(Rect2(center + Vector2(-unit * 8.0, -unit * 3.0), Vector2(unit * 16.0, unit * 12.0)), Palette.STEEL_LIGHT)
