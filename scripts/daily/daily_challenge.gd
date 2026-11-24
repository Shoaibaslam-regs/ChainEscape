class_name DailyChallenge
extends RefCounted
## Today's puzzle: generated from the date, so every player gets the same
## board on the same day, offline. Some days carry a twist on a weekly rotation.

const SEED_SALT := "chain-escape-daily-v1"
const DIFFICULTY := 0.7
## Twists by weekday, Sunday first ("" = none).
const WEEKDAY_TWISTS: Array[String] = [
	LevelData.TWIST_LONG_CHAINS,
	"",
	LevelData.TWIST_DOUBLE_LOCKS,
	"",
	LevelData.TWIST_WALLS,
	"",
	LevelData.TWIST_HIDDEN_LINKS,
]


static func level_for(date_key: String) -> LevelData:
	var twist := WEEKDAY_TWISTS[DailyDate.weekday(date_key)]
	var twists := PackedStringArray([twist]) if not twist.is_empty() else PackedStringArray()
	return LevelGenerator.generate_from_seed("%s:%s" % [SEED_SALT, date_key], DIFFICULTY, twists)
