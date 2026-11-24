extends TestSuite
## App entry point, screen navigation, overlays and level progression.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
## Completion panel appears after this delay (GameScreen.COMPLETE_DELAY_SECONDS).
const COMPLETE_WAIT := GameScreen.COMPLETE_DELAY_SECONDS + 0.15

var _paths: PackedStringArray = []


## Boots Main with throwaway save files so the player's data is untouched.
func _boot(name: String) -> Main:
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate() as Main
	_paths = PackedStringArray([temp_save_path(name), temp_save_path(name + "_settings"), temp_save_path(name + "_achievements"), temp_save_path(name + "_daily"), temp_save_path(name + "_weekly")])
	main.save_path = _paths[0]
	main.settings_path = _paths[1]
	main.achievements_path = _paths[2]
	main.daily_path = _paths[3]
	main.weekly_path = _paths[4]
	main.daily_date_override = "2026-11-24"
	tree.root.add_child(main)
	await wait_frames(1)
	return main


## Same files as the last _boot (simulates relaunching the app).
func _relaunch() -> Main:
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate() as Main
	main.save_path = _paths[0]
	main.settings_path = _paths[1]
	main.achievements_path = _paths[2]
	main.daily_path = _paths[3]
	main.weekly_path = _paths[4]
	main.daily_date_override = "2026-11-24"
	tree.root.add_child(main)
	await wait_frames(1)
	return main


func _open_game(main: Main) -> GameScreen:
	main.show_game()
	await wait_frames(1)
	return main.get_current_screen() as GameScreen


func _clear_level(game: GameScreen) -> bool:
	var cleared := tap_clear(game.get_board_view())
	await wait_seconds(COMPLETE_WAIT)
	return cleared


func _shutdown(main: Main, delete_files: bool = true) -> void:
	main.queue_free()
	await wait_frames(1)
	if delete_files:
		for path: String in _paths:
			remove_file(path)


func test_main_scene_is_configured() -> void:
	var configured: String = ProjectSettings.get_setting("application/run/main_scene", "")
	check_eq(configured, MAIN_SCENE_PATH, "run/main_scene")
	check(not ProjectSettings.get_setting("application/config/quit_on_go_back", true), "app handles Android back itself")


func test_splash_home_game_and_back_home() -> void:
	var main: Main = await _boot("flow_nav")
	var splash := main.get_current_screen() as SplashScreen
	check(splash != null, "starts on the splash")
	if splash != null:
		splash.skip()
		await wait_frames(1)
	var home := main.get_current_screen() as HomeScreen
	check(home != null, "splash hands over to Home")
	if home != null:
		check_eq(home.get_level_text(), "LEVEL 1  ·  VAULT IN 26", "Play shows the next level and countdown")
		home.get_play_button().pressed.emit()
		await wait_frames(1)
	var game := main.get_current_screen() as GameScreen
	check(game != null, "Play opens the game")
	if game != null:
		check_eq(game.get_level_number(), 1, "new player starts at level 1")
		check(game.get_board_view().get_board() != null, "level 1 board shown")
		game.get_pause_panel().home_requested.emit()
		await wait_frames(1)
		check(main.get_current_screen() is HomeScreen, "Home from the pause menu")
	await _shutdown(main)


func test_clearing_level_shows_complete_then_next() -> void:
	var main: Main = await _boot("flow_next")
	var game: GameScreen = await _open_game(main)
	check(not game.get_complete_panel().visible, "no completion panel while playing")
	check(await _clear_level(game), "level 1 cleared via taps")
	check_eq(game.get_state(), GameScreen.State.COMPLETE, "complete state")
	check(game.get_complete_panel().visible, "completion panel shown")
	check_eq(game.get_complete_panel().get_title_text(), "LEVEL 1 CLEARED", "title")
	check(game.get_complete_panel().is_clean_shown(), "no wrong taps badge for a clean solve")
	check_eq(main.get_progress().get_highest_completed_level(), 1, "completion recorded")
	check_eq(game.get_complete_panel().get_stars(), 3, "clean solve shows 3 stars")
	var seal := game.get_complete_panel().get_seal()
	check(not seal.is_unlocked() and seal.visible_link_count() == UnlockSeal.LINK_COUNT, "lock starts chained")
	await wait_seconds(UnlockSeal.duration() + 0.3)
	check(seal.is_unlocked() and seal.visible_link_count() == 0, "lock opened and the chain fell away")
	check_eq(main.get_progress().get_stars(1), 3, "3 stars saved for level 1")
	check_eq(game.get_complete_panel().get_upcoming_text(), "NEXT VAULT IN 26", "countdown to the first vault")
	game.get_complete_panel().get_next_button().pressed.emit()
	check_eq(game.get_level_number(), 2, "Next opens level 2")
	check(not game.get_complete_panel().visible, "panel closed")
	await _shutdown(main, false)

	var relaunched: Main = await _relaunch()
	var resumed: GameScreen = await _open_game(relaunched)
	check_eq(resumed.get_level_number(), 2, "progress persisted across launches")
	await _shutdown(relaunched)


func test_retry_for_three_stars() -> void:
	var main: Main = await _boot("flow_retry")
	var game: GameScreen = await _open_game(main)
	check(await _clear_level(game), "clean clear")
	check(not game.get_complete_panel().get_retry_button().visible, "no retry link with 3 stars")
	await _shutdown(main, false)
	var again: Main = await _relaunch()
	var replay: GameScreen = await _open_game(again)
	await _start_generated_level(replay, 10)
	check(_tap_wrong(replay), "one wrong move")
	check(await _clear_level(replay), "cleared with a wrong move")
	var panel := replay.get_complete_panel()
	check_eq(panel.get_stars(), 2, "2 stars")
	check(panel.get_retry_button().visible, "retry link offered")
	panel.get_retry_button().pressed.emit()
	await wait_frames(1)
	while replay.get_achievement_panel().visible:
		replay.get_achievement_panel().get_continue_button().pressed.emit()
		await wait_frames(1)
	check_eq(replay.get_level_number(), 10, "the same level starts again")
	check_eq(replay.get_state(), GameScreen.State.PLAYING, "ready to play")
	check(await _clear_level(replay), "cleared cleanly this time")
	check_eq(again.get_progress().get_stars(10), 3, "best stars now 3")
	await _shutdown(again)


func test_level_complete_home_button() -> void:
	var main: Main = await _boot("flow_complete_home")
	var game: GameScreen = await _open_game(main)
	check(await _clear_level(game), "level cleared")
	var home_button := game.get_complete_panel().get_node("%HomeButton") as Button
	check(home_button != null and home_button.visible, "Home button on Level complete")
	home_button.pressed.emit()
	await wait_frames(1)
	# Achievements (if any) show first; otherwise the game screen is already gone.
	while is_instance_valid(game) and game.get_achievement_panel().visible:
		game.get_achievement_panel().get_continue_button().pressed.emit()
		await wait_frames(1)
	check(main.get_current_screen() is HomeScreen, "Home button returns Home")
	await _shutdown(main)


func test_first_chain_shows_achievement_before_next_level() -> void:
	var main: Main = await _boot("flow_achievement")
	var game: GameScreen = await _open_game(main)
	game.play_level(4)
	check(await _clear_level(game), "level 4 (first dependency) cleared")
	check_eq(game.get_chains_broken(), 1, "one chain broken")
	game.get_complete_panel().get_next_button().pressed.emit()
	check_eq(game.get_state(), GameScreen.State.ACHIEVEMENT, "achievement shown first")
	check_eq(game.get_achievement_panel().get_title_text(), "FIRST KEY", "First Key unlocked")
	check_eq(game.get_level_number(), 4, "still on level 4 behind the panel")
	game.get_achievement_panel().get_continue_button().pressed.emit()
	check_eq(game.get_level_number(), 5, "continue goes to the next level")
	check(not game.get_achievement_panel().visible, "panel closed")
	check(main.get_achievements().is_unlocked("first_key"), "saved")
	await _shutdown(main)


func test_sounds_for_level_start_and_arrow_release() -> void:
	var main: Main = await _boot("flow_sounds")
	var game: GameScreen = await _open_game(main)
	check_eq(main.get_feedback().last_sound, Feedback.Sound.LEVEL_START, "level start sound when a level opens")
	var view := game.get_board_view()
	view.finish_intro()
	var board := view.get_board()
	for arrow: Arrow in board.get_arrows():
		if board.can_exit(arrow.id):
			view.tap_at(view.cell_to_local(arrow.cell))
			break
	check_eq(main.get_feedback().last_sound, Feedback.Sound.EXIT, "arrow release sound on exit")
	game.restart()
	check_eq(main.get_feedback().last_sound, Feedback.Sound.LEVEL_START, "restart plays the level start sound too")
	await _shutdown(main)


func test_quick_releases_show_praise() -> void:
	var main: Main = await _boot("flow_praise")
	var game: GameScreen = await _open_game(main)
	game.get_board_view().finish_intro()
	check(tap_clear(game.get_board_view()), "level 1's three arrows released in a quick run")
	check_eq(game.get_release_streak().get_count(), 3, "streak of three")
	check(game.get_praise_popup().visible, "praise shown")
	check_eq(game.get_praise_popup().text, "Nice!", "Nice! for three quick releases")
	check(game.get_praise_popup().get_font_size() <= PraisePopup.MAX_FONT_SIZE, "a small word, not a big banner")
	check_eq(main.get_feedback().last_sound, Feedback.Sound.PRAISE, "praise sparkle played")
	game.get_praise_popup().show_praise("UNSTOPPABLE!")
	await wait_frames(2)
	var popup := game.get_praise_popup()
	var word_width := popup.get_theme_font("font").get_string_size("UNSTOPPABLE!", HORIZONTAL_ALIGNMENT_LEFT, -1, popup.get_font_size()).x
	check(word_width <= game.get_viewport_rect().size.x, "long praise words shrink to fit (%d px)" % word_width)
	await _shutdown(main)


func test_wrong_tap_breaks_streak() -> void:
	var main: Main = await _boot("flow_streak_break")
	var game: GameScreen = await _open_game(main)
	var view := game.get_board_view()
	view.finish_intro()
	var board := view.get_board()
	for arrow: Arrow in board.get_arrows():
		if board.can_exit(arrow.id):
			view.tap_at(view.cell_to_local(arrow.cell))
			break
	check_eq(game.get_release_streak().get_count(), 1, "one release")
	for arrow: Arrow in board.get_arrows():
		if not board.can_exit(arrow.id):
			view.tap_at(view.cell_to_local(arrow.cell))
			break
	check_eq(game.get_release_streak().get_count(), 0, "wrong tap resets the streak")
	await _shutdown(main)


func test_twist_debut_popup_over_board() -> void:
	var main: Main = await _boot("flow_vault")
	var game: GameScreen = await _open_game(main)
	game.play_level(LevelSequence.FIRST_CHALLENGE_LEVEL)
	check_eq(game.get_state(), GameScreen.State.INTRO, "waiting for the twist pop-up")
	check(game.get_board_view().visible, "the board is shown first")
	check(not game.get_twist_popup().visible, "pop-up waits for the arrows to land")
	game.get_board_view().finish_intro()
	var popup := game.get_twist_popup()
	check(popup.visible, "pop-up rises over the board once the arrows land")
	check_eq(popup.get_overline_text(), "NEW TWIST", "new twist")
	check_eq(popup.get_title_text(), "DOUBLE LOCKS", "named")
	popup.get_got_it_button().pressed.emit()
	check_eq(game.get_state(), GameScreen.State.PLAYING, "GOT IT starts play")
	check(await _clear_level(game), "challenge cleared")
	check_eq(game.get_complete_panel().get_seal_text(), "VAULT SEAL", "vault seal")
	check_eq(main.get_achievements().get_stat(AchievementTracker.STAT_VAULT_CHALLENGES), 1, "challenge counted")
	# Practice level: same twist, but the player is never told again.
	game.play_level(LevelSequence.FIRST_CHALLENGE_LEVEL + 1)
	game.get_board_view().finish_intro()
	check_eq(game.get_state(), GameScreen.State.PLAYING, "no pop-up on practice levels")
	check(game.get_current_level().has_twist(LevelData.TWIST_DOUBLE_LOCKS), "practice uses the new twist")
	await wait_frames(2)
	var status_row := game.get_node("Margin/Layout/StatusRow") as Control
	check(status_row.get_global_rect().size.x <= game.get_viewport_rect().size.x, "status row fits the screen")
	await _shutdown(main)


func test_first_merge_level_popup() -> void:
	var main: Main = await _boot("flow_merge")
	var game: GameScreen = await _open_game(main)
	game.play_level(main.get_levels().first_merge_level())
	game.get_board_view().finish_intro()
	var popup := game.get_twist_popup()
	check(popup.visible, "pop-up on the first merge")
	check_eq(popup.get_overline_text(), "TWISTS COMBINED", "combined")
	check_eq(popup.get_entry_names(), PackedStringArray(["Double locks", "Walls"]), "both rules shown")
	main.handle_back()
	check_eq(game.get_state(), GameScreen.State.PLAYING, "back dismisses the pop-up")
	await _shutdown(main)


func test_master_level_release_completes() -> void:
	var main: Main = await _boot("flow_master")
	var game: GameScreen = await _open_game(main)
	game.play_level(50)
	check_eq(game.get_state(), GameScreen.State.INTRO, "first master level gets a pop-up")
	var view := game.get_board_view()
	view.finish_intro()
	check(game.get_twist_popup().get_entry_names().has("Master arrow"), "pop-up explains the master arrow")
	game.get_twist_popup().get_got_it_button().pressed.emit()
	var board := view.get_board()
	var master_id := board.get_master_id()
	while not board.can_exit(master_id):
		var progressed := false
		for arrow: Arrow in board.get_arrows():
			if arrow.id != master_id and board.can_exit(arrow.id):
				view.tap_at(view.cell_to_local(arrow.cell))
				progressed = true
				break
		check(progressed, "can work toward the master")
		if not progressed:
			break
	var remaining := board.arrow_count()
	check(remaining > 1, "arrows still on the board when the master is free (%d)" % remaining)
	view.tap_at(view.cell_to_local(board.get_arrow(master_id).cell))
	check(board.is_cleared(), "master release clears the board")
	check(game.was_master_released(), "release noted")
	await wait_seconds(COMPLETE_WAIT)
	check_eq(game.get_complete_panel().get_title_text(), "MASTER CLEAR", "master clear title")
	check_eq(game.get_complete_panel().get_seal_text(), "MASTER SEAL", "master seal")
	check(main.get_achievements().is_unlocked("master_escape"), "Master Escape unlocked")
	var panel := game.get_complete_panel()
	check(panel.get_global_rect().size.x <= game.get_viewport_rect().size.x + 1.0, "completion panel fits the screen with three chips")
	await _shutdown(main)


func test_home_rewards_card_and_achievements_screen() -> void:
	var main: Main = await _boot("flow_rewards")
	main.get_achievements().record_level_cleared(3, 0, true, false)
	main.get_progress().record_level_completed(27)
	main.show_home()
	await wait_frames(2)
	var home := main.get_current_screen() as HomeScreen
	check_eq(home.get_points_text(), "135 POINTS", "27 levels cleared = 135 points")
	check_eq(home.get_level_text(), "LEVEL 28  ·  VAULT IN %d" % (main.get_levels().challenge_level(1) - 28), "Play shows the countdown")
	main.get_progress().record_stars(1, 3)
	main.get_progress().record_stars(2, 2)
	main.show_home()
	await wait_frames(2)
	home = main.get_current_screen() as HomeScreen
	check_eq(home.get_stars_text(), "5", "total stars on Home")
	check_eq(home.get_rewards_text(), "2/%d" % AchievementTracker.DEFINITIONS.size(), "achievements unlocked (First Key, Chain Reaction)")
	check_eq(home.get_rank_text(), "KEYHOLDER", "135 points = Keyholder rank")
	check(home.is_breathing(), "hero art breathes gently")
	check(home.is_shining(), "Play button shine runs")
	# Measure at real phone proportions (the test window is square).
	var old_size := tree.root.size
	tree.root.size = Vector2i(720, 1280)
	await wait_frames(3)
	var top := (home.get_node("%SettingsButton") as Control).get_global_rect().position.y
	var bottom := home.get_view_all_button().get_global_rect().end.y
	check(top >= 24.0, "Home top on screen with margin (%d)" % top)
	check(bottom <= 1280.0 - 24.0, "Home fits a 16:9 phone (dock ends at %d)" % bottom)
	tree.root.size = old_size
	await wait_frames(2)
	home.get_view_all_button().pressed.emit()
	await wait_frames(1)
	var screen := main.get_current_screen() as AchievementsScreen
	check(screen != null, "View all opens the Achievements screen")
	if screen != null:
		check_eq(screen.get_row_count(), AchievementTracker.DEFINITIONS.size(), "every achievement listed")
		await wait_frames(2)
		var blocking := screen.get_list_controls().filter(func(c: Control) -> bool: return c.mouse_filter == Control.MOUSE_FILTER_STOP)
		check(blocking.is_empty(), "nothing in the list blocks drag-scrolling (%d blocking)" % blocking.size())
		check(screen.get_scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "no scrollbar, drag to scroll")
		main.handle_back()
		await wait_frames(1)
		check(main.get_current_screen() is HomeScreen, "back returns Home")
	await _shutdown(main)


func test_daily_challenge_flow() -> void:
	var main: Main = await _boot("flow_daily")
	(main.get_current_screen() as SplashScreen).skip()
	await wait_frames(1)
	var home := main.get_current_screen() as HomeScreen
	check_eq(home.get_daily_status(), "New puzzle", "Home shows a new daily puzzle")
	home.get_daily_button().pressed.emit()
	await wait_frames(1)
	var daily := main.get_current_screen() as DailyScreen
	check(daily != null, "Daily screen opens")
	check_eq(daily.get_streak_text(), "0-DAY STREAK", "no streak yet")
	await wait_frames(2)
	var layout := daily.get_node("Margin/Layout") as Control
	check(layout.get_combined_minimum_size().y <= daily.size.y - 80.0, "Daily screen fits a 16:9 phone (needs %d of %d px)" % [layout.get_combined_minimum_size().y, daily.size.y - 80.0])
	daily.get_play_button().pressed.emit()
	await wait_frames(1)
	var game := main.get_current_screen() as GameScreen
	check(game != null and game.is_daily(), "daily game")
	check_eq(game.get_current_level().layout, DailyChallenge.level_for("2026-11-24").layout, "today's board")
	check(await _clear_level(game), "daily solved")
	check_eq(game.get_complete_panel().get_title_text(), "DAILY SOLVED", "daily completion title")
	check_eq(game.get_complete_panel().get_seal_text(), "1-DAY STREAK", "streak chip")
	check(main.get_daily().is_solved("2026-11-24"), "result saved")
	check_eq(main.get_progress().get_highest_completed_level(), 0, "campaign progress untouched")
	game.get_complete_panel().get_next_button().pressed.emit()
	while game.get_state() == GameScreen.State.ACHIEVEMENT:
		game.get_achievement_panel().get_continue_button().pressed.emit()
	await wait_frames(1)
	daily = main.get_current_screen() as DailyScreen
	check(daily != null, "Done returns to the Daily screen")
	if daily != null:
		check_eq(daily.get_streak_text(), "1-DAY STREAK", "streak shown")
		check(daily.get_status_text().begins_with("Solved"), "solved status")
	main.show_home()
	await wait_frames(1)
	check_eq((main.get_current_screen() as HomeScreen).get_daily_status(), "Solved", "Home shows solved")
	await _shutdown(main)


func test_double_tap_continue_navigates_once() -> void:
	var main: Main = await _boot("flow_double_tap")
	var game: GameScreen = await _open_game(main)
	game.play_level(4)
	check(await _clear_level(game), "cleared")
	game.get_complete_panel().get_next_button().pressed.emit()
	check_eq(game.get_state(), GameScreen.State.ACHIEVEMENT, "achievement shown")
	game.get_achievement_panel().get_continue_button().pressed.emit()
	check_eq(game.get_level_number(), 5, "continued to level 5")
	game.get_achievement_panel().get_continue_button().pressed.emit()
	check_eq(game.get_level_number(), 5, "a second tap does not skip another level")
	check_eq(game.get_state(), GameScreen.State.PLAYING, "and does not disturb the new level")
	await _shutdown(main)


## Taps a blocked (path or lock) arrow; returns false if none exists.
func _tap_wrong(game: GameScreen) -> bool:
	var view := game.get_board_view()
	var board := view.get_board()
	for arrow: Arrow in board.get_arrows():
		if not board.can_exit(arrow.id) and not board.is_locked(arrow.id) and not view.is_marked_wrong(arrow.id):
			view.tap_at(view.cell_to_local(arrow.cell))
			return true
	return false


func _start_generated_level(game: GameScreen, level_number: int) -> void:
	game.play_level(level_number)
	game.get_board_view().finish_intro()
	if game.get_twist_popup().visible:
		game.get_twist_popup().get_got_it_button().pressed.emit()


func test_three_wrong_moves_end_the_attempt() -> void:
	var main: Main = await _boot("flow_moves")
	var game: GameScreen = await _open_game(main)
	await _start_generated_level(game, 10)
	check_eq(game.get_move_budget().remaining(), 3, "three wrong moves allowed")
	check(_tap_wrong(game) and _tap_wrong(game), "two wrong taps")
	check_eq(game.get_move_budget().remaining(), 1, "one left")
	check_eq(game.get_state(), GameScreen.State.PLAYING, "still playing")
	check(_tap_wrong(game), "third wrong tap")
	check_eq(game.get_state(), GameScreen.State.OUT_OF_MOVES, "attempt over")
	check(game.get_out_of_moves_panel().visible, "out of moves panel")
	check(game.get_out_of_moves_panel().get_watch_button().visible, "ad offered in development builds")
	var arrows := game.get_board_view().get_board().arrow_count()
	game.get_out_of_moves_panel().get_restart_button().pressed.emit()
	check_eq(game.get_state(), GameScreen.State.PLAYING, "restart plays again")
	check_eq(game.get_move_budget().remaining(), 3, "restart restores all moves")
	check(game.get_board_view().get_board().arrow_count() >= arrows, "board reset")
	await _shutdown(main)


func test_watching_ad_grants_one_move() -> void:
	var main: Main = await _boot("flow_ad")
	var game: GameScreen = await _open_game(main)
	await _start_generated_level(game, 10)
	for tap: int in 3:
		_tap_wrong(game)
	check_eq(game.get_state(), GameScreen.State.OUT_OF_MOVES, "out of moves")
	game.get_out_of_moves_panel().get_watch_button().pressed.emit()
	check(game.get_out_of_moves_panel().get_watch_button().disabled, "button waits while the ad plays")
	await wait_seconds(RewardedAds.DEBUG_AD_SECONDS + 0.2)
	check_eq(game.get_state(), GameScreen.State.PLAYING, "play resumes after the ad")
	check_eq(game.get_move_budget().remaining(), 1, "one extra move")
	check(not game.get_out_of_moves_panel().visible, "panel closed")
	_tap_wrong(game)
	check_eq(game.get_state(), GameScreen.State.OUT_OF_MOVES, "using it ends the attempt again")
	await _shutdown(main)


func test_no_move_limit_on_tutorial_and_daily() -> void:
	var main: Main = await _boot("flow_no_limit")
	var game: GameScreen = await _open_game(main)
	game.play_level(4)
	game.get_board_view().finish_intro()
	check(not game.get_move_budget().enabled, "tutorial level has no limit")
	for tap: int in 5:
		_tap_wrong(game)
	check_eq(game.get_state(), GameScreen.State.PLAYING, "still playing after five wrong taps")
	await _shutdown(main)
	main = await _boot("flow_no_limit_daily")
	main.show_daily_game()
	await wait_frames(1)
	game = main.get_current_screen() as GameScreen
	check(not game.get_move_budget().enabled, "Daily challenge has no limit")
	await _shutdown(main)


func test_hidden_links_lock_tap_is_free() -> void:
	var main: Main = await _boot("flow_hidden")
	var game: GameScreen = await _open_game(main)
	await _start_generated_level(game, main.get_levels().debut_level(3))
	check(game.get_current_level().has_twist(LevelData.TWIST_HIDDEN_LINKS), "hidden links level")
	var view := game.get_board_view()
	var board := view.get_board()
	for arrow: Arrow in board.get_arrows():
		if board.is_locked(arrow.id):
			view.tap_at(view.cell_to_local(arrow.cell))
			break
	check_eq(game.get_move_budget().remaining(), 3, "revealing a chain costs nothing")
	await _shutdown(main)


func test_wrong_tap_is_counted() -> void:
	var main: Main = await _boot("flow_wrong")
	var game: GameScreen = await _open_game(main)
	var view := game.get_board_view()
	view.finish_intro()
	var board := view.get_board()
	for arrow: Arrow in board.get_arrows():
		if not board.can_exit(arrow.id):
			view.tap_at(view.cell_to_local(arrow.cell))
			break
	check_eq(game.get_wrong_taps(), 1, "blocked tap counted")
	var stuck_id := -1
	for arrow: Arrow in board.get_arrows():
		if view.is_marked_wrong(arrow.id):
			stuck_id = arrow.id
	check(stuck_id != -1 and view.get_arrow_view(stuck_id).is_marked_wrong, "the tried arrow turns red")
	await wait_seconds(0.3)
	check(view.get_arrow_view(stuck_id).has_wrong_mark(), "and shows a cross mark, not just colour")
	view.tap_at(view.cell_to_local(board.get_arrow(stuck_id).cell))
	check_eq(game.get_wrong_taps(), 1, "tapping the red arrow again costs nothing")
	check(await _clear_level(game), "cleared anyway")
	check(not game.get_complete_panel().is_clean_shown(), "no clean badge after a wrong tap")
	await _shutdown(main)


func test_red_arrow_clears_once_it_can_leave() -> void:
	var main: Main = await _boot("flow_red")
	var game: GameScreen = await _open_game(main)
	await _start_generated_level(game, 10)
	var view := game.get_board_view()
	var board := view.get_board()
	check(_tap_wrong(game), "tap a blocked arrow")
	var red := -1
	for arrow: Arrow in board.get_arrows():
		if view.is_marked_wrong(arrow.id):
			red = arrow.id
	check(red != -1, "it is marked red")
	var guard := 0
	while board.get_arrow(red) != null and not board.can_exit(red) and guard < 200:
		guard += 1
		for arrow: Arrow in board.get_arrows():
			if arrow.id != red and board.can_exit(arrow.id) and not board.is_master(arrow.id):
				view.tap_at(view.cell_to_local(arrow.cell))
				break
	check(board.get_arrow(red) != null and board.can_exit(red), "the red arrow became free")
	check(not view.is_marked_wrong(red), "and is no longer red")
	await _shutdown(main)


func test_pause_blocks_board_and_back_button_flow() -> void:
	var main: Main = await _boot("flow_pause")
	var game: GameScreen = await _open_game(main)
	main.handle_back()
	check_eq(game.get_state(), GameScreen.State.PAUSED, "back pauses")
	check(game.get_pause_panel().visible, "pause sheet open")
	main.handle_back()
	check_eq(game.get_state(), GameScreen.State.PLAYING, "back again resumes")
	check(not game.get_pause_panel().visible, "sheet closed")
	game.pause()
	game.get_pause_panel().settings_requested.emit()
	check(main.is_settings_open(), "settings from pause")
	main.handle_back()
	check(not main.is_settings_open(), "back closes settings")
	check_eq(game.get_state(), GameScreen.State.PAUSED, "still paused under settings")
	game.get_pause_panel().get_resume_button().pressed.emit()
	check_eq(game.get_state(), GameScreen.State.PLAYING, "resume button")
	await _shutdown(main)


func test_arrow_theme_picker_unlocks_and_applies() -> void:
	var main: Main = await _boot("flow_theme")
	var game: GameScreen = await _open_game(main)
	main.open_settings()
	var panel := main.get_settings_panel()
	# Measure at real phone proportions (the test window is square).
	var old_size := tree.root.size
	tree.root.size = Vector2i(720, 1280)
	await wait_frames(3)
	var version := panel.get_node("%VersionLabel") as Control
	var back := panel.get_node("%BackButton") as Control
	var bottom := version.get_global_rect().end.y
	check(panel.get_global_rect().size.y <= 1280.5, "measured on a 720 x 1280 screen (%d)" % panel.get_global_rect().size.y)
	check(back.get_global_rect().position.y >= 32.0, "Settings top (Back) keeps its margin (%d)" % back.get_global_rect().position.y)
	check(bottom <= panel.get_global_rect().end.y + 0.5, "Settings fits a 16:9 phone (version line ends at %d of %d)" % [bottom, panel.get_global_rect().end.y])
	tree.root.size = old_size
	await wait_frames(2)
	panel.choose_theme("emerald")
	check_eq(main.get_settings().arrow_theme, "gold", "locked theme cannot be chosen")
	check(panel.get_theme_caption().contains("500"), "caption shows the points needed")
	main.handle_back()
	main.get_progress().record_level_completed(100)
	main.open_settings()
	panel.choose_theme("emerald")
	check_eq(main.get_settings().arrow_theme, "emerald", "unlocked at 500 points")
	check_eq(game.get_arrow_metal(), ArrowTheme.colors_of(ArrowTheme.find("emerald")), "open game recoloured right away")
	main.handle_back()
	main.get_progress().reset()
	check_eq(main.get_arrow_theme()["id"], "gold", "after a reset, back to Gold")
	await _shutdown(main)


func test_first_levels_guide_new_players() -> void:
	var main: Main = await _boot("flow_tutorial")
	var game: GameScreen = await _open_game(main)
	check_eq(game.get_tip_text(), "Tap an arrow to send it off the board.", "level 1 tip")
	await wait_seconds(GameScreen.HAND_DELAY_SECONDS + 1.6)
	var target := game.get_hand_target()
	var board := game.get_board_view().get_board()
	check(target != -1 and board.can_exit(target), "hand points at an arrow that can leave")
	var view := game.get_board_view()
	view.tap_at(view.cell_to_local(board.get_arrow(target).cell))
	check_eq(game.get_hand_target(), -1, "hand hides after the move")
	await wait_seconds(GameScreen.HAND_DELAY_SECONDS + 0.4)
	check(game.get_hand_target() != -1, "and points at the next arrow")
	var last_child := game.get_board_view().get_child(game.get_board_view().get_child_count() - 1)
	check(last_child is TutorialHand, "hand drawn above the arrows")
	check_eq((last_child as TutorialHand).z_index, 0, "but below overlays like Pause")
	await _shutdown(main)


func test_hand_prefers_the_key_arrow() -> void:
	var levels := LevelSequence.new(load("res://levels/level_catalog.tres"))
	var board := levels.get_level(4).build_board(PackedStringArray())
	var id := GameScreen.hint_arrow(board)
	var holds_key := false
	for other: Arrow in board.get_arrows():
		if board.get_pending_requirements(other.id).has(board.get_arrow(id)):
			holds_key = true
	check(board.can_exit(id) and holds_key, "level 4 hand points at the key arrow")
	check_eq(levels.get_level(6).tip, "", "later tutorial levels have no tip")
	check_eq(levels.get_level(6).guided_moves, 0, "and no hand")


func test_music_plays_and_can_be_turned_off() -> void:
	var main: Main = await _boot("flow_music")
	main.show_home()
	await wait_frames(1)
	check(main.get_music().is_enabled() and main.get_music().is_playing(), "music on by default, from Home")
	main.open_settings()
	main.get_settings_panel().get_toggle("music_enabled").button_pressed = false
	check(not main.get_settings().music_enabled, "setting saved")
	await wait_seconds(Music.FADE_OUT_SECONDS + 0.3)
	check(not main.get_music().is_playing(), "music fades out and stops")
	var stream := load(Music.TRACK_PATH) as AudioStreamWAV
	check(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the track loops")
	await _shutdown(main)


func test_weekly_challenge_flow() -> void:
	var main: Main = await _boot("flow_weekly")
	main.show_home()
	await wait_frames(1)
	var home := main.get_current_screen() as HomeScreen
	check_eq(home.get_weekly_text(), "0/5", "Home shows the weekly progress")
	home.get_weekly_button().pressed.emit()
	await wait_frames(1)
	var screen := main.get_current_screen() as WeeklyScreen
	check(screen != null, "Weekly screen opens")
	screen.get_puzzle_button(0).pressed.emit()
	await wait_frames(1)
	var game := main.get_current_screen() as GameScreen
	check(game != null and game.get_challenge() is WeeklyMode, "weekly puzzle 1 starts")
	check(not game.get_move_budget().enabled, "no move limit, like the Daily")
	game.get_board_view().finish_intro()
	check(await _clear_level(game), "puzzle solved")
	check_eq(game.get_complete_panel().get_title_text(), "PUZZLE 1 SOLVED", "result title")
	check(main.get_weekly().is_solved(WeeklyChallenge.week_key(main.get_today()), 0), "result saved")
	game.get_complete_panel().get_next_button().pressed.emit()
	await wait_frames(1)
	while is_instance_valid(game) and game.get_achievement_panel().visible:
		game.get_achievement_panel().get_continue_button().pressed.emit()
		await wait_frames(1)
	check(main.get_current_screen() is WeeklyScreen, "Done returns to the Weekly screen")
	main.show_home()
	await wait_frames(1)
	check_eq((main.get_current_screen() as HomeScreen).get_weekly_text(), "1/5", "Home updates to 1/5")
	await _shutdown(main)


func test_settings_save_and_apply() -> void:
	var main: Main = await _boot("flow_settings")
	main.open_settings()
	var panel := main.get_settings_panel()
	panel.get_toggle("sound_enabled").button_pressed = false
	panel.get_toggle("reduced_motion").button_pressed = true
	check(not main.get_settings().sound_enabled and main.get_settings().reduced_motion, "store updated")
	var reloaded := SettingsStore.new(_paths[1])
	reloaded.load_settings()
	check(not reloaded.sound_enabled and reloaded.reduced_motion, "saved immediately")
	panel.close()
	var game: GameScreen = await _open_game(main)
	check(not game.get_board_view().is_intro_playing(), "reduced motion skips the level-start fly-in")
	await _shutdown(main)


func test_reset_progress_needs_confirmation() -> void:
	var main: Main = await _boot("flow_reset")
	main.get_progress().record_level_completed(7)
	main.get_achievements().record_level_cleared(3, 0)
	main.open_settings()
	main.get_settings_panel().reset_confirmed.emit()
	await wait_frames(1)
	check_eq(main.get_progress().get_next_level_number(), 1, "progress reset")
	check_eq(main.get_achievements().unlocked_count(), 0, "achievements reset")
	check(main.get_current_screen() is HomeScreen, "back on Home")
	check((main.get_current_screen() as HomeScreen).get_level_text().begins_with("LEVEL 1  "), "Home shows level 1")
	await _shutdown(main)


func test_play_continues_past_handmade_levels() -> void:
	var main: Main = await _boot("flow_endless")
	var last_handmade := main.get_levels().handmade_count()
	var game: GameScreen = await _open_game(main)
	game.play_level(last_handmade)
	check(await _clear_level(game), "last hand-made level cleared")
	for step: int in 3:
		_continue_past_overlays(game)
		var expected_level := last_handmade + 1 + step
		check_eq(game.get_level_number(), expected_level, "Next opens level %d" % expected_level)
		check(game.get_board_view().get_board() != null, "generated level %d shown" % expected_level)
		check(await _clear_level(game), "generated level %d cleared via taps" % expected_level)
	check_eq(main.get_progress().get_highest_completed_level(), last_handmade + 3, "generated completions recorded")
	await _shutdown(main)


func test_restart_replays_same_generated_level() -> void:
	var main: Main = await _boot("flow_restart")
	var game: GameScreen = await _open_game(main)
	var level_number := main.get_levels().handmade_count() + 5
	game.play_level(level_number)
	var view := game.get_board_view()
	view.finish_intro()
	var arrows_before := view.get_board().arrow_count()
	for arrow: Arrow in view.get_board().get_arrows():
		if view.get_board().can_exit(arrow.id):
			view.tap_at(view.cell_to_local(arrow.cell))
			break
	check_eq(view.get_board().arrow_count(), arrows_before - 1, "one arrow removed")
	game.restart()
	check_eq(game.get_level_number(), level_number, "same level after restart")
	check_eq(view.get_board().arrow_count(), arrows_before, "board fully restored")
	await _shutdown(main)


func test_missing_level_shows_error_state() -> void:
	var main: Main = await _boot("flow_missing")
	var game: GameScreen = await _open_game(main)
	game.play_level(0)
	check(game.get_board_view().get_board() == null, "no board shown")
	check_eq(game.get_status_text(), "Level 0 is not available.", "error message")
	check_eq(game.get_state(), GameScreen.State.ERROR, "error state")
	await _shutdown(main)


## Presses Next, then Continue on any achievement panels, until play resumes.
func _continue_past_overlays(game: GameScreen) -> void:
	game.get_complete_panel().get_next_button().pressed.emit()
	while game.get_state() == GameScreen.State.ACHIEVEMENT:
		game.get_achievement_panel().get_continue_button().pressed.emit()
