extends SceneTree
## Headless test runner. Exit code 0 when every test passes.
##   godot --headless --path . --script res://tests/run_tests.gd

const SUITE_PATHS: Array[String] = [
	"res://tests/test_board_state.gd",
	"res://tests/test_board_view.gd",
	"res://tests/test_levels.gd",
	"res://tests/test_level_generator.gd",
	"res://tests/test_progress.gd",
	"res://tests/test_settings_and_achievements.gd",
	"res://tests/test_daily.gd",
	"res://tests/test_splash_and_theme.gd",
	"res://tests/test_app_flow.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var test_count: int = 0
	for path: String in SUITE_PATHS:
		var script: GDScript = load(path)
		if script == null:
			failures.append("could not load suite %s" % path)
			continue
		var suite: TestSuite = script.new()
		suite.tree = self
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			suite.current_test = "%s::%s" % [path.get_file().get_basename(), method_name]
			await suite.call(method_name)
			test_count += 1
		failures.append_array(suite.failures)

	# Let the audio server release playbacks of sounds stopped by the last
	# test before quitting; otherwise they are reported as leaked at exit.
	await create_timer(0.25).timeout

	if failures.is_empty():
		print("ALL TESTS PASSED (%d tests)" % test_count)
		quit(0)
	else:
		for failure: String in failures:
			printerr("FAIL: ", failure)
		printerr("%d failure(s) in %d tests" % [failures.size(), test_count])
		quit(1)
