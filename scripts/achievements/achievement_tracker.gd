class_name AchievementTracker
extends RefCounted
## Chain-themed achievements, counted and saved offline in
## user://achievements.cfg. Each achievement unlocks when one statistic
## reaches its goal; several achievements may share a statistic as tiers.

const DEFAULT_PATH := "user://achievements.cfg"
const SECTION := "achievements"
const KEY_VERSION := "version"
const FORMAT_VERSION := 1

## Statistics.
const STAT_CHAINS_BROKEN := "chains_broken"
const STAT_LEVELS_CLEARED := "levels_cleared"
## Levels in a row cleared without a wrong tap (resets on a wrong tap).
const STAT_CLEAN_STREAK := "clean_streak"
## Most chains broken in a single level cleared without a wrong tap.
const STAT_BEST_CLEAN_CHAINS := "best_clean_chains"
const STAT_VAULT_CHALLENGES := "vault_challenges"
const STAT_MASTERS_RELEASED := "masters_released"
const ALL_STATS: Array[String] = [
	STAT_CHAINS_BROKEN, STAT_LEVELS_CLEARED, STAT_CLEAN_STREAK,
	STAT_BEST_CLEAN_CHAINS, STAT_VAULT_CHALLENGES, STAT_MASTERS_RELEASED,
]

## id, title, description, stat, goal. Order matters for tier lookups.
const DEFINITIONS: Array[Dictionary] = [
	{"id": "first_key", "title": "First Key", "description": "Break your first chain", "stat": STAT_CHAINS_BROKEN, "goal": 1},
	{"id": "locksmith", "title": "Locksmith", "description": "Break 100 chains", "stat": STAT_CHAINS_BROKEN, "goal": 100},
	{"id": "master_locksmith", "title": "Master Locksmith", "description": "Break 250 chains", "stat": STAT_CHAINS_BROKEN, "goal": 250},
	{"id": "grand_locksmith", "title": "Grand Locksmith", "description": "Break 1,000 chains", "stat": STAT_CHAINS_BROKEN, "goal": 1000},
	{"id": "escape_artist", "title": "Escape Artist", "description": "Clear 25 levels", "stat": STAT_LEVELS_CLEARED, "goal": 25},
	{"id": "great_escape", "title": "Great Escape", "description": "Clear 100 levels", "stat": STAT_LEVELS_CLEARED, "goal": 100},
	{"id": "escape_legend", "title": "Escape Legend", "description": "Clear 500 levels", "stat": STAT_LEVELS_CLEARED, "goal": 500},
	{"id": "clean_hands", "title": "Clean Hands", "description": "Clear 10 levels in a row without a wrong tap", "stat": STAT_CLEAN_STREAK, "goal": 10},
	{"id": "chain_reaction", "title": "Chain Reaction", "description": "Break 3 chains in one level without a wrong tap", "stat": STAT_BEST_CLEAN_CHAINS, "goal": 3},
	{"id": "vault_breaker", "title": "Vault Breaker", "description": "Clear 10 Vault challenges", "stat": STAT_VAULT_CHALLENGES, "goal": 10},
	{"id": "vault_master", "title": "Vault Master", "description": "Clear 50 Vault challenges", "stat": STAT_VAULT_CHALLENGES, "goal": 50},
	{"id": "master_escape", "title": "Master Escape", "description": "Release a master arrow", "stat": STAT_MASTERS_RELEASED, "goal": 1},
	{"id": "grand_escape", "title": "Grand Escape", "description": "Release 10 master arrows", "stat": STAT_MASTERS_RELEASED, "goal": 10},
]

var path: String

var _stats: Dictionary[String, int] = {}
var _unlocked: Dictionary[String, bool] = {}


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_achievements() -> void:
	_stats.clear()
	_unlocked.clear()
	if not FileAccess.file_exists(path):
		return
	var file := ConfigFile.new()
	var result := file.load(path)
	if result != OK:
		push_warning("AchievementTracker: could not read %s (%s); starting fresh." % [path, error_string(result)])
		return
	for stat: String in ALL_STATS:
		var value: Variant = file.get_value(SECTION, stat, 0)
		_stats[stat] = maxi(value, 0) if value is int else 0
	var unlocked: Variant = file.get_value(SECTION, "unlocked", PackedStringArray())
	if unlocked is PackedStringArray:
		for id: String in unlocked:
			_unlocked[id] = true


func save_achievements() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_VERSION, FORMAT_VERSION)
	for stat: String in _stats:
		file.set_value(SECTION, stat, _stats[stat])
	file.set_value(SECTION, "unlocked", PackedStringArray(_unlocked.keys()))
	var result := file.save(path)
	if result != OK:
		push_warning("AchievementTracker: could not save %s (%s)." % [path, error_string(result)])
		return false
	return true


## Updates statistics after a cleared level and returns the definitions
## unlocked by it, in definition order. Saves immediately.
func record_level_cleared(chains_broken: int, wrong_taps: int, was_challenge: bool = false, master_released: bool = false) -> Array[Dictionary]:
	_add(STAT_CHAINS_BROKEN, maxi(chains_broken, 0))
	_add(STAT_LEVELS_CLEARED, 1)
	if was_challenge:
		_add(STAT_VAULT_CHALLENGES, 1)
	if master_released:
		_add(STAT_MASTERS_RELEASED, 1)
	if wrong_taps == 0:
		_add(STAT_CLEAN_STREAK, 1)
		_stats[STAT_BEST_CLEAN_CHAINS] = maxi(get_stat(STAT_BEST_CLEAN_CHAINS), chains_broken)
	else:
		_stats[STAT_CLEAN_STREAK] = 0
	var newly_unlocked: Array[Dictionary] = []
	for definition: Dictionary in DEFINITIONS:
		if not is_unlocked(definition["id"]) and get_stat(definition["stat"]) >= definition["goal"]:
			_unlocked[definition["id"]] = true
			newly_unlocked.append(definition)
	save_achievements()
	return newly_unlocked


func get_stat(stat: String) -> int:
	return _stats.get(stat, 0)


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


## 0..1 progress toward [param definition]'s goal.
func get_progress(definition: Dictionary) -> float:
	return clampf(float(get_stat(definition["stat"])) / float(definition["goal"]), 0.0, 1.0)


## The next locked tier after [param definition] that tracks the same
## statistic, or an empty dictionary if there is none.
func next_tier(definition: Dictionary) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate["stat"] == definition["stat"] and candidate["goal"] > definition["goal"] and not is_unlocked(candidate["id"]):
			return candidate
	return {}


## Up to [param count] locked achievements, closest to unlocking first.
## Only the lowest locked tier of each statistic is considered.
func closest_locked(count: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen_stats: Dictionary[String, bool] = {}
	for definition: Dictionary in DEFINITIONS:
		if is_unlocked(definition["id"]) or seen_stats.has(definition["stat"]):
			continue
		seen_stats[definition["stat"]] = true
		candidates.append(definition)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return get_progress(a) > get_progress(b))
	return candidates.slice(0, count)


## Clears every statistic and unlock (Settings > Reset progress).
func reset() -> void:
	_stats.clear()
	_unlocked.clear()
	save_achievements()


func _add(stat: String, amount: int) -> void:
	_stats[stat] = get_stat(stat) + amount
