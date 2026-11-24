class_name GameTheme
extends RefCounted
## Builds the single Theme every screen inherits from Main.
##
## Sizes are for the 720×1280 base resolution. Label styles are theme type
## variations, so a scene picks one with `theme_type_variation` instead of
## overriding fonts and colours per node.

const FONT_PATH := "res://assets/fonts/Cairo-Variable.ttf"

const SIZE_DISPLAY := 84
const SIZE_TITLE := 48
const SIZE_HEADING := 38
const SIZE_BODY := 30
const SIZE_CAPTION := 26
const SIZE_OVERLINE := 22
const SIZE_BUTTON := 32

const BUTTON_RADIUS := 28
const PRIMARY_RADIUS := 36
const CARD_RADIUS := 32
const ICON_BUTTON_SIZE := 88
const TOGGLE_ON := "res://assets/icons/toggle_on.svg"
const TOGGLE_OFF := "res://assets/icons/toggle_off.svg"

static var _cached: Theme


## Returns the shared theme, building it on first use.
static func get_theme() -> Theme:
	if _cached == null:
		_cached = _build()
	return _cached


## A Cairo face at [param weight] (100–900) with optional extra letter spacing.
static func font(weight: int, letter_spacing: int = 0) -> Font:
	var base: FontFile = load(FONT_PATH)
	if base == null:
		push_error("GameTheme: missing font %s" % FONT_PATH)
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	variation.spacing_glyph = letter_spacing
	return variation


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(500)
	theme.default_font_size = SIZE_BODY

	theme.set_color("font_color", "Label", Palette.TEXT)
	_add_label_style(theme, "DisplayLabel", 900, SIZE_DISPLAY, Palette.TEXT, 6)
	_add_label_style(theme, "TitleLabel", 900, SIZE_TITLE, Palette.TEXT, 2)
	_add_label_style(theme, "HeadingLabel", 800, SIZE_HEADING, Palette.TEXT, 0)
	_add_label_style(theme, "CaptionLabel", 600, SIZE_CAPTION, Palette.TEXT_SECONDARY, 0)
	_add_label_style(theme, "OverlineLabel", 800, SIZE_OVERLINE, Palette.GOLD, 4)

	_style_button(theme, "Button", Palette.SURFACE, Palette.TEXT, Palette.GOLD_OUTLINE, BUTTON_RADIUS)
	theme.set_type_variation("PrimaryButton", "Button")
	_style_button(theme, "PrimaryButton", Palette.GOLD, Palette.GOLD_INK, Color.TRANSPARENT, PRIMARY_RADIUS)
	theme.set_type_variation("IconButton", "Button")
	_style_button(theme, "IconButton", Palette.SURFACE, Palette.GOLD, Palette.GOLD_OUTLINE, 26, Vector4(22, 22, 22, 22))
	theme.set_type_variation("FlatButton", "Button")
	_style_button(theme, "FlatButton", Color.TRANSPARENT, Palette.TEXT_SECONDARY, Color.TRANSPARENT, BUTTON_RADIUS)
	theme.set_type_variation("DangerButton", "Button")
	_style_button(theme, "DangerButton", Palette.SURFACE, Color("F08A7F"), Color(Palette.CORAL, 0.35), BUTTON_RADIUS)
	theme.set_constant("icon_max_width", "Button", 40)
	theme.set_constant("h_separation", "Button", 16)

	_add_panel_style(theme, "ChipPanel", _box(Palette.SURFACE, Color(1, 1, 1, 0.06), 34, 2, Vector4(26, 10, 26, 10)))
	_add_panel_style(theme, "CardPanel", _box(Palette.WORKBENCH, Color(1, 1, 1, 0.04), CARD_RADIUS, 2, Vector4(32, 28, 32, 28)))
	var sheet := _box(Palette.WORKBENCH, Palette.GOLD_OUTLINE, 52, 2, Vector4(48, 28, 48, 56))
	sheet.corner_radius_bottom_left = 0
	sheet.corner_radius_bottom_right = 0
	sheet.border_width_bottom = 0
	_add_panel_style(theme, "SheetPanel", sheet)

	theme.set_stylebox("background", "ProgressBar", _box(Palette.CELL, Color.TRANSPARENT, 8, 0, Vector4.ZERO))
	theme.set_stylebox("fill", "ProgressBar", _box(Palette.GOLD, Color.TRANSPARENT, 8, 0, Vector4.ZERO))
	theme.set_constant("outline_size", "ProgressBar", 0)

	theme.set_font("font", "CheckButton", font(700))
	theme.set_font_size("font_size", "CheckButton", SIZE_BODY)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "CheckButton", Palette.TEXT)
	var toggle_on: Texture2D = load(TOGGLE_ON)
	var toggle_off: Texture2D = load(TOGGLE_OFF)
	for icon_name: String in ["checked", "checked_disabled", "checked_mirrored"]:
		theme.set_icon(icon_name, "CheckButton", toggle_on)
	for icon_name: String in ["unchecked", "unchecked_disabled", "unchecked_mirrored"]:
		theme.set_icon(icon_name, "CheckButton", toggle_off)
	for box_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		theme.set_stylebox(box_name, "CheckButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(0, 18, 0, 18)))
	return theme


static func _add_label_style(theme: Theme, type_name: StringName, weight: int, size: int, color: Color, spacing: int) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_font("font", type_name, font(weight, spacing))
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, color)


static func _add_panel_style(theme: Theme, type_name: StringName, box: StyleBoxFlat) -> void:
	theme.set_type_variation(type_name, "PanelContainer")
	theme.set_stylebox("panel", type_name, box)


static func _style_button(theme: Theme, type_name: StringName, fill: Color, text: Color, outline: Color, radius: int, margins: Vector4 = Vector4(32, 16, 32, 16)) -> void:
	theme.set_font("font", type_name, font(800, 1))
	theme.set_font_size("font_size", type_name, SIZE_BUTTON)
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, type_name, text)
	theme.set_color("font_pressed_color", type_name, text.darkened(0.15))
	theme.set_color("font_disabled_color", type_name, Color(text, 0.4))
	theme.set_stylebox("normal", type_name, _box(fill, outline, radius, 2, margins))
	theme.set_stylebox("hover", type_name, _box(fill.lightened(0.06), outline, radius, 2, margins))
	theme.set_stylebox("pressed", type_name, _box(fill.darkened(0.12), outline, radius, 2, margins))
	theme.set_stylebox("focus", type_name, _box(Color.TRANSPARENT, Color(Palette.GOLD, 0.6), radius, 3, margins))
	theme.set_stylebox("disabled", type_name, _box(Color(fill, 0.45), Color(outline, outline.a * 0.5), radius, 2, margins))


## A rounded box; [param margins] is (left, top, right, bottom).
static func _box(fill: Color, outline: Color, radius: int, outline_width: int = 2, margins: Vector4 = Vector4(32, 16, 32, 16)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.corner_detail = 8
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	if outline.a > 0.0:
		box.border_color = outline
		box.set_border_width_all(outline_width)
	box.anti_aliasing = true
	return box
