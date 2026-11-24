class_name AchievementsScreen
extends Control
## Every achievement with its progress, opened from the Rewards row on Home.
## Two calm sections: what is in progress (closest first), then what is
## unlocked. Nothing in the list takes touches, so a drag anywhere scrolls.

signal back_requested

const BADGE_GOLD := preload("res://assets/icons/badge_gold.svg")
const BADGE_LOCKED := preload("res://assets/icons/badge_locked.svg")
const HAIRLINE := Color(0.725, 0.761, 0.827, 0.08)

@onready var _summary: Label = %Summary
@onready var _overall_bar: ProgressBar = %OverallBar
@onready var _list: VBoxContainer = %List
@onready var _scroll: ScrollContainer = %Scroll


func _ready() -> void:
	%BackButton.pressed.connect(back_requested.emit)


func setup(tracker: AchievementTracker) -> void:
	var total := AchievementTracker.DEFINITIONS.size()
	_summary.text = "%d of %d unlocked" % [tracker.unlocked_count(), total]
	_overall_bar.value = 100.0 * tracker.unlocked_count() / float(total)
	for child: Node in _list.get_children():
		child.queue_free()
	var in_progress: Array[Dictionary] = []
	var unlocked: Array[Dictionary] = []
	for definition: Dictionary in AchievementTracker.DEFINITIONS:
		(unlocked if tracker.is_unlocked(definition["id"]) else in_progress).append(definition)
	in_progress.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return tracker.get_progress(a) > tracker.get_progress(b))
	_add_section("IN PROGRESS", in_progress, tracker)
	_add_section("UNLOCKED", unlocked, tracker)


func get_row_count() -> int:
	var count := 0
	for node: Node in _list.find_children("Row*", "HBoxContainer", true, false):
		if not node.is_queued_for_deletion():
			count += 1
	return count


func get_scroll() -> ScrollContainer:
	return _scroll


## Every control inside the list, to check none of them blocks scrolling.
func get_list_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for node: Node in _list.find_children("*", "Control", true, false):
		controls.append(node as Control)
	return controls


func handle_back() -> bool:
	back_requested.emit()
	return true


func _add_section(heading: String, definitions: Array[Dictionary], tracker: AchievementTracker) -> void:
	if definitions.is_empty():
		return
	var label := Label.new()
	label.theme_type_variation = &"OverlineLabel"
	label.add_theme_color_override("font_color", Palette.TEXT_TERTIARY)
	label.text = "%s · %d" % [heading, definitions.size()]
	_calm(label)
	_list.add_child(label)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	_calm(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	_calm(rows)
	card.add_child(rows)
	for i in definitions.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = HAIRLINE
			line.custom_minimum_size = Vector2(0, 2)
			_calm(line)
			rows.add_child(line)
		rows.add_child(_make_row(definitions[i], tracker))
	_list.add_child(card)


func _make_row(definition: Dictionary, tracker: AchievementTracker) -> Control:
	var unlocked := tracker.is_unlocked(definition["id"])
	var row := HBoxContainer.new()
	row.name = "Row_%s" % definition["id"]
	row.add_theme_constant_override("separation", 22)
	_calm(row)
	var badge := TextureRect.new()
	badge.texture = BADGE_GOLD if unlocked else BADGE_LOCKED
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size = Vector2(60, 60)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		badge.modulate.a = 0.7
	_calm(badge)
	row.add_child(badge)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	_calm(column)
	row.add_child(column)
	var padding := Control.new()
	padding.custom_minimum_size = Vector2(0, 14)
	_calm(padding)
	column.add_child(padding)
	var header := HBoxContainer.new()
	_calm(header)
	column.add_child(header)
	var title := Label.new()
	title.text = definition["title"]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", GameTheme.font(700))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Palette.TEXT if unlocked else Palette.TEXT_SECONDARY)
	_calm(title)
	header.add_child(title)
	var count := Label.new()
	count.theme_type_variation = &"CaptionLabel"
	count.add_theme_font_size_override("font_size", 22)
	if unlocked:
		count.text = "Unlocked"
		count.add_theme_color_override("font_color", Palette.GOLD)
	else:
		count.text = "%d / %d" % [mini(tracker.get_stat(definition["stat"]), definition["goal"]), definition["goal"]]
		count.add_theme_color_override("font_color", Palette.TEXT_TERTIARY)
	_calm(count)
	header.add_child(count)
	var description := Label.new()
	description.theme_type_variation = &"CaptionLabel"
	description.add_theme_font_size_override("font_size", 22)
	description.add_theme_color_override("font_color", Palette.TEXT_TERTIARY)
	description.text = definition["description"]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_calm(description)
	column.add_child(description)
	if not unlocked:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.show_percentage = false
		bar.value = tracker.get_progress(definition) * 100.0
		_calm(bar)
		var bar_gap := Control.new()
		bar_gap.custom_minimum_size = Vector2(0, 8)
		_calm(bar_gap)
		column.add_child(bar_gap)
		column.add_child(bar)
	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, 14)
	_calm(bottom)
	column.add_child(bottom)
	return row


## Display only: lets touches fall through to the scroll container.
func _calm(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
