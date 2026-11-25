class_name HintStore
extends RefCounted
## Hints the player can use on numbered levels, saved offline in
## user://hints.cfg. New players start with STARTER_HINTS; one more is given
## for every FREE_HINT_EVERY levels cleared (so nobody is stuck offline).
## Rewarded videos add more in the ads step.

## The number of hints changed (used, earned or reset).
signal changed(hints: int)

const DEFAULT_PATH := "user://hints.cfg"
const SECTION := "hints"
const KEY_VERSION := "version"
const FORMAT_VERSION := 1
const STARTER_HINTS := 2
## Free hint every this many levels cleared (0 turns the free hints off).
const FREE_HINT_EVERY := 5

var path: String
var _hints: int = STARTER_HINTS
## Highest level that already paid out its free hint (no double grants on replays).
var _last_rewarded_level: int = 0


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_hints() -> void:
	_hints = STARTER_HINTS
	_last_rewarded_level = 0
	if not FileAccess.file_exists(path):
		return
	var file := ConfigFile.new()
	if file.load(path) != OK:
		push_warning("HintStore: could not read %s; starting fresh." % path)
		return
	var hints: Variant = file.get_value(SECTION, "hints", STARTER_HINTS)
	var last: Variant = file.get_value(SECTION, "last_rewarded_level", 0)
	_hints = maxi(hints, 0) if hints is int else STARTER_HINTS
	_last_rewarded_level = maxi(last, 0) if last is int else 0


func save_hints() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_VERSION, FORMAT_VERSION)
	file.set_value(SECTION, "hints", _hints)
	file.set_value(SECTION, "last_rewarded_level", _last_rewarded_level)
	var result := file.save(path)
	if result != OK:
		push_warning("HintStore: could not save %s (%s)." % [path, error_string(result)])
		return false
	return true


func get_hints() -> int:
	return _hints


## Uses one hint. Returns false (and changes nothing) when none are left.
func use_hint() -> bool:
	if _hints <= 0:
		return false
	_hints -= 1
	save_hints()
	changed.emit(_hints)
	return true


func add_hints(count: int) -> void:
	_hints += maxi(count, 0)
	save_hints()
	changed.emit(_hints)


## Called when a numbered level is cleared for the first time: every
## FREE_HINT_EVERY levels pays out one free hint. Returns true if it did.
func on_level_cleared(level_number: int) -> bool:
	if FREE_HINT_EVERY <= 0 or level_number <= _last_rewarded_level or level_number % FREE_HINT_EVERY != 0:
		return false
	_last_rewarded_level = level_number
	add_hints(1)
	return true


## Levels until the next free hint after [param highest_cleared].
func levels_until_free_hint(highest_cleared: int) -> int:
	if FREE_HINT_EVERY <= 0:
		return -1
	return FREE_HINT_EVERY - (highest_cleared % FREE_HINT_EVERY)


## Settings > Reset progress: back to the starter hints.
func reset() -> void:
	_hints = STARTER_HINTS
	_last_rewarded_level = 0
	save_hints()
	changed.emit(_hints)
