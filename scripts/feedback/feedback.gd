class_name Feedback
extends Node
## Plays sound effects and vibration, respecting the player's settings.
## Created once by Main and handed to the screens that need it.

enum Sound { EXIT, BLOCKED, CHAIN_BREAK, UNLOCK, LEVEL_COMPLETE, BUTTON, LEVEL_START, PRAISE, LINK_JOIN, SPLASH_RISE, CHAIN_SLIDE, LOCK_SNAP, TITLE_CHIME }

const STREAMS: Dictionary[Sound, AudioStream] = {
	Sound.EXIT: preload("res://assets/audio/exit.wav"),
	Sound.BLOCKED: preload("res://assets/audio/blocked.wav"),
	Sound.CHAIN_BREAK: preload("res://assets/audio/chain_break.wav"),
	Sound.UNLOCK: preload("res://assets/audio/unlock.wav"),
	Sound.LEVEL_COMPLETE: preload("res://assets/audio/level_complete.wav"),
	Sound.BUTTON: preload("res://assets/audio/button.wav"),
	Sound.LEVEL_START: preload("res://assets/audio/level_start.wav"),
	Sound.PRAISE: preload("res://assets/audio/praise.wav"),
	Sound.LINK_JOIN: preload("res://assets/audio/link_join.wav"),
	Sound.SPLASH_RISE: preload("res://assets/audio/splash_rise.wav"),
	Sound.CHAIN_SLIDE: preload("res://assets/audio/chain_slide.wav"),
	Sound.LOCK_SNAP: preload("res://assets/audio/lock_snap.wav"),
	Sound.TITLE_CHIME: preload("res://assets/audio/title_chime.wav"),
}
## Sounds that repeat quickly get a small random pitch change each time so a
## run of taps doesn't sound mechanical.
const PITCH_VARIATION: Dictionary[Sound, float] = {
	Sound.CHAIN_BREAK: 0.04,
}
## Enough voices for quick taps to overlap without cutting each other off.
const VOICE_COUNT := 6

var sound_enabled: bool = true
var vibration_enabled: bool = true

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
## Last sound and pitch requested, for tests.
var last_sound: int = -1
var last_pitch: float = 1.0


func _ready() -> void:
	for index: int in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)


## Stop every voice before going away so the audio server releases its
## playbacks cleanly (e.g. leaving the game while a sound is still playing).
func _exit_tree() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		# Let go of the sound too, so nothing is still in use when the app closes.
		voice.stream = null


func apply_settings(settings: SettingsStore) -> void:
	sound_enabled = settings.sound_enabled
	vibration_enabled = settings.vibration_enabled


## Plays [param sound]. [param pitch] scales it (the release sound climbs a
## scale during quick streaks); some sounds also get a little random variation.
func play(sound: Sound, pitch: float = 1.0) -> void:
	if not sound_enabled or _voices.is_empty():
		return
	var variation: float = PITCH_VARIATION.get(sound, 0.0)
	last_sound = sound
	last_pitch = pitch
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = STREAMS[sound]
	voice.pitch_scale = pitch * (1.0 + randf_range(-variation, variation))
	voice.play()


## Short haptic pulse on phones; does nothing on desktop.
func vibrate(duration_ms: int) -> void:
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)
