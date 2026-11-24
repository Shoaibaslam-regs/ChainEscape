extends TestSuite
## Daily challenge: dates, today's puzzle and results/streaks.


func test_date_round_trips_and_labels() -> void:
	check_eq(DailyDate.from_day_number(DailyDate.to_day_number("2026-11-24")), "2026-11-24", "round trip")
	check_eq(DailyDate.add_days("2026-11-30", 1), "2026-12-01", "month boundary")
	check_eq(DailyDate.add_days("2026-12-31", 1), "2027-01-01", "year boundary")
	check_eq(DailyDate.add_days("2028-02-28", 1), "2028-02-29", "leap day")
	check_eq(DailyDate.weekday("2026-11-24"), 2, "24 Nov 2026 is a Tuesday")
	check_eq(DailyDate.long_label("2026-11-24"), "Tuesday, 24 November", "long label")
	check_eq(DailyDate.short_label("2026-11-24"), "NOV 24", "short label")
	check(DailyDate.is_valid(DailyDate.today_key()), "today's key is valid")
	var remaining := DailyDate.seconds_until_tomorrow()
	check(remaining > 0 and remaining <= DailyDate.SECONDS_PER_DAY, "countdown in range")


func test_daily_puzzle_is_deterministic_and_solvable() -> void:
	var first := DailyChallenge.level_for("2026-11-24")
	var again := DailyChallenge.level_for("2026-11-24")
	check_eq(again.layout, first.layout, "same board for everyone on the same day")
	check(DailyChallenge.level_for("2026-11-25").layout != first.layout, "a new board the next day")
	for offset: int in 14:
		var key := DailyDate.add_days("2026-11-24", offset)
		var level := DailyChallenge.level_for(key)
		check(level != null and BoardSolver.is_solvable(level.build_board()), "%s solvable" % key)
		var twist := DailyChallenge.WEEKDAY_TWISTS[DailyDate.weekday(key)]
		check(twist.is_empty() or level.has_twist(twist), "%s uses its weekday twist" % key)


func test_daily_puzzle_differs_from_numbered_levels() -> void:
	var sequence := LevelSequence.new(load("res://levels/level_catalog.tres"))
	var daily := DailyChallenge.level_for("2026-11-24")
	for level_number: int in range(9, 60):
		check(sequence.get_level(level_number).layout != daily.layout, "not a copy of level %d" % level_number)


func test_streaks() -> void:
	var path := temp_save_path("daily_streak")
	var store := DailyStore.new(path)
	check_eq(store.current_streak("2026-11-24"), 0, "no streak yet")
	store.record_solve("2026-11-21", 2)
	store.record_solve("2026-11-22", 0)
	store.record_solve("2026-11-23", 1)
	check_eq(store.current_streak("2026-11-24"), 3, "streak alive until today is played")
	store.record_solve("2026-11-24", 0)
	check_eq(store.current_streak("2026-11-24"), 4, "today extends it")
	check_eq(store.current_streak("2026-11-26"), 0, "a missed day breaks it")
	check_eq(store.best_streak(), 4, "best streak kept")
	store.record_solve("2026-11-26", 3)
	check_eq(store.current_streak("2026-11-26"), 1, "new streak after the gap")
	check_eq(store.best_streak(), 4, "best streak not lowered")
	remove_file(path)


func test_results_keep_fewest_wrong_taps_and_persist() -> void:
	var path := temp_save_path("daily_results")
	var store := DailyStore.new(path)
	check_eq(store.get_wrong_taps("2026-11-24"), -1, "unsolved")
	store.record_solve("2026-11-24", 3)
	store.record_solve("2026-11-24", 1)
	store.record_solve("2026-11-24", 5)
	check_eq(store.get_wrong_taps("2026-11-24"), 1, "best result kept")
	var reloaded := DailyStore.new(path)
	reloaded.load_results()
	check(reloaded.is_solved("2026-11-24") and reloaded.get_wrong_taps("2026-11-24") == 1, "saved and restored")
	check_eq(reloaded.best_streak(), 1, "best streak restored")
	var week := reloaded.week("2026-11-24")
	check_eq(week.size(), 7, "seven days")
	check(week[6]["is_today"] and week[6]["solved"] and week[6]["letter"] == "T", "today last: a solved Tuesday")
	check(not week[5]["solved"], "yesterday unsolved")
	reloaded.reset()
	check(not reloaded.is_solved("2026-11-24") and reloaded.best_streak() == 0, "reset clears results")
	remove_file(path)


func test_corrupt_daily_file_starts_fresh() -> void:
	var path := temp_save_path("daily_corrupt")
	var file := ConfigFile.new()
	file.set_value(DailyStore.SECTION, "results", {"not-a-date": 2, "2026-11-24": "x", "2026-11-23": 1})
	file.save(path)
	var store := DailyStore.new(path)
	store.load_results()
	check(store.is_solved("2026-11-23"), "valid entry kept")
	check(not store.is_solved("2026-11-24") and not store.is_solved("not-a-date"), "invalid entries dropped")
	remove_file(path)
