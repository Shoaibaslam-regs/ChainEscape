extends TestSuite
## BoardView: taps map to cells, results are signalled and animated.

var _view: BoardView
var _exited: Array[Arrow] = []
var _blocked: Array = [] # [arrow, blocker] pairs
var _locked: Array = [] # [arrow, required arrows] pairs
var _cleared_count: int = 0
var _blocked_id: int
var _free_id: int


## Board used by most tests:
##   (0,1) RIGHT - path-blocked by (2,1)
##   (2,1) UP    - free
## Pass a board to override it.
func _setup(board: BoardState = null) -> void:
	if board == null:
		board = BoardState.new(Vector2i(3, 3))
		_blocked_id = board.add_arrow(Vector2i(0, 1), Arrow.Direction.RIGHT)
		_free_id = board.add_arrow(Vector2i(2, 1), Arrow.Direction.UP)
	_view = BoardView.new()
	_view.size = Vector2(300, 300)
	tree.root.add_child(_view)
	_view.set_board(board)
	_exited.clear()
	_blocked.clear()
	_locked.clear()
	_cleared_count = 0
	_view.arrow_exited.connect(func(a: Arrow) -> void: _exited.append(a))
	_view.arrow_blocked.connect(func(a: Arrow, b: Arrow) -> void: _blocked.append([a, b]))
	_view.arrow_locked.connect(func(a: Arrow, r: Array[Arrow]) -> void: _locked.append([a, r]))
	_view.board_cleared.connect(func() -> void: _cleared_count += 1)
	await wait_frames(1)


func _teardown() -> void:
	_view.queue_free()
	await wait_frames(1)


func _arrow_view_count() -> int:
	return _view.get_children().filter(func(n: Node) -> bool: return n is ArrowView).size()


func test_layout_maps_cells_both_ways() -> void:
	await _setup()
	check_eq(_view.cell_to_local(Vector2i(1, 1)), Vector2(150, 150), "centre cell position")
	check_eq(_view.local_to_cell(Vector2(10, 290)), Vector2i(0, 2), "bottom-left cell")
	check_eq(_arrow_view_count(), 2, "one view per arrow")
	await _teardown()


func test_tap_blocked_arrow_signals_blocked() -> void:
	await _setup()
	_view.tap_at(_view.cell_to_local(Vector2i(0, 1)))
	check_eq(_blocked.size(), 1, "blocked signal emitted once")
	if _blocked.size() == 1:
		check_eq(_blocked[0][0].id, _blocked_id, "tapped arrow")
		check_eq(_blocked[0][1].id, _free_id, "blocker")
	check(_exited.is_empty(), "nothing exited")
	check_eq(_view.get_board().arrow_count(), 2, "board unchanged")
	await _teardown()


func test_tap_free_arrow_exits_and_view_is_freed() -> void:
	await _setup()
	_view.tap_at(_view.cell_to_local(Vector2i(2, 1)))
	check_eq(_exited.size(), 1, "exit signal emitted")
	check_eq(_view.get_board().arrow_count(), 1, "removed from board immediately")
	await wait_seconds(0.6)
	check_eq(_arrow_view_count(), 1, "exited view freed after animation")
	# The previously blocked arrow can now leave.
	_view.tap_at(_view.cell_to_local(Vector2i(0, 1)))
	check_eq(_exited.size(), 2, "unblocked arrow exits")
	check(_view.get_board().is_cleared(), "board cleared")
	await _teardown()


func test_tapping_same_arrow_twice_exits_once() -> void:
	await _setup()
	var pos := _view.cell_to_local(Vector2i(2, 1))
	_view.tap_at(pos)
	_view.tap_at(pos)
	check_eq(_exited.size(), 1, "second tap during animation ignored")
	await _teardown()


func test_tap_empty_or_outside_does_nothing() -> void:
	await _setup()
	_view.tap_at(_view.cell_to_local(Vector2i(1, 1)))
	_view.tap_at(Vector2(-50, 20))
	_view.tap_at(Vector2(1000, 1000))
	check(_exited.is_empty() and _blocked.is_empty(), "no signals")
	check_eq(_view.get_board().arrow_count(), 2, "board unchanged")
	await _teardown()


func test_mouse_click_input_triggers_tap() -> void:
	await _setup()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _view.cell_to_local(Vector2i(2, 1))
	_view._gui_input(click)
	check_eq(_exited.size(), 1, "left click exits arrow")
	await _teardown()


## (0,0) UP is free on the path but requires (2,2) DOWN.
func _locked_board() -> BoardState:
	var board := BoardState.new(Vector2i(3, 3))
	var dependent := board.add_arrow(Vector2i(0, 0), Arrow.Direction.UP)
	var required := board.add_arrow(Vector2i(2, 2), Arrow.Direction.DOWN)
	board.add_dependency(dependent, required)
	return board


func test_tap_locked_arrow_signals_locked() -> void:
	await _setup(_locked_board())
	check(_view.get_arrow_view(0).is_locked, "dependent drawn locked")
	check(not _view.get_arrow_view(1).is_locked, "required arrow not locked")
	_view.tap_at(_view.cell_to_local(Vector2i(0, 0)))
	check_eq(_locked.size(), 1, "locked signal emitted")
	if _locked.size() == 1:
		check_eq(_locked[0][0].id, 0, "tapped arrow")
		var required: Array[Arrow] = _locked[0][1]
		check(required.size() == 1 and required[0].id == 1, "required arrows reported")
	check(_blocked.is_empty() and _exited.is_empty(), "no other outcome")
	check_eq(_view.get_board().arrow_count(), 2, "board unchanged")
	await _teardown()


func test_exit_of_requirement_unlocks_dependent_view() -> void:
	await _setup(_locked_board())
	_view.tap_at(_view.cell_to_local(Vector2i(2, 2)))
	check_eq(_exited.size(), 1, "required arrow exited")
	check(not _view.get_board().is_locked(0), "rules unlock the dependent instantly")
	check(_view.get_arrow_view(0).is_unlocking(), "padlock plays its unlock animation")
	await wait_seconds(0.7)
	check(not _view.get_arrow_view(0).is_locked, "dependent drawn unlocked after the animation")
	_view.tap_at(_view.cell_to_local(Vector2i(0, 0)))
	check_eq(_exited.size(), 2, "dependent exits")
	await _teardown()


func test_dependent_can_exit_while_unlock_animates() -> void:
	await _setup(_locked_board())
	_view.tap_at(_view.cell_to_local(Vector2i(2, 2)))
	_view.tap_at(_view.cell_to_local(Vector2i(0, 0)))
	check_eq(_exited.size(), 2, "no waiting for the animation")
	await _teardown()


func test_key_ring_lock_count_and_chains() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	var waiting := board.add_arrow(Vector2i(1, 1), Arrow.Direction.UP)
	var first_key := board.add_arrow(Vector2i(0, 2), Arrow.Direction.LEFT)
	var second_key := board.add_arrow(Vector2i(2, 2), Arrow.Direction.RIGHT)
	board.add_dependency(waiting, first_key)
	board.add_dependency(waiting, second_key)
	await _setup(board)
	check_eq(_view.get_arrow_view(waiting).lock_count, 2, "double lock counted")
	check(_view.get_arrow_view(first_key).is_key and _view.get_arrow_view(second_key).is_key, "both keys marked")
	check(not _view.get_arrow_view(waiting).is_key, "waiting arrow is not a key")
	check_eq(_view.get_chain_layer().get_segment_count(), 2, "two chains drawn")
	_view.tap_at(_view.cell_to_local(Vector2i(0, 2)))
	check_eq(_view.get_arrow_view(waiting).lock_count, 1, "one lock left")
	check(_view.get_arrow_view(waiting).is_locked, "still locked by the second key")
	check_eq(_view.get_chain_layer().get_segment_count(), 1, "broken chain removed")
	check_eq(_view.get_children().filter(func(n: Node) -> bool: return n is ChainBreakEffect).size(), 1, "break effect playing")
	await wait_seconds(0.9)
	check_eq(_view.get_children().filter(func(n: Node) -> bool: return n is ChainBreakEffect).size(), 0, "break effect frees itself")
	await _teardown()


func test_intro_flies_arrows_in_and_first_tap_only_finishes_it() -> void:
	await _setup()
	var view := _view.get_arrow_view(_free_id)
	var target := view.position
	_view.play_intro()
	check(_view.is_intro_playing(), "intro playing")
	check(view.position != target, "arrow starts away from its cell")
	check(is_equal_approx(view.position.x, target.x), "an UP arrow arrives along its own column")
	check(view.position.y < target.y, "from above: the side it will leave by")
	_view.tap_at(_view.cell_to_local(Vector2i(2, 1)))
	check(not _view.is_intro_playing(), "tap finishes the intro")
	check_eq(view.position, target, "arrow snapped to its cell")
	check(_exited.is_empty(), "that tap did not move an arrow")
	_view.tap_at(_view.cell_to_local(Vector2i(2, 1)))
	check_eq(_exited.size(), 1, "next tap plays normally")
	await _teardown()


func test_intro_finishes_on_its_own() -> void:
	await _setup()
	var finished := [false]
	_view.intro_finished.connect(func() -> void: finished[0] = true)
	_view.play_intro()
	await wait_seconds(BoardView.INTRO_STAGGER_SECONDS + BoardView.INTRO_FLIGHT_SECONDS + BoardView.INTRO_BADGES_SECONDS + 0.2)
	check(finished[0] and not _view.is_intro_playing(), "intro completes")
	check_eq(_view.get_arrow_view(_free_id).position, _view.cell_to_local(Vector2i(2, 1)), "arrow in its cell")
	await _teardown()


func test_board_cleared_emitted_once_after_last_exit() -> void:
	await _setup()
	_view.tap_at(_view.cell_to_local(Vector2i(2, 1)))
	check_eq(_cleared_count, 0, "not cleared with one arrow left")
	_view.tap_at(_view.cell_to_local(Vector2i(0, 1)))
	check_eq(_cleared_count, 1, "cleared after last exit")
	_view.tap_at(_view.cell_to_local(Vector2i(0, 1)))
	check_eq(_cleared_count, 1, "tapping an empty board does not re-emit")
	await _teardown()


func test_hidden_links_reveal_on_lock_tap() -> void:
	_view = BoardView.new()
	_view.hide_links = true
	_view.size = Vector2(300, 300)
	tree.root.add_child(_view)
	_view.set_board(_locked_board())
	_exited.clear()
	_blocked.clear()
	_locked.clear()
	await wait_frames(1)
	check_eq(_view.get_chain_layer().get_segment_count(), 0, "chains hidden")
	check(not _view.get_arrow_view(1).is_key, "key ring hidden")
	check(_view.get_arrow_view(0).is_locked, "padlock still shown")
	_view.tap_at(_view.cell_to_local(Vector2i(0, 0)))
	check(_view.is_links_revealed(0), "tapping the lock reveals its chain")
	check_eq(_view.get_chain_layer().get_segment_count(), 1, "chain drawn")
	check(_view.get_arrow_view(1).is_key, "key ring shown")
	await wait_seconds(BoardView.REVEAL_SECONDS + 0.2)
	check_eq(_view.get_chain_layer().get_segment_count(), 0, "hidden again")
	await _teardown()


func test_master_release_cascade() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	var master := board.add_arrow(Vector2i(1, 1), Arrow.Direction.UP)
	board.add_arrow(Vector2i(0, 0), Arrow.Direction.DOWN)
	board.add_arrow(Vector2i(2, 2), Arrow.Direction.UP)
	board.set_master(master)
	await _setup(board)
	var released := [false]
	_view.master_released.connect(func(_m: Arrow) -> void: released[0] = true)
	check(_view.get_arrow_view(master).is_master, "master drawn as master")
	_view.tap_at(_view.cell_to_local(Vector2i(1, 1)))
	check(released[0], "master released")
	check(_view.get_board().is_cleared(), "board cleared at once")
	check_eq(_cleared_count, 1, "board_cleared once")
	check_eq(_view.get_children().filter(func(n: Node) -> bool: return n is MasterRippleEffect).size(), 1, "ripple playing")
	await wait_seconds(1.3)
	check_eq(_view.get_children().filter(func(n: Node) -> bool: return n is ArrowView).size(), 0, "every arrow flew off")
	await _teardown()


func test_walled_in_tap_is_blocked() -> void:
	var board := BoardState.new(Vector2i(3, 1))
	board.add_wall(Vector2i(2, 0))
	board.add_arrow(Vector2i(0, 0), Arrow.Direction.RIGHT)
	await _setup(board)
	_view.tap_at(_view.cell_to_local(Vector2i(0, 0)))
	check_eq(_blocked.size(), 1, "blocked by the wall")
	if _blocked.size() == 1:
		check(_blocked[0][1] == null, "no arrow blocker: it's a wall")
	check(_exited.is_empty(), "did not exit")
	await _teardown()
