class_name BoardState
extends RefCounted
## Grid of arrows (and walls) and the rules for moving arrows off the board.
## An arrow can exit when:
##   1. it is not locked: every arrow it requires has already left, and
##   2. its path is clear: every cell between it and the board edge, in its
##      direction, holds neither an arrow nor a wall.
## Walls never move. Mirrors turn a path 90 degrees and black holes send it
## on from their paired white hole (see PathTracer); a path that loops
## forever counts as walled in. If a master arrow is set, its exit releases
## every remaining arrow at once (the level is complete).

var size: Vector2i:
	get:
		return _size

var _size: Vector2i
var _next_id: int = 0
var _arrows_by_id: Dictionary[int, Arrow] = {}
var _arrow_id_by_cell: Dictionary[Vector2i, int] = {}
var _walls: Dictionary[Vector2i, bool] = {}
## cell -> PathTracer.MIRROR_*.
var _mirrors: Dictionary = {}
## black hole cell -> white hole cell.
var _portals: Dictionary = {}
var _white_holes: Dictionary[Vector2i, bool] = {}
var _master_id: int = -1


func _init(p_size: Vector2i) -> void:
	if p_size.x <= 0 or p_size.y <= 0:
		push_error("BoardState: invalid size %s" % p_size)
	_size = p_size.max(Vector2i.ZERO)


## Places an arrow and returns its id, or -1 if the cell is outside the
## board or already occupied (the caller reports invalid data).
## Ids are assigned sequentially from 0.
func add_arrow(cell: Vector2i, direction: Arrow.Direction) -> int:
	if not is_inside(cell) or not _is_plain(cell):
		return -1
	var arrow := Arrow.new(_next_id, cell, direction)
	_next_id += 1
	_arrows_by_id[arrow.id] = arrow
	_arrow_id_by_cell[cell] = arrow.id
	return arrow.id


## Places a wall. Returns false outside the board or on an occupied cell.
func add_wall(cell: Vector2i) -> bool:
	if not is_inside(cell) or not _is_plain(cell):
		return false
	_walls[cell] = true
	return true


## Places a mirror (PathTracer.MIRROR_SLASH or MIRROR_BACKSLASH).
func add_mirror(cell: Vector2i, kind: int) -> bool:
	if not is_inside(cell) or not _is_plain(cell):
		return false
	_mirrors[cell] = kind
	return true


## Links a black hole to the white hole it sends arrows out of.
func add_portal(black_hole: Vector2i, white_hole: Vector2i) -> bool:
	if black_hole == white_hole or not is_inside(black_hole) or not is_inside(white_hole):
		return false
	if not _is_plain(black_hole) or not _is_plain(white_hole):
		return false
	_portals[black_hole] = white_hole
	_white_holes[white_hole] = true
	return true


func get_mirrors() -> Dictionary:
	return _mirrors


func get_portals() -> Dictionary:
	return _portals


## Animation waypoints for the arrow's way out (see PathTracer.trace).
func get_exit_waypoints(id: int) -> Array[Dictionary]:
	var arrow := get_arrow(id)
	if arrow == null:
		return []
	return _trace(arrow)["waypoints"]


func _trace(arrow: Arrow) -> Dictionary:
	return PathTracer.trace(arrow.cell, arrow.direction, _size, _mirrors, _portals)


## True if nothing (arrow, wall, mirror or hole) occupies the cell.
func _is_plain(cell: Vector2i) -> bool:
	return not (_arrow_id_by_cell.has(cell) or _walls.has(cell) or _mirrors.has(cell) or _portals.has(cell) or _white_holes.has(cell))


func is_wall(cell: Vector2i) -> bool:
	return _walls.has(cell)


func get_walls() -> Array[Vector2i]:
	var walls: Array[Vector2i] = []
	walls.assign(_walls.keys())
	return walls


## Marks [param id] as the master arrow. Returns false for an unknown id.
func set_master(id: int) -> bool:
	if not _arrows_by_id.has(id):
		return false
	_master_id = id
	return true


func get_master_id() -> int:
	return _master_id


func is_master(id: int) -> bool:
	return id >= 0 and id == _master_id


## Makes [param dependent_id] wait until [param required_id] has left.
## Rejects unknown ids, self-dependencies, duplicates and anything that
## would create a dependency cycle (which could never be solved).
func add_dependency(dependent_id: int, required_id: int) -> bool:
	var dependent := get_arrow(dependent_id)
	if dependent == null or get_arrow(required_id) == null:
		return false
	if dependent_id == required_id or dependent.requires.has(required_id):
		return false
	if _depends_on(required_id, dependent_id):
		return false
	dependent.requires.append(required_id)
	return true


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


func get_arrow(id: int) -> Arrow:
	return _arrows_by_id.get(id)


func get_arrow_at(cell: Vector2i) -> Arrow:
	if not _arrow_id_by_cell.has(cell):
		return null
	return _arrows_by_id[_arrow_id_by_cell[cell]]


func get_arrows() -> Array[Arrow]:
	var arrows: Array[Arrow] = []
	arrows.assign(_arrows_by_id.values())
	return arrows


func arrow_count() -> int:
	return _arrows_by_id.size()


func is_cleared() -> bool:
	return _arrows_by_id.is_empty()


## Cells the arrow travels through to leave the board, nearest first.
## Empty for an unknown id or an arrow already on the edge.
func get_exit_path(id: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var arrow := get_arrow(id)
	if arrow == null:
		return path
	path.assign(_trace(arrow)["cells"])
	return path


## The nearest arrow standing in this arrow's exit path, or null if clear.
func find_blocker(id: int) -> Arrow:
	for cell: Vector2i in get_exit_path(id):
		var other := get_arrow_at(cell)
		if other != null and other.id != id:
			return other
	return null


## Required arrows still on the board, in the order they were added.
## Empty when the arrow is free of dependencies (or unknown).
func get_pending_requirements(id: int) -> Array[Arrow]:
	var pending: Array[Arrow] = []
	var arrow := get_arrow(id)
	if arrow == null:
		return pending
	for required_id: int in arrow.requires:
		var required := get_arrow(required_id)
		if required != null:
			pending.append(required)
	return pending


func is_locked(id: int) -> bool:
	return not get_pending_requirements(id).is_empty()


## True if a wall stands in the arrow's exit path (it can never leave).
func is_walled_in(id: int) -> bool:
	var arrow := get_arrow(id)
	if arrow != null and not _trace(arrow)["escaped"]:
		return true
	for cell: Vector2i in get_exit_path(id):
		if _walls.has(cell):
			return true
	return false


func can_exit(id: int) -> bool:
	return _arrows_by_id.has(id) and not is_locked(id) and find_blocker(id) == null and not is_walled_in(id)


## Removes the arrow if it is unlocked and its path is clear. Removing the
## master arrow removes every arrow (all escape with it).
## Returns whether it exited. Arrows that required it become free of
## that requirement automatically, since pending requirements are
## computed from the arrows still on the board.
func try_exit(id: int) -> bool:
	if not can_exit(id):
		return false
	if is_master(id):
		_arrows_by_id.clear()
		_arrow_id_by_cell.clear()
		return true
	var arrow: Arrow = _arrows_by_id[id]
	_arrows_by_id.erase(id)
	_arrow_id_by_cell.erase(arrow.cell)
	return true


## True if [param from_id] requires [param to_id], directly or transitively.
func _depends_on(from_id: int, to_id: int) -> bool:
	var stack: Array[int] = [from_id]
	var visited: Dictionary[int, bool] = {}
	while not stack.is_empty():
		var current: int = stack.pop_back()
		if current == to_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		var arrow := get_arrow(current)
		if arrow != null:
			stack.append_array(arrow.requires)
	return false
