class_name ChainBreakEffect
extends Node2D
## A broken chain: its links pop apart one by one, starting at the key end and
## running toward the lock, each flung sideways and falling away while fading.
## Purely visual; frees itself when done.

const LINK_DURATION := 0.42
const LINK_STAGGER := 0.03
const SCATTER_CELLS := 0.35
const FALL_CELLS := 0.6
const SPIN := 2.2

var _links: Array[Vector2] = []
var _angle: float = 0.0
var _cell_size: float = 64.0
var _progress: float = 0.0:
	set(value):
		_progress = value
		queue_redraw()


## [param lock_point] and [param key_point] are the two arrow centres.
func setup(lock_point: Vector2, key_point: Vector2, cell_size: float) -> void:
	_cell_size = cell_size
	_angle = lock_point.angle_to_point(key_point)
	_links = ChainLayer.link_positions(lock_point, key_point, cell_size)
	_links.reverse()


func get_total_duration() -> float:
	return LINK_DURATION + LINK_STAGGER * maxi(_links.size() - 1, 0)


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_progress", 1.0, get_total_duration())
	tween.tween_callback(queue_free)


func _draw() -> void:
	var elapsed := _progress * get_total_duration()
	var sideways := Vector2.from_angle(_angle + PI * 0.5)
	for index: int in _links.size():
		var t := clampf((elapsed - index * LINK_STAGGER) / LINK_DURATION, 0.0, 1.0)
		var side := 1.0 if index % 2 == 0 else -1.0
		var spread := 0.6 + 0.4 * fmod(index * 0.37, 1.0)
		var offset := sideways * side * spread * SCATTER_CELLS * _cell_size * t
		offset.y += FALL_CELLS * _cell_size * t * t
		ChainLayer.draw_link(self, _links[index] + offset, _angle + side * SPIN * t, index % 2 == 1, _cell_size, 1.0 - t)
