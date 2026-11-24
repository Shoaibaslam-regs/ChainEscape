class_name PausePanel
extends Control
## Bottom sheet over the dimmed game: Resume, Restart, Settings, Home.

signal resume_requested
signal restart_requested
signal settings_requested
signal home_requested

const OPEN_SECONDS := 0.22

@onready var _dim: ColorRect = %Dim
@onready var _sheet: Control = %Sheet
@onready var _caption: Label = %Caption
@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	hide()
	_resume_button.pressed.connect(resume_requested.emit)
	%RestartButton.pressed.connect(restart_requested.emit)
	%SettingsButton.pressed.connect(settings_requested.emit)
	%HomeButton.pressed.connect(home_requested.emit)
	_dim.gui_input.connect(_on_dim_input)


## [param title] is e.g. "Level 27" or "Daily · NOV 24".
func open(title: String, arrows_left: int) -> void:
	_caption.text = "%s · %d %s left" % [title, arrows_left, "arrow" if arrows_left == 1 else "arrows"]
	show()
	_dim.modulate.a = 0.0
	var sheet_top := _sheet.position.y
	_sheet.position.y = sheet_top + _sheet.size.y
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dim, "modulate:a", 1.0, OPEN_SECONDS)
	tween.tween_property(_sheet, "position:y", sheet_top, OPEN_SECONDS)


func close() -> void:
	hide()


func get_resume_button() -> Button:
	return _resume_button


## Tapping the dimmed game behind the sheet resumes, like most mobile sheets.
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		resume_requested.emit()
