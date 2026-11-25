class_name SplashScreen
extends Control
## The splash: the app icon's "padlock escape" told as a short story on
## Home's black stage (slow gold rays and dust). A chain slides in, a padlock
## drops onto it, the gold arrow appears caught behind it, then the lock
## springs open, a link breaks and the arrow shoots free; the title rises.
## Each step has its own sound. Tap to skip. The same emblem plays the
## escape on Level complete.

signal finished

## The emblem fills this share of the screen width, centred a little high.
const STAGE_WIDTH := 0.86
const STAGE_CENTER_Y := 0.40
const TITLE_START := UnlockSeal.ESCAPE_AT + 0.3
const FINISH_TIME := TITLE_START + 1.05
const REDUCED_MOTION_HOLD_SECONDS := 0.6

var _emblem := UnlockSeal.new()
var _rays: HomeBackdrop
var _title := MetalLabel.new()
var _tagline := Label.new()
var _tween: Tween
var _feedback: Feedback
var _is_finished: bool = false
var _played: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The same stage as Home: black background, gold rays and dust.
	var background := (load("res://scenes/ui/screen_background.tscn") as PackedScene).instantiate() as Control
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays = HomeBackdrop.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)
	add_child(_emblem)
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


func _autoplay() -> void:
	if not _played:
		play()


## Restarts the splash (or shows the finished picture with Reduce motion).
func play(reduced_motion: bool = false, feedback: Feedback = null) -> void:
	_played = true
	_kill_tween()
	_is_finished = false
	_feedback = feedback
	_layout()
	_title.modulate.a = 0.0
	_tagline.modulate.a = 0.0
	_tween = create_tween().set_parallel()
	if reduced_motion:
		_emblem.show_final()
		_title.modulate.a = 1.0
		_tagline.modulate.a = 1.0
		_tween.tween_interval(REDUCED_MOTION_HOLD_SECONDS)
		_tween.chain().tween_callback(_finish)
		return
	_emblem.play_story(feedback)
	var rest_y := _title.position.y
	_title.position.y = rest_y + 30.0
	_tween.tween_property(_title, "modulate:a", 1.0, 0.35).set_delay(TITLE_START)
	_tween.tween_property(_title, "position:y", rest_y, 0.45).set_delay(TITLE_START).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_tagline, "modulate:a", 1.0, 0.4).set_delay(TITLE_START + 0.25)
	_tween.tween_callback(_play.bind(Feedback.Sound.TITLE_CHIME)).set_delay(TITLE_START)
	_tween.tween_callback(_title.play_glint.bind(0.7)).set_delay(TITLE_START + 0.3)
	_tween.tween_callback(_finish).set_delay(FINISH_TIME)


func skip() -> void:
	_kill_tween()
	_emblem.show_final()
	_title.modulate.a = 1.0
	_tagline.modulate.a = 1.0
	_layout()
	_finish()


func handle_back() -> bool:
	skip()
	return true


func is_finished() -> bool:
	return _is_finished


## Emblem layers for tests: "arrow", "chain", "chain_link", "lock_body",
## "shackle_closed", "shackle_open".
func get_layer(layer_name: String) -> Control:
	return _emblem.get_layer(layer_name)


func get_emblem() -> UnlockSeal:
	return _emblem


## Stops the animation and its sounds immediately (Main calls this when it
## switches to another screen).
func dismiss() -> void:
	_kill_tween()
	_feedback = null
	_played = true
	_emblem.show_final()


func _exit_tree() -> void:
	_kill_tween()
	_feedback = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _is_finished:
		accept_event()
		skip()


func _layout() -> void:
	var side := size.x * STAGE_WIDTH
	_emblem.size = Vector2(side, side)
	_emblem.position = Vector2((size.x - side) * 0.5, size.y * STAGE_CENTER_Y - side * 0.5)
	var title_y := _emblem.position.y + side * 0.92
	_title.size = Vector2(size.x, 110)
	_title.position = Vector2(0, title_y)
	_tagline.size = Vector2(size.x, 50)
	_tagline.position = Vector2(0, title_y + 104)
	_rays.focus = _emblem.position + Vector2(0.53, 0.55) * side


func _play(sound: Feedback.Sound) -> void:
	if _feedback != null:
		_feedback.play(sound)


func _finish() -> void:
	if _is_finished:
		return
	_is_finished = true
	finished.emit()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
