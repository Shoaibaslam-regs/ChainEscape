class_name SettingsPanel
extends Control
## Settings overlay, opened from Home or from Pause. Saves each change
## immediately. Resetting progress asks for confirmation first.

signal closed
signal settings_changed
signal reset_confirmed

var _settings: SettingsStore
var _points: int = 0
var _swatches: Array[ThemeSwatch] = []

@onready var _sound_toggle: CheckButton = %SoundToggle
@onready var _vibration_toggle: CheckButton = %VibrationToggle
@onready var _motion_toggle: CheckButton = %MotionToggle
@onready var _reset_button: Button = %ResetButton
@onready var _confirm_card: Control = %ConfirmCard
@onready var _version_label: Label = %VersionLabel
@onready var _theme_row: HBoxContainer = %ThemeRow
@onready var _theme_caption: Label = %ThemeCaption


func _ready() -> void:
	%BackButton.pressed.connect(close)
	_sound_toggle.toggled.connect(_on_toggle.bind("sound_enabled"))
	_vibration_toggle.toggled.connect(_on_toggle.bind("vibration_enabled"))
	_motion_toggle.toggled.connect(_on_toggle.bind("reduced_motion"))
	_reset_button.pressed.connect(func() -> void: _confirm_card.show())
	%CancelResetButton.pressed.connect(func() -> void: _confirm_card.hide())
	%ConfirmResetButton.pressed.connect(_on_reset_confirmed)
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	_version_label.text = "Chain Escape · version %s" % version
	for theme: Dictionary in ArrowTheme.THEMES:
		var swatch := ThemeSwatch.new()
		swatch.theme_id = theme["id"]
		swatch.colors = ArrowTheme.colors_of(theme)
		swatch.tooltip_text = theme["name"]
		swatch.pressed.connect(_on_theme_pressed.bind(theme["id"]))
		_theme_row.add_child(swatch)
		_swatches.append(swatch)


## [param points] decides which arrow themes are unlocked.
func open(settings: SettingsStore, points: int = 0) -> void:
	_settings = settings
	_points = points
	_refresh_themes()
	_sound_toggle.set_pressed_no_signal(settings.sound_enabled)
	_vibration_toggle.set_pressed_no_signal(settings.vibration_enabled)
	_motion_toggle.set_pressed_no_signal(settings.reduced_motion)
	_confirm_card.hide()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func close() -> void:
	hide()
	closed.emit()


func get_toggle(setting_name: String) -> CheckButton:
	match setting_name:
		"sound_enabled":
			return _sound_toggle
		"vibration_enabled":
			return _vibration_toggle
		"reduced_motion":
			return _motion_toggle
	return null


func get_theme_caption() -> String:
	return _theme_caption.text


## Taps a theme swatch (tests use this like a player's tap).
func choose_theme(id: String) -> void:
	_on_theme_pressed(id)


func _refresh_themes() -> void:
	var current := ArrowTheme.resolve(_settings.arrow_theme, _points)
	for swatch: ThemeSwatch in _swatches:
		swatch.is_locked = not ArrowTheme.is_unlocked(swatch.theme_id, _points)
		swatch.is_selected = swatch.theme_id == current["id"]
	_show_caption(current)


func _show_caption(theme: Dictionary) -> void:
	if ArrowTheme.is_unlocked(theme["id"], _points):
		_theme_caption.text = theme["name"]
	else:
		var needed: int = theme["points"]
		_theme_caption.text = "%s · unlocks at %d points (%d to go)" % [theme["name"], needed, needed - _points]


func _on_theme_pressed(id: String) -> void:
	if _settings == null:
		return
	if not ArrowTheme.is_unlocked(id, _points):
		_show_caption(ArrowTheme.find(id))
		return
	_settings.arrow_theme = id
	_settings.save_settings()
	_refresh_themes()
	settings_changed.emit()


func _on_toggle(pressed: bool, setting_name: String) -> void:
	if _settings == null:
		return
	_settings.set(setting_name, pressed)
	_settings.save_settings()
	settings_changed.emit()


func _on_reset_confirmed() -> void:
	_confirm_card.hide()
	reset_confirmed.emit()
