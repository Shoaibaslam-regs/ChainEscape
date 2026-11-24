extends TestSuite
## Weekly challenge: week boundaries, puzzles, saving and seals.


func test_week_runs_monday_to_sunday() -> void:
	# 2026-11-23 is a Monday.
	check_eq(WeeklyChallenge.week_key("2026-11-23"), "2026-11-23", "Monday starts the week")
	check_eq(WeeklyChallenge.week_key("2026-11-25"), "2026-11-23", "Wednesday belongs to it")
	check_eq(WeeklyChallenge.week_key("2026-11-29"), "2026-11-23", "Sunday ends it")
	check_eq(WeeklyChallenge.week_key("2026-11-30"), "2026-11-30", "next Monday starts a new week")
	check_eq(WeeklyChallenge.days_left("2026-11-23"), 7, "7 days left on Monday")
	check_eq(WeeklyChallenge.days_left("2026-11-29"), 1, "last day on Sunday")
	check_eq(WeeklyChallenge.range_label("2026-11-23"), "NOV 23 – NOV 29", "range label")


func test_puzzles_are_shared_solvable_and_rising() -> void:
	var week := "2026-11-23"
	for index: int in WeeklyChallenge.PUZZLES:
		var level := WeeklyChallenge.level_for(week, index)
		var again := WeeklyChallenge.level_for(week, index)
		check(level != null and level.layout == again.layout, "puzzle %d is the same for everyone" % (index + 1))
		check(level != null and BoardSolver.is_solvable(level.build_board()), "puzzle %d solvable" % (index + 1))
		var expected_twists := 0 if index == 0 else (1 if index < 3 else 2)
		check_eq(level.twists.size(), expected_twists, "puzzle %d twist count" % (index + 1))
	check(WeeklyChallenge.level_for("2026-11-30", 0).layout != WeeklyChallenge.level_for(week, 0).layout, "a new week brings new puzzles")


func test_store_keeps_best_and_counts_seals() -> void:
	var path := temp_save_path("weekly")
	var store := WeeklyStore.new(path)
	var week := "2026-11-23"
	store.record_solve(week, 0, 3)
	store.record_solve(week, 0, 1)
	store.record_solve(week, 0, 4)
	check_eq(store.get_wrong_taps(week, 0), 1, "fewest wrong taps kept")
	check_eq(store.solved_count(week), 1, "one solved")
	for index: int in range(1, WeeklyChallenge.PUZZLES):
		store.record_solve(week, index, 0)
	check(store.is_week_complete(week), "week complete")
	check_eq(store.seals(), 1, "one Weekly seal")
	var reloaded := WeeklyStore.new(path)
	reloaded.load_results()
	check(reloaded.is_week_complete(week) and reloaded.seals() == 1, "saved and restored")
	reloaded.reset()
	check_eq(reloaded.seals(), 0, "reset clears it")
	remove_file(path)
