class_name Music
extends Node
## Quiet background music: one looping track that fades in and out.
## The track is res://assets/audio/music.wav (a synthesised placeholder until
## a licensed track replaces it under the same name). Off when the player
## turns music off in Settings.

const TRACK_PATH := "res://assets/audio/music.wav"
## Kept well under the sound effects.
const VOLUME_DB := -16.0
const SILENT_DB := -60.0
const FADE_IN_SECONDS := 2.5
const FADE_OUT_SECONDS := 0.8

var _player := AudioStreamPlayer.new()
var _fade: Tween
var _enabled: bool = false


func _ready() -> void:
	if ResourceLoader.exists(TRACK_PATH):
		_player.stream = load(TRACK_PATH)
	_player.volume_db = SILENT_DB
	add_child(_player)


func apply_settings(settings: SettingsStore) -> void:
	set_enabled(settings.music_enabled)


func set_enabled(enabled: bool) -> void:
	if enabled == _enabled:
		return
	_enabled = enabled
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	if enabled and _player.stream != null:
		if not _player.playing:
			_player.play()
		_fade.tween_property(_player, "volume_db", VOLUME_DB, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE)
	else:
		_fade.tween_property(_player, "volume_db", SILENT_DB, FADE_OUT_SECONDS)
		_fade.tween_callback(_player.stop)


func is_playing() -> bool:
	return _player.playing


func is_enabled() -> bool:
	return _enabled


func _exit_tree() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_player.stop()
	# Release the track so nothing is left in use when the app closes.
	_player.stream = null
