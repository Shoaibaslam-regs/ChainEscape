extends TestSuite


func test_arrow_themes_unlock_by_points() -> void:
	check_eq(ArrowTheme.THEMES[0]["points"], 0, "Gold is free")
	check(ArrowTheme.is_unlocked("gold", 0), "Gold always unlocked")
	check(not ArrowTheme.is_unlocked("emerald", 245), "Emerald locked below 250")
	check(ArrowTheme.is_unlocked("emerald", 250), "Emerald at 250")
	check_eq(ArrowTheme.resolve("sapphire", 300)["id"], "gold", "locked choice falls back to Gold")
	check_eq(ArrowTheme.resolve("nonsense", 9999)["id"], "gold", "unknown id falls back to Gold")
	check_eq(ArrowTheme.next_locked(300)["id"], "sapphire", "next theme to earn")
	check(ArrowTheme.next_locked(999999).is_empty(), "all unlocked eventually")
	var last := 0
	for theme: Dictionary in ArrowTheme.THEMES:
		check(int(theme["points"]) >= last, "themes ordered by cost")
		last = theme["points"]


func test_arrow_theme_setting_saved() -> void:
	var path := temp_save_path("theme_settings")
	var settings := SettingsStore.new(path)
	check_eq(settings.arrow_theme, "gold", "default Gold")
	settings.arrow_theme = "emerald"
	settings.save_settings()
	var reloaded := SettingsStore.new(path)
	reloaded.load_settings()
	check_eq(reloaded.arrow_theme, "emerald", "theme restored")
	remove_file(path)
## SettingsStore, AchievementTracker, ProgressStore.reset and Feedback.


func test_settings_default_and_round_trip() -> void:
	var path := temp_save_path("settings")
	var store := SettingsStore.new(path)
	store.load_settings()
	check(store.sound_enabled and store.vibration_enabled and not store.reduced_motion, "defaults")
	store.sound_enabled = false
	store.reduced_motion = true
	check(store.save_settings(), "saved")
	var reloaded := SettingsStore.new(path)
	reloaded.load_settings()
	check(not reloaded.sound_enabled and reloaded.vibration_enabled and reloaded.reduced_motion, "values restored")
	remove_file(path)


func test_settings_ignore_wrong_types() -> void:
	var path := temp_save_path("settings_bad")
	var file := ConfigFile.new()
	file.set_value(SettingsStore.SECTION, "sound_enabled", "nope")
	file.save(path)
	var store := SettingsStore.new(path)
	store.load_settings()
	check(store.sound_enabled, "invalid value falls back to default")
	remove_file(path)


func test_first_chain_unlocks_first_key() -> void:
	var path := temp_save_path("ach_first")
	var tracker := AchievementTracker.new(path)
	var unlocked := tracker.record_level_cleared(0, 0)
	check(unlocked.is_empty(), "no chains: nothing unlocked")
	unlocked = tracker.record_level_cleared(1, 2)
	check_eq(unlocked.size(), 1, "one unlock")
	if unlocked.size() == 1:
		check_eq(unlocked[0]["id"], "first_key", "First Key")
	check(tracker.record_level_cleared(1, 0).is_empty(), "never unlocks twice")
	remove_file(path)


func test_clean_streak_and_chain_reaction() -> void:
	var path := temp_save_path("ach_clean")
	var tracker := AchievementTracker.new(path)
	for level: int in 9:
		tracker.record_level_cleared(0, 0)
	check_eq(tracker.get_stat(AchievementTracker.STAT_CLEAN_STREAK), 9, "streak counts clean levels")
	tracker.record_level_cleared(0, 1)
	check_eq(tracker.get_stat(AchievementTracker.STAT_CLEAN_STREAK), 0, "a wrong tap resets the streak")
	for level: int in 9:
		tracker.record_level_cleared(0, 0)
	var unlocked := tracker.record_level_cleared(3, 0)
	var ids := unlocked.map(func(d: Dictionary) -> String: return d["id"])
	check(ids.has("clean_hands"), "10 clean levels in a row")
	check(ids.has("chain_reaction"), "3 chains in a clean level")
	check(ids.has("first_key"), "first chains")
	check(not tracker.record_level_cleared(5, 1).map(func(d: Dictionary) -> String: return d["id"]).has("chain_reaction"), "already unlocked")
	remove_file(path)


func test_tiers_progress_and_persistence() -> void:
	var path := temp_save_path("ach_tiers")
	var tracker := AchievementTracker.new(path)
	tracker.record_level_cleared(100, 1)
	check(tracker.is_unlocked("locksmith"), "100 chains: Locksmith")
	var locksmith: Dictionary = AchievementTracker.DEFINITIONS.filter(func(d: Dictionary) -> bool: return d["id"] == "locksmith")[0]
	check_eq(tracker.next_tier(locksmith).get("id", ""), "master_locksmith", "next tier")
	check(is_equal_approx(tracker.get_progress(tracker.next_tier(locksmith)), 0.4), "100 of 250")
	var closest := tracker.closest_locked(3)
	check_eq(closest.size(), 3, "three suggestions")
	check(closest.all(func(d: Dictionary) -> bool: return not tracker.is_unlocked(d["id"])), "only locked ones")
	var reloaded := AchievementTracker.new(path)
	reloaded.load_achievements()
	check(reloaded.is_unlocked("locksmith") and reloaded.get_stat(AchievementTracker.STAT_CHAINS_BROKEN) == 100, "saved and restored")
	reloaded.reset()
	check(reloaded.unlocked_count() == 0 and reloaded.get_stat(AchievementTracker.STAT_CHAINS_BROKEN) == 0, "reset clears all")
	remove_file(path)


func test_progress_reset() -> void:
	var path := temp_save_path("progress_reset")
	var store := ProgressStore.new(path)
	store.record_level_completed(12)
	store.reset()
	var reloaded := ProgressStore.new(path)
	reloaded.load_progress()
	check_eq(reloaded.get_next_level_number(), 1, "back to level 1")
	remove_file(path)


func test_release_streak_window_and_reset() -> void:
	var streak := ReleaseStreak.new()
	check_eq(streak.register_release(10.0), 1, "first release")
	check_eq(streak.register_release(10.5), 2, "quick follow-up continues")
	check_eq(streak.register_release(10.5 + ReleaseStreak.WINDOW_SECONDS - 0.01), 3, "just inside the window still counts")
	check_eq(streak.register_release(10.5 + ReleaseStreak.WINDOW_SECONDS * 2.0 + 0.01), 1, "just outside the window starts over")
	check_eq(streak.register_release(20.0), 1, "slow release starts over")
	streak.register_release(20.2)
	streak.reset()
	check_eq(streak.register_release(20.3), 1, "reset starts over")


func test_release_streak_praise_and_pitch() -> void:
	check_eq(ReleaseStreak.praise_for(1), "", "no praise for one")
	check_eq(ReleaseStreak.praise_for(2), "", "no praise for two")
	check_eq(ReleaseStreak.praise_for(3), "NICE!", "3")
	check_eq(ReleaseStreak.praise_for(5), "SWEET!", "5")
	check_eq(ReleaseStreak.praise_for(8), "GREAT!", "8")
	check_eq(ReleaseStreak.praise_for(12), "AMAZING!", "12")
	check_eq(ReleaseStreak.praise_for(16), "UNSTOPPABLE!", "16")
	check_eq(ReleaseStreak.praise_for(17), "", "not every release")
	check_eq(ReleaseStreak.praise_for(20), "UNSTOPPABLE!", "repeats every 4 after 16")
	check(is_equal_approx(ReleaseStreak.pitch_for(1), 1.0), "streak 1 at base pitch")
	check(is_equal_approx(ReleaseStreak.pitch_for(4), pow(2.0, 7.0 / 12.0)), "climbs the pentatonic scale")
	check(ReleaseStreak.pitch_for(5) > ReleaseStreak.pitch_for(4), "keeps rising")
	check(is_equal_approx(ReleaseStreak.pitch_for(500), ReleaseStreak.pitch_for(ReleaseStreak.SCALE_STEPS.size())), "capped at the top note")


func test_feedback_respects_sound_setting() -> void:
	var feedback := Feedback.new()
	tree.root.add_child(feedback)
	await wait_frames(1)
	feedback.play(Feedback.Sound.EXIT)
	check_eq(feedback.last_sound, Feedback.Sound.EXIT, "plays when enabled")
	var settings := SettingsStore.new("user://unused.cfg")
	settings.sound_enabled = false
	feedback.apply_settings(settings)
	feedback.play(Feedback.Sound.BLOCKED)
	check_eq(feedback.last_sound, Feedback.Sound.EXIT, "silent when disabled")
	feedback.queue_free()
	await wait_frames(1)
