class_name TestSuite
extends RefCounted
## Base class for headless test suites. Methods named test_* are run by
## tests/run_tests.gd; they may be coroutines (use `await`).

var tree: SceneTree
var current_test: String = ""
var failures: PackedStringArray = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s (expected %s, got %s)" % [current_test, message, expected, actual])


func wait_frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame


func wait_seconds(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


## Taps every free arrow through a BoardView, as a player would, until the
## board is cleared or nothing can move. Returns whether it was cleared.
func tap_clear(view: BoardView) -> bool:
	var board := view.get_board()
	var progressed := true
	while progressed and not board.is_cleared():
		progressed = false
		for arrow: Arrow in board.get_arrows():
			if board.can_exit(arrow.id):
				view.tap_at(view.cell_to_local(arrow.cell))
				progressed = true
	return board.is_cleared()


## A save path under user:// that starts empty; delete with remove_file().
func temp_save_path(name: String) -> String:
	var path := "user://test_%s.cfg" % name
	remove_file(path)
	return path


func remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
