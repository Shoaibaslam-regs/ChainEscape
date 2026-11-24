extends TestSuite
## LevelData parsing/validation and the hand-made catalog.

const CATALOG_PATH := "res://levels/level_catalog.tres"


func _level(layout: String, dependencies: Array[Vector4i] = []) -> LevelData:
	var level := LevelData.new()
	level.layout = layout
	level.dependencies = dependencies
	return level


func test_layout_parses_cells_and_directions() -> void:
	var board := _level("^ . >\n< v .").build_board()
	check(board != null, "valid layout builds")
	if board == null:
		return
	check_eq(board.size, Vector2i(3, 2), "size from rows and columns")
	check_eq(board.arrow_count(), 4, "four arrows")
	check_eq(board.get_arrow_at(Vector2i(0, 0)).direction, Arrow.Direction.UP, "^")
	check_eq(board.get_arrow_at(Vector2i(2, 0)).direction, Arrow.Direction.RIGHT, ">")
	check_eq(board.get_arrow_at(Vector2i(0, 1)).direction, Arrow.Direction.LEFT, "<")
	check_eq(board.get_arrow_at(Vector2i(1, 1)).direction, Arrow.Direction.DOWN, "v")
	check(board.get_arrow_at(Vector2i(1, 0)) == null, ". is empty")


func test_spacing_and_blank_lines_are_ignored() -> void:
	var board := _level("\n  ^.>  \n\n\t< v .\n").build_board()
	check(board != null and board.size == Vector2i(3, 2), "same board despite whitespace")


func test_dependencies_use_cells() -> void:
	var board := _level("^ ^", [Vector4i(0, 0, 1, 0)]).build_board()
	check(board != null, "builds")
	if board != null:
		check(board.is_locked(board.get_arrow_at(Vector2i(0, 0)).id), "(0,0) waits for (1,0)")
		check(not board.is_locked(board.get_arrow_at(Vector2i(1, 0)).id), "(1,0) is free")


func test_invalid_levels_report_errors() -> void:
	var cases: Dictionary = {
		"empty layout": _level(""),
		"no arrows": _level(". .\n. ."),
		"ragged rows": _level("^ .\n^"),
		"unknown symbol": _level("^ x"),
		"dependency on empty cell": _level("^ .", [Vector4i(0, 0, 1, 0)]),
		"dependency outside board": _level("^ .", [Vector4i(0, 0, 5, 5)]),
		"self dependency": _level("^ .", [Vector4i(0, 0, 0, 0)]),
		"dependency cycle": _level("^ ^", [Vector4i(0, 0, 1, 0), Vector4i(1, 0, 0, 0)]),
	}
	for case_name: String in cases:
		var errors := PackedStringArray()
		var board: BoardState = (cases[case_name] as LevelData).build_board(errors)
		check(board == null, "%s: no board returned" % case_name)
		check(not errors.is_empty(), "%s: error reported" % case_name)


func test_catalog_levels_are_valid_and_solvable() -> void:
	var catalog: LevelCatalog = load(CATALOG_PATH)
	check(catalog != null and catalog.count() > 0, "catalog loads with levels")
	if catalog == null:
		return
	for index: int in catalog.count():
		var level := catalog.get_level(index)
		var label := "level %d" % (index + 1)
		check(level != null, "%s exists" % label)
		if level == null:
			continue
		check(not level.title.is_empty(), "%s has a title" % label)
		var errors := PackedStringArray()
		var board := level.build_board(errors)
		check(board != null, "%s builds: %s" % [label, errors])
		if board == null:
			continue
		var stuck_at_start := board.get_arrows().filter(func(a: Arrow) -> bool: return not board.can_exit(a.id))
		check(not stuck_at_start.is_empty(), "%s is not trivially solvable" % label)
		check(BoardSolver.is_solvable(board), "%s can be cleared" % label)


func test_catalog_introduces_dependencies_after_basics() -> void:
	var catalog: LevelCatalog = load(CATALOG_PATH)
	check(catalog.get_level(0).dependencies.is_empty(), "first level has no dependencies")
	var any_dependencies := false
	for level: LevelData in catalog.levels:
		any_dependencies = any_dependencies or not level.dependencies.is_empty()
	check(any_dependencies, "some level uses dependencies")


func test_symbol_for_round_trips_every_direction() -> void:
	for symbol: String in LevelData.SYMBOLS:
		check_eq(LevelData.symbol_for(LevelData.SYMBOLS[symbol]), symbol, "symbol %s" % symbol)


func test_walls_and_master_in_layout() -> void:
	var level := _level("^ # >\n. ^ .")
	level.master_cell = Vector2i(1, 1)
	var board := level.build_board()
	check(board != null, "builds")
	if board != null:
		check(board.is_wall(Vector2i(1, 0)), "# is a wall")
		check(board.is_master(board.get_arrow_at(Vector2i(1, 1)).id), "master cell")
	var broken := _level("^ .")
	broken.master_cell = Vector2i(1, 0)
	var errors := PackedStringArray()
	check(broken.build_board(errors) == null and not errors.is_empty(), "master on an empty cell is an error")
