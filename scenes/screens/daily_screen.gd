class_name DailyScreen
extends Control
## The Daily challenge hub: today's board (live preview), play or your
## result, a countdown to tomorrow's puzzle, and the day streak with a
## seven-day tracker. Leaderboards arrive with the online update.

signal back_requested
signal play_requested

const CHECK_ICON := preload("res://assets/icons/check.svg")
const COUNTDOWN_REFRESH_SECONDS := 20.0

@onready var _date_label: Label = %DateLabel
@onready var _preview: BoardView = %Preview
@onready var _status_label: Label = %StatusLabel
@onready var _play_button: Button = %PlayButton
@onready var _play_label: Label = %PlayLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _streak_label: Label = %StreakLabel
@onready var _best_label: Label = %BestLabel
@onready var _week_row: HBoxContainer = %WeekRow

var _date_key: String = ""


func _ready() -> void:
	%BackButton.pressed.connect(back_requested.emit)
	_play_button.pressed.connect(play_requested.emit)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timer := Timer.new()
	timer.wait_time = COUNTDOWN_REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(_update_countdown)
	add_child(timer)


func setup(date_key: String, store: DailyStore, level: LevelData) -> void:
	_date_key = date_key
	_date_label.text = DailyDate.long_label(date_key)
	var board := level.build_board() if level != null else null
	_preview.hide_links = level != null and level.has_twist(LevelData.TWIST_HIDDEN_LINKS)
	_preview.set_board(board)
	var wrong_taps := store.get_wrong_taps(date_key)
	if wrong_taps < 0:
		_status_label.text = "The same board for every player today. Solve it with as few wrong taps as you can."
		_play_label.text = "PLAY TODAY'S PUZZLE"
	else:
		_status_label.text = "Solved with %s. Play again to improve it." % ("no wrong taps" if wrong_taps == 0 else "%d wrong %s" % [wrong_taps, "tap" if wrong_taps == 1 else "taps"])
		_play_label.text = "PLAY AGAIN"
	var streak := store.current_streak(date_key)
	_streak_label.text = "%d-DAY STREAK" % streak
	_best_label.text = "Best: %d" % store.best_streak()
	_build_week(store.week(date_key))
	_update_countdown()


func get_play_button() -> Button:
	return _play_button


func get_status_text() -> String:
	return _status_label.text


func get_streak_text() -> String:
	return _streak_label.text


func handle_back() -> bool:
	back_requested.emit()
	return true


func _update_countdown() -> void:
	var seconds := DailyDate.seconds_until_tomorrow()
	_countdown_label.text = "New puzzle in %d h %d min" % [seconds / 3600, (seconds % 3600) / 60]


func _build_week(days: Array[Dictionary]) -> void:
	for child: Node in _week_row.get_children():
		child.queue_free()
	for day: Dictionary in days:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 8)
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(64, 64)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(18)
		style.bg_color = Palette.GOLD if day["solved"] else (Palette.TILE if day["is_today"] else Palette.CELL)
		if day["is_today"] and not day["solved"]:
			style.border_color = Palette.GOLD_OUTLINE
			style.set_border_width_all(2)
		tile.add_theme_stylebox_override("panel", style)
		if day["solved"]:
			var check := TextureRect.new()
			check.texture = CHECK_ICON
			check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			check.custom_minimum_size = Vector2(34, 34)
			check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tile.add_child(check)
		column.add_child(tile)
		var letter := Label.new()
		letter.text = day["letter"]
		letter.theme_type_variation = &"OverlineLabel"
		letter.add_theme_color_override("font_color", Palette.TEXT if day["is_today"] else Palette.TEXT_TERTIARY)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(letter)
		_week_row.add_child(column)
