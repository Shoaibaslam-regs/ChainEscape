class_name TwistPopup
extends Control
## Premium pop-up over the dimmed board, shown once the level has flown in:
## a new twist's debut, the first level that merges two twists, or the first
## master arrow. The player reads the rule in context, then taps GOT IT.

signal dismissed

const ICONS: Dictionary[String, Texture2D] = {
	LevelData.TWIST_DOUBLE_LOCKS: preload("res://assets/icons/twists/double_locks.svg"),
	LevelData.TWIST_WALLS: preload("res://assets/icons/twists/walls.svg"),
	LevelData.TWIST_LONG_CHAINS: preload("res://assets/icons/twists/long_chains.svg"),
	LevelData.TWIST_HIDDEN_LINKS: preload("res://assets/icons/twists/hidden_links.svg"),
	LevelData.TWIST_BLACK_HOLES: preload("res://assets/icons/twists/black_holes.svg"),
	LevelData.TWIST_MIRRORS: preload("res://assets/icons/twists/mirrors.svg"),
}
const MASTER_ICON := preload("res://assets/icons/twists/master.svg")
const MASTER_NAME := "Master arrow"
const MASTER_DESCRIPTION := "Free the large gold arrow and every other arrow escapes with it."
const ICON_SIZE := 104.0

@onready var _card: PanelContainer = %Card
@onready var _overline: Label = %Overline
@onready var _title: MetalLabel = %Title
@onready var _entries: VBoxContainer = %Entries
@onready var _got_it_button: Button = %GotItButton


func _ready() -> void:
	hide()
	_got_it_button.pressed.connect(_on_got_it)
	_card.add_theme_stylebox_override("panel", _card_style())


## True when [param level] should show this pop-up.
static func is_needed(level: LevelData) -> bool:
	return not level.new_twist.is_empty() or level.is_first_merge or level.is_first_master


func open(level: LevelData) -> void:
	for child: Node in _entries.get_children():
		child.queue_free()
	var shown: Array[String] = []
	if not level.new_twist.is_empty():
		_overline.text = "NEW TWIST"
		_title.text = String(LevelData.TWIST_NAMES[level.new_twist]).to_upper()
		shown.append(level.new_twist)
	elif level.is_first_merge:
		_overline.text = "TWISTS COMBINED"
		_title.text = "TWO AT ONCE"
		shown.assign(level.twists)
	else:
		_overline.text = "NEW"
		_title.text = "MASTER ARROW"
	for twist: String in shown:
		_entries.add_child(_make_entry(ICONS.get(twist), LevelData.TWIST_NAMES.get(twist, twist), LevelData.TWIST_DESCRIPTIONS.get(twist, "")))
	if level.is_first_master:
		_entries.add_child(_make_entry(MASTER_ICON, MASTER_NAME, MASTER_DESCRIPTION))
	show()
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.88
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title.play_glint(0.7, 0.2)


func close() -> void:
	hide()


func get_title_text() -> String:
	return _title.text


func get_overline_text() -> String:
	return _overline.text


func get_entry_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry: Node in _entries.get_children():
		if not entry.is_queued_for_deletion():
			names.append(entry.get_meta("entry_name", ""))
	return names


func get_got_it_button() -> Button:
	return _got_it_button


func _on_got_it() -> void:
	close()
	dismissed.emit()


func _make_entry(icon: Texture2D, entry_name: String, description: String) -> Control:
	var row := HBoxContainer.new()
	row.set_meta("entry_name", entry_name)
	row.add_theme_constant_override("separation", 22)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2.ONE * ICON_SIZE
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := Label.new()
	name_label.text = entry_name
	name_label.theme_type_variation = &"HeadingLabel"
	text.add_child(name_label)
	var description_label := Label.new()
	description_label.text = description
	description_label.theme_type_variation = &"CaptionLabel"
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(description_label)
	row.add_child(text)
	return row


static func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.SURFACE
	box.border_color = Palette.GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(44)
	box.content_margin_left = 44
	box.content_margin_right = 44
	box.content_margin_top = 44
	box.content_margin_bottom = 44
	box.shadow_color = Color(Palette.GOLD, 0.18)
	box.shadow_size = 28
	box.anti_aliasing = true
	return box
