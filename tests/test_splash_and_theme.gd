extends TestSuite
## Splash intro, shared theme and brand assets.

const SPLASH_SCENE := "res://scenes/screens/splash_screen.tscn"
const BRAND_TEXTURES: Array[String] = [
	"res://assets/brand/link_steel.svg",
	"res://assets/brand/link_gold.svg",
	"res://assets/brand/link_weave.svg",
	"res://assets/brand/arrow.svg",
	"res://assets/brand/sparks.svg",
]

var _splash: SplashScreen
var _finished_count: int = 0


func _open_splash() -> void:
	_splash = (load(SPLASH_SCENE) as PackedScene).instantiate() as SplashScreen
	_finished_count = 0
	_splash.finished.connect(func() -> void: _finished_count += 1)
	tree.root.add_child(_splash)
	await wait_frames(1)


func _close_splash() -> void:
	_splash.queue_free()
	await wait_frames(1)


func test_splash_plays_through_and_finishes_once() -> void:
	await _open_splash()
	check(not _splash.is_finished(), "still playing right after opening")
	await wait_seconds(SplashScreen.FINISH_TIME + 0.4)
	check(_splash.is_finished(), "finished on its own")
	check_eq(_finished_count, 1, "finished emitted exactly once")
	await _close_splash()


func test_splash_skip_is_immediate_and_idempotent() -> void:
	await _open_splash()
	_splash.skip()
	_splash.skip()
	check_eq(_finished_count, 1, "skip emits finished once")
	await wait_seconds(SplashScreen.FINISH_TIME + 0.2)
	check_eq(_finished_count, 1, "timeline does not emit again after skip")
	await _close_splash()


func test_tap_skips_splash() -> void:
	await _open_splash()
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	_splash._gui_input(tap)
	check_eq(_finished_count, 1, "tap skips")
	await _close_splash()


func test_main_opens_on_splash_then_title() -> void:
	var path := temp_save_path("splash_flow")
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as Main
	main.save_path = path
	main.settings_path = temp_save_path("splash_flow_settings")
	main.achievements_path = temp_save_path("splash_flow_achievements")
	tree.root.add_child(main)
	await wait_frames(1)
	check(main.get_current_screen() is SplashScreen, "cold start shows the splash")
	await wait_seconds(SplashScreen.FINISH_TIME + 0.4)
	check(main.get_current_screen() is HomeScreen, "Home follows when the splash ends")
	main.queue_free()
	await wait_frames(1)
	remove_file(path)
	remove_file("user://test_splash_flow_settings.cfg")
	remove_file("user://test_splash_flow_achievements.cfg")


func test_theme_uses_cairo_and_defines_styles() -> void:
	var theme := GameTheme.get_theme()
	check(theme == GameTheme.get_theme(), "theme is built once and shared")
	var default_font := theme.default_font as FontVariation
	check(default_font != null and default_font.base_font is FontFile, "default font is a Cairo variation")
	if default_font != null and default_font.base_font is FontFile:
		check_eq((default_font.base_font as FontFile).get_font_name(), "Cairo", "font family")
	for type_name: StringName in [&"DisplayLabel", &"TitleLabel", &"HeadingLabel", &"CaptionLabel", &"OverlineLabel", &"PrimaryButton"]:
		check(theme.get_type_variation_base(type_name) != &"", "%s is a type variation" % type_name)
	check(theme.has_stylebox("normal", "PrimaryButton"), "primary button style")


func test_splash_builds_the_icon_with_its_sounds() -> void:
	await _open_splash()
	var feedback := Feedback.new()
	tree.root.add_child(feedback)
	await wait_frames(1)
	var heard: Array[Feedback.Sound] = []
	_splash.play(false, feedback)
	await wait_frames(1)
	var arrow := _splash.get_layer("arrow")
	var chain_a := _splash.get_layer("chain_a")
	var chain_b := _splash.get_layer("chain_b")
	var lock := _splash.get_layer("lock")
	check(arrow.scale.x < 0.5, "the arrow starts small in the centre")
	check(chain_a.position.y < 0.0 and chain_b.position.y > 0.0, "one chain starts above, the other below")
	check(lock.modulate.a < 0.1, "the lock is not there yet")
	# Note each sound as it plays.
	for step: int in 70:
		await wait_seconds(0.04)
		if heard.is_empty() or heard.back() != feedback.last_sound:
			heard.append(feedback.last_sound)
	check(is_equal_approx(chain_a.position.y, 0.0) and is_equal_approx(chain_b.position.y, 0.0), "both chains in place")
	check(is_equal_approx(lock.position.y, 0.0) and lock.modulate.a > 0.99, "the lock sits on the crossing")
	for sound: Feedback.Sound in [Feedback.Sound.SPLASH_RISE, Feedback.Sound.CHAIN_SLIDE, Feedback.Sound.LINK_JOIN, Feedback.Sound.LOCK_SNAP, Feedback.Sound.TITLE_CHIME]:
		check(heard.has(sound), "splash plays %s" % Feedback.Sound.keys()[sound])
	check(heard.find(Feedback.Sound.LOCK_SNAP) < heard.find(Feedback.Sound.TITLE_CHIME), "lock before the title chime")
	feedback.queue_free()
	await _close_splash()


func test_reduced_motion_splash_is_still_and_short() -> void:
	await _open_splash()
	_splash.play(true)
	await wait_seconds(SplashScreen.REDUCED_MOTION_HOLD_SECONDS + 0.2)
	check_eq(_finished_count, 1, "finishes after a short hold")
	await _close_splash()


func test_brand_textures_are_sharp_and_boot_image_exists() -> void:
	for path: String in BRAND_TEXTURES:
		var texture: Texture2D = load(path)
		check(texture != null, "%s loads" % path)
		if texture != null:
			check(texture.get_width() >= 500, "%s imported at high resolution (%d px)" % [path, texture.get_width()])
	var boot: Texture2D = load(ProjectSettings.get_setting("application/boot_splash/image"))
	check(boot != null and boot.get_size() == Vector2(720, 1280), "boot splash image is a 720x1280 frame")
