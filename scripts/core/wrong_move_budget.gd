class_name WrongMoveBudget
extends RefCounted
## How many wrong moves (taps on a blocked or locked arrow) a level allows
## before the attempt ends. A rewarded ad can grant one more.

const DEFAULT_LIMIT := 3

var limit: int = DEFAULT_LIMIT
## False on levels without a limit (tutorial, Daily challenge).
var enabled: bool = true

var _remaining: int = DEFAULT_LIMIT


func reset(p_enabled: bool = true, p_limit: int = DEFAULT_LIMIT) -> void:
	enabled = p_enabled
	limit = p_limit
	_remaining = p_limit


## Records one wrong move. Returns true if that used the last one.
func use_one() -> bool:
	if not enabled or _remaining <= 0:
		return false
	_remaining -= 1
	return _remaining == 0


func grant_extra(count: int = 1) -> void:
	_remaining += count


func remaining() -> int:
	return _remaining


func is_exhausted() -> bool:
	return enabled and _remaining <= 0
