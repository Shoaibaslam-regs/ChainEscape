class_name CompletePanel
extends Control
## Level cleared: open padlock, title, what the player did, then Next or Replay.

signal next_requested
signal home_requested
## Replay the level just finished, to earn the stars still missing.
signal retry_requested

const OPEN_SECONDS := 0.25
const STAR_FULL := preload("res://assets/icons/star_full.svg")
const STAR_EMPTY := preload("res://assets/icons/star_empty.svg")
## Stars start once the lock has opened and the chain is falling.
const STAR_FIRST_DELAY := 0.75
const STAR_STEP := 0.22

@onready var _padlock: UnlockSeal = %Padlock
@onready var _title: MetalLabel = %Title
@onready var _caption: Label = %Caption
@onready var _chains_chip: Control = %ChainsChip
@onready var _chains_label: Label = %ChainsLabel
@onready var _clean_chip: Control = %CleanChip
@onready var _seal_chip: Control = %SealChip
@onready var _seal_label: Label = %SealLabel
@onready var _next_label: Label = %NextLabel
@onready var _next_level_label: Label = %NextLevelLabel
@onready var _next_button: Button = %NextButton
@onready var _stars_row: HBoxContainer = %Stars
@onready var _upcoming: Label = %Upcoming

var _stars: int = 0
var _stars_tween: Tween


func _ready() -> void:
	hide()
	_next_button.pressed.connect(next_requested.emit)
	%HomeButton.pressed.connect(home_requested.emit)
	%RetryButton.pressed.connect(retry_requested.emit)


## [param was_challenge] / [param master_released] add the Vault seal and
## the "Master clear" title. [param stars] (1-3) fill in one by one;
## [param upcoming] is the countdown line, e.g. "NEXT VAULT IN 8".
func open(level_number: int, chains_broken: int, wrong_taps: int, was_challenge: bool = false, master_released: bool = false, stars: int = 0, upcoming: String = "") -> void:
	_stars = clampi(stars, 0, ProgressStore.MAX_STARS)
	_stars_row.visible = _stars > 0
	%RetryButton.visible = _stars > 0 and _stars < ProgressStore.MAX_STARS
	_upcoming.text = upcoming
	_upcoming.visible = not upcoming.is_empty()
	_title.text = "MASTER CLEAR" if master_released else "LEVEL %d CLEARED" % level_number
	if master_released:
		_caption.text = "Level %d · the master arrow set every arrow free." % level_number
	else:
		_caption.text = "You broke every chain." if chains_broken > 0 else "Every arrow escaped."
	_seal_chip.visible = was_challenge or master_released
	_seal_label.text = "MASTER SEAL" if master_released else "VAULT SEAL"
	_chains_chip.visible = chains_broken > 0
	_chains_label.text = "%d %s BROKEN" % [chains_broken, "CHAIN" if chains_broken == 1 else "CHAINS"]
	_clean_chip.visible = wrong_taps == 0
	_next_label.text = "NEXT LEVEL"
	_next_level_label.text = "LEVEL %d" % (level_number + 1)
	_play_entrance()


## A Daily or Weekly puzzle solved: its result, then back to its screen.
func open_challenge(mode: ChallengeMode, chains_broken: int, wrong_taps: int) -> void:
	_stars = 0
	_stars_row.visible = false
	%RetryButton.visible = false
	_upcoming.visible = false
	_title.text = mode.result_title()
	_caption.text = mode.result_caption(wrong_taps)
	_chains_chip.visible = chains_broken > 0
	_chains_label.text = "%d %s BROKEN" % [chains_broken, "CHAIN" if chains_broken == 1 else "CHAINS"]
	_clean_chip.visible = wrong_taps == 0
	var seal := mode.seal_text()
	_seal_chip.visible = not seal.is_empty()
	_seal_label.text = seal
	_next_label.text = "DONE"
	_next_level_label.text = mode.done_label()
	_play_entrance()


func _play_entrance() -> void:
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, OPEN_SECONDS)
	_padlock.play()
	_title.play_glint(0.7, 0.25)
	_play_stars()


## Empty stars appear first, then the earned ones pop in gold one by one.
func _play_stars() -> void:
	if _stars_tween != null and _stars_tween.is_valid():
		_stars_tween.kill()
	var star_nodes := _stars_row.get_children()
	for star: TextureRect in star_nodes:
		star.texture = STAR_EMPTY
		star.pivot_offset = star.custom_minimum_size * 0.5
		star.scale = Vector2.ONE
	if _stars == 0:
		return
	_stars_tween = create_tween()
	for i in _stars:
		var star := star_nodes[i] as TextureRect
		_stars_tween.tween_callback(func() -> void:
			star.texture = STAR_FULL
			star.scale = Vector2.ONE * 1.45).set_delay(STAR_FIRST_DELAY if i == 0 else STAR_STEP)
		_stars_tween.tween_property(star, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _stars_tween != null and _stars_tween.is_valid():
		_stars_tween.kill()
	hide()


## Stars earned in the shown result (0 for a Daily).
func get_stars() -> int:
	return _stars if _stars_row.visible else 0


func get_retry_button() -> Button:
	return %RetryButton


func get_seal() -> UnlockSeal:
	return _padlock


func get_upcoming_text() -> String:
	return _upcoming.text if _upcoming.visible else ""


func get_next_button() -> Button:
	return _next_button


func get_title_text() -> String:
	return _title.text


func is_clean_shown() -> bool:
	return _clean_chip.visible


func get_seal_text() -> String:
	return _seal_label.text if _seal_chip.visible else ""
