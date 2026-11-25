class_name ProfileScreen
extends Control
## The player's account: name, avatar and frame (earned by playing), a way
## into Achievements, and social login (Facebook, "coming soon" until the
## OAuth flow is plugged into SocialLogin). Opened from the player card on Home.

signal back_requested
signal achievements_requested

const BACK_ICON := preload("res://assets/icons/back.svg")
const FACEBOOK_ICON := preload("res://assets/icons/facebook.svg")
const LOCK_GLYPH := preload("res://assets/avatars/padlock.svg")
const BACKGROUND := preload("res://scenes/ui/screen_background.tscn")
const FACEBOOK_BLUE := Color("1877F2")
const AVATAR_COLUMNS := 5
const ITEM_HEIGHT := 100.0
const FRAME_ITEM_HEIGHT := 84.0
const NAME_HELP := "Tap your name to change it"
const NAME_INVALID := "Use 2 to 16 letters or numbers"

var _profile: ProfileStore
var _tracker: AchievementTracker
var _points: int = 0
var _login := SocialLogin.new()

var _hero_badge := AvatarBadge.new()
var _name_edit := LineEdit.new()
var _name_note := Label.new()
var _rank_label := Label.new()
var _avatar_grid := GridContainer.new()
var _frame_grid := GridContainer.new()
var _avatar_heading := Label.new()
var _frame_heading := Label.new()
var _avatar_note := Label.new()
var _frame_note := Label.new()
var _achievements_button := Button.new()
var _achievements_count := Label.new()
var _facebook_button := Button.new()
var _account_note := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_login.finished.connect(_on_login_finished)


func setup(profile: ProfileStore, points: int, tracker: AchievementTracker) -> void:
	_profile = profile
	_points = points
	_tracker = tracker
	_refresh()


func handle_back() -> bool:
	if _name_edit.has_focus():
		_name_edit.release_focus()
		return true
	back_requested.emit()
	return true


# --- Building -------------------------------------------------------------

func _build() -> void:
	add_child(BACKGROUND.instantiate())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	layout.add_child(top)
	var back := Button.new()
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(88, 88)
	back.theme_type_variation = &"IconButton"
	back.icon = BACK_ICON
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.expand_icon = true
	back.tooltip_text = "Back"
	back.pressed.connect(back_requested.emit)
	top.add_child(back)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 42)
	title.text = "PROFILE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)

	layout.add_child(_build_hero())
	layout.add_child(_section(_avatar_heading, _avatar_grid, _avatar_note, AVATAR_COLUMNS))
	layout.add_child(_section(_frame_heading, _frame_grid, _frame_note, ProfileItems.FRAMES.size()))
	layout.add_child(_build_achievements_row())
	layout.add_child(_build_account())


func _build_hero() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	card.add_child(row)
	_hero_badge.custom_minimum_size = Vector2(132, 132)
	_hero_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hero_badge)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	_name_edit.name = "NameEdit"
	_name_edit.max_length = ProfileStore.NAME_MAX
	_name_edit.placeholder_text = "Your name"
	_name_edit.select_all_on_focus = true
	_name_edit.add_theme_font_size_override("font_size", 38)
	_name_edit.add_theme_color_override("font_color", Palette.TEXT)
	_name_edit.add_theme_color_override("caret_color", Palette.GOLD)
	var field := StyleBoxFlat.new()
	field.bg_color = Palette.SURFACE
	field.set_corner_radius_all(16)
	field.content_margin_left = 18
	field.content_margin_right = 18
	field.content_margin_top = 6
	field.content_margin_bottom = 6
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.set_border_width_all(3)
	field_focus.border_color = Palette.GOLD
	_name_edit.add_theme_stylebox_override("normal", field)
	_name_edit.add_theme_stylebox_override("focus", field_focus)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _name_edit.release_focus())
	_name_edit.focus_exited.connect(_commit_name)
	text.add_child(_name_edit)
	_rank_label.theme_type_variation = &"OverlineLabel"
	text.add_child(_rank_label)
	_name_note.theme_type_variation = &"CaptionLabel"
	_name_note.add_theme_color_override("font_color", Palette.TEXT_TERTIARY)
	_name_note.text = NAME_HELP
	text.add_child(_name_note)
	return card


func _section(heading: Label, grid: GridContainer, note: Label, columns: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	heading.theme_type_variation = &"OverlineLabel"
	heading.add_theme_color_override("font_color", Palette.TEXT_TERTIARY)
	box.add_child(heading)
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	note.theme_type_variation = &"CaptionLabel"
	note.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	return box


func _build_achievements_row() -> Control:
	_achievements_button.name = "AchievementsButton"
	_achievements_button.custom_minimum_size = Vector2(0, 88)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.WORKBENCH
	normal.set_corner_radius_all(24)
	normal.border_color = Color(1, 1, 1, 0.04)
	normal.set_border_width_all(2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.CELL
	for state: String in ["normal", "hover", "focus"]:
		_achievements_button.add_theme_stylebox_override(state, normal)
	_achievements_button.add_theme_stylebox_override("pressed", pressed)
	_achievements_button.pressed.connect(achievements_requested.emit)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 32
	row.offset_right = -32
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievements_button.add_child(row)
	var label := Label.new()
	label.theme_type_variation = &"HeadingLabel"
	label.add_theme_font_size_override("font_size", 28)
	label.text = "Achievements"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_achievements_count.theme_type_variation = &"OverlineLabel"
	_achievements_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_achievements_count)
	return _achievements_button


func _build_account() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var heading := Label.new()
	heading.theme_type_variation = &"OverlineLabel"
	heading.add_theme_color_override("font_color", Palette.TEXT_TERTIARY)
	heading.text = "ACCOUNT"
	box.add_child(heading)
	_facebook_button.name = "FacebookButton"
	_facebook_button.custom_minimum_size = Vector2(0, 88)
	_facebook_button.text = "Continue with Facebook"
	_facebook_button.icon = FACEBOOK_ICON
	_facebook_button.add_theme_constant_override("icon_max_width", 40)
	_facebook_button.add_theme_constant_override("h_separation", 16)
	_facebook_button.add_theme_font_size_override("font_size", 28)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_facebook_button.add_theme_color_override(state, Color.WHITE)
	var blue := StyleBoxFlat.new()
	blue.bg_color = FACEBOOK_BLUE
	blue.set_corner_radius_all(24)
	blue.content_margin_left = 32
	blue.content_margin_right = 32
	var blue_pressed := blue.duplicate() as StyleBoxFlat
	blue_pressed.bg_color = FACEBOOK_BLUE.darkened(0.2)
	for state: String in ["normal", "hover", "focus"]:
		_facebook_button.add_theme_stylebox_override(state, blue)
	_facebook_button.add_theme_stylebox_override("pressed", blue_pressed)
	_facebook_button.pressed.connect(_on_facebook_pressed)
	box.add_child(_facebook_button)
	_account_note.theme_type_variation = &"CaptionLabel"
	_account_note.add_theme_color_override("font_color", Palette.TEXT_TERTIARY)
	_account_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_account_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_account_note.text = "Save your progress and play with friends. Your progress stays on this phone until you connect."
	box.add_child(_account_note)
	return box


func _make_item(is_avatar: bool, item: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Item_%s" % item["id"]
	button.custom_minimum_size = Vector2(0, ITEM_HEIGHT if is_avatar else FRAME_ITEM_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = String(item["name"])
	var unlocked := ProfileItems.is_unlocked(item, _points, _tracker)
	var chosen: bool = item["id"] == (_profile.avatar_id if is_avatar else _profile.frame_id)
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.WORKBENCH if unlocked else Palette.SURFACE
	box.set_corner_radius_all(22)
	if chosen:
		box.set_border_width_all(4)
		box.border_color = Palette.GOLD
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, box)
	var badge := AvatarBadge.new()
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := 10 if is_avatar else 8
	for offset: String in ["offset_left", "offset_top"]:
		badge.set(offset, inset)
	for offset: String in ["offset_right", "offset_bottom"]:
		badge.set(offset, -inset)
	if is_avatar:
		badge.set_profile(item["id"], _current_frame()["id"])
	else:
		badge.set_profile(_current_avatar()["id"], item["id"])
	if not unlocked:
		badge.modulate = Color(0.55, 0.55, 0.6, 0.45)
	button.add_child(badge)
	if not unlocked:
		# A small lock in the corner; the item itself stays recognisable.
		var lock := TextureRect.new()
		lock.name = "LockMark"
		lock.texture = LOCK_GLYPH
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		lock.offset_left = -38
		lock.offset_top = -38
		lock.offset_right = -2
		lock.offset_bottom = -2
		button.add_child(lock)
	button.pressed.connect(_on_item_pressed.bind(is_avatar, item))
	return button


# --- State ----------------------------------------------------------------

func _current_avatar() -> Dictionary:
	return ProfileItems.resolve(ProfileItems.AVATARS, _profile.avatar_id, _points, _tracker)


func _current_frame() -> Dictionary:
	return ProfileItems.resolve(ProfileItems.FRAMES, _profile.frame_id, _points, _tracker)


func _refresh() -> void:
	if _profile == null:
		return
	_hero_badge.set_profile(_current_avatar()["id"], _current_frame()["id"])
	if not _name_edit.has_focus():
		_name_edit.text = _profile.player_name
	_rank_label.text = "%s · %d %s" % [String(Rank.for_points(_points)["name"]).to_upper(), _points, "POINT" if _points == 1 else "POINTS"]
	_avatar_heading.text = "AVATAR · %d/%d" % [ProfileItems.unlocked_count(ProfileItems.AVATARS, _points, _tracker), ProfileItems.AVATARS.size()]
	_frame_heading.text = "FRAME · %d/%d" % [ProfileItems.unlocked_count(ProfileItems.FRAMES, _points, _tracker), ProfileItems.FRAMES.size()]
	_fill_grid(_avatar_grid, true, ProfileItems.AVATARS)
	_fill_grid(_frame_grid, false, ProfileItems.FRAMES)
	if _avatar_note.text.is_empty():
		_avatar_note.text = String(_current_avatar()["name"])
	if _frame_note.text.is_empty():
		_frame_note.text = "%s frame" % _current_frame()["name"]
	var total := AchievementTracker.DEFINITIONS.size()
	var unlocked := _tracker.unlocked_count() if _tracker != null else 0
	_achievements_count.text = "%d/%d  ›" % [unlocked, total]
	if _profile.linked_provider == SocialLogin.FACEBOOK:
		_facebook_button.text = "Connected to Facebook"


func _fill_grid(grid: GridContainer, is_avatar: bool, items: Array[Dictionary]) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for item: Dictionary in items:
		grid.add_child(_make_item(is_avatar, item))


func _on_item_pressed(is_avatar: bool, item: Dictionary) -> void:
	var note := _avatar_note if is_avatar else _frame_note
	var label := String(item["name"]) if is_avatar else "%s frame" % item["name"]
	if not ProfileItems.is_unlocked(item, _points, _tracker):
		note.text = "%s: %s to unlock" % [label, ProfileItems.unlock_text(item)]
		return
	note.text = label
	if is_avatar:
		_profile.set_avatar(item["id"])
	else:
		_profile.set_frame(item["id"])
	_refresh()


func _commit_name() -> void:
	if _profile == null:
		return
	if _profile.set_player_name(_name_edit.text):
		_name_edit.text = _profile.player_name
		_name_note.text = NAME_HELP
	else:
		_name_edit.text = _profile.player_name
		_name_note.text = NAME_INVALID


func _on_facebook_pressed() -> void:
	_login.sign_in(SocialLogin.FACEBOOK)


func _on_login_finished(success: bool, message: String) -> void:
	_account_note.text = message
	_account_note.add_theme_color_override("font_color", Palette.TEXT_SECONDARY if success else Palette.GOLD)


# --- For tests --------------------------------------------------------------

func get_name_edit() -> LineEdit:
	return _name_edit


func get_name_note() -> String:
	return _name_note.text


func get_item_button(is_avatar: bool, id: String) -> Button:
	return (_avatar_grid if is_avatar else _frame_grid).get_node_or_null("Item_%s" % id) as Button


func get_note(is_avatar: bool) -> String:
	return (_avatar_note if is_avatar else _frame_note).text


func get_account_note() -> String:
	return _account_note.text


func get_facebook_button() -> Button:
	return _facebook_button


func get_achievements_button() -> Button:
	return _achievements_button


func get_hero_badge() -> AvatarBadge:
	return _hero_badge
