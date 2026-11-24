class_name Main
extends Control
## Application root. Lives for the whole session and hosts exactly one screen
## at a time inside ScreenContainer, plus the Settings overlay. Owns
## navigation, the Android back button and the shared services (levels,
## progress, achievements, settings, feedback), which it hands to screens.

@export var splash_screen_scene: PackedScene
@export var home_screen_scene: PackedScene
@export var game_screen_scene: PackedScene
@export var settings_panel_scene: PackedScene
@export var daily_screen_scene: PackedScene
@export var achievements_screen_scene: PackedScene
@export var level_catalog: LevelCatalog
## Save locations, overridable so tests never touch the player's real data.
@export var save_path: String = ProgressStore.DEFAULT_PATH
@export var settings_path: String = SettingsStore.DEFAULT_PATH
@export var achievements_path: String = AchievementTracker.DEFAULT_PATH
@export var daily_path: String = DailyStore.DEFAULT_PATH
## Pins "today" for tests (e.g. "2026-11-24"); empty means the device date.
@export var daily_date_override: String = ""

## Fade-in for each new screen (the splash appears instantly so it continues
## seamlessly from the system boot image).
const SCREEN_FADE_SECONDS := 0.2

@onready var _screen_container: Control = %ScreenContainer
@onready var _overlay_container: Control = %OverlayContainer

var _current_screen: Node = null
var _settings_panel: SettingsPanel
var _progress: ProgressStore
var _levels: LevelSequence
var _settings: SettingsStore
var _achievements: AchievementTracker
var _feedback: Feedback
var _daily: DailyStore
var _ads: RewardedAds


func _ready() -> void:
	theme = GameTheme.get_theme()
	_progress = ProgressStore.new(save_path)
	_progress.load_progress()
	_settings = SettingsStore.new(settings_path)
	_settings.load_settings()
	_achievements = AchievementTracker.new(achievements_path)
	_achievements.load_achievements()
	_daily = DailyStore.new(daily_path)
	_daily.load_results()
	_feedback = Feedback.new()
	add_child(_feedback)
	_ads = RewardedAds.new()
	add_child(_ads)
	_feedback.apply_settings(_settings)
	if level_catalog == null:
		push_error("Main: level_catalog is not assigned.")
		level_catalog = LevelCatalog.new()
	_levels = LevelSequence.new(level_catalog)
	if splash_screen_scene != null:
		show_splash()
	else:
		show_home()


## The animated intro; continues to Home when it ends or is skipped.
func show_splash() -> void:
	var screen := _show_screen(splash_screen_scene, false) as SplashScreen
	if screen != null:
		screen.finished.connect(show_home, CONNECT_ONE_SHOT)
		screen.play(_settings.reduced_motion, _feedback)


func show_home() -> void:
	var screen := _show_screen(home_screen_scene) as HomeScreen
	if screen == null:
		return
	var next_level := _progress.get_next_level_number()
	screen.set_next_level(next_level, _levels.upcoming_label(next_level))
	screen.set_stars(_progress.total_stars())
	screen.set_reduced_motion(_settings.reduced_motion)
	screen.set_points(_progress.get_points())
	screen.set_daily_status(_daily_status())
	screen.set_rewards(_achievements)
	screen.rewards_requested.connect(show_achievements)
	screen.play_requested.connect(show_game)
	screen.settings_requested.connect(open_settings)
	screen.daily_requested.connect(show_daily)


func show_achievements() -> void:
	var screen := _show_screen(achievements_screen_scene) as AchievementsScreen
	if screen == null:
		return
	screen.setup(_achievements)
	screen.back_requested.connect(show_home)


func show_daily() -> void:
	var screen := _show_screen(daily_screen_scene) as DailyScreen
	if screen == null:
		return
	var today := get_today()
	screen.setup(today, _daily, DailyChallenge.level_for(today))
	screen.back_requested.connect(show_home)
	screen.play_requested.connect(show_daily_game)


func show_daily_game() -> void:
	var screen := _show_screen(game_screen_scene) as GameScreen
	if screen == null:
		return
	screen.home_requested.connect(show_home)
	screen.settings_requested.connect(open_settings)
	screen.daily_finished.connect(show_daily)
	screen.setup(_levels, _progress, _achievements, _feedback, _settings.reduced_motion, _ads)
	screen.set_arrow_theme(get_arrow_theme())
	var today := get_today()
	screen.play_daily(today, DailyChallenge.level_for(today), _daily)


func get_today() -> String:
	return daily_date_override if not daily_date_override.is_empty() else DailyDate.today_key()


func get_daily() -> DailyStore:
	return _daily


func _daily_status() -> String:
	var today := get_today()
	if _daily.is_solved(today):
		return "Solved"
	var streak := _daily.current_streak(today)
	return "%d-day streak" % streak if streak > 0 else "New puzzle"


## Opens gameplay at the level after the highest one completed.
func show_game() -> void:
	var screen := _show_screen(game_screen_scene) as GameScreen
	if screen == null:
		return
	screen.home_requested.connect(show_home)
	screen.settings_requested.connect(open_settings)
	screen.setup(_levels, _progress, _achievements, _feedback, _settings.reduced_motion, _ads)
	screen.set_arrow_theme(get_arrow_theme())
	screen.play_level(_progress.get_next_level_number())


func open_settings() -> void:
	if _settings_panel == null:
		_settings_panel = settings_panel_scene.instantiate() as SettingsPanel
		_overlay_container.add_child(_settings_panel)
		_settings_panel.settings_changed.connect(_feedback.apply_settings.bind(_settings))
		_settings_panel.settings_changed.connect(_apply_arrow_theme)
		_settings_panel.reset_confirmed.connect(_on_reset_confirmed)
	_settings_panel.open(_settings, _progress.get_points())


## The chosen theme if unlocked, otherwise Gold.
func get_arrow_theme() -> Dictionary:
	return ArrowTheme.resolve(_settings.arrow_theme, _progress.get_points())


func _apply_arrow_theme() -> void:
	var game := _current_screen as GameScreen
	if game != null:
		game.set_arrow_theme(get_arrow_theme())


func is_settings_open() -> bool:
	return _settings_panel != null and _settings_panel.visible


## Android back: closes Settings, otherwise lets the current screen handle
## it; if nothing does (Home), the app exits.
func handle_back() -> void:
	if is_settings_open():
		_settings_panel.close()
		return
	if _current_screen != null and _current_screen.has_method("handle_back") and _current_screen.handle_back():
		return
	get_tree().quit()


func get_current_screen() -> Node:
	return _current_screen


func get_settings_panel() -> SettingsPanel:
	return _settings_panel


func get_progress() -> ProgressStore:
	return _progress


func get_levels() -> LevelSequence:
	return _levels


func get_achievements() -> AchievementTracker:
	return _achievements


func get_settings() -> SettingsStore:
	return _settings


func get_feedback() -> Feedback:
	return _feedback


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func _on_reset_confirmed() -> void:
	_progress.reset()
	_achievements.reset()
	_daily.reset()
	_settings_panel.close()
	show_home()


func _show_screen(screen_scene: PackedScene, fade_in: bool = true) -> Node:
	if screen_scene == null:
		push_error("Main: screen scene is not assigned.")
		return null
	if _current_screen != null:
		_current_screen.queue_free()
	_current_screen = screen_scene.instantiate()
	_screen_container.add_child(_current_screen)
	var canvas_item := _current_screen as CanvasItem
	if fade_in and canvas_item != null:
		canvas_item.modulate.a = 0.0
		canvas_item.create_tween().tween_property(canvas_item, "modulate:a", 1.0, SCREEN_FADE_SECONDS)
	return _current_screen
