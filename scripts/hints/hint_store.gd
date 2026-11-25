class_name HintStore
extends RefCounted
## Hints the player can use on numbered levels, saved offline in
## user://hints.cfg. Everyone starts with STARTER_HINTS; after that, each
## rewarded video gives one more (at most MAX_AD_HINTS_PER_DAY a day).

## The number of hints changed (used, earned or reset).
signal changed(hints: int)

const DEFAULT_PATH := "user://hints.cfg"
const SECTION := "hints"
const KEY_VERSION := "version"
const FORMAT_VERSION := 1
const STARTER_HINTS := 2
## Free hint every this many levels cleared (0 = off: the user chose 2
## starter hints, then videos only).
const FREE_HINT_EVERY := 0
const MAX_AD_HINTS_PER_DAY := 10

var path: String
var _hints: int = STARTER_HINTS
## Highest level that already paid out its free hint (no double grants on replays).
var _last_rewarded_level: int = 0
var _ad_day: String = ""
var _ad_hints_today: int = 0


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
	var ad_day: Variant = file.get_value(SECTION, "ad_day", "")
	var ad_count: Variant = file.get_value(SECTION, "ad_hints_today", 0)
	_ad_day = ad_day if ad_day is String else ""
	_ad_hints_today = maxi(ad_count, 0) if ad_count is int else 0


func save_hints() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_VERSION, FORMAT_VERSION)
	file.set_value(SECTION, "hints", _hints)
	file.set_value(SECTION, "last_rewarded_level", _last_rewarded_level)
	file.set_value(SECTION, "ad_day", _ad_day)
	file.set_value(SECTION, "ad_hints_today", _ad_hints_today)
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


## Whether another rewarded video may give a hint today.
func can_earn_from_ad(today: String = DailyDate.today_key()) -> bool:
	return _ads_today(today) < MAX_AD_HINTS_PER_DAY


## A rewarded video was fully watched: one more hint (only on a completed
## view, saved immediately). Returns false when today's cap is reached.
func earn_from_ad(today: String = DailyDate.today_key()) -> bool:
	if not can_earn_from_ad(today):
		return false
	_ad_day = today
	_ad_hints_today = _ads_today(today) + 1
	add_hints(1)
	return true


func _ads_today(today: String) -> int:
	return _ad_hints_today if _ad_day == today else 0


## Settings > Reset progress: back to the starter hints.
func reset() -> void:
	_hints = STARTER_HINTS
	_last_rewarded_level = 0
	save_hints()
	changed.emit(_hints)
