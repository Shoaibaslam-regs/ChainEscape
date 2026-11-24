extends SceneTree
func _initialize() -> void:
	var seq := LevelSequence.new(load("res://levels/level_catalog.tres"))
	for n in [30, 60, 100, 101, 150, 250, 400, 401]:
		var t := Time.get_ticks_usec()
		var level := seq.get_level(n)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		var b := level.build_board()
		var free := 0
		for a: Arrow in b.get_arrows():
			if b.can_exit(a.id): free += 1
		print("L%d %.0fms hard=%.2f size=%s arrows=%d rounds=%d deps=%d free=%d" % [n, ms, seq.hardness_for(n), b.size, b.arrow_count(), BoardSolver.count_solution_rounds(level.build_board()), level.dependencies.size(), free])
	quit()
