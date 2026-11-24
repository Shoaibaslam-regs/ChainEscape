class_name AchievementPanel
extends Control
## "Achievement unlocked": the badge, progress toward the next tier and the
## achievements the player is closest to. Shown after Level complete, only
## when something unlocked.

signal continue_requested

const NEARBY_COUNT := 2

@onready var _badge: TextureRect = %Badge
@onready var _title: MetalLabel = %Title
@onready var _description: Label = %Description
@onready var _next_tier_card: Control = %NextTierCard
@onready var _next_tier_name: Label = %NextTierName
@onready var _next_tier_count: Label = %NextTierCount
@onready var _next_tier_bar: ProgressBar = %NextTierBar
@onready var _nearby_heading: Label = %NearbyHeading
@onready var _nearby_list: VBoxContainer = %NearbyList
@onready var _continue_label: Label = %ContinueLevelLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	hide()
	_continue_button.pressed.connect(continue_requested.emit)


## [param continue_caption] is the small line under CONTINUE, e.g. "LEVEL 28".
func open(definition: Dictionary, tracker: AchievementTracker, continue_caption: String) -> void:
	_title.text = String(definition["title"]).to_upper()
	_description.text = definition["description"]
	_continue_label.text = continue_caption

	var next := tracker.next_tier(definition)
	_next_tier_card.visible = not next.is_empty()
	if not next.is_empty():
		_next_tier_name.text = "Next: %s" % next["title"]
		_next_tier_count.text = "%d / %d" % [mini(tracker.get_stat(next["stat"]), next["goal"]), next["goal"]]
		_next_tier_bar.value = tracker.get_progress(next) * 100.0

	for child: Node in _nearby_list.get_children():
		child.queue_free()
	var nearby := tracker.closest_locked(NEARBY_COUNT).filter(func(d: Dictionary) -> bool: return d["stat"] != definition["stat"])
	_nearby_heading.visible = not nearby.is_empty()
	for other: Dictionary in nearby:
		_nearby_list.add_child(_make_row(other, tracker))

	show()
	modulate.a = 0.0
	_badge.pivot_offset = _badge.size * 0.5
	_badge.scale = Vector2.ONE * 0.5
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(_badge, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title.play_glint(0.7, 0.3)


func close() -> void:
	hide()


func get_title_text() -> String:
	return _title.text


func get_continue_button() -> Button:
	return _continue_button


func _make_row(definition: Dictionary, tracker: AchievementTracker) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var name_label := Label.new()
	name_label.text = definition["title"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_override("font", GameTheme.font(800))
	header.add_child(name_label)
	var count_label := Label.new()
	count_label.theme_type_variation = &"CaptionLabel"
	count_label.text = "%d / %d" % [mini(tracker.get_stat(definition["stat"]), definition["goal"]), definition["goal"]]
	header.add_child(count_label)
	var goal_label := Label.new()
	goal_label.theme_type_variation = &"CaptionLabel"
	goal_label.text = definition["description"]
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(goal_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.value = tracker.get_progress(definition) * 100.0
	bar.add_theme_stylebox_override("fill", _steel_fill())
	column.add_child(bar)
	return card


static func _steel_fill() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.STEEL
	box.set_corner_radius_all(8)
	return box
