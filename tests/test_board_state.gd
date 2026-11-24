extends TestSuite
## Rules of BoardState: placement, exit paths, blocking, removal.

const UP := Arrow.Direction.UP
const DOWN := Arrow.Direction.DOWN
const LEFT := Arrow.Direction.LEFT
const RIGHT := Arrow.Direction.RIGHT


func test_direction_vectors() -> void:
	check_eq(Arrow.direction_to_vector(UP), Vector2i(0, -1), "UP")
	check_eq(Arrow.direction_to_vector(DOWN), Vector2i(0, 1), "DOWN")
	check_eq(Arrow.direction_to_vector(LEFT), Vector2i(-1, 0), "LEFT")
	check_eq(Arrow.direction_to_vector(RIGHT), Vector2i(1, 0), "RIGHT")


func test_add_arrow_assigns_sequential_ids() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	check_eq(board.add_arrow(Vector2i(0, 0), UP), 0, "first id")
	check_eq(board.add_arrow(Vector2i(1, 0), UP), 1, "second id")
	check_eq(board.arrow_count(), 2, "count")
	check_eq(board.get_arrow_at(Vector2i(1, 0)).id, 1, "lookup by cell")


func test_add_arrow_rejects_outside_and_occupied_cells() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	board.add_arrow(Vector2i(1, 1), UP)
	check_eq(board.add_arrow(Vector2i(1, 1), DOWN), -1, "occupied cell rejected")
	check_eq(board.add_arrow(Vector2i(3, 0), DOWN), -1, "x out of range rejected")
	check_eq(board.add_arrow(Vector2i(0, -1), DOWN), -1, "negative y rejected")
	check_eq(board.arrow_count(), 1, "only the valid arrow was added")


func test_exit_path_runs_to_edge() -> void:
	var board := BoardState.new(Vector2i(4, 3))
	var id := board.add_arrow(Vector2i(1, 1), RIGHT)
	var expected: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1)]
	check_eq(board.get_exit_path(id), expected, "path to right edge")
	var edge := board.add_arrow(Vector2i(0, 0), UP)
	check(board.get_exit_path(edge).is_empty(), "edge arrow has empty path")


func test_clear_path_can_exit() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	var id := board.add_arrow(Vector2i(1, 1), LEFT)
	board.add_arrow(Vector2i(2, 1), UP) # behind it
	board.add_arrow(Vector2i(1, 0), LEFT) # beside its path
	check(board.can_exit(id), "arrows behind or beside do not block")


func test_nearest_blocker_is_reported() -> void:
	var board := BoardState.new(Vector2i(5, 1))
	var id := board.add_arrow(Vector2i(0, 0), RIGHT)
	var near := board.add_arrow(Vector2i(2, 0), UP)
	board.add_arrow(Vector2i(4, 0), UP)
	check(not board.can_exit(id), "blocked arrow cannot exit")
	check_eq(board.find_blocker(id).id, near, "nearest blocker")


func test_blocked_exit_leaves_board_unchanged() -> void:
	var board := BoardState.new(Vector2i(3, 1))
	var id := board.add_arrow(Vector2i(0, 0), RIGHT)
	board.add_arrow(Vector2i(2, 0), UP)
	check(not board.try_exit(id), "try_exit fails")
	check_eq(board.arrow_count(), 2, "nothing removed")
	check(board.get_arrow(id) != null, "arrow still present")


func test_exit_removes_arrow_and_unblocks_others() -> void:
	var board := BoardState.new(Vector2i(3, 1))
	var back := board.add_arrow(Vector2i(0, 0), RIGHT)
	var front := board.add_arrow(Vector2i(2, 0), UP)
	check(board.try_exit(front), "front arrow exits")
	check(board.get_arrow(front) == null, "front removed by id")
	check(board.get_arrow_at(Vector2i(2, 0)) == null, "front cell freed")
	check(board.can_exit(back), "back arrow is now free")
	check(board.try_exit(back), "back arrow exits")
	check(board.is_cleared(), "board cleared")


func test_facing_arrows_deadlock() -> void:
	var board := BoardState.new(Vector2i(2, 1))
	var a := board.add_arrow(Vector2i(0, 0), RIGHT)
	var b := board.add_arrow(Vector2i(1, 0), LEFT)
	check(not board.can_exit(a) and not board.can_exit(b), "arrows facing each other block each other")


func test_unknown_id_is_safe() -> void:
	var board := BoardState.new(Vector2i(2, 2))
	check(board.get_arrow(42) == null, "get_arrow")
	check(not board.can_exit(42), "can_exit")
	check(not board.try_exit(42), "try_exit")
	check(board.get_exit_path(42).is_empty(), "get_exit_path")
	check(board.find_blocker(42) == null, "find_blocker")


func test_dependency_locks_an_otherwise_free_arrow() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	var dependent := board.add_arrow(Vector2i(0, 0), UP)
	var required := board.add_arrow(Vector2i(2, 2), DOWN)
	check(board.add_dependency(dependent, required), "dependency added")
	check(board.find_blocker(dependent) == null, "path is clear")
	check(board.is_locked(dependent), "but arrow is locked")
	check(not board.can_exit(dependent), "locked arrow cannot exit")
	check(not board.try_exit(dependent), "try_exit fails")
	check_eq(board.arrow_count(), 2, "nothing removed")
	var pending := board.get_pending_requirements(dependent)
	check(pending.size() == 1 and pending[0].id == required, "pending lists the required arrow")


func test_removing_requirement_unlocks_dependent() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	var dependent := board.add_arrow(Vector2i(0, 0), UP)
	var required := board.add_arrow(Vector2i(2, 2), DOWN)
	board.add_dependency(dependent, required)
	check(board.try_exit(required), "required arrow exits")
	check(not board.is_locked(dependent), "dependent unlocked")
	check(board.get_pending_requirements(dependent).is_empty(), "nothing pending")
	check(board.try_exit(dependent), "dependent exits")
	check(board.is_cleared(), "board cleared")


func test_all_requirements_must_leave() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	var dependent := board.add_arrow(Vector2i(1, 1), UP)
	var first := board.add_arrow(Vector2i(0, 2), LEFT)
	var second := board.add_arrow(Vector2i(2, 2), RIGHT)
	board.add_dependency(dependent, first)
	board.add_dependency(dependent, second)
	board.try_exit(first)
	check(board.is_locked(dependent), "still locked with one requirement left")
	board.try_exit(second)
	check(board.can_exit(dependent), "free once both have left")


func test_dependency_chain_resolves_in_order() -> void:
	var board := BoardState.new(Vector2i(3, 1))
	var a := board.add_arrow(Vector2i(0, 0), UP)
	var b := board.add_arrow(Vector2i(1, 0), UP)
	var c := board.add_arrow(Vector2i(2, 0), UP)
	board.add_dependency(a, b)
	board.add_dependency(b, c)
	check(not board.try_exit(a), "a waits for b")
	check(not board.try_exit(b), "b waits for c")
	check(board.try_exit(c), "c exits")
	check(not board.try_exit(a), "a still waits for b")
	check(board.try_exit(b), "b exits")
	check(board.try_exit(a), "a exits")


func test_locked_and_path_blocked_both_prevent_exit() -> void:
	var board := BoardState.new(Vector2i(3, 1))
	var a := board.add_arrow(Vector2i(0, 0), RIGHT)
	var blocker := board.add_arrow(Vector2i(1, 0), UP)
	var required := board.add_arrow(Vector2i(2, 0), UP)
	board.add_dependency(a, required)
	board.try_exit(required)
	check(not board.is_locked(a), "unlocked")
	check(not board.can_exit(a), "but still blocked by path")
	board.try_exit(blocker)
	check(board.can_exit(a), "free once unlocked and clear")


func test_invalid_dependencies_are_rejected() -> void:
	var board := BoardState.new(Vector2i(3, 1))
	var a := board.add_arrow(Vector2i(0, 0), UP)
	var b := board.add_arrow(Vector2i(1, 0), UP)
	var c := board.add_arrow(Vector2i(2, 0), UP)
	check(not board.add_dependency(a, a), "self dependency")
	check(not board.add_dependency(a, 99), "unknown required id")
	check(not board.add_dependency(99, a), "unknown dependent id")
	check(board.add_dependency(a, b), "valid a <- b")
	check(not board.add_dependency(a, b), "duplicate")
	check(not board.add_dependency(b, a), "direct cycle")
	check(board.add_dependency(b, c), "valid b <- c")
	check(not board.add_dependency(c, a), "transitive cycle")
	check_eq(board.get_arrow(a).requires, [b] as Array[int], "a's requirements unchanged")
	check_eq(board.get_arrow(c).requires, [] as Array[int], "c has no requirements")


func test_solver_counts_rounds() -> void:
	check_eq(BoardSolver.count_solution_rounds(BoardState.new(Vector2i(2, 2))), 0, "empty board needs no rounds")
	var board := BoardState.new(Vector2i(4, 1))
	board.add_arrow(Vector2i(0, 0), RIGHT)
	board.add_arrow(Vector2i(1, 0), RIGHT)
	board.add_arrow(Vector2i(2, 0), RIGHT)
	check_eq(BoardSolver.count_solution_rounds(board), 3, "a line of arrows leaves one per round")
	check(board.is_cleared(), "solver clears the board it is given")


func test_solver_respects_dependencies() -> void:
	var board := BoardState.new(Vector2i(2, 1))
	var waiting := board.add_arrow(Vector2i(0, 0), UP)
	var required := board.add_arrow(Vector2i(1, 0), UP)
	board.add_dependency(waiting, required)
	check_eq(BoardSolver.count_solution_rounds(board), 2, "dependency adds a round")


func test_solver_detects_deadlock() -> void:
	var board := BoardState.new(Vector2i(3, 1))
	board.add_arrow(Vector2i(0, 0), RIGHT)
	board.add_arrow(Vector2i(1, 0), LEFT)
	board.add_arrow(Vector2i(2, 0), UP)
	check_eq(BoardSolver.count_solution_rounds(board), -1, "facing arrows can never leave")
	check(not BoardSolver.is_solvable(board), "is_solvable agrees")


func test_walls_block_paths_forever() -> void:
	var board := BoardState.new(Vector2i(3, 1))
	check(board.add_wall(Vector2i(1, 0)), "wall placed")
	check_eq(board.add_arrow(Vector2i(1, 0), UP), -1, "no arrow on a wall")
	check(not board.add_wall(Vector2i(1, 0)), "no double wall")
	var walled := board.add_arrow(Vector2i(0, 0), RIGHT)
	var free := board.add_arrow(Vector2i(2, 0), UP)
	check(board.is_walled_in(walled), "wall in the path")
	check(not board.can_exit(walled), "walled-in arrow can't exit")
	check(board.can_exit(free), "others unaffected")
	check(not BoardSolver.is_solvable(board), "a walled-in arrow makes the board unsolvable")


func test_master_release_clears_board() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	var master := board.add_arrow(Vector2i(1, 1), UP)
	var key := board.add_arrow(Vector2i(0, 0), LEFT)
	board.add_arrow(Vector2i(2, 2), RIGHT)
	board.add_arrow(Vector2i(0, 2), LEFT)
	check(board.set_master(master), "master set")
	check(not board.set_master(99), "unknown id rejected")
	board.add_dependency(master, key)
	check(not board.can_exit(master), "master waits for its key")
	check(board.try_exit(key), "key leaves")
	check(board.try_exit(master), "master leaves")
	check(board.is_cleared(), "every arrow escaped with the master")


func test_solver_rounds_with_master() -> void:
	var board := BoardState.new(Vector2i(4, 1))
	var a := board.add_arrow(Vector2i(0, 0), UP)
	var master := board.add_arrow(Vector2i(1, 0), UP)
	var c := board.add_arrow(Vector2i(2, 0), UP)
	board.add_dependency(master, a)
	board.add_dependency(c, master)
	board.set_master(master)
	var rounds := BoardSolver.exit_rounds(board)
	check_eq(rounds[a], 1, "key first")
	check_eq(rounds[master], 2, "master second")
	check_eq(rounds[c], 2, "everything else leaves with the master")


func test_mirror_turns_the_path() -> void:
	var board := BoardState.new(Vector2i(4, 4))
	var id := board.add_arrow(Vector2i(0, 2), Arrow.Direction.RIGHT)
	check(board.add_mirror(Vector2i(2, 2), PathTracer.MIRROR_SLASH), "mirror placed")
	check_eq(board.get_exit_path(id), [Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0)] as Array[Vector2i], "'/' turns a right-moving arrow up")
	var blocker := board.add_arrow(Vector2i(2, 0), Arrow.Direction.UP)
	check(not board.can_exit(id), "an arrow after the bounce blocks it")
	board.try_exit(blocker)
	check(board.can_exit(id), "free once that arrow leaves")
	check_eq(PathTracer.reflect(Arrow.Direction.DOWN, PathTracer.MIRROR_BACKSLASH), Arrow.Direction.RIGHT, "'\\' turns down into right")
	check(not board.add_arrow(Vector2i(2, 2), Arrow.Direction.UP) >= 0, "no arrow on a mirror")


func test_black_hole_sends_arrow_out_of_white_hole() -> void:
	var board := BoardState.new(Vector2i(5, 5))
	var id := board.add_arrow(Vector2i(0, 0), Arrow.Direction.RIGHT)
	check(board.add_portal(Vector2i(2, 0), Vector2i(2, 3)), "portal placed")
	check_eq(board.get_exit_path(id), [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)] as Array[Vector2i], "in the black hole, out of the white hole, same direction")
	var kinds := board.get_exit_waypoints(id).map(func(p: Dictionary) -> String: return p["kind"])
	check(kinds.has(PathTracer.ENTER) and kinds.has(PathTracer.EMERGE), "waypoints mark the jump")
	var far := board.add_arrow(Vector2i(4, 3), Arrow.Direction.DOWN)
	check_eq(board.find_blocker(id), board.get_arrow(far), "blocked on the far side of the white hole")
	var crossing := board.add_arrow(Vector2i(2, 4), Arrow.Direction.UP)
	check_eq(board.get_exit_path(crossing)[0], Vector2i(2, 3), "white holes are ordinary cells to fly across")


func test_endless_loop_counts_as_stuck() -> void:
	var board := BoardState.new(Vector2i(3, 3))
	# Four mirrors around the middle send the arrow round and round.
	# right -> "\" -> down -> "/" -> left -> "\" -> up -> "/" -> right ...
	board.add_mirror(Vector2i(0, 0), PathTracer.MIRROR_SLASH)
	board.add_mirror(Vector2i(2, 0), PathTracer.MIRROR_BACKSLASH)
	board.add_mirror(Vector2i(2, 2), PathTracer.MIRROR_SLASH)
	board.add_mirror(Vector2i(0, 2), PathTracer.MIRROR_BACKSLASH)
	var id := board.add_arrow(Vector2i(1, 0), Arrow.Direction.RIGHT)
	check(board.is_walled_in(id), "an arrow that can never reach the edge is stuck")
	check(not board.can_exit(id), "and cannot exit")
