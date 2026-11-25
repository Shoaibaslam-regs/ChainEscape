extends TestSuite
## Profile items (unlock rules) and the saved profile.


func test_names_are_cleaned() -> void:
	check_eq(ProfileStore.clean_name("  Ali   Raza "), "Ali Raza", "spaces tidied")
	check_eq(ProfileStore.clean_name("Escape<>Artist!"), "EscapeArtist", "symbols dropped")
	check_eq(ProfileStore.clean_name("a"), "", "too short")
	check_eq(ProfileStore.clean_name("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "ABCDEFGHIJKLMNOP", "at most 16 characters")
	check_eq(ProfileStore.clean_name("علی رضا"), "علی رضا", "Arabic-script names are kept")
	check_eq(ProfileStore.clean_name("Ali 😀"), "Ali", "emoji dropped (the font has none)")


func test_unlock_rules() -> void:
	var tracker := AchievementTracker.new(temp_save_path("profile_tracker"))
	tracker.load_achievements()
	var free := ProfileItems.find(ProfileItems.AVATARS, "arrow")
	var by_rank := ProfileItems.find(ProfileItems.FRAMES, "bronze")
	var by_achievement := ProfileItems.find(ProfileItems.AVATARS, "bolt")
	check(ProfileItems.is_unlocked(free, 0, tracker), "free items are open from the start")
	check(not ProfileItems.is_unlocked(by_rank, 99, tracker), "Bronze needs Keyholder (100 points)")
	check(ProfileItems.is_unlocked(by_rank, 100, tracker), "and opens at 100 points")
	check(not ProfileItems.is_unlocked(by_achievement, 0, tracker), "Bolt needs Chain Reaction")
	tracker.record_level_cleared(3, 0)
	check(ProfileItems.is_unlocked(by_achievement, 0, tracker), "Bolt opens with Chain Reaction")
	check_eq(ProfileItems.resolve(ProfileItems.FRAMES, "gold", 0, tracker)["id"], ProfileItems.DEFAULT_FRAME, "a locked pick shows the default")
	check_eq(ProfileItems.unlock_text(by_rank), "Reach Keyholder rank", "rank unlock text")
	remove_file("user://test_profile_tracker.cfg")


func test_every_item_has_art_and_a_real_unlock() -> void:
	for avatar: Dictionary in ProfileItems.AVATARS:
		check(ProfileItems.avatar_texture(avatar["id"]) != null, "avatar art for %s" % avatar["id"])
	for item: Dictionary in ProfileItems.AVATARS + ProfileItems.FRAMES:
		var unlock: Dictionary = item["unlock"]
		if unlock.has("rank"):
			check(ProfileItems.rank_points(unlock["rank"]) > 0, "%s: rank %s exists" % [item["id"], unlock["rank"]])
		if unlock.has("achievement"):
			check(ProfileItems.unlock_text(item) != "Free", "%s: achievement %s exists" % [item["id"], unlock["achievement"]])
	for frame: Dictionary in ProfileItems.FRAMES:
		check(AvatarBadge.FRAME_COLORS.has(frame["style"]), "frame style %s is drawn" % frame["style"])


func test_profile_saves_and_survives_bad_files() -> void:
	var path := temp_save_path("profile_store")
	var store := ProfileStore.new(path)
	store.load_profile()
	check_eq(store.player_name, ProfileStore.DEFAULT_NAME, "default name")
	check(store.set_player_name("Shoaib"), "a good name is accepted")
	store.set_avatar("gem")
	store.set_frame("chain")
	store.set_avatar("not_an_avatar")
	var again := ProfileStore.new(path)
	again.load_profile()
	check_eq([again.player_name, again.avatar_id, again.frame_id], ["Shoaib", "gem", "chain"], "everything saved")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[profile]\nname=42\navatar=\"nope\"\n")
	file.close()
	again.load_profile()
	check_eq([again.player_name, again.avatar_id], [ProfileStore.DEFAULT_NAME, ProfileItems.DEFAULT_AVATAR], "bad values fall back to defaults")
	remove_file(path)
