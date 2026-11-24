class_name PathTracer
extends RefCounted
## Follows an arrow from its cell to the board edge, through the special
## cells that change where it goes:
##   mirror "/" or "\"  turns it 90 degrees,
##   black hole         swallows it; it comes out of the paired white hole
##                      and keeps going the same way (white holes are
##                      ordinary cells for anything flying across them).
## Shared by the rules (BoardState), the generator and the exit animation,
## so all three always agree on the path.

const MIRROR_SLASH := 0  ## "/"
const MIRROR_BACKSLASH := 1  ## "\"

## Waypoint kinds for the animation.
const START := "start"
const TURN := "turn"
const ENTER := "enter"
const EMERGE := "emerge"
const EDGE := "edge"


## Returns {"cells": Array[Vector2i] (every cell passed, in order, both
## holes included), "waypoints": Array[Dictionary] ({"cell", "kind", "dir"}),
## "escaped": bool (false if mirrors or holes trap it in a loop)}.
static func trace(start: Vector2i, direction: Arrow.Direction, board_size: Vector2i, mirrors: Dictionary, portals: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	var waypoints: Array[Dictionary] = [{"cell": start, "kind": START, "dir": direction}]
	var cell := start
	var heading := direction
	var limit := board_size.x * board_size.y * 4 + 8
	var escaped := false
	for step: int in limit:
		cell += Arrow.direction_to_vector(heading)
		if cell.x < 0 or cell.y < 0 or cell.x >= board_size.x or cell.y >= board_size.y:
			waypoints.append({"cell": cell, "kind": EDGE, "dir": heading})
			escaped = true
			break
		cells.append(cell)
		if mirrors.has(cell):
			heading = reflect(heading, mirrors[cell])
			waypoints.append({"cell": cell, "kind": TURN, "dir": heading})
		elif portals.has(cell):
			waypoints.append({"cell": cell, "kind": ENTER, "dir": heading})
			cell = portals[cell]
			cells.append(cell)
			waypoints.append({"cell": cell, "kind": EMERGE, "dir": heading})
	return {"cells": cells, "waypoints": waypoints, "escaped": escaped}


static func reflect(direction: Arrow.Direction, mirror: int) -> Arrow.Direction:
	if mirror == MIRROR_SLASH:
		match direction:
			Arrow.Direction.RIGHT:
				return Arrow.Direction.UP
			Arrow.Direction.UP:
				return Arrow.Direction.RIGHT
			Arrow.Direction.LEFT:
				return Arrow.Direction.DOWN
			_:
				return Arrow.Direction.LEFT
	match direction:
		Arrow.Direction.RIGHT:
			return Arrow.Direction.DOWN
		Arrow.Direction.DOWN:
			return Arrow.Direction.RIGHT
		Arrow.Direction.LEFT:
			return Arrow.Direction.UP
		_:
			return Arrow.Direction.LEFT
