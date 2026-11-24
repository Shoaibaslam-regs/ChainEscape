class_name DailyStore
extends RefCounted
## Daily challenge results, saved offline in user://daily.cfg: the fewest
## wrong taps for each solved day, and the best streak ever. The current
## streak is worked out from the solved days.

const DEFAULT_PATH := "user://daily.cfg"
const SECTION := "daily"
const KEY_VERSION := "version"
const FORMAT_VERSION := 1
const WEEK_LETTERS: Array[String] = ["S", "M", "T", "W", "T", "F", "S"]

var path: String

var _results: Dictionary[String, int] = {}
var _best_streak: int = 0


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_results() -> void:
	_results.clear()
	_best_streak = 0
	if not FileAccess.file_exists(path):
		return
	var file := ConfigFile.new()
	var result := file.load(path)
	if result != OK:
		push_warning("DailyStore: could not read %s (%s); starting fresh." % [path, error_string(result)])
		return
	var saved: Variant = file.get_value(SECTION, "results", {})
	if saved is Dictionary:
		for key: Variant in saved:
			if key is String and DailyDate.is_valid(key) and saved[key] is int:
				_results[key] = maxi(saved[key], 0)
	var best: Variant = file.get_value(SECTION, "best_streak", 0)
	_best_streak = maxi(best, 0) if best is int else 0


func save_results() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_VERSION, FORMAT_VERSION)
	var plain: Dictionary = {}
	for key: String in _results:
		plain[key] = _results[key]
	file.set_value(SECTION, "results", plain)
	file.set_value(SECTION, "best_streak", _best_streak)
	var result := file.save(path)
	if result != OK:
		push_warning("DailyStore: could not save %s (%s)." % [path, error_string(result)])
		return false
	return true


## Records a solve; keeps the fewest wrong taps if the day is replayed.
func record_solve(date_key: String, wrong_taps: int) -> void:
	_results[date_key] = mini(_results.get(date_key, wrong_taps), maxi(wrong_taps, 0))
	_best_streak = maxi(_best_streak, current_streak(date_key))
	save_results()


func is_solved(date_key: String) -> bool:
	return _results.has(date_key)


## Fewest wrong taps for the day, or -1 if not solved.
func get_wrong_taps(date_key: String) -> int:
	return _results.get(date_key, -1)


## Consecutive solved days ending today, or ending yesterday if today is not
## solved yet (the streak is still alive until midnight).
func current_streak(today_key: String) -> int:
	var day := DailyDate.to_day_number(today_key)
	if not is_solved(today_key):
		day -= 1
	var streak := 0
	while is_solved(DailyDate.from_day_number(day - streak)):
		streak += 1
	return streak


func best_streak() -> int:
	return _best_streak


## The seven days ending today: {key, letter, solved, is_today}.
func week(today_key: String) -> Array[Dictionary]:
	var days: Array[Dictionary] = []
	for offset: int in range(-6, 1):
		var key := DailyDate.add_days(today_key, offset)
		days.append({"key": key, "letter": WEEK_LETTERS[DailyDate.weekday(key)], "solved": is_solved(key), "is_today": offset == 0})
	return days


func reset() -> void:
	_results.clear()
	_best_streak = 0
	save_results()
