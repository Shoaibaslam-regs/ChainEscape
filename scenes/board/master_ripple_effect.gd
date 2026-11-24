class_name MasterRippleEffect
extends Node2D
## The gold ripple that spreads from the master arrow when it is released,
## as every other arrow escapes. Purely visual; frees itself.

const DURATION := 1.0
const RING_COUNT := 2
const RING_SPACING := 0.22

var max_radius: float = 600.0
var line_width: float = 4.0

var _progress: float = 0.0:
	set(value):
		_progress = value
		queue_redraw()


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_progress", 1.0, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _draw() -> void:
	for ring: int in RING_COUNT:
		var t := clampf(_progress - ring * RING_SPACING, 0.0, 1.0)
		if t <= 0.0:
			continue
		var color := Color(Palette.GOLD_LIGHT, (1.0 - t) * 0.7)
		draw_arc(Vector2.ZERO, max_radius * t, 0.0, TAU, 96, color, line_width * (1.0 - t * 0.5), true)
