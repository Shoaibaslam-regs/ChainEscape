class_name WeeklyMode
extends ChallengeMode
## One puzzle of a week's Weekly challenge.

var week: String
var index: int
var store: WeeklyStore


func _init(p_week: String, p_index: int, p_store: WeeklyStore) -> void:
	week = p_week
	index = p_index
	store = p_store


func title() -> String:
	return "WEEKLY %d" % (index + 1)


func overline() -> String:
	return "WEEKLY CHALLENGE · %d OF %d" % [index + 1, WeeklyChallenge.PUZZLES]


func pause_title() -> String:
	return "Weekly · puzzle %d" % (index + 1)


func record_solve(wrong_taps: int) -> void:
	if store != null:
		store.record_solve(week, index, wrong_taps)


func result_title() -> String:
	return "WEEK COMPLETE" if store != null and store.is_week_complete(week) else "PUZZLE %d SOLVED" % (index + 1)


func result_caption(wrong_taps: int) -> String:
	var solved := store.solved_count(week) if store != null else 0
	if solved == WeeklyChallenge.PUZZLES:
		return "All %d puzzles solved. This week's seal is yours." % WeeklyChallenge.PUZZLES
	return "Solved with %s · %d of %d this week." % [ChallengeMode.wrong_taps_text(wrong_taps), solved, WeeklyChallenge.PUZZLES]


func seal_text() -> String:
	return "WEEKLY SEAL" if store != null and store.is_week_complete(week) else ""


func done_label() -> String:
	return "BACK TO WEEKLY"
