class_name HomeBackdrop
extends Control
## Home's living backdrop: soft gold light rays turning slowly behind the
## hero, and fine gold dust drifting upward. Calm by design; still when
## motion is reduced.

const RAY_COUNT := 12
const RAY_COLOR := Color(0.91, 0.69, 0.29, 0.05)
## The backdrop drifts slowly, so 30 redraws a second is plenty (battery).
const REDRAW_INTERVAL := 1.0 / 30.0
const RAY_SECONDS_PER_TURN := 140.0
const RAY_RADIUS := 760.0
const DUST_COUNT := 34
const DUST_COLOR := Color(1.0, 0.87, 0.6)

## Where the rays meet (local coordinates), e.g. the hero art's centre.
var focus: Vector2 = Vector2(360, 460):
	set(value):
		focus = value
		queue_redraw()
var animated: bool = true:
	set(value):
		animated = value
		set_process(value)
		queue_redraw()

var _angle: float = 0.0
var _time: float = 0.0
var _dust: Array[Dictionary] = []
var _since_redraw: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in DUST_COUNT:
		_dust.append({
			"x": rng.randf(), "y": rng.randf(),
			"speed": rng.randf_range(0.008, 0.022),
			"size": rng.randf_range(1.2, 3.2),
			"phase": rng.randf() * TAU,
			"alpha": rng.randf_range(0.18, 0.5),
		})
	set_process(animated)


func _process(delta: float) -> void:
	_time += delta
	_angle = fmod(_angle + delta * TAU / RAY_SECONDS_PER_TURN, TAU)
	for particle: Dictionary in _dust:
		particle["y"] = fposmod(float(particle["y"]) - float(particle["speed"]) * delta, 1.0)
	_since_redraw += delta
	if _since_redraw >= REDRAW_INTERVAL:
		_since_redraw = 0.0
		queue_redraw()


func _draw() -> void:
	# Each ray is feathered: bright along its middle, fading to nothing at
	# its sides and toward the outside.
	var wedge := TAU / RAY_COUNT * 0.5
	var clear := Color(RAY_COLOR, 0.0)
	for i: int in RAY_COUNT:
		var start := _angle + i * TAU / RAY_COUNT
		var left := focus + Vector2.from_angle(start) * RAY_RADIUS
		var middle := focus + Vector2.from_angle(start + wedge * 0.5) * RAY_RADIUS * 0.75
		var right := focus + Vector2.from_angle(start + wedge) * RAY_RADIUS
		draw_polygon(PackedVector2Array([focus, left, middle]), PackedColorArray([RAY_COLOR, clear, Color(RAY_COLOR, RAY_COLOR.a * 0.35)]))
		draw_polygon(PackedVector2Array([focus, middle, right]), PackedColorArray([RAY_COLOR, Color(RAY_COLOR, RAY_COLOR.a * 0.35), clear]))
	for particle: Dictionary in _dust:
		var twinkle := 0.6 + 0.4 * sin(_time * 1.3 + float(particle["phase"]))
		var position_px := Vector2(float(particle["x"]) * size.x, float(particle["y"]) * size.y)
		draw_circle(position_px, float(particle["size"]), Color(DUST_COLOR, float(particle["alpha"]) * twinkle), true, -1.0, true)
