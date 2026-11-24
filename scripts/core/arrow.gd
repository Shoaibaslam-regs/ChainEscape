class_name Arrow
extends RefCounted
## One arrow on the board: a cell position and the direction it exits in.
## Pure data — no rendering or input.

enum Direction { UP, DOWN, LEFT, RIGHT }

var id: int
var cell: Vector2i
var direction: Direction
## Ids of arrows that must leave the board before this one may exit.
## Managed by BoardState.add_dependency; never contains duplicates.
var requires: Array[int] = []


func _init(p_id: int, p_cell: Vector2i, p_direction: Direction) -> void:
	id = p_id
	cell = p_cell
	direction = p_direction


## Grid step for a direction. Grid y grows downward, so UP is (0, -1).
static func direction_to_vector(dir: Direction) -> Vector2i:
	match dir:
		Direction.UP:
			return Vector2i.UP
		Direction.DOWN:
			return Vector2i.DOWN
		Direction.LEFT:
			return Vector2i.LEFT
		Direction.RIGHT:
			return Vector2i.RIGHT
	push_error("Arrow: unknown direction %d" % dir)
	return Vector2i.ZERO
