class_name TwistPopup
extends Control
## Premium pop-up over the dimmed board, shown once the level has flown in:
## a new twist's debut, the first level that merges two twists, or the first
## master arrow. The twist itself pops onto a small stage in the centre
## (turning gold rays, a soft glow, then a gentle float); its name is said
## once, then one line on how it works, then GOT IT.

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
## Picture size on the stage: one twist, or each of two side by side.
const STAGE_HEIGHT := 300.0
const ICON_SIZE_SINGLE := 230.0
const ICON_SIZE_PAIR := 180.0
const RAY_COUNT := 12

var _stage := Control.new()
var _icons: Array[TextureRect] = []
var _plus := Label.new()
var _ray_angle: float = 0.0
var _rays_alpha: float = 0.0
var _idle: Array[Tween] = []

@onready var _card: PanelContainer = %Card
@onready var _overline: Label = %Overline
@onready var _title: MetalLabel = %Title
@onready var _entries: VBoxContainer = %Entries
@onready var _got_it_button: Button = %GotItButton


func _ready() -> void:
	hide()
	set_process(false)
	_got_it_button.pressed.connect(_on_got_it)
	_card.add_theme_stylebox_override("panel", _card_style())
	# The stage sits between the overline and the name.
	_stage.custom_minimum_size = Vector2(0, STAGE_HEIGHT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	_stage.resized.connect(_layout_stage)
	_overline.get_parent().add_child(_stage)
	_overline.get_parent().move_child(_stage, _overline.get_index() + 1)
	_plus.text = "+"
	_plus.theme_type_variation = &"DisplayLabel"
	_plus.add_theme_font_size_override("font_size", 64)
	_plus.add_theme_color_override("font_color", Palette.GOLD)
	_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage.add_child(_plus)


func _process(delta: float) -> void:
	_ray_angle = fmod(_ray_angle + delta * 0.35, TAU)
	_stage.queue_redraw()


## True when [param level] should show this pop-up.
static func is_needed(level: LevelData) -> bool:
	return not level.new_twist.is_empty() or level.is_first_merge or level.is_first_master


func open(level: LevelData) -> void:
	for child: Node in _entries.get_children():
		child.queue_free()
	for icon: TextureRect in _icons:
		icon.queue_free()
	_icons.clear()
	# Each entry: [picture, name, how it works].
	var shown: Array[Array] = []
	if not level.new_twist.is_empty():
		_overline.text = "NEW TWIST"
		_title.text = String(LevelData.TWIST_NAMES[level.new_twist]).to_upper()
		shown.append([ICONS.get(level.new_twist), LevelData.TWIST_NAMES[level.new_twist], LevelData.TWIST_DESCRIPTIONS.get(level.new_twist, "")])
	elif level.is_first_merge:
		_overline.text = "TWISTS COMBINED"
		_title.text = "TWO AT ONCE"
		for twist: String in level.twists:
			shown.append([ICONS.get(twist), LevelData.TWIST_NAMES.get(twist, twist), LevelData.TWIST_DESCRIPTIONS.get(twist, "")])
	else:
		_overline.text = "NEW"
		_title.text = "MASTER ARROW"
		shown.append([MASTER_ICON, MASTER_NAME, MASTER_DESCRIPTION])
	if level.is_first_master and not level.new_twist.is_empty():
		shown.append([MASTER_ICON, MASTER_NAME, MASTER_DESCRIPTION])
	for entry: Array in shown:
		var icon := TextureRect.new()
		icon.texture = entry[0]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_meta("entry_name", entry[1])
		_stage.add_child(icon)
		_icons.append(icon)
		# The name is the title for one twist; with two, each line names its twist once.
		_entries.add_child(_make_description(entry[2], entry[1] if shown.size() > 1 else ""))
	_plus.visible = _icons.size() > 1
	show()
	set_process(true)
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.9
	_layout_stage()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The twist pops in, a beat after the card.
	_rays_alpha = 0.0
	tween.tween_property(self, "_rays_alpha", 1.0, 0.6).set_delay(0.15)
	for index: int in _icons.size():
		var icon := _icons[index]
		icon.scale = Vector2.ONE * 0.2
		icon.rotation = -0.5
		icon.modulate.a = 0.0
		var delay := 0.18 + index * 0.12
		tween.tween_property(icon, "scale", Vector2.ONE, 0.5).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, "rotation", 0.0, 0.5).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, "modulate:a", 1.0, 0.2).set_delay(delay)
	_plus.modulate.a = 0.0
	tween.tween_property(_plus, "modulate:a", 1.0, 0.3).set_delay(0.35)
	_title.play_glint(0.7, 0.45)
	tween.chain().tween_callback(_start_idle)


func close() -> void:
	_stop_idle()
	set_process(false)
	hide()


func get_title_text() -> String:
	return _title.text


func get_overline_text() -> String:
	return _overline.text


func get_entry_names() -> PackedStringArray:
	var names := PackedStringArray()
	for icon: TextureRect in _icons:
		names.append(icon.get_meta("entry_name", ""))
	return names


## Every visible text in the pop-up (tests check nothing is said twice).
func get_all_text() -> String:
	var parts := PackedStringArray([_overline.text, _title.text])
	for entry: Node in _entries.get_children():
		if not entry.is_queued_for_deletion() and entry is Label:
			parts.append((entry as Label).text)
	return " | ".join(parts)


func get_stage_icons() -> Array[TextureRect]:
	return _icons


func get_got_it_button() -> Button:
	return _got_it_button


func _on_got_it() -> void:
	close()
	dismissed.emit()


## One centred line on how a twist works; with two twists it starts with
## the twist's name ("Walls: ...") so each name is said exactly once.
func _make_description(description: String, prefix: String) -> Label:
	var label := Label.new()
	label.text = description if prefix.is_empty() else "%s: %s" % [prefix, description]
	label.theme_type_variation = &"CaptionLabel"
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(520, 0)
	return label


func _layout_stage() -> void:
	var count := _icons.size()
	if count == 0:
		return
	var size_px := ICON_SIZE_SINGLE if count == 1 else ICON_SIZE_PAIR
	var gap := 70.0
	var total := count * size_px + (count - 1) * gap
	var left := (_stage.size.x - total) * 0.5
	for index: int in count:
		var icon := _icons[index]
		icon.size = Vector2.ONE * size_px
		icon.pivot_offset = icon.size * 0.5
		icon.position = Vector2(left + index * (size_px + gap), (_stage.size.y - size_px) * 0.5)
	_plus.size = Vector2(gap, size_px)
	_plus.position = Vector2(left + size_px, (_stage.size.y - size_px) * 0.5)


## A gentle float once the twist has landed.
func _start_idle() -> void:
	_stop_idle()
	for index: int in _icons.size():
		var icon := _icons[index]
		var base_y := icon.position.y
		var bob := create_tween().set_loops()
		bob.tween_property(icon, "position:y", base_y - 8.0, 1.4 + index * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(icon, "position:y", base_y, 1.4 + index * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle.append(bob)


func _stop_idle() -> void:
	for bob: Tween in _idle:
		if bob.is_valid():
			bob.kill()
	_idle.clear()


func is_floating() -> bool:
	return _idle.any(func(bob: Tween) -> bool: return bob.is_valid())


## Gold rays turning slowly behind the twist, and a soft glow.
func _draw_stage() -> void:
	if _rays_alpha <= 0.0:
		return
	var center := _stage.size * 0.5
	var radius := _stage.size.y * 0.75
	var color := Color(Palette.GOLD, 0.10 * _rays_alpha)
	var clear := Color(Palette.GOLD, 0.0)
	for i: int in RAY_COUNT:
		var a := _ray_angle + i * TAU / RAY_COUNT
		var b := a + TAU / RAY_COUNT * 0.45
		_stage.draw_polygon(PackedVector2Array([center, center + Vector2.from_angle(a) * radius, center + Vector2.from_angle(b) * radius]), PackedColorArray([color, clear, clear]))
	for ring: int in 5:
		_stage.draw_circle(center, radius * (0.55 - ring * 0.08), Color(Palette.GOLD, 0.035 * _rays_alpha), true, -1.0, true)


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
