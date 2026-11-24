class_name WeeklyChallenge
extends RefCounted
## Five harder puzzles each week (Monday to Sunday, device time, offline),
## the same for every player. Puzzle 1 has no twist, 2-3 one twist, 4-5 two
## twists merged; each is harder and bigger than the one before.

const SEED_SALT := "chain-escape-weekly-v1"
const PUZZLES := 5
const DIFFICULTY := 1.0
const HARDNESS_FIRST := 0.5
const HARDNESS_STEP := 0.1
const SIZE_FIRST := 0.2
const SIZE_STEP := 0.18


## The week's key: the date of its Monday ("YYYY-MM-DD").
static func week_key(today_key: String) -> String:
	return DailyDate.add_days(today_key, -_days_since_monday(today_key))


## Days left including today (7 on Monday, 1 on Sunday).
static func days_left(today_key: String) -> int:
	return 7 - _days_since_monday(today_key)


## e.g. "NOV 23 – NOV 29".
static func range_label(week: String) -> String:
	return "%s – %s" % [DailyDate.short_label(week), DailyDate.short_label(DailyDate.add_days(week, 6))]


## 1..5 difficulty dots for a puzzle.
static func stars_for(index: int) -> int:
	return clampi(index + 1, 1, PUZZLES)


static func twists_for(week: String, index: int) -> PackedStringArray:
	var count := 0 if index == 0 else (1 if index < 3 else 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s:%s:%d:twists" % [SEED_SALT, week, index]).hash()
	var pool := LevelSequence.TWIST_ORDER.duplicate()
	var twists := PackedStringArray()
	for pick: int in count:
		twists.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return twists


static func level_for(week: String, index: int) -> LevelData:
	var hardness := minf(HARDNESS_FIRST + HARDNESS_STEP * index, 1.0)
	var size := minf(SIZE_FIRST + SIZE_STEP * index, 1.0)
	return LevelGenerator.generate_from_seed("%s:%s:%d" % [SEED_SALT, week, index], DIFFICULTY, twists_for(week, index), false, hardness, size)


static func _days_since_monday(today_key: String) -> int:
	return (DailyDate.weekday(today_key) + 6) % 7
