class_name ProgressStore
extends RefCounted
## Local, offline save of the player's progress through the endless level
## sequence. Levels unlock strictly in order, so the only thing to remember
## is the highest level completed.
##
## Stored as a small ConfigFile in user://. A missing or unreadable file
## simply means "no progress yet".

const DEFAULT_PATH := "user://progress.cfg"
const SECTION := "progress"
const KEY_VERSION := "version"
const KEY_HIGHEST_COMPLETED := "highest_completed_level"
## Version 1 stored a list of completed level ids ("level_01", ...).
const LEGACY_KEY_COMPLETED_IDS := "completed_levels"
const LEGACY_ID_PREFIX := "level_"
## Bump when the format changes, and migrate older versions in load_progress.
const FORMAT_VERSION := 2
## Points for clearing a level for the first time (replays add nothing).
## Total points will also be the score for the future online ranking.
const POINTS_PER_LEVEL := 5
const KEY_STARS := "stars"
const MAX_STARS := 3

var path: String

var _highest_completed_level: int = 0
## Best stars earned per level number.
var _stars: Dictionary[int, int] = {}


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_progress() -> void:
	_highest_completed_level = 0
	_stars.clear()
	if not FileAccess.file_exists(path):
		return
	var file := ConfigFile.new()
	var result := file.load(path)
	if result != OK:
		push_warning("ProgressStore: could not read %s (%s); starting fresh." % [path, error_string(result)])
		return
	var version: Variant = file.get_value(SECTION, KEY_VERSION, 1)
	if version is int and version >= 2:
		_highest_completed_level = _read_highest_completed(file)
		_read_stars(file)
	else:
		_highest_completed_level = _migrate_from_completed_ids(file)
		save_progress()


func save_progress() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_VERSION, FORMAT_VERSION)
	file.set_value(SECTION, KEY_HIGHEST_COMPLETED, _highest_completed_level)
	var stars: Dictionary = {}
	for level: int in _stars:
		stars[level] = _stars[level]
	file.set_value(SECTION, KEY_STARS, stars)
	var result := file.save(path)
	if result != OK:
		push_warning("ProgressStore: could not save %s (%s)." % [path, error_string(result)])
		return false
	return true


func get_highest_completed_level() -> int:
	return _highest_completed_level


## The level "Play" should open: the one after the highest completed.
## Stars for a clear with [param wrong_taps] wrong moves: 3, 2, then 1.
static func stars_for(wrong_taps: int) -> int:
	return clampi(MAX_STARS - wrong_taps, 1, MAX_STARS)


## Keeps the best stars for the level. Returns true if it was a new best.
func record_stars(level_number: int, stars: int) -> bool:
	stars = clampi(stars, 1, MAX_STARS)
	if stars <= _stars.get(level_number, 0):
		return false
	_stars[level_number] = stars
	save_progress()
	return true


func get_stars(level_number: int) -> int:
	return _stars.get(level_number, 0)


func total_stars() -> int:
	var total := 0
	for stars: int in _stars.values():
		total += stars
	return total


func get_points() -> int:
	return _highest_completed_level * POINTS_PER_LEVEL


func get_next_level_number() -> int:
	return _highest_completed_level + 1


func is_unlocked(level_number: int) -> bool:
	return level_number >= 1 and level_number <= get_next_level_number()


## Records a completed level and saves if it raises the player's progress.
## Replaying an earlier level changes nothing.
func record_level_completed(level_number: int) -> void:
	if level_number <= _highest_completed_level:
		return
	_highest_completed_level = level_number
	save_progress()


## Forgets all progress (Settings > Reset progress) and saves.
func reset() -> void:
	_highest_completed_level = 0
	_stars.clear()
	save_progress()


func _read_stars(file: ConfigFile) -> void:
	var saved: Variant = file.get_value(SECTION, KEY_STARS, {})
	if not saved is Dictionary:
		return
	for level: Variant in saved:
		var value: Variant = saved[level]
		if level is int and level > 0 and value is int:
			_stars[level] = clampi(value, 1, MAX_STARS)


func _read_highest_completed(file: ConfigFile) -> int:
	var value: Variant = file.get_value(SECTION, KEY_HIGHEST_COMPLETED, 0)
	if not value is int or value < 0:
		push_warning("ProgressStore: invalid progress value in %s; starting fresh." % path)
		return 0
	return value


## Version 1 saves listed ids "level_01", "level_02", ... Progress is the
## longest unbroken run from level 1, matching the in-order unlock rule.
func _migrate_from_completed_ids(file: ConfigFile) -> int:
	var completed: Variant = file.get_value(SECTION, LEGACY_KEY_COMPLETED_IDS, PackedStringArray())
	if not completed is PackedStringArray:
		push_warning("ProgressStore: unexpected data in %s; starting fresh." % path)
		return 0
	var completed_numbers: Dictionary[int, bool] = {}
	for level_id: String in completed:
		var number_text := level_id.trim_prefix(LEGACY_ID_PREFIX)
		if level_id.begins_with(LEGACY_ID_PREFIX) and number_text.is_valid_int():
			completed_numbers[number_text.to_int()] = true
	var highest := 0
	while completed_numbers.has(highest + 1):
		highest += 1
	return highest
