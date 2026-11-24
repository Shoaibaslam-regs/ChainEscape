class_name LevelData
extends Resource
## One level, hand-made or generated. The layout is a text grid so levels
## are easy to write and review:
##   ^ v < >  an arrow pointing up / down / left / right
##   #        a wall (blocks every path, never moves)
##   .        an empty cell
## Spaces between characters are ignored; each line is one row.

const SYMBOLS: Dictionary[String, Arrow.Direction] = {
	"^": Arrow.Direction.UP,
	"v": Arrow.Direction.DOWN,
	"<": Arrow.Direction.LEFT,
	">": Arrow.Direction.RIGHT,
}
const EMPTY_SYMBOL := "."
const WALL_SYMBOL := "#"
const NO_CELL := Vector2i(-1, -1)

## Challenge twists (Phase 2 design: Vault challenges).
const TWIST_DOUBLE_LOCKS := "double_locks"
const TWIST_WALLS := "walls"
const TWIST_LONG_CHAINS := "long_chains"
const TWIST_HIDDEN_LINKS := "hidden_links"
const TWIST_NAMES: Dictionary[String, String] = {
	TWIST_DOUBLE_LOCKS: "Double locks",
	TWIST_WALLS: "Walls",
	TWIST_LONG_CHAINS: "Long chains",
	TWIST_HIDDEN_LINKS: "Hidden links",
}
const TWIST_DESCRIPTIONS: Dictionary[String, String] = {
	TWIST_DOUBLE_LOCKS: "Some locks hang from two chains. Clear both keys to open them.",
	TWIST_WALLS: "Solid walls block every path, for good. Find the way around them.",
	TWIST_LONG_CHAINS: "Chains of four or more arrows that must open in order.",
	TWIST_HIDDEN_LINKS: "Chains stay hidden. Tap a lock to glimpse what it waits for.",
}

## Optional display name; generated levels leave it empty.
@export var title: String = ""
## First-time guidance: one short line shown above the board (optional).
@export var tip: String = ""
## How many moves the pointing hand guides on this level (0 = no hand).
@export var guided_moves: int = 0
@export_multiline var layout: String = ""
## Each entry is (x, y, z, w): the arrow at (x, y) waits for the arrow at (z, w).
@export var dependencies: Array[Vector4i] = []
## Cell of the master arrow (releasing it clears the level), or NO_CELL.
@export var master_cell: Vector2i = NO_CELL
## Vault challenge level (harder, with twists).
@export var is_challenge: bool = false
## Twists used by this level (TWIST_* names).
@export var twists: PackedStringArray = PackedStringArray()
## The twist this level introduces for the first time, or "".
@export var new_twist: String = ""
## The first level that merges two twists (shows the twist pop-up).
@export var is_first_merge: bool = false
## The first master-arrow level (shows the master pop-up).
@export var is_first_master: bool = false


func has_twist(twist: String) -> bool:
	return twists.has(twist)


static func symbol_for(direction: Arrow.Direction) -> String:
	return SYMBOLS.find_key(direction)


## Builds a fresh board, or returns null and appends readable messages to
## [param errors] if the level data is invalid.
func build_board(errors: PackedStringArray = PackedStringArray()) -> BoardState:
	var error_count_before := errors.size()
	var rows := _parse_rows(errors)
	if errors.size() > error_count_before:
		return null

	var board := BoardState.new(Vector2i(rows[0].length(), rows.size()))
	for y: int in rows.size():
		for x: int in rows[y].length():
			var symbol := rows[y][x]
			if SYMBOLS.has(symbol):
				board.add_arrow(Vector2i(x, y), SYMBOLS[symbol])
			elif symbol == WALL_SYMBOL:
				board.add_wall(Vector2i(x, y))

	for link: Vector4i in dependencies:
		var dependent_cell := Vector2i(link.x, link.y)
		var required_cell := Vector2i(link.z, link.w)
		var dependent := board.get_arrow_at(dependent_cell)
		var required := board.get_arrow_at(required_cell)
		if dependent == null or required == null:
			var empty_cell := dependent_cell if dependent == null else required_cell
			errors.append("%s: dependency %s refers to empty cell %s" % [_describe(), link, empty_cell])
		elif not board.add_dependency(dependent.id, required.id):
			errors.append("%s: dependency %s is a duplicate, self-link or cycle" % [_describe(), link])

	if master_cell != NO_CELL:
		var master := board.get_arrow_at(master_cell)
		if master == null:
			errors.append("%s: master arrow cell %s is empty" % [_describe(), master_cell])
		else:
			board.set_master(master.id)

	if errors.size() > error_count_before:
		return null
	if board.arrow_count() == 0:
		errors.append("%s: layout has no arrows" % _describe())
		return null
	return board


func _parse_rows(errors: PackedStringArray) -> PackedStringArray:
	var rows := PackedStringArray()
	for line: String in layout.split("\n"):
		var row := line.replace(" ", "").replace("\t", "").strip_edges()
		if not row.is_empty():
			rows.append(row)
	if rows.is_empty():
		errors.append("%s: layout is empty" % _describe())
		return rows
	var width := rows[0].length()
	for y: int in rows.size():
		if rows[y].length() != width:
			errors.append("%s: row %d has %d cells, expected %d" % [_describe(), y, rows[y].length(), width])
		for x: int in rows[y].length():
			var symbol := rows[y][x]
			if symbol != EMPTY_SYMBOL and symbol != WALL_SYMBOL and not SYMBOLS.has(symbol):
				errors.append("%s: unknown symbol '%s' at (%d, %d)" % [_describe(), symbol, x, y])
	return rows


func _describe() -> String:
	if not resource_path.is_empty():
		return "Level '%s'" % resource_path
	if not title.is_empty():
		return "Level '%s'" % title
	return "Generated level"
