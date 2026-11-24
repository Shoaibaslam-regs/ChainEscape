class_name TutorialHand
extends Node2D
## A pointing hand that gently taps one arrow on the first levels, with a
## soft ring where the fingertip lands. Lives on the BoardView, in board
## coordinates.

const TEXTURE := preload("res://assets/icons/hand.svg")
## Fingertip position inside the texture (64 x 72 SVG at import scale 2).
const TIP := Vector2(31, 3)
const TEXTURE_SIZE := Vector2(64, 72)
const TAP_SECONDS := 1.15

var _sprite := Sprite2D.new()
var _tween: Tween
var _ring: float = 0.0:
	set(value):
		_ring = value
		queue_redraw()
var _cell_size: float = 100.0
var _target_id: int = -1


func _init() -> void:
	# Added last on the board, so it draws over the arrows; a z_index would
	# also lift it over overlays (Pause, Level complete) drawn after the board.
	z_index = 0
	_sprite.texture = TEXTURE
	_sprite.centered = false
	add_child(_sprite)
	hide()


## Points at [param target] (board-local centre of an arrow).
func point_at(target: Vector2, cell_size: float, arrow_id: int, animate: bool = true) -> void:
	_kill()
	_target_id = arrow_id
	_cell_size = cell_size
	position = target
	var scale_factor := clampf(cell_size * 0.62 / TEXTURE_SIZE.y, 0.5, 1.6)
	_sprite.scale = Vector2.ONE * scale_factor
	# The texture is imported at 2x, so it draws at twice TEXTURE_SIZE.
	_sprite.scale /= 2.0
	var rest := _rest_offset()
	_sprite.position = rest
	show()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	if not animate:
		return
	_tween.tween_callback(_loop_taps)


func hide_hand() -> void:
	_kill()
	_target_id = -1
	hide()


func get_target_id() -> int:
	return _target_id if visible else -1


func _loop_taps() -> void:
	var tap := create_tween().set_loops()
	var rest := _rest_offset()
	var press := _press_offset()
	tap.tween_property(_sprite, "position", press, TAP_SECONDS * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tap.tween_callback(func() -> void: _ring = 0.0)
	tap.tween_property(self, "_ring", 1.0, TAP_SECONDS * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tap.parallel().tween_property(_sprite, "position", rest, TAP_SECONDS * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tap.tween_interval(TAP_SECONDS * 0.25)
	_tween = tap


func _press_offset() -> Vector2:
	return -TIP * 2.0 * _sprite.scale + Vector2(0.06, 0.1) * _cell_size


func _rest_offset() -> Vector2:
	return _press_offset() + Vector2(0.16, 0.2) * _cell_size


func _draw() -> void:
	if _ring <= 0.0 or _ring >= 1.0:
		return
	var radius := _cell_size * (0.18 + 0.3 * _ring)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(Palette.GOLD_LIGHT, 0.55 * (1.0 - _ring)), maxf(_cell_size * 0.03, 2.0), true)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_ring = 0.0
