class_name AchievementsScreen
extends Control
## Every achievement with its progress: gold badge when unlocked, steel when
## locked. Opened from the Rewards card on Home.

signal back_requested

const BADGE_GOLD := preload("res://assets/icons/badge_gold.svg")
const BADGE_LOCKED := preload("res://assets/icons/badge_locked.svg")

@onready var _summary: Label = %Summary
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	%BackButton.pressed.connect(back_requested.emit)


func setup(tracker: AchievementTracker) -> void:
	_summary.text = "%d of %d unlocked" % [tracker.unlocked_count(), AchievementTracker.DEFINITIONS.size()]
	for child: Node in _list.get_children():
		child.queue_free()
	# Unlocked first, then the rest by how close they are.
	var ordered := AchievementTracker.DEFINITIONS.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_done := tracker.is_unlocked(a["id"])
		var b_done := tracker.is_unlocked(b["id"])
		if a_done != b_done:
			return a_done
		return tracker.get_progress(a) > tracker.get_progress(b))
	for definition: Dictionary in ordered:
		_list.add_child(_make_row(definition, tracker))


func get_row_count() -> int:
	return _list.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


func handle_back() -> bool:
	back_requested.emit()
	return true


func _make_row(definition: Dictionary, tracker: AchievementTracker) -> Control:
	var unlocked := tracker.is_unlocked(definition["id"])
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	card.add_child(row)
	var badge := TextureRect.new()
	badge.texture = BADGE_GOLD if unlocked else BADGE_LOCKED
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size = Vector2(80, 80)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = definition["title"]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", GameTheme.font(800))
	title.add_theme_color_override("font_color", Palette.TEXT if unlocked else Palette.TEXT_SECONDARY)
	header.add_child(title)
	var count := Label.new()
	count.theme_type_variation = &"CaptionLabel"
	if unlocked:
		count.text = "UNLOCKED"
		count.theme_type_variation = &"OverlineLabel"
	else:
		count.text = "%d / %d" % [mini(tracker.get_stat(definition["stat"]), definition["goal"]), definition["goal"]]
	header.add_child(count)
	var description := Label.new()
	description.theme_type_variation = &"CaptionLabel"
	description.text = definition["description"]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	if not unlocked:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 10)
		bar.show_percentage = false
		bar.value = tracker.get_progress(definition) * 100.0
		column.add_child(bar)
	return card
