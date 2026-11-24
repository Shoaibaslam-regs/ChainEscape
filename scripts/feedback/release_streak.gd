class_name ReleaseStreak
extends RefCounted
## Counts arrows released in quick succession and decides the praise word
## and note for each one. Pure logic (time is passed in), so it is easy to
## test and has no effect on the puzzle rules.

## A release within this many seconds of the previous one continues the streak.
const WINDOW_SECONDS := 0.9
## Streak length -> praise word. Past the last entry, every PRAISE_REPEAT
## releases repeat the last word.
const PRAISE: Dictionary[int, String] = {
	3: "NICE!",
	5: "SWEET!",
	8: "GREAT!",
	12: "AMAZING!",
	16: "UNSTOPPABLE!",
}
const PRAISE_REPEAT := 4
## Major pentatonic steps in semitones; each release in a streak climbs one.
const SCALE_STEPS: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]

var _count: int = 0
var _last_time: float = -INF


## Records a release at [param time] (seconds) and returns the streak length.
func register_release(time: float) -> int:
	_count = _count + 1 if time - _last_time <= WINDOW_SECONDS else 1
	_last_time = time
	return _count


func reset() -> void:
	_count = 0
	_last_time = -INF


func get_count() -> int:
	return _count


## The praise word for a streak of [param count], or "" for none.
static func praise_for(count: int) -> String:
	if PRAISE.has(count):
		return PRAISE[count]
	var last_threshold: int = PRAISE.keys().max()
	if count > last_threshold and (count - last_threshold) % PRAISE_REPEAT == 0:
		return PRAISE[last_threshold]
	return ""


## Pitch multiplier for the release sound at streak [param count] (1-based):
## climbs the pentatonic scale, then stays at the top.
static func pitch_for(count: int) -> float:
	var step: int = SCALE_STEPS[clampi(count - 1, 0, SCALE_STEPS.size() - 1)]
	return pow(2.0, step / 12.0)
