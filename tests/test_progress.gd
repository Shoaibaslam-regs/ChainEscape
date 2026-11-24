extends TestSuite
## ProgressStore: local save/load of progress, unlock rule and migration.


func test_missing_file_means_no_progress() -> void:
	var store := ProgressStore.new(temp_save_path("missing"))
	store.load_progress()
	check_eq(store.get_highest_completed_level(), 0, "nothing completed")
	check_eq(store.get_next_level_number(), 1, "play starts at level 1")


func test_levels_unlock_in_order() -> void:
	var path := temp_save_path("unlock")
	var store := ProgressStore.new(path)
	check(store.is_unlocked(1), "level 1 always unlocked")
	check(not store.is_unlocked(2), "level 2 locked initially")
	check(not store.is_unlocked(0) and not store.is_unlocked(-1), "numbers below 1 are never unlocked")
	store.record_level_completed(1)
	check(store.is_unlocked(2), "level 2 unlocked after level 1")
	check(not store.is_unlocked(3), "level 3 still locked")
	check_eq(store.get_next_level_number(), 2, "continue at level 2")
	remove_file(path)


func test_progress_survives_reload() -> void:
	var path := temp_save_path("roundtrip")
	var store := ProgressStore.new(path)
	store.record_level_completed(1)
	store.record_level_completed(2)
	check(FileAccess.file_exists(path), "saved to disk on completion")
	var reloaded := ProgressStore.new(path)
	reloaded.load_progress()
	check_eq(reloaded.get_highest_completed_level(), 2, "progress restored")
	remove_file(path)


func test_replaying_earlier_level_keeps_progress() -> void:
	var path := temp_save_path("replay")
	var store := ProgressStore.new(path)
	store.record_level_completed(1)
	store.record_level_completed(2)
	store.record_level_completed(3)
	store.record_level_completed(1)
	store.record_level_completed(0)
	check_eq(store.get_highest_completed_level(), 3, "highest level kept")
	remove_file(path)


func test_points_five_per_level_cleared_once() -> void:
	var path := temp_save_path("points")
	var store := ProgressStore.new(path)
	check_eq(store.get_points(), 0, "no points yet")
	store.record_level_completed(1)
	store.record_level_completed(2)
	check_eq(store.get_points(), 10, "5 points per level")
	store.record_level_completed(1)
	check_eq(store.get_points(), 10, "replays add nothing")
	store.reset()
	check_eq(store.get_points(), 0, "reset clears points")
	remove_file(path)


func test_stars_best_kept_and_saved() -> void:
	check_eq(ProgressStore.stars_for(0), 3, "no wrong moves: 3 stars")
	check_eq(ProgressStore.stars_for(1), 2, "one: 2 stars")
	check_eq(ProgressStore.stars_for(2), 1, "two: 1 star")
	check_eq(ProgressStore.stars_for(9), 1, "never fewer than one")
	var path := temp_save_path("stars")
	var store := ProgressStore.new(path)
	check(store.record_stars(5, 2), "first clear is a new best")
	check(not store.record_stars(5, 1), "a worse replay is not")
	check_eq(store.get_stars(5), 2, "best kept")
	check(store.record_stars(5, 3), "improving is a new best")
	store.record_stars(6, 1)
	check_eq(store.total_stars(), 4, "total stars")
	var reloaded := ProgressStore.new(path)
	reloaded.load_progress()
	check(reloaded.get_stars(5) == 3 and reloaded.total_stars() == 4, "saved and restored")
	reloaded.reset()
	check_eq(reloaded.total_stars(), 0, "reset clears stars")
	remove_file(path)


func test_handles_very_high_levels() -> void:
	var path := temp_save_path("high")
	var store := ProgressStore.new(path)
	store.record_level_completed(250000)
	var reloaded := ProgressStore.new(path)
	reloaded.load_progress()
	check_eq(reloaded.get_highest_completed_level(), 250000, "large level numbers stored exactly")
	remove_file(path)


func test_corrupt_file_starts_fresh() -> void:
	var path := temp_save_path("corrupt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("this is [not a valid config file")
	file.close()
	var store := ProgressStore.new(path)
	store.load_progress()
	check_eq(store.get_highest_completed_level(), 0, "corrupt save ignored")
	store.record_level_completed(1)
	var reloaded := ProgressStore.new(path)
	reloaded.load_progress()
	check_eq(reloaded.get_highest_completed_level(), 1, "new save replaces corrupt file")
	remove_file(path)


func test_invalid_progress_value_starts_fresh() -> void:
	var path := temp_save_path("invalid_value")
	for bad_value: Variant in [-3, "seven", 2.5]:
		var file := ConfigFile.new()
		file.set_value(ProgressStore.SECTION, ProgressStore.KEY_VERSION, ProgressStore.FORMAT_VERSION)
		file.set_value(ProgressStore.SECTION, ProgressStore.KEY_HIGHEST_COMPLETED, bad_value)
		file.save(path)
		var store := ProgressStore.new(path)
		store.load_progress()
		check_eq(store.get_highest_completed_level(), 0, "value %s rejected" % [bad_value])
	remove_file(path)


func test_save_includes_format_version() -> void:
	var path := temp_save_path("version")
	var store := ProgressStore.new(path)
	store.record_level_completed(1)
	var file := ConfigFile.new()
	check_eq(file.load(path), OK, "file is a valid ConfigFile")
	check_eq(file.get_value(ProgressStore.SECTION, ProgressStore.KEY_VERSION), ProgressStore.FORMAT_VERSION, "version stored")
	remove_file(path)


func test_version_1_save_is_migrated() -> void:
	var path := temp_save_path("migrate")
	_write_version_1_save(path, ["level_01", "level_02", "level_03", "level_04", "level_05", "level_06", "level_07", "level_08"])
	var store := ProgressStore.new(path)
	store.load_progress()
	check_eq(store.get_highest_completed_level(), 8, "all eight hand-made levels carried over")
	check_eq(store.get_next_level_number(), 9, "continues at the first generated level")
	var file := ConfigFile.new()
	file.load(path)
	check_eq(file.get_value(ProgressStore.SECTION, ProgressStore.KEY_VERSION), ProgressStore.FORMAT_VERSION, "file rewritten in the new format")
	check(not file.has_section_key(ProgressStore.SECTION, ProgressStore.LEGACY_KEY_COMPLETED_IDS), "old list removed")
	remove_file(path)


func test_version_1_migration_stops_at_first_gap() -> void:
	var path := temp_save_path("migrate_gap")
	_write_version_1_save(path, ["level_02", "level_01", "level_04", "bogus", "level_x"])
	var store := ProgressStore.new(path)
	store.load_progress()
	check_eq(store.get_highest_completed_level(), 2, "unbroken run from level 1, order-independent")
	remove_file(path)


func _write_version_1_save(path: String, completed_ids: Array[String]) -> void:
	var file := ConfigFile.new()
	file.set_value(ProgressStore.SECTION, ProgressStore.KEY_VERSION, 1)
	file.set_value(ProgressStore.SECTION, ProgressStore.LEGACY_KEY_COMPLETED_IDS, PackedStringArray(completed_ids))
	file.save(path)
