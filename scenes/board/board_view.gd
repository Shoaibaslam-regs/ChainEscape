class_name BoardView
extends Control
## Renders a BoardState, turns taps into exit attempts and plays the results.
## Holds no rules of its own: all decisions come from BoardState, which is
## updated instantly; every animation here is visual only.

signal arrow_exited(arrow: Arrow)
signal arrow_blocked(arrow: Arrow, blocker: Arrow)
signal arrow_locked(arrow: Arrow, required: Array[Arrow])
## A red (already tried, still stuck) arrow was tapped again: no move is spent.
signal arrow_retapped(arrow: Arrow)
signal board_cleared
signal intro_finished
## A chain broke because [param key_arrow] left; [param lock_arrow] waited on it.
signal chain_broken(lock_arrow: Arrow, key_arrow: Arrow)
## The master arrow left and took every other arrow with it.
signal master_released(master: Arrow)

## Extra cells an exiting arrow travels past the edge while fading out.
const EXIT_OVERSHOOT_CELLS := 1.5
const GRID_DOT_COLOR := Color(Palette.GOLD, 0.16)

## Level-start fly-in: each arrow arrives along its own axis from the side it
## will later leave by, staggered outward from the board centre.
const INTRO_FLIGHT_SECONDS := 0.4
const INTRO_STAGGER_SECONDS := 0.35
const INTRO_BADGES_SECONDS := 0.15
## How far (in board widths) arrows start from their cells.
const INTRO_TRAVEL_BOARDS := 0.9
## Chain links start breaking this long after the key begins its exit, and
## the padlock opens once the break reaches it.
const UNLOCK_DELAY_SECONDS := 0.18
## Hidden-links twist: how long a tapped lock shows its chains.
const REVEAL_SECONDS := 1.6
## Master release cascade: arrows leave nearest-first, this far apart per cell
## of distance from the master.
const CASCADE_STEP_SECONDS := 0.04
## Mirrors and black holes. Each black-hole pair has its own tint.
const MIRROR_DARK := Color("4E5666")
const MIRROR_LIGHT := Color("E6EBF2")
const HOLE_TINTS: Array[Color] = [Color("9A7BFF"), Color("45C2B1")]
const HOLE_CORE := Color("050507")
const WALL_FILL := Color("1E1B16")
const WALL_EDGE := Color(Palette.GOLD, 0.55)
const WALL_HATCH := Color(Palette.GOLD, 0.22)

## Hidden-links twist: chains and key rings are drawn only for locks the
## player has just tapped.
var hide_links: bool = false

var _board: BoardState
var _arrow_views: Dictionary[int, ArrowView] = {}
## Arrows tapped while stuck; they stay red until they can leave.
var _marked_wrong: Dictionary[int, bool] = {}
## The arrow theme's metal stops, applied to every arrow view.
var arrow_metal: PackedColorArray = ArrowTheme.colors_of(ArrowTheme.THEMES[0]):
	set(value):
		arrow_metal = value
		for view: ArrowView in _arrow_views.values():
			view.metal = value
var _cell_size: float = 0.0
var _origin: Vector2 = Vector2.ZERO
## Added before the arrows, so chains draw underneath them and their badges:
## each chain then visibly hangs from its padlock and key ring.
var _chain_layer := ChainLayer.new()
var _intro_tween: Tween
var _intro_playing: bool = false
## Set when play_intro() is called before the board has a size; the intro
## then starts on the first layout.
var _intro_pending: bool = false
## Lock arrow ids whose chains are currently revealed (hidden-links twist).
var _revealed_locks: Dictionary[int, bool] = {}
var _wall_style: StyleBoxFlat


func _init() -> void:
	add_child(_chain_layer)


func set_board(board: BoardState) -> void:
	_stop_intro()
	for view: ArrowView in _arrow_views.values():
		view.queue_free()
	_arrow_views.clear()
	_board = board
	_marked_wrong.clear()
	if _board != null:
		for arrow: Arrow in _board.get_arrows():
			var view := ArrowView.new()
			view.setup(arrow)
			view.is_master = _board.is_master(arrow.id)
			view.metal = arrow_metal
			add_child(view)
			_arrow_views[arrow.id] = view
	_revealed_locks.clear()
	_update_layout()
	_refresh_dependencies(false)


func get_board() -> BoardState:
	return _board


func get_arrow_view(id: int) -> ArrowView:
	return _arrow_views.get(id)


func get_chain_layer() -> ChainLayer:
	return _chain_layer


func is_intro_playing() -> bool:
	return _intro_playing


## Local position of a cell's centre.
func get_cell_size() -> float:
	return _cell_size


func cell_to_local(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size


func local_to_cell(local_position: Vector2) -> Vector2i:
	if _cell_size <= 0.0:
		return Vector2i(-1, -1)
	return Vector2i(((local_position - _origin) / _cell_size).floor())


## Plays the level-start fly-in. Taps during it only finish it early.
func play_intro() -> void:
	_stop_intro()
	if _board == null or _arrow_views.is_empty():
		return
	if _cell_size <= 0.0:
		_intro_pending = true
		return
	_intro_pending = false
	_intro_playing = true
	var center := _origin + Vector2(_board.size) * _cell_size * 0.5
	var max_distance := maxf(center.distance_to(_origin), 1.0)
	var travel := size.x * INTRO_TRAVEL_BOARDS
	for view: ArrowView in _arrow_views.values():
		view.badge_alpha = 0.0
		var target := view.position
		var delay := INTRO_STAGGER_SECONDS * clampf(target.distance_to(center) / max_distance, 0.0, 1.0)
		var start := target + Vector2(Arrow.direction_to_vector(view.direction)) * travel
		view.play_arrival(start, delay, INTRO_FLIGHT_SECONDS)
	_chain_layer.modulate.a = 0.0
	var arrivals_end := INTRO_STAGGER_SECONDS + INTRO_FLIGHT_SECONDS
	_intro_tween = create_tween().set_parallel()
	_intro_tween.tween_property(_chain_layer, "modulate:a", 1.0, INTRO_BADGES_SECONDS).set_delay(arrivals_end - 0.1)
	for view: ArrowView in _arrow_views.values():
		_intro_tween.tween_property(view, "badge_alpha", 1.0, INTRO_BADGES_SECONDS).set_delay(arrivals_end - 0.1)
	_intro_tween.chain().tween_callback(_on_intro_done)


## Snaps the fly-in to its end state.
func finish_intro() -> void:
	if not _intro_playing:
		return
	_stop_intro()
	intro_finished.emit()


## Handles a tap at a local position. Public so tests can drive it directly.
## Dependencies are checked before the path, since a locked arrow can't go
## regardless of what stands in front of it.
func tap_at(local_position: Vector2) -> void:
	if _board == null:
		return
	if _intro_playing:
		finish_intro()
		return
	var arrow := _board.get_arrow_at(local_to_cell(local_position))
	if arrow == null:
		return
	if _marked_wrong.has(arrow.id) and not _board.can_exit(arrow.id):
		var still_view: ArrowView = _arrow_views.get(arrow.id)
		if still_view != null:
			still_view.play_blocked()
		if hide_links:
			_reveal_links(arrow.id)
		arrow_retapped.emit(arrow)
		return
	var pending := _board.get_pending_requirements(arrow.id)
	if not pending.is_empty():
		_play_rejected(arrow, pending)
		_mark_wrong(arrow.id)
		if hide_links:
			_reveal_links(arrow.id)
		arrow_locked.emit(arrow, pending)
		return
	var blocker := _board.find_blocker(arrow.id)
	if blocker != null or _board.is_walled_in(arrow.id):
		var causes: Array[Arrow] = []
		if blocker != null:
			causes.append(blocker)
		_play_rejected(arrow, causes)
		_mark_wrong(arrow.id)
		arrow_blocked.emit(arrow, blocker)
		return
	if _board.is_master(arrow.id):
		_release_master(arrow)
		return
	var waiting := _arrows_waiting_for(arrow)
	var distance := _board.get_exit_path(arrow.id).size() + EXIT_OVERSHOOT_CELLS
	var waypoints := _board.get_exit_waypoints(arrow.id)
	if not _board.try_exit(arrow.id):
		return
	var view: ArrowView = _arrow_views.get(arrow.id)
	_arrow_views.erase(arrow.id)
	if view != null:
		if waypoints.size() > 2:
			view.play_exit_path(_waypoint_positions(waypoints))
		else:
			view.play_exit(distance)
	for waiting_arrow: Arrow in waiting:
		_spawn_chain_break(waiting_arrow, arrow)
	_refresh_dependencies(true)
	arrow_exited.emit(arrow)
	if _board.is_cleared():
		board_cleared.emit()


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		tap_at(mouse.position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# Layout changes move every target, so a running intro restarts.
		var restart_intro := _intro_playing or _intro_pending
		_stop_intro()
		_update_layout()
		if restart_intro:
			play_intro()


## Faint gold dots mark every cell, so the grid reads without tiles; walls
## are dark blocks with a gold edge and hatching.
func _draw() -> void:
	if _board == null or _cell_size <= 0.0:
		return
	var radius := maxf(_cell_size * 0.035, 1.5)
	for y: int in _board.size.y:
		for x: int in _board.size.x:
			var cell := Vector2i(x, y)
			if _board.is_wall(cell):
				_draw_wall(cell)
			elif _board.get_mirrors().has(cell):
				_draw_mirror(cell, _board.get_mirrors()[cell])
			elif _hole_tint(cell) != Color.TRANSPARENT:
				pass
			else:
				draw_circle(cell_to_local(cell), radius, GRID_DOT_COLOR, true, -1.0, true)


	var pair := 0
	for black: Vector2i in _board.get_portals():
		var tint := HOLE_TINTS[pair % HOLE_TINTS.size()]
		_draw_black_hole(black, tint)
		_draw_white_hole(_board.get_portals()[black], tint)
		pair += 1


## Tint of the black/white hole at [param cell], or transparent if none.
func _hole_tint(cell: Vector2i) -> Color:
	var pair := 0
	for black: Vector2i in _board.get_portals():
		if black == cell or _board.get_portals()[black] == cell:
			return HOLE_TINTS[pair % HOLE_TINTS.size()]
		pair += 1
	return Color.TRANSPARENT


## A polished steel bar set corner to corner.
func _draw_mirror(cell: Vector2i, kind: int) -> void:
	var center := cell_to_local(cell)
	var reach := _cell_size * 0.34
	var a := center + (Vector2(-reach, reach) if kind == PathTracer.MIRROR_SLASH else Vector2(-reach, -reach))
	var b := center + (Vector2(reach, -reach) if kind == PathTracer.MIRROR_SLASH else Vector2(reach, reach))
	draw_line(a, b, MIRROR_DARK, maxf(_cell_size * 0.13, 3.0), true)
	draw_line(a, b, Color(MIRROR_LIGHT, 0.9), maxf(_cell_size * 0.05, 1.5), true)
	draw_circle(a, _cell_size * 0.065, MIRROR_DARK, true, -1.0, true)
	draw_circle(b, _cell_size * 0.065, MIRROR_DARK, true, -1.0, true)


## A dark core inside soft glowing rings, with a swirl.
func _draw_black_hole(cell: Vector2i, tint: Color) -> void:
	var center := cell_to_local(cell)
	var radius := _cell_size * 0.36
	for ring: int in 4:
		var t := float(ring) / 3.0
		draw_circle(center, radius * (1.25 - 0.12 * ring), Color(tint, 0.06 + 0.06 * t), true, -1.0, true)
	draw_circle(center, radius * 0.78, HOLE_CORE, true, -1.0, true)
	draw_arc(center, radius * 0.8, 0.0, TAU, 40, Color(tint, 0.9), maxf(_cell_size * 0.035, 1.5), true)
	for arm: int in 3:
		var start := arm * TAU / 3.0
		draw_arc(center, radius * 0.55, start, start + 1.6, 16, Color(tint, 0.45), maxf(_cell_size * 0.025, 1.0), true)


## A bright ring where swallowed arrows come back out.
func _draw_white_hole(cell: Vector2i, tint: Color) -> void:
	var center := cell_to_local(cell)
	var radius := _cell_size * 0.3
	draw_circle(center, radius * 1.3, Color(tint, 0.12), true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 40, Color(Color.WHITE, 0.95), maxf(_cell_size * 0.045, 2.0), true)
	draw_arc(center, radius * 0.62, 0.0, TAU, 32, Color(tint, 0.85), maxf(_cell_size * 0.03, 1.5), true)
	draw_circle(center, radius * 0.22, Color(Color.WHITE, 0.9), true, -1.0, true)


func _draw_wall(cell: Vector2i) -> void:
	if _wall_style == null:
		_wall_style = StyleBoxFlat.new()
		_wall_style.bg_color = WALL_FILL
		_wall_style.border_color = WALL_EDGE
		_wall_style.anti_aliasing = true
	var inset := _cell_size * 0.08
	var rect := Rect2(cell_to_local(cell) - Vector2.ONE * (_cell_size * 0.5 - inset), Vector2.ONE * (_cell_size - inset * 2.0))
	_wall_style.set_corner_radius_all(int(_cell_size * 0.16))
	_wall_style.set_border_width_all(maxi(int(_cell_size * 0.025), 1))
	draw_style_box(_wall_style, rect)
	var width := maxf(_cell_size * 0.025, 1.0)
	var a := rect.position + rect.size * Vector2(0.28, 0.72)
	var b := rect.position + rect.size * Vector2(0.72, 0.28)
	var shift := rect.size * Vector2(0.18, 0.18)
	draw_line(a, b, WALL_HATCH, width, true)
	draw_line(a + shift, b + shift, WALL_HATCH, width, true)


func _update_layout() -> void:
	if _board == null or _board.size.x <= 0 or _board.size.y <= 0:
		_cell_size = 0.0
		_chain_layer.clear()
		queue_redraw()
		return
	var grid := Vector2(_board.size)
	_cell_size = floorf(minf(size.x / grid.x, size.y / grid.y))
	_origin = ((size - grid * _cell_size) * 0.5).floor()
	_chain_layer.cell_size = _cell_size
	for id: int in _arrow_views:
		var view := _arrow_views[id]
		view.cell_size = _cell_size
		view.position = cell_to_local(_board.get_arrow(id).cell)
	_refresh_chains()
	queue_redraw()


## Syncs lock badges, key rings and chains with the board after it changes.
## With [param animate_unlocks], arrows that just became free play their
## unlock animation instead of snapping.
func _refresh_dependencies(animate_unlocks: bool) -> void:
	if _board == null:
		_chain_layer.clear()
		return
	var key_ids: Dictionary[int, bool] = {}
	for arrow: Arrow in _board.get_arrows():
		if not _links_visible(arrow.id):
			continue
		for required: Arrow in _board.get_pending_requirements(arrow.id):
			key_ids[required.id] = true
	var lock_directions: Dictionary[int, Vector2] = {}
	var key_directions: Dictionary[int, Vector2] = {}
	for arrow: Arrow in _board.get_arrows():
		for required: Arrow in _board.get_pending_requirements(arrow.id):
			var toward_key := Vector2(required.cell - arrow.cell).normalized()
			lock_directions[arrow.id] = lock_directions.get(arrow.id, Vector2.ZERO) + toward_key
			key_directions[required.id] = key_directions.get(required.id, Vector2.ZERO) - toward_key
	for id: int in _arrow_views:
		var view := _arrow_views[id]
		var pending_count := _board.get_pending_requirements(id).size()
		view.lock_count = pending_count
		view.is_key = key_ids.has(id)
		if lock_directions.has(id):
			view.lock_badge_direction = lock_directions[id]
		if key_directions.has(id):
			view.key_badge_direction = key_directions[id]
		if pending_count > 0:
			view.is_locked = true
		elif view.is_locked and animate_unlocks:
			view.play_unlock(UNLOCK_DELAY_SECONDS)
		elif not view.is_unlocking():
			view.is_locked = false
	# A red arrow turns back to normal as soon as it can leave.
	for id: int in _marked_wrong.keys():
		if _board.get_arrow(id) == null or _board.can_exit(id):
			_marked_wrong.erase(id)
			var marked_view: ArrowView = _arrow_views.get(id)
			if marked_view != null:
				marked_view.is_marked_wrong = false
	_refresh_chains()


## Local positions for an exit path; the last point lies past the edge.
func _waypoint_positions(waypoints: Array[Dictionary]) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for point: Dictionary in waypoints:
		var position_local := cell_to_local(point["cell"])
		if point["kind"] == PathTracer.EDGE:
			position_local += Vector2(Arrow.direction_to_vector(point["dir"])) * EXIT_OVERSHOOT_CELLS * _cell_size
		points.append({"pos": position_local, "kind": point["kind"], "dir": point["dir"]})
	return points


func _mark_wrong(id: int) -> void:
	_marked_wrong[id] = true
	var view: ArrowView = _arrow_views.get(id)
	if view != null:
		view.is_marked_wrong = true


func is_marked_wrong(id: int) -> bool:
	return _marked_wrong.has(id)


func _refresh_chains() -> void:
	var segments: Array[PackedVector2Array] = []
	if _board != null and _cell_size > 0.0:
		for arrow: Arrow in _board.get_arrows():
			if not _links_visible(arrow.id):
				continue
			for required: Arrow in _board.get_pending_requirements(arrow.id):
				segments.append(PackedVector2Array([cell_to_local(arrow.cell), cell_to_local(required.cell)]))
	_chain_layer.set_segments(segments)


func _links_visible(lock_id: int) -> bool:
	return not hide_links or _revealed_locks.has(lock_id)


func is_links_revealed(lock_id: int) -> bool:
	return _revealed_locks.has(lock_id)


## Hidden-links twist: shows this lock's chains and keys briefly.
func _reveal_links(lock_id: int) -> void:
	_revealed_locks[lock_id] = true
	_refresh_dependencies(false)
	get_tree().create_timer(REVEAL_SECONDS).timeout.connect(func() -> void:
		if not is_instance_valid(self) or _board == null:
			return
		_revealed_locks.erase(lock_id)
		_refresh_dependencies(false))


## The master arrow leaves and every other arrow escapes with it: a gold
## ripple spreads from its cell and the rest launch nearest-first.
func _release_master(master: Arrow) -> void:
	var master_point := cell_to_local(master.cell)
	var others: Array[Arrow] = []
	for other: Arrow in _board.get_arrows():
		if other.id != master.id:
			others.append(other)
	var distances: Dictionary[int, float] = {}
	for other: Arrow in others:
		distances[other.id] = _board.get_exit_path(other.id).size() + EXIT_OVERSHOOT_CELLS
	var master_distance := _board.get_exit_path(master.id).size() + EXIT_OVERSHOOT_CELLS
	if not _board.try_exit(master.id):
		return
	var ripple := MasterRippleEffect.new()
	ripple.position = master_point
	ripple.max_radius = maxf(size.x, size.y)
	ripple.line_width = maxf(_cell_size * 0.06, 2.0)
	ripple.z_index = 3
	add_child(ripple)
	var master_view: ArrowView = _arrow_views.get(master.id)
	if master_view != null:
		master_view.play_exit(master_distance)
	for other: Arrow in others:
		var view: ArrowView = _arrow_views.get(other.id)
		if view != null:
			var delay := Vector2(other.cell - master.cell).length() * CASCADE_STEP_SECONDS
			view.play_exit(distances[other.id], delay)
	_arrow_views.clear()
	_refresh_dependencies(false)
	master_released.emit(master)
	arrow_exited.emit(master)
	board_cleared.emit()


func _arrows_waiting_for(key: Arrow) -> Array[Arrow]:
	var waiting: Array[Arrow] = []
	for other: Arrow in _board.get_arrows():
		if _board.get_pending_requirements(other.id).has(key):
			waiting.append(other)
	return waiting


func _spawn_chain_break(lock_arrow: Arrow, key_arrow: Arrow) -> void:
	var effect := ChainBreakEffect.new()
	effect.z_index = 1
	effect.setup(cell_to_local(lock_arrow.cell), cell_to_local(key_arrow.cell), _cell_size)
	add_child(effect)
	chain_broken.emit(lock_arrow, key_arrow)


## Bumps the tapped arrow and flashes the arrows responsible.
func _play_rejected(arrow: Arrow, causes: Array[Arrow]) -> void:
	var view: ArrowView = _arrow_views.get(arrow.id)
	if view != null:
		view.play_blocked()
	for cause: Arrow in causes:
		var cause_view: ArrowView = _arrow_views.get(cause.id)
		if cause_view != null:
			cause_view.flash()


func _on_intro_done() -> void:
	_intro_playing = false
	intro_finished.emit()


func _stop_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_playing = false
	_intro_pending = false
	_chain_layer.modulate.a = 1.0
	for view: ArrowView in _arrow_views.values():
		view.finish_arrival()
		view.badge_alpha = 1.0
