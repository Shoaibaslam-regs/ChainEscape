class_name WeeklyStore
extends RefCounted
## Weekly challenge results, saved offline in user://weekly.cfg: the fewest
## wrong taps for every solved puzzle, keyed "week#index".

const DEFAULT_PATH := "user://weekly.cfg"
const SECTION := "weekly"
const KEY_VERSION := "version"
const FORMAT_VERSION := 1

var path: String
var _results: Dictionary[String, int] = {}


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_results() -> void:
	_results.clear()
	if not FileAccess.file_exists(path):
		return
	var file := ConfigFile.new()
	var result := file.load(path)
	if result != OK:
		push_warning("WeeklyStore: could not read %s (%s); starting fresh." % [path, error_string(result)])
		return
	var saved: Variant = file.get_value(SECTION, "results", {})
	if saved is Dictionary:
		for key: Variant in saved:
			var value: Variant = saved[key]
			if key is String and value is int:
				_results[key] = maxi(value, 0)


func save_results() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_VERSION, FORMAT_VERSION)
	var results: Dictionary = {}
	for key: String in _results:
		results[key] = _results[key]
	file.set_value(SECTION, "results", results)
	var result := file.save(path)
	if result != OK:
		push_warning("WeeklyStore: could not save %s (%s)." % [path, error_string(result)])
		return false
	return true


## Keeps the fewest wrong taps if a puzzle is replayed.
func record_solve(week: String, index: int, wrong_taps: int) -> void:
	var key := _key(week, index)
	_results[key] = mini(_results.get(key, wrong_taps), maxi(wrong_taps, 0))
	save_results()


func is_solved(week: String, index: int) -> bool:
	return _results.has(_key(week, index))


## Fewest wrong taps, or -1 if not solved.
func get_wrong_taps(week: String, index: int) -> int:
	return _results.get(_key(week, index), -1)


func solved_count(week: String) -> int:
	var count := 0
	for index: int in WeeklyChallenge.PUZZLES:
		if is_solved(week, index):
			count += 1
	return count


func is_week_complete(week: String) -> bool:
	return solved_count(week) == WeeklyChallenge.PUZZLES


## Weeks with all five puzzles solved (Weekly seals earned).
func seals() -> int:
	var weeks: Dictionary[String, bool] = {}
	for key: String in _results:
		weeks[key.get_slice("#", 0)] = true
	var count := 0
	for week: String in weeks:
		if is_week_complete(week):
			count += 1
	return count


func reset() -> void:
	_results.clear()
	save_results()


static func _key(week: String, index: int) -> String:
	return "%s#%d" % [week, index]
