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
## Chains are barriers: an arrow cannot fly through a chain that is still on
## the board (it breaks when its key arrow leaves). Off on hidden-links
## levels, where the chains cannot be seen.
var chains_block: bool = true
## A flight path closer than this (in cells) to a chain crosses it.
const CHAIN_BLOCK_DISTANCE := 0.2
## Flight paths never change while an arrow stays (arrows only ever leave),
## so each arrow's trace is computed once. Cleared if walls, mirrors or holes
## are added.
var _trace_cache: Dictionary[int, Dictionary] = {}
var _path_cache: Dictionary[int, Array] = {}
var _walled_cache: Dictionary[int, bool] = {}
## Active chains, rebuilt only when arrows or links change.
var _chains_cache: Array[Vector4i] = []
var _chains_dirty: bool = true


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
	_clear_path_caches()
	return true


## Places a mirror (PathTracer.MIRROR_SLASH or MIRROR_BACKSLASH).
func add_mirror(cell: Vector2i, kind: int) -> bool:
	if not is_inside(cell) or not _is_plain(cell):
		return false
	_mirrors[cell] = kind
	_clear_path_caches()
	return true


## Links a black hole to the white hole it sends arrows out of.
func add_portal(black_hole: Vector2i, white_hole: Vector2i) -> bool:
	if black_hole == white_hole or not is_inside(black_hole) or not is_inside(white_hole):
		return false
	if not _is_plain(black_hole) or not _is_plain(white_hole):
		return false
	_portals[black_hole] = white_hole
	_white_holes[white_hole] = true
	_clear_path_caches()
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
	if not _trace_cache.has(arrow.id):
		_trace_cache[arrow.id] = PathTracer.trace(arrow.cell, arrow.direction, _size, _mirrors, _portals)
	return _trace_cache[arrow.id]


func _clear_path_caches() -> void:
	_trace_cache.clear()
	_path_cache.clear()
	_walled_cache.clear()


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
	_chains_dirty = true
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
	if not _path_cache.has(id):
		var cells: Array[Vector2i] = []
		cells.assign(_trace(arrow)["cells"])
		_path_cache[id] = cells
	path.assign(_path_cache[id])
	return path


## The nearest arrow standing in this arrow's exit path, or null if clear.
func find_blocker(id: int) -> Arrow:
	var arrow := get_arrow(id)
	if arrow == null:
		return null
	get_exit_path(id)
	for cell: Vector2i in _path_cache[id]:
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
	if arrow == null:
		return false
	if not _walled_cache.has(id):
		var walled: bool = not _trace(arrow)["escaped"]
		if not walled:
			for cell: Vector2i in _trace(arrow)["cells"]:
				if _walls.has(cell):
					walled = true
					break
		_walled_cache[id] = walled
	return _walled_cache[id]


func can_exit(id: int) -> bool:
	# Cheapest checks first.
	return _arrows_by_id.has(id) and not is_locked(id) and not is_walled_in(id) and find_blocker(id) == null \
		and find_blocking_link(id) == NO_LINK


## Chains still on the board, as (lock cell, key cell) pairs: a lock arrow's
## chain to each key arrow that has not left yet.
func get_active_chains() -> Array[Vector4i]:
	if _chains_dirty:
		_chains_cache.clear()
		for arrow: Arrow in _arrows_by_id.values():
			for required_id: int in arrow.requires:
				var key := get_arrow(required_id)
				if key != null:
					_chains_cache.append(Vector4i(arrow.cell.x, arrow.cell.y, key.cell.x, key.cell.y))
		_chains_dirty = false
	return _chains_cache


## The key arrow of the first chain lying across this arrow's flight path
## (release it to break the chain), or null if no chain is in the way. The
## arrow's own chains never block it.
func find_blocking_chain(id: int) -> Arrow:
	var link := find_blocking_link(id)
	return null if link == NO_LINK else get_arrow_at(Vector2i(link.z, link.w))


const NO_LINK := Vector4i(-1, -1, -1, -1)


## The chain (lock cell, key cell) across this arrow's flight path, or NO_LINK.
func find_blocking_link(id: int) -> Vector4i:
	if not chains_block:
		return NO_LINK
	var arrow := get_arrow(id)
	if arrow == null:
		return NO_LINK
	var chains := get_active_chains()
	if chains.is_empty():
		return NO_LINK
	# The flight path as straight segments between neighbouring cell centres
	# (a black-hole jump is not a segment: the arrow is not on the board there).
	var points: Array[Vector2i] = [arrow.cell]
	points.append_array(get_exit_path(id))
	for index: int in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		if absi(a.x - b.x) + absi(a.y - b.y) != 1:
			continue
		for chain: Vector4i in chains:
			var lock_cell := Vector2i(chain.x, chain.y)
			var key_cell := Vector2i(chain.z, chain.w)
			if lock_cell == arrow.cell or key_cell == arrow.cell:
				continue
			if _segment_near_chain(Vector2(a), Vector2(b), Vector2(lock_cell), Vector2(key_cell)):
				return chain
	return NO_LINK


static func _segment_near_chain(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var margin := CHAIN_BLOCK_DISTANCE
	if maxf(a.x, b.x) + margin < minf(c.x, d.x) or minf(a.x, b.x) - margin > maxf(c.x, d.x):
		return false
	if maxf(a.y, b.y) + margin < minf(c.y, d.y) or minf(a.y, b.y) - margin > maxf(c.y, d.y):
		return false
	var closest := Geometry2D.get_closest_points_between_segments(a, b, c, d)
	return closest[0].distance_to(closest[1]) < margin


## Removes the arrow if it is unlocked and its path is clear. Removing the
## master arrow removes every arrow (all escape with it).
## Returns whether it exited. Arrows that required it become free of
## that requirement automatically, since pending requirements are
## computed from the arrows still on the board.
func try_exit(id: int) -> bool:
	if not can_exit(id):
		return false
	_chains_dirty = true
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
