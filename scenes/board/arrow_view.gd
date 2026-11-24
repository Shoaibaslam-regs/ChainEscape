class_name ArrowView
extends Node2D
## Draws one arrow with no tile behind it: polished gold with a soft glow
## when free, polished steel when locked, lit from above whatever way it
## points. Also draws its key ring and padlock badge, and plays its arrive,
## exit, blocked and unlock animations. Positioned by BoardView at the
## centre of its cell; holds no game rules.

signal exit_finished

const EXIT_SPEED_CELLS_PER_SECOND := 14.0
const MIN_EXIT_DURATION := 0.18
const UNLOCK_DURATION := 0.32
const GLOW_ALPHA := 0.17
const GLOW_SIZE_CELLS := 1.0
## Arrows are drawn this much smaller than their cell, so the board breathes.
## Taps still use the whole cell.
const ARROW_SCALE := 0.85
## The master arrow is drawn this much larger than a normal arrow.
const MASTER_SCALE := 1.22
## Arrow pointing right, in units of half a cell.
const ARROW_SHAPE: Array[Vector2] = [
	Vector2(-0.55, -0.155), Vector2(0.13, -0.155), Vector2(0.13, -0.46),
	Vector2(0.63, 0.0),
	Vector2(0.13, 0.46), Vector2(0.13, 0.155), Vector2(-0.55, 0.155),
]
## Badges sit where their chain meets the arrow: this far from the cell
## centre, in cells, matching ChainLayer.END_INSET_CELLS.
const BADGE_DISTANCE_CELLS := ChainLayer.END_INSET_CELLS
## Used when no chain direction is known.
const DEFAULT_LOCK_DIRECTION := Vector2(0.7071, -0.7071)
const DEFAULT_KEY_DIRECTION := Vector2(-0.7071, 0.7071)

static var _glow_texture: GradientTexture2D
static var _badge_font: Font

var arrow_id: int = -1
## Light / mid / dark stops for a free arrow's metal (the arrow theme).
var metal: PackedColorArray = ArrowTheme.colors_of(ArrowTheme.THEMES[0]):
	set(value):
		if value.size() == 3:
			metal = value
			queue_redraw()
var direction: Arrow.Direction = Arrow.Direction.RIGHT
var is_exiting: bool = false

## Waiting on at least one key. Setting it directly snaps the look; use
## play_unlock() to animate the change from locked to free.
var is_locked: bool = false:
	set(value):
		is_locked = value
		_warmth = 0.0 if value else 1.0
		_unlock_progress = 0.0
		queue_redraw()

## How many keys it still waits for; 2 or more shows "×2".
var lock_count: int = 0:
	set(value):
		lock_count = value
		queue_redraw()

## Other arrows wait for this one: shows the teal key ring.
var is_key: bool = false:
	set(value):
		is_key = value
		queue_redraw()

## The master arrow: larger, with a halo and a compass ring. Releasing it
## clears the level.
var is_master: bool = false:
	set(value):
		is_master = value
		queue_redraw()

var cell_size: float = 64.0:
	set(value):
		cell_size = value
		queue_redraw()

## Screen-space directions toward this arrow's keys / waiting arrows, so the
## padlock and key ring sit on the chain ends. Zero means "use the default".
var lock_badge_direction: Vector2 = Vector2.ZERO:
	set(value):
		lock_badge_direction = value
		queue_redraw()
var key_badge_direction: Vector2 = Vector2.ZERO:
	set(value):
		key_badge_direction = value
		queue_redraw()

## Forward nudge along the arrow, in cells (blocked animation).
var _bump: float = 0.0:
	set(value):
		_bump = value
		queue_redraw()
## 0..1 blend toward coral (blocked feedback).
var _flash: float = 0.0:
	set(value):
		_flash = value
		queue_redraw()
## Red metal for an arrow the player already tried while it was stuck.
const WRONG_METAL: Array[Color] = [Color("FFC9BF"), Color("E0503F"), Color("7E1F16")]
## Set while the arrow is marked as a wrong move; cleared once it can go.
var is_marked_wrong: bool = false:
	set(value):
		if value == is_marked_wrong:
			return
		is_marked_wrong = value
		_kill(_wrong_tween)
		_wrong_tween = create_tween()
		_wrong_tween.tween_property(self, "_wrong", 1.0 if value else 0.0, 0.2)
## 0..1 blend toward the red "wrong move" metal.
var _wrong: float = 0.0:
	set(value):
		_wrong = value
		queue_redraw()
## 0 = steel, 1 = gold.
var _warmth: float = 1.0:
	set(value):
		_warmth = value
		queue_redraw()
## 0..1 padlock springing open.
var _unlock_progress: float = 0.0:
	set(value):
		_unlock_progress = value
		queue_redraw()
## Badges fade in after the level-start fly-in.
var badge_alpha: float = 1.0:
	set(value):
		badge_alpha = value
		queue_redraw()

var _motion_tween: Tween
var _flash_tween: Tween
var _wrong_tween: Tween
var _unlock_tween: Tween
var _arrival_target: Vector2


func setup(arrow: Arrow) -> void:
	arrow_id = arrow.id
	direction = arrow.direction
	rotation = Vector2(Arrow.direction_to_vector(direction)).angle()
	if _glow_texture == null:
		_glow_texture = _make_glow_texture()
	if _badge_font == null:
		_badge_font = GameTheme.font(900)


func _draw() -> void:
	var half := cell_size * 0.5 * ARROW_SCALE * (MASTER_SCALE if is_master else 1.0)
	var offset := Vector2(_bump * cell_size, 0.0)
	if is_master:
		_draw_master_halo()
	if _warmth > 0.0:
		var glow_size := Vector2.ONE * cell_size * GLOW_SIZE_CELLS * ARROW_SCALE * (1.5 if is_master else 1.0)
		var glow_alpha := GLOW_ALPHA * (2.2 if is_master else 1.0)
		draw_texture_rect(_glow_texture, Rect2(offset - glow_size * 0.5, glow_size), false, Color(metal[1], glow_alpha * _warmth))

	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for point: Vector2 in ARROW_SHAPE:
		var local := offset + point * half
		points.append(local)
		# Light comes from the top of the screen, whatever the rotation.
		var height := clampf(local.rotated(rotation).y / (half * 1.3) * 0.5 + 0.5, 0.0, 1.0)
		colors.append(_metal_color(height))
	draw_polygon(points, colors)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(metal[0] if _warmth > 0.5 else Palette.STEEL_LIGHT, 0.35), maxf(cell_size * 0.012, 1.0), true)

	if _wrong > 0.01:
		_draw_wrong_mark(offset)
	if badge_alpha <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, -rotation)
	if is_key:
		_draw_key_ring(_badge_position(key_badge_direction, DEFAULT_KEY_DIRECTION))
	if is_locked:
		_draw_padlock(_badge_position(lock_badge_direction, DEFAULT_LOCK_DIRECTION))
	draw_set_transform(Vector2.ZERO)


## Halo ring with four compass ticks around the master arrow (screen-aligned).
func _draw_master_halo() -> void:
	var radius := cell_size * 0.47
	var ring_color := Color(Palette.GOLD, 0.75 * badge_alpha)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring_color, maxf(cell_size * 0.025, 1.5), true)
	for index: int in 4:
		var direction := Vector2.from_angle(index * PI * 0.5)
		draw_line(direction * radius * 1.06, direction * radius * 1.22, ring_color, maxf(cell_size * 0.03, 1.5), true)


## Moves from [param start] to the cell centre (level-start fly-in).
func play_arrival(start: Vector2, delay: float, duration: float) -> void:
	_kill(_motion_tween)
	_arrival_target = position
	position = start
	modulate.a = 0.0
	_motion_tween = create_tween().set_parallel()
	_motion_tween.tween_property(self, "position", _arrival_target, duration).set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "modulate:a", 1.0, duration * 0.4).set_delay(delay)


## Jumps to the end of the arrival animation.
func finish_arrival() -> void:
	if _motion_tween != null and _motion_tween.is_valid() and not is_exiting:
		_motion_tween.kill()
		position = _arrival_target
		modulate.a = 1.0


## Slides the arrow [param distance_cells] cells forward while fading out,
## then frees itself.
func play_exit(distance_cells: float, delay: float = 0.0) -> void:
	is_exiting = true
	z_index = 2
	badge_alpha = 0.0
	_kill(_motion_tween)
	_kill(_flash_tween)
	_kill(_unlock_tween)
	_kill(_wrong_tween)
	_flash = 0.0
	_wrong = 0.0
	_warmth = 1.0
	var target := position + Vector2(Arrow.direction_to_vector(direction)) * distance_cells * cell_size
	var duration := maxf(distance_cells / EXIT_SPEED_CELLS_PER_SECOND, MIN_EXIT_DURATION)
	_motion_tween = create_tween().set_parallel()
	_motion_tween.tween_property(self, "position", target, duration).set_delay(delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(self, "modulate:a", 0.0, duration).set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_motion_tween.chain().tween_callback(_on_exit_done)


## Short forward nudge plus a coral tint: "you can't go yet".
## Used both when the path is blocked and when the arrow is locked.
func play_blocked() -> void:
	if is_exiting:
		return
	_kill(_motion_tween)
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "_bump", 0.12, 0.06).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "_bump", 0.0, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash()


## Briefly tints the arrow coral (also points out a blocker or a key).
func flash() -> void:
	if is_exiting:
		return
	_kill(_flash_tween)
	_flash = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 0.0, 0.35)


## The padlock springs open and fades while the arrow warms from steel to
## gold. Ends with is_locked = false.
func play_unlock(delay: float = 0.0) -> void:
	if is_exiting or not is_locked:
		return
	_kill(_unlock_tween)
	_unlock_tween = create_tween().set_parallel()
	_unlock_tween.tween_property(self, "_unlock_progress", 1.0, UNLOCK_DURATION).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_unlock_tween.tween_property(self, "_warmth", 1.0, UNLOCK_DURATION).set_delay(delay + 0.08)
	_unlock_tween.chain().tween_callback(func() -> void: is_locked = false)


func is_unlocking() -> bool:
	return _unlock_tween != null and _unlock_tween.is_valid()


func _badge_position(chain_direction: Vector2, fallback: Vector2) -> Vector2:
	var direction := chain_direction.normalized() if chain_direction.length() > 0.01 else fallback
	return direction * BADGE_DISTANCE_CELLS * cell_size


func _metal_color(height: float) -> Color:
	var gold := _three_stop(metal[0], metal[1], metal[2], height)
	var steel := _three_stop(Palette.STEEL_LIGHT, Palette.STEEL, Palette.STEEL_DARK, height)
	var red := _three_stop(WRONG_METAL[0], WRONG_METAL[1], WRONG_METAL[2], height)
	return steel.lerp(gold, _warmth).lerp(red, _wrong).lerp(Palette.CORAL, _flash)


## A small dark disc with a white cross on a red (already tried) arrow, so
## it reads without relying on colour (colour-blind players).
func _draw_wrong_mark(center: Vector2) -> void:
	var radius := cell_size * 0.11
	var alpha := _wrong
	draw_circle(center, radius, Color(Palette.OBSIDIAN, 0.92 * alpha), true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 24, Color(Color.WHITE, 0.35 * alpha), maxf(cell_size * 0.012, 1.0), true)
	var arm := radius * 0.48
	var width := maxf(cell_size * 0.028, 1.5)
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), Color(Color.WHITE, alpha), width, true)
	draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), Color(Color.WHITE, alpha), width, true)


func has_wrong_mark() -> bool:
	return _wrong > 0.01


func _draw_key_ring(center: Vector2) -> void:
	var color := Color(1, 1, 1, badge_alpha)
	draw_circle(center, cell_size * 0.1, Palette.OBSIDIAN * color)
	draw_arc(center, cell_size * 0.068, 0.0, TAU, 24, Palette.KEY * color, cell_size * 0.036, true)


func _draw_padlock(center: Vector2) -> void:
	var alpha := badge_alpha * (1.0 - _unlock_progress)
	if alpha <= 0.0:
		return
	var grow := 1.0 + 0.4 * _unlock_progress
	var unit := cell_size * 0.01 * grow
	draw_circle(center, unit * 17.0, Color(Palette.OBSIDIAN, alpha))
	draw_arc(center, unit * 17.0, 0.0, TAU, 28, Color(Palette.CHAIN, 0.45 * alpha), maxf(unit * 1.2, 1.0), true)
	# Shackle lifts and swings open as the lock releases.
	var shackle_center := center + Vector2(unit * 1.5 * _unlock_progress, -unit * (2.5 + 5.0 * _unlock_progress))
	draw_arc(shackle_center, unit * 5.0, PI, TAU, 12, Color(Palette.STEEL_LIGHT, alpha), unit * 2.6, true)
	draw_rect(Rect2(center + Vector2(-unit * 7.5, -unit * 2.0), Vector2(unit * 15.0, unit * 11.0)), Color(Palette.CHAIN, alpha))
	draw_rect(Rect2(center + Vector2(-unit * 7.5, -unit * 2.0), Vector2(unit * 15.0, unit * 3.0)), Color(Palette.STEEL_LIGHT, alpha * 0.8))
	if lock_count >= 2:
		draw_string(_badge_font, center + Vector2(unit * 13.0, -unit * 9.0), "×2", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(unit * 16.0), Color(Palette.GOLD, alpha))


## Flies the arrow along a bending path (mirrors, black holes) and off the
## board. [param points]: {"pos": local position, "kind", "dir"} from the
## arrow's cell to just past the edge (see PathTracer waypoint kinds).
func play_exit_path(points: Array[Dictionary]) -> void:
	is_exiting = true
	z_index = 2
	badge_alpha = 0.0
	_kill(_motion_tween)
	_kill(_flash_tween)
	_kill(_unlock_tween)
	_kill(_wrong_tween)
	_flash = 0.0
	_wrong = 0.0
	_warmth = 1.0
	var tween := create_tween()
	_motion_tween = tween
	var current := position
	var angle := rotation
	for index: int in range(1, points.size()):
		var point: Dictionary = points[index]
		var target: Vector2 = point["pos"]
		var last := index == points.size() - 1
		if point["kind"] == PathTracer.EMERGE:
			# Out of the white hole: appear there and grow back.
			tween.tween_callback(func() -> void: position = target)
			tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(self, "modulate:a", 1.0, 0.1)
			current = target
			continue
		var duration := maxf(current.distance_to(target) / maxf(cell_size, 1.0) / EXIT_SPEED_CELLS_PER_SECOND, 0.04)
		var move := tween.tween_property(self, "position", target, duration)
		if last:
			move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		match point["kind"]:
			PathTracer.TURN:
				var turned := angle + wrapf(Vector2(Arrow.direction_to_vector(point["dir"])).angle() - angle, -PI, PI)
				tween.tween_property(self, "rotation", turned, 0.08).set_trans(Tween.TRANS_SINE)
				angle = turned
			PathTracer.ENTER:
				# Swallowed: spin down into the black hole.
				tween.tween_property(self, "scale", Vector2.ONE * 0.12, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tween.parallel().tween_property(self, "modulate:a", 0.15, 0.14)
		current = target
	tween.tween_callback(_on_exit_done)


func _on_exit_done() -> void:
	exit_finished.emit()
	queue_free()


static func _three_stop(top: Color, middle: Color, bottom: Color, t: float) -> Color:
	return top.lerp(middle, t / 0.45) if t < 0.45 else middle.lerp(bottom, (t - 0.45) / 0.55)


static func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	# White, tinted by the theme colour when drawn.
	gradient.set_color(0, Color(1, 1, 1, 1.0))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
