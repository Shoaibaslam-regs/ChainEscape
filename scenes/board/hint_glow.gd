class_name HintGlow
extends Node2D
## A pulsing gold halo around the arrow a hint points at. Lives on the
## BoardView in board coordinates; fades away after a few pulses.

const PULSES := 3
const PULSE_SECONDS := 0.9

var _cell_size: float = 100.0
var _phase: float = 0.0:
	set(value):
		_phase = value
		queue_redraw()
var _tween: Tween
var _target_id: int = -1


func _init() -> void:
	hide()


func show_at(center: Vector2, cell_size: float, arrow_id: int) -> void:
	stop()
	position = center
	_cell_size = cell_size
	_target_id = arrow_id
	modulate.a = 1.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "_phase", float(PULSES), PULSE_SECONDS * PULSES).from(0.0)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(stop)


func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_target_id = -1
	hide()


func get_target_id() -> int:
	return _target_id if visible else -1


func _draw() -> void:
	var t := fmod(_phase, 1.0)
	var base := _cell_size * 0.42
	# A soft steady glow plus a ring that expands and fades each pulse.
	draw_circle(Vector2.ZERO, base, Color(Palette.GOLD, 0.16), true, -1.0, true)
	draw_arc(Vector2.ZERO, base, 0.0, TAU, 48, Color(Palette.GOLD_LIGHT, 0.9), maxf(_cell_size * 0.04, 2.0), true)
	draw_arc(Vector2.ZERO, base * (1.0 + 0.6 * t), 0.0, TAU, 48, Color(Palette.GOLD, 0.7 * (1.0 - t)), maxf(_cell_size * 0.05, 2.0), true)
