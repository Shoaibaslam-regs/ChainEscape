class_name OutOfMovesPanel
extends Control
## Shown when the level's wrong moves are used up: restart for free, or
## watch a rewarded ad for one more move (only offered when an ad is ready).

signal restart_requested
signal extra_move_requested
signal home_requested

@onready var _card: PanelContainer = %Card
@onready var _caption: Label = %Caption
@onready var _watch_button: Button = %WatchButton
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	hide()
	_card.add_theme_stylebox_override("panel", _card_style())
	_watch_button.pressed.connect(_on_watch)
	_restart_button.pressed.connect(restart_requested.emit)
	%HomeButton.pressed.connect(home_requested.emit)


func open(limit: int, ad_available: bool) -> void:
	_caption.text = "You used all %d wrong moves on this level." % limit
	_watch_button.visible = ad_available
	_watch_button.disabled = false
	_watch_button.text = "WATCH AD · +1 MOVE"
	show()
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.9
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The ad could not be shown: say so and leave Restart.
func show_ad_unavailable() -> void:
	_watch_button.visible = false
	_caption.text = "No ad is available right now. Restart and try again."


func close() -> void:
	hide()


func get_watch_button() -> Button:
	return _watch_button


func get_restart_button() -> Button:
	return _restart_button


func _on_watch() -> void:
	_watch_button.disabled = true
	_watch_button.text = "LOADING AD…"
	extra_move_requested.emit()


static func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.SURFACE
	box.border_color = Color(Palette.CORAL, 0.7)
	box.set_border_width_all(3)
	box.set_corner_radius_all(44)
	box.content_margin_left = 44
	box.content_margin_right = 44
	box.content_margin_top = 44
	box.content_margin_bottom = 40
	box.shadow_color = Color(Palette.CORAL, 0.12)
	box.shadow_size = 24
	box.anti_aliasing = true
	return box
