class_name ShineSweep
extends Control
## A soft diagonal band of light that sweeps across its parent now and
## then (the Play button). The parent should clip its contents.

const BAND_WIDTH := 90.0
const SLANT := 60.0
const SWEEP_SECONDS := 0.9
const PAUSE_SECONDS := 4.0
const COLOR := Color(1, 1, 1, 0.28)

var _x: float = -200.0:
	set(value):
		_x = value
		queue_redraw()
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func start() -> void:
	stop()
	_tween = create_tween().set_loops()
	_tween.tween_interval(1.2)
	_tween.tween_callback(func() -> void: _x = -BAND_WIDTH - SLANT)
	_tween.tween_property(self, "_x", size.x + BAND_WIDTH, SWEEP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(PAUSE_SECONDS)


func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_x = -1000.0


func is_running() -> bool:
	return _tween != null and _tween.is_valid()


func _draw() -> void:
	if _x < -BAND_WIDTH * 4.0:
		return
	var h := size.y
	var mid := PackedVector2Array([Vector2(_x + SLANT, 0), Vector2(_x + SLANT + BAND_WIDTH * 0.5, 0), Vector2(_x + BAND_WIDTH * 0.5, h), Vector2(_x, h)])
	var clear := Color(COLOR, 0.0)
	draw_polygon(PackedVector2Array([Vector2(_x + SLANT - BAND_WIDTH * 0.5, 0), mid[0], mid[3], Vector2(_x - BAND_WIDTH * 0.5, h)]), PackedColorArray([clear, COLOR, COLOR, clear]))
	draw_polygon(PackedVector2Array([mid[0], Vector2(_x + SLANT + BAND_WIDTH, 0), Vector2(_x + BAND_WIDTH, h), mid[3]]), PackedColorArray([COLOR, clear, clear, COLOR]))
