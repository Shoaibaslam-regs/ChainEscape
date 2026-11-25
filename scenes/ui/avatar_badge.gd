class_name AvatarBadge
extends Control
## The player's avatar inside a frame: a coloured disc with the avatar
## glyph, ringed by the frame. Frames are drawn here (crisp at any size);
## glyphs come from assets/avatars. Takes no touches.

const FRAME_COLORS := {
	"steel": [Color("E6EBF2"), Color("8C97AB"), Color("4E5666")],
	"bronze": [Color("F2C29A"), Color("C9804A"), Color("6E3F1F")],
	"silver": [Color("FFFFFF"), Color("C9D2E0"), Color("7D879A")],
	"gold": [Color("FFF0BF"), Color("E8B04A"), Color("9C6B1C")],
	"chain": [Color("E6EBF2"), Color("8C97AB"), Color("4E5666")],
	"vault": [Color("FFF0BF"), Color("E8B04A"), Color("9C6B1C")],
	"emerald": [Color("B8F5D8"), Color("3FCF8E"), Color("1C6E4A")],
}
const RING_SHARE := 0.15

var avatar_id: String = ProfileItems.DEFAULT_AVATAR:
	set(value):
		avatar_id = value
		_texture = ProfileItems.avatar_texture(value)
		queue_redraw()
var frame_id: String = ProfileItems.DEFAULT_FRAME:
	set(value):
		frame_id = value
		queue_redraw()

var _texture: Texture2D = ProfileItems.avatar_texture(ProfileItems.DEFAULT_AVATAR)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func set_profile(p_avatar_id: String, p_frame_id: String) -> void:
	avatar_id = p_avatar_id
	frame_id = p_frame_id


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	if radius < 4.0:
		return
	var center := size * 0.5
	var ring := radius * RING_SHARE
	var inner := radius - ring
	var avatar := ProfileItems.find(ProfileItems.AVATARS, avatar_id)
	var disc: Color = avatar.get("color", Palette.WORKBENCH)
	# Disc with a soft top light.
	draw_circle(center, inner, disc.darkened(0.25))
	draw_circle(center - Vector2(0, inner * 0.18), inner * 0.82, disc)
	if _texture != null:
		var glyph := inner * 1.36
		draw_texture_rect(_texture, Rect2(center - Vector2(glyph, glyph) * 0.5, Vector2(glyph, glyph)), false)
	_draw_frame(center, radius, ring)


func _draw_frame(center: Vector2, radius: float, ring: float) -> void:
	var style: String = ProfileItems.find(ProfileItems.FRAMES, frame_id).get("style", "steel")
	var colors: Array = FRAME_COLORS.get(style, FRAME_COLORS["steel"])
	var light: Color = colors[0]
	var mid: Color = colors[1]
	var dark: Color = colors[2]
	var middle := radius - ring * 0.5
	draw_arc(center, middle, 0.0, TAU, 96, mid, ring, true)
	# Lit from above, shaded below.
	draw_arc(center, middle, PI * 1.08, PI * 1.92, 48, light, ring * 0.45, true)
	draw_arc(center, middle, PI * 0.12, PI * 0.88, 48, dark, ring * 0.45, true)
	draw_arc(center, radius - 1.0, 0.0, TAU, 96, Palette.OBSIDIAN, 2.5, true)
	draw_arc(center, radius - ring + 1.0, 0.0, TAU, 96, Palette.OBSIDIAN, 2.5, true)
	match style:
		"chain":
			for i: int in 12:
				var angle := TAU * i / 12.0
				var at := center + Vector2.from_angle(angle) * middle
				draw_circle(at, ring * 0.42, Palette.OBSIDIAN)
				draw_arc(at, ring * 0.3, 0.0, TAU, 16, light, ring * 0.16, true)
		"vault":
			for i: int in 8:
				var at := center + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * middle
				draw_circle(at, ring * 0.24, dark)
				draw_circle(at - Vector2(ring, ring) * 0.06, ring * 0.14, light)
		"emerald":
			draw_arc(center, radius - ring - 2.0, 0.0, TAU, 96, Palette.GOLD, 2.0, true)
			var top := center - Vector2(0, middle)
			var gem := ring * 0.9
			var points := PackedVector2Array([top + Vector2(0, -gem), top + Vector2(gem * 0.8, 0), top + Vector2(0, gem), top + Vector2(-gem * 0.8, 0)])
			draw_colored_polygon(points, light)
			points.append(points[0])
			draw_polyline(points, Palette.OBSIDIAN, 2.0, true)
