class_name SplashScreen
extends Control
## The splash, built from the app icon's picture in the game's own style, on
## Home's black stage with slow gold rays and dust: the gold arrow grows
## out of the centre, two steel chains slide in from the top and bottom and
## cross over it, the padlock drops onto the crossing and snaps shut, then
## the title rises in, each step with its own sound. Tap to skip.

signal finished

const LAYERS := ["glow", "arrow", "shackle", "chain_a", "chain_b", "lock"]
## Where the chains cross, in the 1024 px icon art.
const CROSSING := Vector2(515, 713)
const ART_SIZE := 1024.0
## The art fills this share of the screen width.
const STAGE_WIDTH := 0.7

const ARROW_START := 0.1
const ARROW_SECONDS := 0.5
const CHAINS_START := 0.6
const CHAIN_SECONDS := 0.38
const CHAIN_GAP := 0.12
const LOCK_START := 1.25
const LOCK_SECONDS := 0.34
const TITLE_START := 1.7
const FINISH_TIME := 2.7
const REDUCED_MOTION_HOLD_SECONDS := 0.6
## The padlock sound has a short latch slide before its snap: start it this
## much early so the snap lands with the lock.
const LOCK_SOUND_LEAD := 0.055

var _layers: Dictionary[String, TextureRect] = {}
var _stage := Control.new()
var _rays: HomeBackdrop
var _flash := TextureRect.new()
var _title := MetalLabel.new()
var _tagline := Label.new()
var _tween: Tween
var _feedback: Feedback
var _is_finished: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The same stage as Home: black background, gold rays and dust.
	var background := (load("res://scenes/ui/screen_background.tscn") as PackedScene).instantiate() as Control
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays = HomeBackdrop.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	for name: String in LAYERS:
		var layer := TextureRect.new()
		layer.texture = load("res://assets/brand/splash/%s.svg" % name)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(layer)
		_layers[name] = layer
	_flash.texture = _radial_texture([Color(1, 1, 1, 1), Color(1, 0.95, 0.7, 0.6), Color(1, 0.8, 0.3, 0)], [0.0, 0.35, 1.0], true)
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_flash)
	for label: Label in [_title, _tagline]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	# Title and tagline exactly as on Home.
	_title.text = "CHAIN ESCAPE"
	_title.theme_type_variation = &"DisplayLabel"
	_title.add_theme_font_size_override("font_size", 70)
	_tagline.text = "EVERY LOCK HAS A KEY"
	_tagline.theme_type_variation = &"OverlineLabel"
	_tagline.add_theme_color_override("font_color", Color(0.639, 0.675, 0.741, 0.8))
	resized.connect(_layout)
	_layout()
	# Starts by itself; Main calls play() again with its settings and sounds.
	_autoplay.call_deferred()


var _played: bool = false


func _autoplay() -> void:
	if not _played:
		play()


## Removed (e.g. skipped into Home): no late sounds or callbacks.
func _exit_tree() -> void:
	dismiss()


## Stops the animation and its sounds immediately (Main calls this when it
## switches to another screen).
func dismiss() -> void:
	_kill_tween()
	_feedback = null
	_played = true


## Restarts the animation (or shows the finished splash with Reduce motion).
func play(reduced_motion: bool = false, feedback: Feedback = null) -> void:
	_played = true
	_kill_tween()
	_feedback = feedback
	_is_finished = false
	_layout()
	if reduced_motion:
		_show_final()
		_tween = create_tween()
		_tween.tween_interval(REDUCED_MOTION_HOLD_SECONDS)
		_tween.tween_callback(_finish)
		return
	_set_start_state()
	var stage_h := _stage.size.y
	_tween = create_tween().set_parallel()
	_tween.tween_property(_rays, "modulate:a", 1.0, 0.6)
	# 1. The arrow grows out of the centre with a bounce.
	var arrow := _layers["arrow"]
	_tween.tween_property(arrow, "scale", Vector2.ONE, ARROW_SECONDS).set_delay(ARROW_START).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(arrow, "modulate:a", 1.0, 0.15).set_delay(ARROW_START)
	_tween.tween_property(_layers["glow"], "modulate:a", 1.0, 0.5).set_delay(ARROW_START + 0.1)
	_tween.tween_callback(_play.bind(Feedback.Sound.SPLASH_RISE)).set_delay(ARROW_START)
	# 2. One chain slides down from the top, the other up from the bottom.
	for index: int in 2:
		var chain := _layers["chain_a" if index == 0 else "chain_b"]
		var start := CHAINS_START + index * CHAIN_GAP
		_tween.tween_property(chain, "position:y", 0.0, CHAIN_SECONDS).set_delay(start).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(chain, "modulate:a", 1.0, 0.12).set_delay(start)
		_tween.tween_callback(_play.bind(Feedback.Sound.CHAIN_SLIDE)).set_delay(start)
		_tween.tween_callback(_play.bind(Feedback.Sound.LINK_JOIN)).set_delay(start + CHAIN_SECONDS * 0.7)
	_tween.tween_callback(_shake.bind(6.0)).set_delay(CHAINS_START + CHAIN_GAP + CHAIN_SECONDS * 0.7)
	# 3. The padlock drops onto the crossing and snaps shut with a flash.
	for name: String in ["shackle", "lock"]:
		var part := _layers[name]
		_tween.tween_property(part, "position:y", 0.0, LOCK_SECONDS).set_delay(LOCK_START).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(part, "modulate:a", 1.0, 0.1).set_delay(LOCK_START)
	_tween.tween_callback(_play.bind(Feedback.Sound.LOCK_SNAP)).set_delay(LOCK_START + LOCK_SECONDS * 0.6 - LOCK_SOUND_LEAD)
	_tween.tween_callback(_lock_snap).set_delay(LOCK_START + LOCK_SECONDS * 0.6)
	# 4. The title rises in.
	_tween.tween_property(_title, "modulate:a", 1.0, 0.35).set_delay(TITLE_START)
	_tween.tween_callback(_play.bind(Feedback.Sound.TITLE_CHIME)).set_delay(TITLE_START)
	_tween.tween_property(_title, "position:y", _title.position.y - 30.0, 0.45).set_delay(TITLE_START).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_tagline, "modulate:a", 1.0, 0.4).set_delay(TITLE_START + 0.25)
	_tween.tween_callback(_title.play_glint.bind(0.7)).set_delay(TITLE_START + 0.3)
	_tween.chain().tween_interval(maxf(0.0, FINISH_TIME - TITLE_START - 0.65))
	_tween.tween_callback(_finish)


func skip() -> void:
	_kill_tween()
	_show_final()
	_finish()


func handle_back() -> bool:
	skip()
	return true


func is_finished() -> bool:
	return _is_finished


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _is_finished:
		accept_event()
		skip()


func _layout() -> void:
	var side := size.x * STAGE_WIDTH
	_stage.size = Vector2(side, side)
	_stage.position = Vector2((size.x - side) * 0.5, size.y * 0.42 - side * 0.5)
	for layer: TextureRect in _layers.values():
		layer.size = _stage.size
		layer.pivot_offset = _stage.size * 0.5
	var flash_size := side * 0.5
	_flash.size = Vector2(flash_size, flash_size)
	_flash.pivot_offset = _flash.size * 0.5
	_flash.position = CROSSING / ART_SIZE * side - _flash.size * 0.5
	var title_y := _stage.position.y + side * 0.96
	_title.size = Vector2(size.x, 110)
	_title.position = Vector2(0, title_y)
	_tagline.size = Vector2(size.x, 50)
	_tagline.position = Vector2(0, title_y + 104)
	# Rays meet behind the arrow, like Home's rays behind its art.
	_rays.focus = _stage.position + Vector2(0.5, 0.42) * side


func _set_start_state() -> void:
	var stage_h := _stage.size.y
	_rays.modulate.a = 0.0
	for name: String in LAYERS:
		var layer := _layers[name]
		layer.modulate.a = 0.0
		layer.position = Vector2.ZERO
		layer.scale = Vector2.ONE
	_layers["arrow"].scale = Vector2.ONE * 0.15
	_layers["chain_a"].position.y = -stage_h * 1.1
	_layers["chain_b"].position.y = stage_h * 1.1
	_layers["shackle"].position.y = -stage_h * 0.55
	_layers["lock"].position.y = -stage_h * 0.55
	_flash.modulate.a = 0.0
	_title.modulate.a = 0.0
	_title.position.y += 30.0
	_tagline.modulate.a = 0.0


func _show_final() -> void:
	_layout()
	_rays.modulate.a = 1.0
	for layer: TextureRect in _layers.values():
		layer.modulate.a = 1.0
		layer.position = Vector2.ZERO
		layer.scale = Vector2.ONE
	_flash.modulate.a = 0.0
	_title.modulate.a = 1.0
	_tagline.modulate.a = 1.0


func _play(sound: Feedback.Sound) -> void:
	if _feedback != null:
		_feedback.play(sound)


## Layer access for tests: "arrow", "chain_a", "chain_b", "shackle", "lock".
func get_layer(layer_name: String) -> Control:
	return _layers[layer_name]


func _lock_snap() -> void:
	_shake(10.0)
	_flash.scale = Vector2.ONE * 0.3
	_flash.modulate.a = 1.0
	var flash := create_tween().set_parallel()
	flash.tween_property(_flash, "scale", Vector2.ONE * 1.4, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flash.tween_property(_flash, "modulate:a", 0.0, 0.45)


func _shake(strength: float) -> void:
	var shake := create_tween()
	var base := _stage.position
	for step: int in 4:
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - step * 0.25)
		shake.tween_property(_stage, "position", base + offset, 0.035)
	shake.tween_property(_stage, "position", base, 0.04)


func _finish() -> void:
	if _is_finished:
		return
	_is_finished = true
	finished.emit()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## [param round_glow]: centred and fully clear at the edges (no square corners).
static func _radial_texture(colors: Array, offsets: Array, round_glow: bool = false) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5) if round_glow else Vector2(0.5, 0.38)
	texture.fill_to = Vector2(1.0, 0.5) if round_glow else Vector2(1.15, 1.0)
	texture.width = 256
	texture.height = 256
	return texture
