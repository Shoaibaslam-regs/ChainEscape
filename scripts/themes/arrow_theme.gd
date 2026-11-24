class_name ArrowTheme
extends RefCounted
## Arrow colour themes, unlocked by total points (5 per level). A theme
## replaces the gold of free arrows; locked arrows always stay steel so the
## rules read the same in every theme.

const DEFAULT_ID := "gold"

## id, name, points needed, then the light / mid / dark metal stops.
const THEMES: Array[Dictionary] = [
	{"id": "gold", "name": "Gold", "points": 0, "colors": [Color("FFF0BF"), Color("E8B04A"), Color("9C6B1C")]},
	{"id": "emerald", "name": "Emerald", "points": 250, "colors": [Color("DFFFE6"), Color("4CB866"), Color("1F6B34")]},
	{"id": "sapphire", "name": "Sapphire", "points": 750, "colors": [Color("D8E6FF"), Color("4F7FE0"), Color("1F3A80")]},
	{"id": "amethyst", "name": "Amethyst", "points": 1500, "colors": [Color("EEDCFF"), Color("A673E8"), Color("5A2E99")]},
	{"id": "rose_gold", "name": "Rose gold", "points": 3000, "colors": [Color("FFE3D6"), Color("E0957A"), Color("8A4A38")]},
]


static func find(id: String) -> Dictionary:
	for theme: Dictionary in THEMES:
		if theme["id"] == id:
			return theme
	return THEMES[0]


static func is_unlocked(id: String, points: int) -> bool:
	return points >= int(find(id)["points"]) and find(id)["id"] == id


## The theme to use: the chosen one if it exists and is unlocked, else Gold
## (e.g. after Reset progress).
static func resolve(id: String, points: int) -> Dictionary:
	return find(id) if is_unlocked(id, points) else THEMES[0]


static func colors_of(theme: Dictionary) -> PackedColorArray:
	return PackedColorArray(theme["colors"])


## The next theme still locked at [param points], or {} when all are open.
static func next_locked(points: int) -> Dictionary:
	for theme: Dictionary in THEMES:
		if points < int(theme["points"]):
			return theme
	return {}
