extends SceneTree
## Boot check: runs the real main scene for 30 frames (splash playing, with
## its sounds), then closes it the way the app really closes: the screens
## are removed first, the audio engine gets a moment to drop playing sounds,
## then the app quits. Any error or leaked resource fails tools/check.sh.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const BOOT_FRAMES := 30
const SHUTDOWN_SECONDS := 0.3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	# Never the player's real saves.
	var stores := ["save", "settings", "achievements", "daily", "weekly", "hints", "profile"]
	for store: String in stores:
		main.set("%s_path" % store, "user://boot_check_%s.cfg" % store)
	root.add_child(main)
	for frame: int in BOOT_FRAMES:
		await process_frame
	main.queue_free()
	await create_timer(SHUTDOWN_SECONDS).timeout
	for store: String in stores:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://boot_check_%s.cfg" % store))
	quit()
