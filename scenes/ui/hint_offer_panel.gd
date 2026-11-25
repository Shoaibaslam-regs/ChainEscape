class_name HintOfferPanel
extends Control
## Out of hints: offers one more hint for watching a short video. Always
## optional ("Not now" goes straight back to the level); says so plainly
## when no video is available.

signal watch_requested
signal closed

const BULB := preload("res://assets/icons/hint.svg")

var _card := PanelContainer.new()
var _caption := Label.new()
var _watch_button := Button.new()
var _later_button := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	column.custom_minimum_size = Vector2(540, 0)
	_card.add_child(column)
	var icon := TextureRect.new()
	icon.texture = BULB
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0, 110)
	column.add_child(icon)
	var title := Label.new()
	title.text = "OUT OF HINTS"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_caption.theme_type_variation = &"CaptionLabel"
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_caption)
	_watch_button.theme_type_variation = &"PrimaryButton"
	_watch_button.custom_minimum_size = Vector2(0, 110)
	_watch_button.text = "WATCH VIDEO · +1 HINT"
	_watch_button.pressed.connect(_on_watch)
	column.add_child(_watch_button)
	_later_button.theme_type_variation = &"FlatButton"
	_later_button.custom_minimum_size = Vector2(0, 80)
	_later_button.text = "Not now"
	_later_button.pressed.connect(close)
	column.add_child(_later_button)


## [param can_watch]: a video is available and today's limit is not reached.
## [param reason] explains why not, when it can't.
func open(can_watch: bool, reason: String = "") -> void:
	_watch_button.visible = can_watch
	_watch_button.disabled = false
	_caption.text = "Watch a short video to get 1 hint." if can_watch else reason
	show()
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.9
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The video could not be shown: say so plainly, nothing frozen.
func show_unavailable() -> void:
	_watch_button.visible = false
	_caption.text = "No video available right now. Try again later."


func close() -> void:
	if visible:
		hide()
		closed.emit()


func get_watch_button() -> Button:
	return _watch_button


func get_caption_text() -> String:
	return _caption.text


func _on_watch() -> void:
	_watch_button.disabled = true
	watch_requested.emit()


static func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.SURFACE
	box.border_color = Palette.GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(44)
	box.content_margin_left = 44
	box.content_margin_right = 44
	box.content_margin_top = 40
	box.content_margin_bottom = 36
	box.shadow_color = Color(Palette.GOLD, 0.15)
	box.shadow_size = 24
	box.anti_aliasing = true
	return box
