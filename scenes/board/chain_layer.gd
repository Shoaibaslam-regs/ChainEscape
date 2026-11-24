class_name ChainLayer
extends Node2D
## Draws the chains between locked arrows and the keys they wait for, as
## polished metal links alternating face-on and side-on like a real chain.

## Distance between link centres, in cells.
const LINK_SPACING_CELLS := 0.13
## Chains stop this far (in cells) from each arrow's centre so they never
## cover the arrow itself.
const END_INSET_CELLS := 0.36

var cell_size: float = 64.0:
	set(value):
		cell_size = value
		queue_redraw()

## Each entry is [lock_point, key_point] in this node's coordinates.
var _segments: Array[PackedVector2Array] = []


func set_segments(segments: Array[PackedVector2Array]) -> void:
	_segments = segments
	queue_redraw()


func clear() -> void:
	_segments = []
	queue_redraw()


func get_segment_count() -> int:
	return _segments.size()


func _draw() -> void:
	for segment: PackedVector2Array in _segments:
		var angle := segment[0].angle_to_point(segment[1])
		var points := link_positions(segment[0], segment[1], cell_size)
		for index: int in points.size():
			draw_link(self, points[index], angle, index % 2 == 1, cell_size)


## Link centres along a chain from [param from] to [param to] (arrow centres).
static func link_positions(from: Vector2, to: Vector2, cell: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var direction := from.direction_to(to)
	var start := from + direction * cell * END_INSET_CELLS
	var end := to - direction * cell * END_INSET_CELLS
	var length := start.distance_to(end)
	var count := maxi(int(length / (cell * LINK_SPACING_CELLS)), 1)
	for index: int in count + 1:
		points.append(start.lerp(end, float(index) / count))
	return points


## One metal link: a dark underlay for separation, the steel body and a
## light highlight along its top edge.
static func draw_link(canvas: CanvasItem, center: Vector2, angle: float, side_on: bool, cell: float, alpha: float = 1.0) -> void:
	var radius_x := cell * 0.095
	var radius_y := cell * (0.026 if side_on else 0.06)
	var width := maxf(cell * (0.034 if side_on else 0.028), 1.0)
	canvas.draw_set_transform(center, angle, Vector2(1.0, radius_y / radius_x))
	canvas.draw_arc(Vector2.ZERO, radius_x, 0.0, TAU, 20, Color(Palette.OBSIDIAN, 0.7 * alpha), width + 2.0, true)
	canvas.draw_arc(Vector2.ZERO, radius_x, 0.0, TAU, 20, Color(Palette.CHAIN, alpha), width, true)
	canvas.draw_arc(Vector2.ZERO, radius_x, PI * 1.1, PI * 1.9, 10, Color(Palette.STEEL_LIGHT, 0.8 * alpha), width * 0.5, true)
	canvas.draw_set_transform(Vector2.ZERO)
