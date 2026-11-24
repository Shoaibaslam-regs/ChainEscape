class_name MetalLabel
extends Label
## A label filled with polished gold (assets/shaders/metal_text.gdshader)
## with an optional moving glint. Used for the game's big titles.

const SHADER := preload("res://assets/shaders/metal_text.gdshader")

## Position of the glint band, about -0.3 (off left) to 1.3 (off right).
var glint: float = -0.3:
	set(value):
		glint = value
		if _material != null:
			_material.set_shader_parameter("glint_position", value)

var _material: ShaderMaterial


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	glint = glint
	resized.connect(_sync_size)
	_sync_size()


## Sweeps the glint across once.
func play_glint(duration: float = 0.6, delay: float = 0.0) -> Tween:
	glint = -0.3
	var tween := create_tween()
	tween.tween_property(self, "glint", 1.3, duration).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func _sync_size() -> void:
	_material.set_shader_parameter("rect_size", size)
