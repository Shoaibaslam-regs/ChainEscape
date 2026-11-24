class_name PraisePopup
extends MetalLabel
## A big gold praise word ("NICE!", "SWEET!"…) that pops in over the board,
## rises a little and fades out. Ignores input so play continues underneath.

const POP_SECONDS := 0.18
const HOLD_SECONDS := 0.35
const FADE_SECONDS := 0.3
const RISE_PIXELS := 48.0
const MAX_FONT_SIZE := 92
const MIN_FONT_SIZE := 48
## Keep the word inside the screen with this much room on each side.
const SIDE_MARGIN := 32.0

var _tween: Tween
var _rest_y: float = 0.0


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_praise(word: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		position.y = _rest_y
	_rest_y = position.y
	text = word
	_fit_font_size(word)
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 0.6
	modulate.a = 1.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "glint", 1.3, POP_SECONDS + HOLD_SECONDS).from(-0.3)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.parallel().tween_property(self, "position:y", _rest_y - RISE_PIXELS, FADE_SECONDS)
	_tween.tween_callback(_finish)


## Shrinks long words (e.g. "UNSTOPPABLE!") so they fit the screen width.
func _fit_font_size(word: String) -> void:
	var font := get_theme_font("font")
	var available := get_viewport_rect().size.x - SIDE_MARGIN * 2.0
	var font_size := MAX_FONT_SIZE
	while font_size > MIN_FONT_SIZE and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 4
	add_theme_font_size_override("font_size", font_size)


func get_font_size() -> int:
	return get_theme_font_size("font_size")


func _finish() -> void:
	hide()
	position.y = _rest_y
