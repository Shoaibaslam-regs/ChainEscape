class_name UnlockSeal
extends Control
## The "padlock escape" emblem (the app icon's picture, in the game's gold
## and steel): a chain across the stage, a padlock on it, the gold arrow
## caught behind it. It can play the whole story (splash: chain slides in,
## padlock drops on, arrow appears trapped, then the lock springs open, a
## link breaks and the arrow shoots free) or just the escape (Level
## complete). Layers share one 1024 x 1024 frame, scaled to fit.

const DESIGN := 1024.0
const LAYER_ORDER := ["glow", "arrow", "chain", "chain_link", "shackle_closed", "lock_body"]
## The shackle really moves: it lifts out of the body along the lock's own
## "up" (the lock hangs tilted 12 degrees), then swings open around its left
## leg. Points are in the 1024 art frame.
const SHACKLE_PIVOT := Vector2(257.4, 755.0)
const LOCK_UP := Vector2(-0.2079, -0.9781)
const SHACKLE_LIFT := 26.0
const SHACKLE_OPEN_ANGLE := -0.55
## The link that breaks (for tests: 1 link falls away).
const LINK_COUNT := 1
## The arrow points up-right (30 degrees from up); trapped, it sits pulled
## back along that line, behind the chain.
const ARROW_DIRECTION := Vector2(0.5, -0.866)
const TRAPPED_PULL := 0.16
const BREAK_POINT := Vector2(544, 637)

## Story timing (seconds).
const CHAIN_IN := 0.1
const CHAIN_SECONDS := 0.45
const LOCK_IN := 0.62
const LOCK_SECONDS := 0.36
const ARROW_IN := 1.0
const ESCAPE_AT := 1.45
## Escape-only timing (Level complete).
const ESCAPE_ONLY_DELAY := 0.3
const FALL_SECONDS := 0.65

var _layers: Dictionary[String, TextureRect] = {}
## All layers live in this square frame; only the frame is centred, so the
## animations move layers relative to the art and nothing drifts.
var _frame := Control.new()
var _flash := TextureRect.new()
var _tween: Tween
var _feedback: Feedback
var _is_unlocked: bool = false
## Bumped on each play, so an older call still waiting for a size gives up.
var _play_id: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	for name: String in LAYER_ORDER:
		var layer := TextureRect.new()
		layer.texture = load("res://assets/brand/escape/%s.svg" % name)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(layer)
		_layers[name] = layer
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 0.95, 0.7, 0.6), Color(1, 0.8, 0.3, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_flash.texture = texture
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_flash)
	resized.connect(_layout)


## The whole story (splash). [param feedback] plays its sounds (optional).
func play_story(feedback: Feedback = null) -> void:
	if not await _wait_for_size():
		return
	_begin(feedback)
	var side := _side()
	for name: String in LAYER_ORDER:
		_layers[name].modulate.a = 0.0
	_flash.modulate.a = 0.0
	# 1. The chain slides in from the left.
	for name: String in ["chain", "chain_link"]:
		var layer := _layers[name]
		layer.position.x = -side * 1.1
		_tween.tween_property(layer, "position:x", 0.0, CHAIN_SECONDS).set_delay(CHAIN_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(layer, "modulate:a", 1.0, 0.12).set_delay(CHAIN_IN)
	_tween.tween_callback(_play.bind(Feedback.Sound.CHAIN_SLIDE)).set_delay(CHAIN_IN)
	_tween.tween_callback(_play.bind(Feedback.Sound.LINK_JOIN)).set_delay(CHAIN_IN + CHAIN_SECONDS * 0.7)
	# 2. The padlock drops onto the chain and locks.
	for name: String in ["lock_body", "shackle_closed"]:
		var layer := _layers[name]
		layer.position.y = -side * 0.5
		_tween.tween_property(layer, "position:y", 0.0, LOCK_SECONDS).set_delay(LOCK_IN).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(layer, "modulate:a", 1.0, 0.1).set_delay(LOCK_IN)
	_tween.tween_callback(_play.bind(Feedback.Sound.LOCK_SNAP)).set_delay(LOCK_IN + LOCK_SECONDS * 0.6 - 0.055)
	# 3. The gold arrow appears, caught behind the chain.
	var arrow := _layers["arrow"]
	arrow.position = -ARROW_DIRECTION * TRAPPED_PULL * side
	_tween.tween_property(arrow, "modulate:a", 1.0, 0.3).set_delay(ARROW_IN)
	_tween.tween_property(_layers["glow"], "modulate:a", 1.0, 0.4).set_delay(ARROW_IN)
	_tween.tween_callback(_play.bind(Feedback.Sound.SPLASH_RISE)).set_delay(ARROW_IN)
	# 4. Escape.
	_add_escape(ESCAPE_AT)


## Only the escape: the scene starts locked, then the arrow breaks free
## (Level complete).
func play() -> void:
	if not await _wait_for_size():
		return
	_begin(null)
	var side := _side()
	for name: String in LAYER_ORDER:
		_layers[name].modulate.a = 1.0
	_layers["arrow"].position = -ARROW_DIRECTION * TRAPPED_PULL * side
	_flash.modulate.a = 0.0
	scale = Vector2.ONE * 0.9
	pivot_offset = size * 0.5
	_tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_add_escape(ESCAPE_ONLY_DELAY)


## Jumps to the finished picture (the icon).
func show_final() -> void:
	_kill_tween()
	_layout()
	for name: String in LAYER_ORDER:
		_layers[name].modulate.a = 1.0
		_layers[name].position = Vector2.ZERO
		_layers[name].rotation = 0.0
	_layers["chain_link"].modulate.a = 0.0
	_set_shackle_open(1.0)
	_flash.modulate.a = 0.0
	scale = Vector2.ONE
	_is_unlocked = true


## Seconds the escape-only animation takes.
static func duration() -> float:
	return ESCAPE_ONLY_DELAY + FALL_SECONDS + 0.1


## Seconds the whole story takes.
static func story_duration() -> float:
	return ESCAPE_AT + FALL_SECONDS + 0.1


func is_unlocked() -> bool:
	return _is_unlocked


func visible_link_count() -> int:
	return 1 if _layers["chain_link"].modulate.a > 0.01 else 0


func get_layer(layer_name: String) -> Control:
	return _layers[layer_name]


## 0 = shut, 1 = fully open (lifted and swung around the left leg).
func _set_shackle_open(amount: float) -> void:
	var shackle := _layers["shackle_closed"]
	shackle.position = LOCK_UP * SHACKLE_LIFT / DESIGN * _side() * minf(amount * 2.0, 1.0)
	shackle.rotation = SHACKLE_OPEN_ANGLE * clampf(amount * 2.0 - 1.0, 0.0, 1.0)


## How far the shackle has swung open (0..1), for tests.
func get_shackle_open() -> float:
	return clampf(_layers["shackle_closed"].rotation / SHACKLE_OPEN_ANGLE, 0.0, 1.0)


## The lock springs open, the middle link breaks and falls, and the arrow
## shoots free along its direction, with a flash at the break.
func _add_escape(at: float) -> void:
	var side := _side()
	var shackle := _layers["shackle_closed"]
	var lifted := LOCK_UP * SHACKLE_LIFT / DESIGN * side
	_tween.tween_callback(_play.bind(Feedback.Sound.LOCK_SNAP)).set_delay(at - 0.05)
	# Snap up out of the body (the body gives a small jolt) ...
	_tween.tween_property(shackle, "position", lifted, 0.1).set_delay(at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var body := _layers["lock_body"]
	_tween.tween_property(body, "position", -lifted * 0.25, 0.06).set_delay(at)
	_tween.tween_property(body, "position", Vector2.ZERO, 0.14).set_delay(at + 0.06).set_trans(Tween.TRANS_SINE)
	# ... then swing open around the left leg, overshooting a little.
	_tween.tween_property(shackle, "rotation", SHACKLE_OPEN_ANGLE, 0.32).set_delay(at + 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		_flash.modulate.a = 1.0
		_flash.scale = Vector2.ONE * 0.3).set_delay(at + 0.08)
	_tween.tween_property(_flash, "scale", Vector2.ONE * 1.5, 0.45).set_delay(at + 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_flash, "modulate:a", 0.0, 0.5).set_delay(at + 0.13)
	var link := _layers["chain_link"]
	link.pivot_offset = BREAK_POINT / DESIGN * side
	_tween.tween_property(link, "position:y", side * 0.35, FALL_SECONDS).set_delay(at + 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(link, "rotation", 1.4, FALL_SECONDS).set_delay(at + 0.12)
	_tween.tween_property(link, "modulate:a", 0.0, FALL_SECONDS * 0.6).set_delay(at + 0.12 + FALL_SECONDS * 0.4)
	_tween.tween_property(_layers["arrow"], "position", Vector2.ZERO, 0.22).set_delay(at + 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_play.bind(Feedback.Sound.EXIT)).set_delay(at + 0.12)
	_tween.chain().tween_callback(func() -> void: _is_unlocked = true)


## Just shown inside a container: wait until it has its real size (otherwise
## the art would be laid out for the wrong size). False if replayed meanwhile.
func _wait_for_size() -> bool:
	_play_id += 1
	var id := _play_id
	_kill_tween()
	for name: String in LAYER_ORDER:
		_layers[name].modulate.a = 0.0
	if size.x <= 0.0 or size.y <= 0.0:
		await resized
	await get_tree().process_frame
	return is_inside_tree() and id == _play_id


func _begin(feedback: Feedback) -> void:
	_kill_tween()
	_feedback = feedback
	_is_unlocked = false
	_layout()
	for name: String in LAYER_ORDER:
		_layers[name].position = Vector2.ZERO
		_layers[name].rotation = 0.0
	_tween = create_tween().set_parallel()


func _play(sound: Feedback.Sound) -> void:
	if _feedback != null:
		_feedback.play(sound)


func _side() -> float:
	return minf(size.x, size.y) if size != Vector2.ZERO else DESIGN


func _layout() -> void:
	var side := _side()
	_frame.size = Vector2(side, side)
	_frame.position = (size - _frame.size) * 0.5
	for layer: TextureRect in _layers.values():
		layer.size = Vector2(side, side)
		layer.pivot_offset = Vector2(side, side) * 0.5
	# The shackle turns around its left leg, not the middle of the art.
	_layers["shackle_closed"].pivot_offset = SHACKLE_PIVOT / DESIGN * side
	var flash_side := side * 0.35
	_flash.size = Vector2(flash_side, flash_side)
	_flash.pivot_offset = _flash.size * 0.5
	_flash.position = BREAK_POINT / DESIGN * side - _flash.size * 0.5


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Removed mid-animation (e.g. skipped): no late sounds.
func _exit_tree() -> void:
	_kill_tween()
	_feedback = null
