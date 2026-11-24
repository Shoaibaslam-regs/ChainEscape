class_name UnlockSeal
extends Control
## The Level complete padlock: starts locked with a chain wrapped across it,
## then the shackle springs open and the chain links break off and fall.
## Drawn from parts laid out in a 200 x 170 design space, scaled to fit.

const BODY := preload("res://assets/brand/seal_body.svg")
const SHACKLE := preload("res://assets/brand/seal_shackle.svg")
const LINK := preload("res://assets/brand/seal_link.svg")
const LINK_EDGE := preload("res://assets/brand/seal_link_edge.svg")

const DESIGN_SIZE := Vector2(200, 170)
const LINK_SIZE := Vector2(34, 22)
## The chain crosses the lock body from left to right, slightly tilted.
const CHAIN_FROM := Vector2(10, 98)
const CHAIN_TO := Vector2(190, 126)
const LINK_COUNT := 9

const POP_SECONDS := 0.3
const OPEN_DELAY := 0.32
const SHACKLE_LIFT := 16.0
const SHACKLE_TURN := -0.42
const FALL_DELAY := 0.38
const FALL_SECONDS := 0.6
const FALL_DISTANCE := 260.0

var _body := TextureRect.new()
var _shackle := TextureRect.new()
var _links: Array[TextureRect] = []
var _tween: Tween
var _is_unlocked: bool = false
## Bumped on every play() so an older, still-waiting call gives up.
var _play_id: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part: TextureRect in [_shackle, _body]:
		part.texture = SHACKLE if part == _shackle else BODY
		_setup_part(part)
		add_child(part)
	for i in LINK_COUNT:
		var link := TextureRect.new()
		link.texture = LINK if i % 2 == 0 else LINK_EDGE
		_setup_part(link)
		add_child(link)
		_links.append(link)
	resized.connect(_reset_parts)


## Plays the unlock: pop in, shackle opens, chain falls away.
func play() -> void:
	_kill_tween()
	_is_unlocked = false
	modulate.a = 0.0
	_play_id += 1
	var play_id := _play_id
	# Just shown: wait for the container to give this control its size.
	if size.x <= 0.0 or size.y <= 0.0:
		await resized
	await get_tree().process_frame
	if not is_inside_tree() or play_id != _play_id:
		return
	_reset_parts()
	var unit := _unit()
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 0.8
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, POP_SECONDS * 0.6)
	_tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The shackle springs up and swings open around its left leg.
	_tween.tween_property(_shackle, "position:y", _shackle.position.y - SHACKLE_LIFT * unit, 0.14) \
		.set_delay(OPEN_DELAY).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_shackle, "rotation", SHACKLE_TURN, 0.26) \
		.set_delay(OPEN_DELAY + 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A small jolt of the body as it opens.
	_tween.tween_property(_body, "position:y", _body.position.y + 3.0 * unit, 0.06).set_delay(OPEN_DELAY)
	_tween.tween_property(_body, "position:y", _body.position.y, 0.12).set_delay(OPEN_DELAY + 0.06)
	# The chain breaks in the middle: links fall outward, middle first.
	var middle := (LINK_COUNT - 1) * 0.5
	for i in LINK_COUNT:
		var link := _links[i]
		var side := signf(i - middle)
		var delay := FALL_DELAY + absf(i - middle) * 0.035
		var drift := side * (14.0 + absf(i - middle) * 6.0) * unit
		var spin := side * (1.2 + fmod(i * 0.7, 1.3)) if side != 0.0 else 0.9
		_tween.tween_property(link, "position:y", link.position.y + FALL_DISTANCE * unit, FALL_SECONDS) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(link, "position:x", link.position.x + drift, FALL_SECONDS).set_delay(delay) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(link, "rotation", link.rotation + spin, FALL_SECONDS).set_delay(delay)
		_tween.tween_property(link, "modulate:a", 0.0, FALL_SECONDS * 0.45).set_delay(delay + FALL_SECONDS * 0.55)
	_tween.chain().tween_callback(func() -> void: _is_unlocked = true)


## Seconds until the chain has fallen away.
static func duration() -> float:
	return FALL_DELAY + LINK_COUNT * 0.5 * 0.035 + FALL_SECONDS


func is_unlocked() -> bool:
	return _is_unlocked


## Visible chain links (all gone once unlocked).
func visible_link_count() -> int:
	return _links.filter(func(link: TextureRect) -> bool: return link.modulate.a > 0.01).size()


func _setup_part(part: TextureRect) -> void:
	part.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	part.stretch_mode = TextureRect.STRETCH_SCALE
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unit() -> float:
	return minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y) if size != Vector2.ZERO else 1.0


## Puts every part back in the locked pose for the current size.
func _reset_parts() -> void:
	if _tween != null and _tween.is_running():
		return
	var unit := _unit()
	var origin := (size - DESIGN_SIZE * unit) * 0.5
	for part: TextureRect in [_body, _shackle]:
		part.position = origin
		part.size = DESIGN_SIZE * unit
		part.rotation = 0.0
		part.modulate.a = 1.0
	_shackle.pivot_offset = Vector2(72, 84) * unit
	var angle := (CHAIN_TO - CHAIN_FROM).angle()
	for i in LINK_COUNT:
		var link := _links[i]
		var center := CHAIN_FROM.lerp(CHAIN_TO, float(i) / float(LINK_COUNT - 1))
		link.size = LINK_SIZE * unit
		link.pivot_offset = link.size * 0.5
		link.position = origin + center * unit - link.size * 0.5
		link.rotation = angle
		link.modulate.a = 1.0


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
