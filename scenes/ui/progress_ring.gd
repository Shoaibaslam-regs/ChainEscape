class_name ProgressRing
extends Control
## A thin circular progress ring (e.g. Weekly 2 of 5) with segment gaps.

@export var segments: int = 5:
	set(value):
		segments = maxi(value, 1)
		queue_redraw()
@export var filled: int = 0:
	set(value):
		filled = value
		queue_redraw()
@export var thickness: float = 7.0

const TRACK := Color(0.725, 0.761, 0.827, 0.14)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - thickness
	var gap := 0.22
	var step := TAU / segments
	for i: int in segments:
		var start := -PI * 0.5 + i * step + gap * 0.5
		var color := Palette.GOLD if i < filled else TRACK
		draw_arc(center, radius, start, start + step - gap, 24, color, thickness, true)
