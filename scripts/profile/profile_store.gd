class_name ProfileStore
extends RefCounted
## The player's name, avatar and frame, saved offline in user://profile.cfg.
## Kept when progress is reset (a locked pick simply shows the default).

signal changed

const DEFAULT_PATH := "user://profile.cfg"
const SECTION := "profile"
const KEY_VERSION := "version"
const FORMAT_VERSION := 1
const DEFAULT_NAME := "Player"
const NAME_MIN := 2
const NAME_MAX := 16

var path: String
var player_name: String = DEFAULT_NAME
var avatar_id: String = ProfileItems.DEFAULT_AVATAR
var frame_id: String = ProfileItems.DEFAULT_FRAME
## "" until a social login is connected (e.g. "facebook").
var linked_provider: String = ""


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


## Trims, collapses spaces and keeps letters, digits, spaces and . _ - '.
## Returns "" when the result is too short to be a name.
static func clean_name(raw: String) -> String:
	var kept := ""
	for character: String in raw.strip_edges():
		var code := character.unicode_at(0)
		# Cased letters (Latin, Greek, Cyrillic...) plus Arabic script, which
		# the game font (Cairo) also draws. No emoji: the font has none.
		var is_letter := character.to_upper() != character.to_lower() or (code >= 0x0600 and code <= 0x06FF)
		var is_digit := character >= "0" and character <= "9"
		if is_letter or is_digit or character in [" ", ".", "_", "-", "'"]:
			kept += character
	while kept.contains("  "):
		kept = kept.replace("  ", " ")
	kept = kept.strip_edges().left(NAME_MAX).strip_edges()
	return kept if kept.length() >= NAME_MIN else ""


func load_profile() -> void:
	player_name = DEFAULT_NAME
	avatar_id = ProfileItems.DEFAULT_AVATAR
	frame_id = ProfileItems.DEFAULT_FRAME
	linked_provider = ""
	if not FileAccess.file_exists(path):
		return
	var file := ConfigFile.new()
	if file.load(path) != OK:
		push_warning("ProfileStore: could not read %s; using defaults." % path)
		return
	var saved_name: Variant = file.get_value(SECTION, "name", DEFAULT_NAME)
	var saved_avatar: Variant = file.get_value(SECTION, "avatar", avatar_id)
	var saved_frame: Variant = file.get_value(SECTION, "frame", frame_id)
	var saved_provider: Variant = file.get_value(SECTION, "linked_provider", "")
	if saved_name is String and not clean_name(saved_name).is_empty():
		player_name = clean_name(saved_name)
	if saved_avatar is String and not ProfileItems.find(ProfileItems.AVATARS, saved_avatar).is_empty():
		avatar_id = saved_avatar
	if saved_frame is String and not ProfileItems.find(ProfileItems.FRAMES, saved_frame).is_empty():
		frame_id = saved_frame
	if saved_provider is String:
		linked_provider = saved_provider


func save_profile() -> bool:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_VERSION, FORMAT_VERSION)
	file.set_value(SECTION, "name", player_name)
	file.set_value(SECTION, "avatar", avatar_id)
	file.set_value(SECTION, "frame", frame_id)
	file.set_value(SECTION, "linked_provider", linked_provider)
	var result := file.save(path)
	if result != OK:
		push_warning("ProfileStore: could not save %s (%s)." % [path, error_string(result)])
	return result == OK


## Returns false (and keeps the old name) when [param raw] is not a usable name.
func set_player_name(raw: String) -> bool:
	var cleaned := clean_name(raw)
	if cleaned.is_empty():
		return false
	if cleaned != player_name:
		player_name = cleaned
		save_profile()
		changed.emit()
	return true


func set_avatar(id: String) -> void:
	if id != avatar_id and not ProfileItems.find(ProfileItems.AVATARS, id).is_empty():
		avatar_id = id
		save_profile()
		changed.emit()


func set_frame(id: String) -> void:
	if id != frame_id and not ProfileItems.find(ProfileItems.FRAMES, id).is_empty():
		frame_id = id
		save_profile()
		changed.emit()
