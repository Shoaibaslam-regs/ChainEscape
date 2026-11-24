class_name RewardedAds
extends Node
## Interface for rewarded video ads ("watch an ad to get one move").
## The game only talks to this class; the real ad network plugs in behind it
## in the monetisation phase (it needs an SDK, consent and privacy work).
##
## This base implementation is the development stand-in: in debug builds it
## pretends an ad was watched after a short delay so the flow can be tested;
## in release builds it reports no ads available, and the game hides the
## button.

signal finished(rewarded: bool)

## Simulated ad length in debug builds.
const DEBUG_AD_SECONDS := 0.4

var _showing: bool = false


func is_available() -> bool:
	return OS.is_debug_build()


func is_showing() -> bool:
	return _showing


## Shows an ad; emits [signal finished] with whether the reward was earned.
func show_ad() -> void:
	if _showing:
		return
	if not is_available():
		finished.emit(false)
		return
	_showing = true
	await get_tree().create_timer(DEBUG_AD_SECONDS).timeout
	_showing = false
	finished.emit(true)
