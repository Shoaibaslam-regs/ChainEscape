class_name SettingsStore
extends RefCounted
## Player preferences, saved offline in user://settings.cfg.
## A missing or unreadable file means "defaults".

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const KEY_VERSION := "version"
const FORMAT_VERSION := 1

var path: String
var sound_enabled: bool = true
var vibration_enabled: bool = true
## Replaces the splash and level-start animations with simple fades/snaps.
var reduced_motion: bool = false
## Chosen arrow theme id (see ArrowTheme); used only while unlocked.
var arrow_theme: String = ArrowTheme.DEFAULT_ID


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_settings() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := ConfigFile.new()
	var result := file.load(path)
	if result != OK:
		push_warning("SettingsStore: could not read %s (%s); using defaults." % [path, error_string(result)])
		return
	sound_enabled = _read_bool(file, "sound_enabled", sound_enabled)
	vibration_enabled = _read_bool(file, "vibration_enabled", vibration_enabled)
	reduced_motion = _read_bool(file, "reduced_motion", reduced_motion)
	var theme: Variant = file.get_value(SECTION, "arrow_theme", arrow_theme)
	arrow_theme = theme if theme is String else ArrowTheme.DEFAULT_ID


func save_settings() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_VERSION, FORMAT_VERSION)
	file.set_value(SECTION, "sound_enabled", sound_enabled)
	file.set_value(SECTION, "vibration_enabled", vibration_enabled)
	file.set_value(SECTION, "reduced_motion", reduced_motion)
	file.set_value(SECTION, "arrow_theme", arrow_theme)
	var result := file.save(path)
	if result != OK:
		push_warning("SettingsStore: could not save %s (%s)." % [path, error_string(result)])
		return false
	return true


func _read_bool(file: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant = file.get_value(SECTION, key, fallback)
	return value if value is bool else fallback
