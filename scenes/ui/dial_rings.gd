class_name DialRings
extends Control
## Faint concentric "vault dial" rings drawn around this control's centre.
## Decoration only; it ignores input.

@export var ring_radii: PackedFloat32Array = [250.0, 330.0, 425.0]
@export var ring_alphas: PackedFloat32Array = [0.10, 0.07, 0.05]
## Rings at these indexes are drawn dashed.
@export var dashed_rings: PackedInt32Array = [1]
@export var color: Color = Palette.GOLD
@export var line_width: float = 2.5
@export var dash_count: int = 72


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	for index: int in ring_radii.size():
		var ring_color := Color(color, ring_alphas[index] if index < ring_alphas.size() else 0.05)
		var radius := ring_radii[index]
		if dashed_rings.has(index):
			var step := TAU / dash_count
			for dash: int in dash_count:
				var start := dash * step
				draw_arc(center, radius, start, start + step * 0.35, 4, ring_color, line_width, true)
		else:
			draw_arc(center, radius, 0.0, TAU, 96, ring_color, line_width, true)
