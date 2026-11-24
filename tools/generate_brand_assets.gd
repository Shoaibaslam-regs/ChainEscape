extends SceneTree
## Regenerates brand raster assets from the SVG sources in assets/brand.
##   godot --headless --path . --script res://tools/generate_brand_assets.gd
##
## boot_splash.png: the system boot image. It must match the first frame of
## SplashScreen: the obsidian background and warm spotlight only, because the
## two links slide in from the sides as the intro starts. Keep these numbers
## in sync with scenes/screens/splash_screen.tscn.

const OUTPUT_SIZE := Vector2i(720, 1280)
const MARK_CENTER := Vector2i(360, 580)
const SPOTLIGHT_RADIUS := 600.0


func _initialize() -> void:
	var error := _write_boot_splash("res://assets/brand/boot_splash.png")
	quit(0 if error == OK else 1)


func _write_boot_splash(path: String) -> Error:
	var image := Image.create_empty(OUTPUT_SIZE.x, OUTPUT_SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in OUTPUT_SIZE.y:
		for x: int in OUTPUT_SIZE.x:
			var distance := Vector2(x, y).distance_to(Vector2(MARK_CENTER))
			var weight := clampf(1.0 - distance / SPOTLIGHT_RADIUS, 0.0, 1.0)
			image.set_pixel(x, y, Palette.OBSIDIAN.lerp(Palette.SPOTLIGHT, weight))

	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("Wrote ", path, " (", error_string(error), ")")
	return error
