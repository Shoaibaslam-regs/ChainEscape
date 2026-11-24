class_name SplashScreen
extends Control
## Animated intro shown once on cold start (approved design: "Splash ·
## gold & obsidian"). It continues from the boot image (spotlight only): the
## dial rings fade in, the steel and gold links fly in from the left and right
## screen edges, speed into each other and attach with a recoil, a flash and
## a metallic clink, tug once, the gold arrow breaks out, then the title
## appears with a glint.
## Tap anywhere to skip. Emits [signal finished] exactly once.

signal finished

## Timeline in seconds from the start of the intro.
const LINKS_IN_END := 0.55
const JOIN_TIME := 0.55
const TUG_TIME := 0.72
const ARROW_START := 0.86
const ARROW_DURATION := 0.28
const GLOW_PEAK_TIME := 1.06
const TITLE_START := 1.12
const GLINT_START := 1.27
const GLINT_DURATION := 0.6
const TAGLINE_START := 1.27
const FINISH_TIME := 2.05

## Extra distance beyond the screen edge where the links start.
const LINK_START_MARGIN := 40.0
const LINK_FADE_SECONDS := 0.15
## How far each link bounces back on impact.
const RECOIL_DISTANCE := 6.0
const TUG_DISTANCE := 5.0
const ARROW_START_OFFSET := Vector2(-44.0, 44.0)
const TITLE_RISE := 24.0

@onready var _dial_rings: Control = %DialRings
@onready var _mark: Control = %Mark
@onready var _left_link: TextureRect = %LeftLink
@onready var _right_link: TextureRect = %RightLink
@onready var _weave: TextureRect = %Weave
@onready var _join_flash: TextureRect = %JoinFlash
@onready var _arrow: TextureRect = %Arrow
@onready var _sparks: TextureRect = %Sparks
@onready var _glow: TextureRect = %Glow
@onready var _title: Label = %Title
@onready var _tagline: Label = %Tagline

var _tween: Tween
var _is_finished: bool = false
var _feedback: Feedback


## With reduced motion the finished frame is shown, held briefly, then ends.
const REDUCED_MOTION_HOLD_SECONDS := 0.6


func _ready() -> void:
	_title.resized.connect(_sync_title_shader_size)
	_sync_title_shader_size()
	play()


## Restarts the intro from the first frame (or shows the still version).
## [param feedback] plays the clink when the links attach (optional).
func play(reduced_motion: bool = false, feedback: Feedback = null) -> void:
	_kill_tween()
	_is_finished = false
	_feedback = feedback
	if reduced_motion:
		_show_final_frame()
		_tween = create_tween()
		_tween.tween_callback(_finish).set_delay(REDUCED_MOTION_HOLD_SECONDS)
		return
	_set_start_state()
	var mark_x := _mark.position.x
	var title_y := _title.position.y
	_title.position.y = title_y + TITLE_RISE

	_tween = create_tween().set_parallel()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_dial_rings, "modulate:a", 1.0, LINKS_IN_END)
	# 1. The links fly in from the screen edges, speeding into each other,
	#    and recoil slightly on impact.
	for link: TextureRect in [_left_link, _right_link]:
		var side := -1.0 if link == _left_link else 1.0
		_tween.tween_property(link, "position:x", 0.0, LINKS_IN_END) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(link, "modulate:a", 1.0, LINK_FADE_SECONDS)
		_tween.tween_property(link, "position:x", side * RECOIL_DISTANCE, 0.05).set_delay(JOIN_TIME)
		_tween.tween_property(link, "position:x", 0.0, 0.14).set_delay(JOIN_TIME + 0.05) \
			.set_trans(Tween.TRANS_BACK)
	_tween.tween_callback(_play_clink).set_delay(JOIN_TIME)
	# 2. They interlock: the weave appears with a soft flash at the joint.
	_tween.tween_property(_weave, "modulate:a", 1.0, 0.02).set_delay(JOIN_TIME)
	_tween.tween_property(_join_flash, "modulate:a", 1.0, 0.06).set_delay(JOIN_TIME)
	_tween.tween_property(_join_flash, "scale", Vector2.ONE * 1.5, 0.3).set_delay(JOIN_TIME)
	_tween.tween_property(_join_flash, "modulate:a", 0.0, 0.22).set_delay(JOIN_TIME + 0.08)
	# 3. One tug.
	_tween.tween_property(_mark, "position:x", mark_x - TUG_DISTANCE, 0.06).set_delay(TUG_TIME)
	_tween.tween_property(_mark, "position:x", mark_x + TUG_DISTANCE * 0.4, 0.07).set_delay(TUG_TIME + 0.06)
	_tween.tween_property(_mark, "position:x", mark_x, 0.08).set_delay(TUG_TIME + 0.13)
	# 4. The arrow breaks out, with sparks and a glow.
	_tween.tween_property(_arrow, "position", Vector2.ZERO, ARROW_DURATION).set_delay(ARROW_START) \
		.set_trans(Tween.TRANS_EXPO)
	_tween.tween_property(_arrow, "scale", Vector2.ONE, ARROW_DURATION).set_delay(ARROW_START) \
		.set_trans(Tween.TRANS_EXPO)
	_tween.tween_property(_arrow, "modulate:a", 1.0, 0.08).set_delay(ARROW_START)
	_tween.tween_property(_sparks, "modulate:a", 1.0, 0.05).set_delay(ARROW_START + 0.14)
	_tween.tween_property(_sparks, "scale", Vector2.ONE * 1.3, 0.4).set_delay(ARROW_START + 0.14)
	_tween.tween_property(_sparks, "modulate:a", 0.0, 0.3).set_delay(ARROW_START + 0.24)
	_tween.tween_property(_glow, "modulate:a", 1.0, GLOW_PEAK_TIME - ARROW_START).set_delay(ARROW_START)
	_tween.tween_property(_glow, "modulate:a", 0.35, 0.4).set_delay(GLOW_PEAK_TIME)
	# 5. Title rises in, a glint sweeps across it, then the tagline.
	_tween.tween_property(_title, "modulate:a", 1.0, 0.3).set_delay(TITLE_START)
	_tween.tween_property(_title, "position:y", title_y, 0.3).set_delay(TITLE_START)
	_tween.tween_method(_set_glint, -0.3, 1.3, GLINT_DURATION).set_delay(GLINT_START) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_tagline, "modulate:a", 1.0, 0.3).set_delay(TAGLINE_START)
	_tween.tween_callback(_finish).set_delay(FINISH_TIME)


## Ends the intro immediately (tap to skip).
func skip() -> void:
	_finish()


## Android back skips the intro.
func handle_back() -> bool:
	skip()
	return true


func is_finished() -> bool:
	return _is_finished


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accept_event()
		skip()


func _set_start_state() -> void:
	_dial_rings.modulate.a = 0.0
	var slide := link_slide_distance()
	_left_link.position.x = -slide
	_right_link.position.x = slide
	_left_link.modulate.a = 0.0
	_right_link.modulate.a = 0.0
	_weave.modulate.a = 0.0
	_join_flash.modulate.a = 0.0
	_join_flash.scale = Vector2.ONE * 0.4
	_arrow.position = ARROW_START_OFFSET
	_arrow.scale = Vector2.ONE * 0.7
	_arrow.modulate.a = 0.0
	_sparks.modulate.a = 0.0
	_sparks.scale = Vector2.ONE * 0.6
	_glow.modulate.a = 0.0
	_title.modulate.a = 0.0
	_tagline.modulate.a = 0.0
	_set_glint(-0.3)


## How far each link starts from its resting place: far enough to be fully
## off-screen on any width (phones, tablets, desktop windows).
func link_slide_distance() -> float:
	return get_viewport_rect().size.x * 0.5 + _mark.size.x * 0.5 + LINK_START_MARGIN


func _play_clink() -> void:
	if _feedback != null:
		_feedback.play(Feedback.Sound.LINK_JOIN)


func _show_final_frame() -> void:
	for node: CanvasItem in [_dial_rings, _left_link, _right_link, _weave, _arrow, _title, _tagline]:
		node.modulate.a = 1.0
	_left_link.position.x = 0.0
	_right_link.position.x = 0.0
	_arrow.position = Vector2.ZERO
	_arrow.scale = Vector2.ONE
	_join_flash.modulate.a = 0.0
	_sparks.modulate.a = 0.0
	_glow.modulate.a = 0.35
	_set_glint(-0.3)


func _set_glint(value: float) -> void:
	var material := _title.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("glint_position", value)


func _sync_title_shader_size() -> void:
	var material := _title.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("rect_size", _title.size)


func _finish() -> void:
	if _is_finished:
		return
	_is_finished = true
	_kill_tween()
	finished.emit()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
