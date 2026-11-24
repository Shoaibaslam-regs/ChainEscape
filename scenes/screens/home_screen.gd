class_name HomeScreen
extends Control
## The main menu: logo, title, and a Play button that continues at the
## player's next level. There is no level select; play only moves forward.

signal play_requested
signal settings_requested
signal daily_requested
signal rewards_requested

@onready var _title: MetalLabel = %Title
@onready var _play_button: Button = %PlayButton
@onready var _level_label: Label = %LevelLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _daily_button: Button = %DailyButton
@onready var _achievements_value: Label = %AchievementsValue
@onready var _vault_value: Label = %VaultValue
@onready var _master_value: Label = %MasterValue
@onready var _logo: TextureRect = %Logo

## The hero art "breathes" very slowly: a calm sign of life, not a distraction.
const BREATH_SECONDS := 3.2
const BREATH_SCALE := 1.025

var _breath: Tween



func _ready() -> void:
	_play_button.pressed.connect(play_requested.emit)
	_settings_button.pressed.connect(settings_requested.emit)
	_daily_button.pressed.connect(daily_requested.emit)
	%ViewAllButton.pressed.connect(rewards_requested.emit)
	%RewardsCard.gui_input.connect(_on_rewards_card_input)
	_title.play_glint(0.7, 0.25)
	_logo.resized.connect(func() -> void: _logo.pivot_offset = _logo.size * 0.5)
	set_reduced_motion(false)


## Reduce motion: the hero art stays still.
func set_reduced_motion(reduced: bool) -> void:
	if _breath != null and _breath.is_valid():
		_breath.kill()
	_logo.scale = Vector2.ONE
	_logo.modulate = Color.WHITE
	if reduced:
		return
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_logo, "scale", Vector2.ONE * BREATH_SCALE, BREATH_SECONDS)
	_breath.parallel().tween_property(_logo, "modulate", Color(1.06, 1.04, 1.0), BREATH_SECONDS)
	_breath.tween_property(_logo, "scale", Vector2.ONE, BREATH_SECONDS)
	_breath.parallel().tween_property(_logo, "modulate", Color.WHITE, BREATH_SECONDS)


func is_breathing() -> bool:
	return _breath != null and _breath.is_valid()


## [param upcoming] is e.g. "VAULT IN 8" or "VAULT CHALLENGE" (optional).
func set_next_level(level_number: int, upcoming: String = "") -> void:
	_level_label.text = "LEVEL %d" % level_number
	if not upcoming.is_empty():
		_level_label.text += "  ·  " + upcoming


func set_stars(stars: int) -> void:
	%StarsLabel.text = str(stars)


func get_stars_text() -> String:
	return %StarsLabel.text


func set_points(points: int) -> void:
	%PointsLabel.text = "%d %s" % [points, "POINT" if points == 1 else "POINTS"]


func get_points_text() -> String:
	return %PointsLabel.text


## e.g. "New puzzle", "Solved", "5-day streak".
func set_daily_status(status: String) -> void:
	_daily_button.text = "Daily challenge · %s" % status


## Fills the Rewards row: achievements unlocked and seals earned.
func set_rewards(tracker: AchievementTracker) -> void:
	_achievements_value.text = "%d/%d" % [tracker.unlocked_count(), AchievementTracker.DEFINITIONS.size()]
	_vault_value.text = str(tracker.get_stat(AchievementTracker.STAT_VAULT_CHALLENGES))
	_master_value.text = str(tracker.get_stat(AchievementTracker.STAT_MASTERS_RELEASED))


func get_rewards_text() -> String:
	return "%s|%s|%s" % [_achievements_value.text, _vault_value.text, _master_value.text]


func get_view_all_button() -> Button:
	return %ViewAllButton


func _on_rewards_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		rewards_requested.emit()


func get_daily_button() -> Button:
	return _daily_button


func get_play_button() -> Button:
	return _play_button


func get_level_text() -> String:
	return _level_label.text


## Android back on Home is not handled here, so Main exits the app.
func handle_back() -> bool:
	return false
