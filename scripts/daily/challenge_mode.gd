class_name ChallengeMode
extends RefCounted
## A special puzzle played outside the numbered levels (Daily, Weekly): its
## texts on the game screen and Level complete, and where its result is
## saved. The game screen plays it the same way whatever the kind.


## Shown as the level title, e.g. "DAILY".
func title() -> String:
	return ""


## Small line above the title, e.g. "DAILY CHALLENGE · NOV 24".
func overline() -> String:
	return ""


## Pause sheet caption, e.g. "Daily · NOV 24".
func pause_title() -> String:
	return ""


func missing_message() -> String:
	return "This puzzle is not available."


func record_solve(_wrong_taps: int) -> void:
	pass


## Level complete title, caption and seal chip ("" hides the chip).
func result_title() -> String:
	return ""


func result_caption(_wrong_taps: int) -> String:
	return ""


func seal_text() -> String:
	return ""


## The button that leaves the result, e.g. "BACK TO DAILY".
func done_label() -> String:
	return ""


static func wrong_taps_text(wrong_taps: int) -> String:
	if wrong_taps == 0:
		return "no wrong taps"
	return "%d wrong %s" % [wrong_taps, "tap" if wrong_taps == 1 else "taps"]
