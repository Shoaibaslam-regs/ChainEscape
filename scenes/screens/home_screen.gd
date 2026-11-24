class_name HomeScreen
extends Control
## The lobby: rank and stars at the top, the hero on a living backdrop
## (slow light rays, drifting gold dust), a big Play button with a shine,
## Daily and Weekly cards, and a dock for Achievements and Themes. Elements
## arrive in a short cascade. There is no level select; play only moves
## forward. Reduce motion makes it all still.

signal play_requested
signal settings_requested
signal daily_requested
signal rewards_requested
signal weekly_requested
signal themes_requested

## The hero art "breathes" very slowly: a calm sign of life, not a distraction.
const BREATH_SECONDS := 3.2
const BREATH_SCALE := 1.025
const CASCADE_STEP := 0.07
const CASCADE_SECONDS := 0.45
const TITLE_GLINT_EVERY := 7.0

@onready var _title: MetalLabel = %Title
@onready var _play_button: Button = %PlayButton
@onready var _level_label: Label = %LevelLabel
@onready var _logo: TextureRect = %Logo
@onready var _backdrop: HomeBackdrop = %Backdrop
@onready var _shine: ShineSweep = %Shine

var _breath: Tween
var _glint_timer: Timer
var _reduced_motion: bool = false


func _ready() -> void:
	_play_button.pressed.connect(play_requested.emit)
	%SettingsButton.pressed.connect(settings_requested.emit)
	%DailyButton.pressed.connect(daily_requested.emit)
	%WeeklyButton.pressed.connect(weekly_requested.emit)
	%AchievementsButton.pressed.connect(rewards_requested.emit)
	%RankButton.pressed.connect(rewards_requested.emit)
	%ThemesButton.pressed.connect(themes_requested.emit)
	_logo.resized.connect(_on_logo_moved)
	_logo.item_rect_changed.connect(_on_logo_moved)
	_glint_timer = Timer.new()
	_glint_timer.wait_time = TITLE_GLINT_EVERY
	_glint_timer.timeout.connect(func() -> void: _title.play_glint(0.8))
	add_child(_glint_timer)
	set_reduced_motion(false)


## Reduce motion: no backdrop drift, breathing, shine or cascade.
func set_reduced_motion(reduced: bool) -> void:
	_reduced_motion = reduced
	if _breath != null and _breath.is_valid():
		_breath.kill()
	_logo.scale = Vector2.ONE
	_logo.modulate = Color.WHITE
	_backdrop.animated = not reduced
	if reduced:
		_shine.stop()
		_glint_timer.stop()
		for node: CanvasItem in _cascade_nodes():
			node.modulate.a = 1.0
		return
	_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_logo, "scale", Vector2.ONE * BREATH_SCALE, BREATH_SECONDS)
	_breath.parallel().tween_property(_logo, "modulate", Color(1.06, 1.04, 1.0), BREATH_SECONDS)
	_breath.tween_property(_logo, "scale", Vector2.ONE, BREATH_SECONDS)
	_breath.parallel().tween_property(_logo, "modulate", Color.WHITE, BREATH_SECONDS)
	_glint_timer.start()
	_play_cascade()
	# The shine needs the button's final size.
	_shine.start.call_deferred()


func is_breathing() -> bool:
	return _breath != null and _breath.is_valid()


func is_shining() -> bool:
	return _shine.is_running()


## [param upcoming] is e.g. "VAULT IN 8" or "VAULT CHALLENGE" (optional).
func set_next_level(level_number: int, upcoming: String = "") -> void:
	_level_label.text = "LEVEL %d" % level_number
	if not upcoming.is_empty():
		_level_label.text += "  ·  " + upcoming


## Rank title, progress to the next one, and points.
func set_points(points: int) -> void:
	var rank := Rank.for_points(points)
	%RankName.text = String(rank["name"]).to_upper()
	%RankBar.value = Rank.progress(points) * 100.0
	%PointsLabel.text = "%d %s" % [points, "POINT" if points == 1 else "POINTS"]
	if rank["next_points"] >= 0:
		%RankButton.tooltip_text = "%d points to %s" % [int(rank["next_points"]) - points, rank["next_name"]]
	%ThemesValue.text = _next_theme_text(points)


func set_stars(stars: int) -> void:
	%StarsLabel.text = str(stars)


## [param status] e.g. "New puzzle", "Solved", "5-day streak";
## [param detail] a small second line.
func set_daily_status(status: String, detail: String = "") -> void:
	%DailyStatus.text = status
	if not detail.is_empty():
		%DailyDetail.text = detail


func set_weekly_progress(solved: int, total: int, days_left: int) -> void:
	%Ring.segments = total
	%Ring.filled = solved
	%RingLabel.text = "%d/%d" % [solved, total]
	%WeeklyStatus.text = "Week complete" if solved >= total else "%d of %d solved" % [solved, total]
	%WeeklyDetail.text = "Last day" if days_left == 1 else "%d days left" % days_left


## Achievements unlocked, shown in the dock.
func set_rewards(tracker: AchievementTracker) -> void:
	%AchievementsValue.text = "%d/%d" % [tracker.unlocked_count(), AchievementTracker.DEFINITIONS.size()]


func get_points_text() -> String:
	return %PointsLabel.text


func get_rank_text() -> String:
	return %RankName.text


func get_stars_text() -> String:
	return %StarsLabel.text


func get_rewards_text() -> String:
	return %AchievementsValue.text


func get_daily_status() -> String:
	return %DailyStatus.text


func get_weekly_text() -> String:
	return %RingLabel.text


func get_daily_button() -> Button:
	return %DailyButton


func get_weekly_button() -> Button:
	return %WeeklyButton


func get_view_all_button() -> Button:
	return %AchievementsButton


func get_themes_button() -> Button:
	return %ThemesButton


func get_play_button() -> Button:
	return _play_button


func get_level_text() -> String:
	return _level_label.text


## Android back on Home is not handled here, so Main exits the app.
func handle_back() -> bool:
	return false


func _next_theme_text(points: int) -> String:
	var next := ArrowTheme.next_locked(points)
	if next.is_empty():
		return "All unlocked"
	return "%s · %d/%d" % [next["name"], points, next["points"]]


func _cascade_nodes() -> Array[CanvasItem]:
	return [%TopBar, %Hero, _play_button, %ModeRow, %Dock]


## Each block fades in a beat after the one above it.
func _play_cascade() -> void:
	var nodes := _cascade_nodes()
	for index: int in nodes.size():
		var node := nodes[index]
		node.modulate.a = 0.0
		create_tween().tween_property(node, "modulate:a", 1.0, CASCADE_SECONDS) \
			.set_delay(0.05 + index * CASCADE_STEP).set_trans(Tween.TRANS_SINE)


func _on_logo_moved() -> void:
	_logo.pivot_offset = _logo.size * 0.5
	_backdrop.focus = _logo.get_global_rect().get_center() - _backdrop.get_global_rect().position
