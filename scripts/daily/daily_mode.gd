class_name DailyMode
extends ChallengeMode
## The Daily challenge for one date.

var date_key: String
var store: DailyStore


func _init(p_date_key: String, p_store: DailyStore) -> void:
	date_key = p_date_key
	store = p_store


func title() -> String:
	return "DAILY"


func overline() -> String:
	return "DAILY CHALLENGE · %s" % DailyDate.short_label(date_key)


func pause_title() -> String:
	return "Daily · %s" % DailyDate.short_label(date_key)


func missing_message() -> String:
	return "Today's puzzle is not available."


func record_solve(wrong_taps: int) -> void:
	if store != null:
		store.record_solve(date_key, wrong_taps)


func result_title() -> String:
	return "DAILY SOLVED"


func result_caption(wrong_taps: int) -> String:
	if wrong_taps == 0:
		return "%s · flawless, no wrong taps." % DailyDate.long_label(date_key)
	return "%s · %s. A new puzzle tomorrow." % [DailyDate.long_label(date_key), ChallengeMode.wrong_taps_text(wrong_taps)]


func seal_text() -> String:
	var streak := store.current_streak(date_key) if store != null else 0
	return "%d-DAY STREAK" % streak if streak > 0 else ""


func done_label() -> String:
	return "BACK TO DAILY"
