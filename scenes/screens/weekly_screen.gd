class_name WeeklyScreen
extends Control
## The Weekly challenge hub: this week's five puzzles (any order), how hard
## each is, your result on each, days left, and the Weekly seal.

signal back_requested
signal puzzle_requested(index: int)

const BADGE_GOLD := preload("res://assets/icons/badge_gold.svg")
const BADGE_LOCKED := preload("res://assets/icons/badge_locked.svg")
const HAIRLINE := Color(0.725, 0.761, 0.827, 0.08)

@onready var _range_label: Label = %RangeLabel
@onready var _list: VBoxContainer = %List
@onready var _seal_icon: TextureRect = %SealIcon
@onready var _seal_title: Label = %SealTitle
@onready var _seal_caption: Label = %SealCaption

var _buttons: Array[Button] = []


func _ready() -> void:
	%BackButton.pressed.connect(back_requested.emit)


func setup(today_key: String, store: WeeklyStore) -> void:
	var week := WeeklyChallenge.week_key(today_key)
	var days := WeeklyChallenge.days_left(today_key)
	_range_label.text = "%s · %s" % [WeeklyChallenge.range_label(week), "last day" if days == 1 else "%d days left" % days]
	for child: Node in _list.get_children():
		child.queue_free()
	_buttons.clear()
	for index: int in WeeklyChallenge.PUZZLES:
		if index > 0:
			var line := ColorRect.new()
			line.color = HAIRLINE
			line.custom_minimum_size = Vector2(0, 2)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_list.add_child(line)
		_list.add_child(_make_row(index, store.get_wrong_taps(week, index)))
	var solved := store.solved_count(week)
	var complete := store.is_week_complete(week)
	_seal_icon.texture = BADGE_GOLD if complete else BADGE_LOCKED
	_seal_title.text = "WEEKLY SEAL EARNED" if complete else "WEEKLY SEAL · %d / %d" % [solved, WeeklyChallenge.PUZZLES]
	var earned := store.seals()
	_seal_caption.text = ("Seals earned: %d" % earned) if complete else "Solve all %d puzzles this week. Seals earned: %d" % [WeeklyChallenge.PUZZLES, earned]


func get_puzzle_button(index: int) -> Button:
	return _buttons[index]


func handle_back() -> bool:
	back_requested.emit()
	return true


func _make_row(index: int, wrong_taps: int) -> Control:
	var solved := wrong_taps >= 0
	var button := Button.new()
	button.theme_type_variation = &"FlatButton"
	button.custom_minimum_size = Vector2(0, 112)
	button.pressed.connect(puzzle_requested.emit.bind(index))
	_buttons.append(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var number := Label.new()
	number.text = str(index + 1)
	number.custom_minimum_size = Vector2(56, 0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.theme_type_variation = &"TitleLabel"
	number.add_theme_font_size_override("font_size", 40)
	number.add_theme_color_override("font_color", Palette.GOLD if solved else Palette.TEXT_TERTIARY)
	row.add_child(number)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	var title := Label.new()
	title.text = "Puzzle %d" % (index + 1)
	title.add_theme_font_override("font", GameTheme.font(700))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Palette.TEXT)
	column.add_child(title)
	var detail := Label.new()
	var dots := "●".repeat(WeeklyChallenge.stars_for(index)) + "○".repeat(WeeklyChallenge.PUZZLES - WeeklyChallenge.stars_for(index))
	detail.text = dots if not solved else "%s  ·  %s" % [dots, ChallengeMode.wrong_taps_text(wrong_taps).capitalize()]
	detail.theme_type_variation = &"CaptionLabel"
	detail.add_theme_font_size_override("font_size", 22)
	detail.add_theme_color_override("font_color", Palette.GOLD if not solved else Palette.KEY)
	column.add_child(detail)
	var status := Label.new()
	status.text = "Again ›" if solved else "Play ›"
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.theme_type_variation = &"OverlineLabel"
	status.add_theme_color_override("font_color", Palette.TEXT_TERTIARY if solved else Palette.GOLD)
	row.add_child(status)
	for label: Label in [number, title, detail, status]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button
