class_name PraisePopup
extends MetalLabel
## A small gold word ("Nice!", "Sweet!"...) that rises softly from the arrow
## just released and fades away. It belongs to the move, never covers the
## board, and ignores input so play continues underneath.

const IN_SECONDS := 0.14
const RISE_SECONDS := 0.9
const FADE_DELAY := 0.45
const FADE_SECONDS := 0.4
const RISE_PIXELS := 64.0
## Starts this far above the arrow, so the word never hides it.
const START_OFFSET := 36.0
const MAX_FONT_SIZE := 44
const MIN_FONT_SIZE := 30
const SIDE_MARGIN := 24.0

var _tween: Tween


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_theme_font_override("font", GameTheme.font(700))
	hide()


## Shows [param word] rising from [param at] (in the parent's coordinates);
## without a point it appears in the upper middle of the screen.
func show_praise(word: String, at: Vector2 = Vector2.INF) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	text = word.capitalize() if word == word.to_upper() else word
	_fit_font_size(text)
	reset_size()
	size = get_combined_minimum_size()
	var screen := get_viewport_rect().size
	var anchor := at if at != Vector2.INF else Vector2(screen.x * 0.5, screen.y * 0.35)
	var start := anchor - size * 0.5 - Vector2(0.0, START_OFFSET)
	start.x = clampf(start.x, SIDE_MARGIN, maxf(SIDE_MARGIN, screen.x - size.x - SIDE_MARGIN))
	start.y = maxf(start.y, SIDE_MARGIN)
	position = start
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 0.8
	modulate.a = 0.0
	show()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, IN_SECONDS)
	_tween.tween_property(self, "scale", Vector2.ONE, IN_SECONDS * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", start.y - RISE_PIXELS, RISE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "glint", 1.3, RISE_SECONDS).from(-0.3)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS).set_delay(FADE_DELAY)
	_tween.chain().tween_callback(hide)


## Shrinks long words (e.g. "Unstoppable!") so they fit the screen width.
func _fit_font_size(word: String) -> void:
	var font := get_theme_font("font")
	var available := get_viewport_rect().size.x - SIDE_MARGIN * 2.0
	var font_size := MAX_FONT_SIZE
	while font_size > MIN_FONT_SIZE and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 2
	add_theme_font_size_override("font_size", font_size)


func get_font_size() -> int:
	return get_theme_font_size("font_size")
