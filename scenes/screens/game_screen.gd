class_name GameScreen
extends Control
## Gameplay: one level of the endless sequence, its counters, and the
## Pause / Level complete / Achievement overlays. Owns the play-state
## machine so overlapping actions (e.g. pausing during the completion) can't
## conflict.

signal home_requested
signal settings_requested
## A Daily or Weekly puzzle was solved and the player is done with it.
signal challenge_finished

enum State { INTRO, PLAYING, PAUSED, OUT_OF_MOVES, COMPLETE, ACHIEVEMENT, ERROR }

const KEY_FULL := preload("res://assets/icons/key_full.svg")
const KEY_SPENT := preload("res://assets/icons/key_spent.svg")

## Lets the last arrow finish leaving before the completion panel appears.
const COMPLETE_DELAY_SECONDS := 0.45
const BLOCKED_VIBRATION_MS := 25
const COMPLETE_VIBRATION_MS := 45

@onready var _board_view: BoardView = %BoardView
@onready var _overline: Label = %Overline
@onready var _level_title: Label = %LevelTitle
@onready var _arrows_label: Label = %ArrowsLabel
@onready var _locks_group: Control = %LocksGroup
@onready var _locks_divider: Control = %LocksDivider
@onready var _moves_divider: Control = %MovesDivider
@onready var _locks_label: Label = %LocksLabel
@onready var _message: Label = %Message
@onready var _pause_button: Button = %PauseButton
@onready var _restart_button: Button = %RestartButton
@onready var _pause_panel: PausePanel = %PausePanel
@onready var _complete_panel: CompletePanel = %CompletePanel
@onready var _tip_label: Label = %TipLabel

## Delay before the hand appears (after the fly-in, or after a move).
const HAND_DELAY_SECONDS := 0.7
var _hand := TutorialHand.new()
var _guided_left: int = 0
## Bumped when the hand is rescheduled, so stale timers do nothing.
var _hand_request: int = 0
@onready var _achievement_panel: AchievementPanel = %AchievementPanel
@onready var _praise_popup: PraisePopup = %PraisePopup
@onready var _twist_popup: TwistPopup = %TwistPopup
@onready var _out_of_moves_panel: OutOfMovesPanel = %OutOfMovesPanel
@onready var _pips: HBoxContainer = %Pips

var _levels: LevelSequence
var _progress: ProgressStore
var _achievements: AchievementTracker
var _feedback: Feedback
var _ads: RewardedAds
var _reduced_motion: bool = false
var _move_budget := WrongMoveBudget.new()

var _level_number: int = 0
var _state: State = State.PLAYING
var _wrong_taps: int = 0
var _chains_broken: int = 0
var _pending_unlocks: Array[Dictionary] = []
var _release_streak := ReleaseStreak.new()
var _current_level: LevelData
var _master_released: bool = false
## Set while playing a Daily or Weekly puzzle (null for numbered levels).
var _challenge: ChallengeMode
## What to do once all pending achievements have been shown.
var _after_achievements: Callable


func _ready() -> void:
	_pause_button.pressed.connect(pause)
	_restart_button.pressed.connect(restart)
	_board_view.arrow_exited.connect(_on_arrow_exited)
	_board_view.arrow_blocked.connect(_on_wrong_tap.unbind(2))
	_board_view.arrow_locked.connect(_on_locked_tap.unbind(2))
	_board_view.arrow_retapped.connect(_on_retap.unbind(1))
	_board_view.chain_broken.connect(_on_chain_broken.unbind(2))
	_board_view.board_cleared.connect(_on_board_cleared)
	_board_view.master_released.connect(func(_master: Arrow) -> void: _master_released = true)
	_twist_popup.dismissed.connect(_on_twist_popup_dismissed)
	_out_of_moves_panel.restart_requested.connect(restart)
	_out_of_moves_panel.home_requested.connect(home_requested.emit)
	_out_of_moves_panel.extra_move_requested.connect(_on_extra_move_requested)
	_board_view.intro_finished.connect(_on_board_intro_finished)
	_board_view.add_child(_hand)
	_board_view.resized.connect(func() -> void:
		if _hand.visible:
			_reposition_hand())
	_pause_panel.resume_requested.connect(resume)
	_pause_panel.restart_requested.connect(restart)
	_pause_panel.settings_requested.connect(settings_requested.emit)
	_pause_panel.home_requested.connect(home_requested.emit)
	_complete_panel.next_requested.connect(_on_complete_next)
	_complete_panel.home_requested.connect(_leave_complete.bind(home_requested.emit))
	_complete_panel.retry_requested.connect(_leave_complete.bind(restart))
	_achievement_panel.continue_requested.connect(_show_next_achievement_or_continue)


## [param achievements] and [param feedback] are optional so the screen can
## run on its own in tests.
func setup(levels: LevelSequence, progress: ProgressStore, achievements: AchievementTracker = null, feedback: Feedback = null, reduced_motion: bool = false, ads: RewardedAds = null) -> void:
	_ads = ads
	_levels = levels
	_progress = progress
	_achievements = achievements
	_feedback = feedback
	_reduced_motion = reduced_motion


## Loads and shows level [param level_number] (1-based). Shows an error
## message instead of the board if the level is missing or invalid.
func play_level(level_number: int) -> void:
	_challenge = null
	_level_number = level_number
	var level := _levels.get_level(level_number) if _levels != null else null
	_load(level, "LEVEL %d" % level_number, "Level %d is not available." % level_number)


## Plays the Daily challenge for [param date_key].
func play_daily(date_key: String, level: LevelData, store: DailyStore) -> void:
	play_challenge(DailyMode.new(date_key, store), level)


## Plays a Daily or Weekly puzzle: no move limit, its own texts and saving.
func play_challenge(mode: ChallengeMode, level: LevelData) -> void:
	_challenge = mode
	_load(level, mode.title(), mode.missing_message())


## True while playing a Daily or Weekly puzzle (not a numbered level).
func is_daily() -> bool:
	return _challenge != null


func get_challenge() -> ChallengeMode:
	return _challenge


func _load(level: LevelData, title: String, missing_message: String) -> void:
	_close_overlays()
	_wrong_taps = 0
	_chains_broken = 0
	_pending_unlocks.clear()
	_release_streak.reset()
	_master_released = false
	_level_title.text = title
	_hand.hide_hand()
	_hand_request += 1
	_guided_left = 0
	_tip_label.hide()
	if level == null:
		_show_error(missing_message)
		return
	var errors := PackedStringArray()
	var board := level.build_board(errors)
	if board == null:
		for message: String in errors:
			push_error(message)
		_show_error("This level could not be loaded.")
		return
	_current_level = level
	_message.hide()
	# Prepare the next level while this one is played.
	if not is_daily() and _levels != null:
		_levels.prefetch(_level_number + 1)
	_overline.text = _overline_for(level)
	_restart_button.disabled = false
	_pause_button.disabled = false
	_board_view.hide_links = level.has_twist(LevelData.TWIST_HIDDEN_LINKS)
	_board_view.set_board(board)
	# New arrow views were just added; keep the hand drawn above them.
	_board_view.move_child(_hand, -1)
	var has_locks := _count_locked(board) > 0
	_locks_group.visible = has_locks
	_locks_divider.visible = has_locks
	_update_counters()
	_show_tip(level.tip if not is_daily() else "")
	_guided_left = level.guided_moves if not is_daily() else 0
	# Tutorial levels and the Daily challenge have no wrong-move limit.
	_move_budget.reset(not is_daily() and _levels != null and _levels.is_generated(_level_number))
	_update_moves()
	# The board always comes first; a twist pop-up (if any) rises over it once
	# the arrows have landed. Play starts when it is dismissed.
	_state = State.INTRO if TwistPopup.is_needed(level) and not is_daily() else State.PLAYING
	_play_sound(Feedback.Sound.LEVEL_START)
	if not _reduced_motion:
		_board_view.play_intro()
	else:
		if _state == State.INTRO:
			_twist_popup.open(level)
		_schedule_hand()


func _on_board_intro_finished() -> void:
	if _state == State.INTRO and not _twist_popup.visible:
		_twist_popup.open(_current_level)
	_schedule_hand()


func _show_tip(tip: String) -> void:
	_tip_label.text = tip
	_tip_label.visible = not tip.is_empty()
	if _tip_label.visible and not _reduced_motion:
		_tip_label.modulate.a = 0.0
		create_tween().tween_property(_tip_label, "modulate:a", 1.0, 0.5).set_delay(0.4)
	else:
		_tip_label.modulate.a = 1.0


## The arrow a beginner should tap now: one that can leave, preferring one
## that holds a key for a locked arrow. -1 if none.
static func hint_arrow(board: BoardState) -> int:
	var fallback := -1
	for arrow: Arrow in board.get_arrows():
		if not board.can_exit(arrow.id):
			continue
		if fallback == -1:
			fallback = arrow.id
		for other: Arrow in board.get_arrows():
			if other.id != arrow.id and board.get_pending_requirements(other.id).has(arrow):
				return arrow.id
	return fallback


## Shows the hand after a short pause, if this level still guides moves.
func _schedule_hand() -> void:
	_hand.hide_hand()
	_hand_request += 1
	if _guided_left <= 0:
		return
	var request := _hand_request
	await get_tree().create_timer(HAND_DELAY_SECONDS).timeout
	if not is_inside_tree() or request != _hand_request or _state != State.PLAYING:
		return
	_reposition_hand()


func _reposition_hand() -> void:
	if _guided_left <= 0 or _board_view.get_board() == null or _board_view.get_cell_size() <= 0.0:
		return
	var board := _board_view.get_board()
	var id := hint_arrow(board)
	if id == -1:
		_hand.hide_hand()
		return
	_hand.point_at(_board_view.cell_to_local(board.get_arrow(id).cell), _board_view.get_cell_size(), id, not _reduced_motion)


## The arrow the hand points at, or -1 when it is hidden.
func get_hand_target() -> int:
	return _hand.get_target_id()


func get_tip_text() -> String:
	return _tip_label.text if _tip_label.visible else ""


func _on_twist_popup_dismissed() -> void:
	if _state == State.INTRO:
		_state = State.PLAYING
		_schedule_hand()
		_play_sound(Feedback.Sound.BUTTON)


func _overline_for(level: LevelData) -> String:
	if is_daily():
		return _challenge.overline()
	if level.master_cell != LevelData.NO_CELL:
		return "MASTER LEVEL"
	if level.is_challenge:
		return "VAULT CHALLENGE"
	return level.title.to_upper()


func restart() -> void:
	if is_daily():
		play_challenge(_challenge, _current_level)
	else:
		play_level(_level_number)


func play_next_level() -> void:
	play_level(_level_number + 1)


func pause() -> void:
	if _state != State.PLAYING:
		return
	_state = State.PAUSED
	_release_streak.reset()
	_board_view.finish_intro()
	_play_sound(Feedback.Sound.BUTTON)
	var title := _challenge.pause_title() if is_daily() else "Level %d" % _level_number
	_pause_panel.open(title, _board_view.get_board().arrow_count())


func resume() -> void:
	if _state != State.PAUSED:
		return
	_state = State.PLAYING
	_pause_panel.close()


## Android back button. Returns true when handled here.
func handle_back() -> bool:
	match _state:
		State.OUT_OF_MOVES:
			restart()
		State.INTRO:
			_board_view.finish_intro()
			if _twist_popup.visible:
				_twist_popup.close()
				_on_twist_popup_dismissed()
		State.PLAYING:
			pause()
		State.PAUSED:
			resume()
		_:
			home_requested.emit()
	return true


func get_state() -> State:
	return _state


func get_level_number() -> int:
	return _level_number


func get_board_view() -> BoardView:
	return _board_view


func set_arrow_theme(theme: Dictionary) -> void:
	_board_view.arrow_metal = ArrowTheme.colors_of(theme)


func get_arrow_metal() -> PackedColorArray:
	return _board_view.arrow_metal


func get_complete_panel() -> CompletePanel:
	return _complete_panel


func get_achievement_panel() -> AchievementPanel:
	return _achievement_panel


func get_pause_panel() -> PausePanel:
	return _pause_panel


func get_twist_popup() -> TwistPopup:
	return _twist_popup


func get_current_level() -> LevelData:
	return _current_level


func was_master_released() -> bool:
	return _master_released


func get_wrong_taps() -> int:
	return _wrong_taps


func get_chains_broken() -> int:
	return _chains_broken


func get_praise_popup() -> PraisePopup:
	return _praise_popup


func get_release_streak() -> ReleaseStreak:
	return _release_streak


func get_status_text() -> String:
	return _message.text if _message.visible else _arrows_label.text


## Quick releases build a streak: each one plays the release note a step
## higher, and milestones show a praise word with a sparkle.
func _on_arrow_exited(arrow: Arrow) -> void:
	if _guided_left > 0:
		_guided_left -= 1
		_schedule_hand()
	var streak := _release_streak.register_release(Time.get_ticks_msec() / 1000.0)
	_play_sound(Feedback.Sound.EXIT, ReleaseStreak.pitch_for(streak))
	var praise := ReleaseStreak.praise_for(streak)
	if not praise.is_empty():
		_praise_popup.show_praise(praise, _praise_point(arrow))
		_play_sound(Feedback.Sound.PRAISE)
	_update_counters()


func _on_wrong_tap() -> void:
	_wrong_taps += 1
	_release_streak.reset()
	_play_sound(Feedback.Sound.BLOCKED)
	if _feedback != null:
		_feedback.vibrate(BLOCKED_VIBRATION_MS)
	if _state == State.PLAYING and _move_budget.use_one():
		_out_of_moves()
	_update_moves()


## On hidden-links levels, tapping a padlock is how its chain is revealed,
## so it doesn't cost a move there.
func _on_locked_tap() -> void:
	if _current_level != null and _current_level.has_twist(LevelData.TWIST_HIDDEN_LINKS):
		_play_sound(Feedback.Sound.BLOCKED)
		return
	_on_wrong_tap()


## Tapping a red arrow again only reminds: it is still stuck, no move spent.
func _on_retap() -> void:
	_release_streak.reset()
	_play_sound(Feedback.Sound.BLOCKED, 0.85)


## Where the released arrow stood, in this screen's coordinates.
func _praise_point(arrow: Arrow) -> Vector2:
	var on_board := _board_view.cell_to_local(arrow.cell)
	return get_global_transform().affine_inverse() * (_board_view.get_global_transform() * on_board)


func _out_of_moves() -> void:
	_state = State.OUT_OF_MOVES
	_release_streak.reset()
	_out_of_moves_panel.open(_move_budget.limit, _ads != null and _ads.is_available())


func _on_extra_move_requested() -> void:
	if _ads == null:
		_out_of_moves_panel.show_ad_unavailable()
		return
	_ads.finished.connect(_on_ad_finished, CONNECT_ONE_SHOT)
	_ads.show_ad()


func _on_ad_finished(rewarded: bool) -> void:
	if _state != State.OUT_OF_MOVES:
		return
	if not rewarded:
		_out_of_moves_panel.show_ad_unavailable()
		return
	_move_budget.grant_extra(1)
	_out_of_moves_panel.close()
	_state = State.PLAYING
	_update_moves()


## Gold keys for the wrong moves left; a key that was just used shrinks
## into a dim outline.
func _update_moves() -> void:
	_pips.visible = _move_budget.enabled
	_moves_divider.visible = _move_budget.enabled
	var remaining := _move_budget.remaining()
	for index: int in _pips.get_child_count():
		var key := _pips.get_child(index) as TextureRect
		var spent := index >= remaining
		if spent and key.texture == KEY_FULL:
			key.pivot_offset = key.size * 0.5
			var tween := key.create_tween()
			tween.tween_property(key, "scale", Vector2.ONE * 0.6, 0.12)
			tween.tween_callback(func() -> void: key.texture = KEY_SPENT)
			tween.tween_property(key, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not spent:
			key.texture = KEY_FULL
			key.scale = Vector2.ONE


func get_move_budget() -> WrongMoveBudget:
	return _move_budget


func get_out_of_moves_panel() -> OutOfMovesPanel:
	return _out_of_moves_panel


func _on_chain_broken() -> void:
	_chains_broken += 1
	_play_sound(Feedback.Sound.CHAIN_BREAK)
	_update_counters()


func _on_board_cleared() -> void:
	_state = State.COMPLETE
	if is_daily():
		_challenge.record_solve(_wrong_taps)
	elif _progress != null:
		_progress.record_level_completed(_level_number)
		_progress.record_stars(_level_number, ProgressStore.stars_for(_wrong_taps))
	var was_challenge := _current_level != null and _current_level.is_challenge and not is_daily()
	if _achievements != null:
		_pending_unlocks = _achievements.record_level_cleared(_chains_broken, _wrong_taps, was_challenge, _master_released)
	_pause_button.disabled = true
	_restart_button.disabled = true
	var level_number := _level_number
	var challenge := _challenge
	await get_tree().create_timer(COMPLETE_DELAY_SECONDS).timeout
	# The player may have left or restarted during the delay.
	if not is_inside_tree() or _state != State.COMPLETE or _level_number != level_number or _challenge != challenge:
		return
	_play_sound(Feedback.Sound.LEVEL_COMPLETE)
	if _feedback != null:
		_feedback.vibrate(COMPLETE_VIBRATION_MS)
	if is_daily():
		_complete_panel.open_challenge(_challenge, _chains_broken, _wrong_taps)
	else:
		var upcoming := _levels.next_special_label(_level_number) if _levels != null else ""
		_complete_panel.open(_level_number, _chains_broken, _wrong_taps, was_challenge, _master_released, ProgressStore.stars_for(_wrong_taps), upcoming)


func _on_complete_next() -> void:
	_leave_complete(challenge_finished.emit if is_daily() else play_next_level)


## Leaving the completion panel shows any new achievements first, then
## runs [param action] (next level or replay).
func _leave_complete(action: Callable) -> void:
	_play_sound(Feedback.Sound.BUTTON)
	_complete_panel.close()
	_after_achievements = action
	_show_next_achievement_or_continue()


func _show_next_achievement_or_continue() -> void:
	# A stray tap after the follow-up already ran (e.g. a double tap) is ignored.
	if not _after_achievements.is_valid():
		return
	if _pending_unlocks.is_empty():
		_achievement_panel.close()
		_state = State.COMPLETE
		# Run the follow-up exactly once, so a double tap on Continue can't
		# navigate twice.
		var action := _after_achievements
		_after_achievements = Callable()
		if action.is_valid():
			action.call()
		return
	_state = State.ACHIEVEMENT
	var caption := "HOME"
	if _after_achievements == play_next_level:
		caption = "LEVEL %d" % (_level_number + 1)
	elif _after_achievements == restart:
		caption = "RETRY LEVEL %d" % _level_number
	if is_daily():
		caption = _challenge.done_label() if _after_achievements != home_requested.emit else "HOME"
	_achievement_panel.open(_pending_unlocks.pop_front(), _achievements, caption)
	_play_sound(Feedback.Sound.UNLOCK)


func _update_counters() -> void:
	var board := _board_view.get_board()
	_arrows_label.text = str(board.arrow_count() if board != null else 0)
	_locks_label.text = str(_count_locked(board) if board != null else 0)


func _count_locked(board: BoardState) -> int:
	var count := 0
	for arrow: Arrow in board.get_arrows():
		if board.is_locked(arrow.id):
			count += 1
	return count


func _close_overlays() -> void:
	_twist_popup.close()
	_out_of_moves_panel.close()
	_board_view.visible = true
	_pause_panel.close()
	_complete_panel.close()
	_achievement_panel.close()


func _show_error(message: String) -> void:
	_state = State.ERROR
	_board_view.set_board(null)
	_overline.text = ""
	_message.text = message
	_message.show()
	_locks_group.hide()
	_locks_divider.hide()
	_pips.hide()
	_moves_divider.hide()
	_arrows_label.text = ""
	_restart_button.disabled = true
	_pause_button.disabled = true


func _play_sound(sound: Feedback.Sound, pitch: float = 1.0) -> void:
	if _feedback != null:
		_feedback.play(sound, pitch)
