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
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	for frame: int in BOOT_FRAMES:
		await process_frame
	main.queue_free()
	await create_timer(SHUTDOWN_SECONDS).timeout
	quit()
