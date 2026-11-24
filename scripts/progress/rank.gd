class_name Rank
extends RefCounted
## The player's title, earned with points (5 per level cleared). Shown on
## Home with progress to the next title.

const RANKS: Array[Dictionary] = [
	{"name": "Apprentice", "points": 0},
	{"name": "Keyholder", "points": 100},
	{"name": "Locksmith", "points": 400},
	{"name": "Vaultbreaker", "points": 1200},
	{"name": "Master Locksmith", "points": 4000},
	{"name": "Grand Escape Artist", "points": 12000},
]


## {"name", "points" (this rank's start), "next_name", "next_points"}
## (next_* empty / -1 at the top rank).
static func for_points(points: int) -> Dictionary:
	var index := 0
	for i: int in RANKS.size():
		if points >= int(RANKS[i]["points"]):
			index = i
	var current: Dictionary = RANKS[index]
	var has_next := index + 1 < RANKS.size()
	return {
		"name": current["name"],
		"points": current["points"],
		"next_name": RANKS[index + 1]["name"] if has_next else "",
		"next_points": int(RANKS[index + 1]["points"]) if has_next else -1,
	}


## 0..1 progress from this rank to the next (1 at the top rank).
static func progress(points: int) -> float:
	var rank := for_points(points)
	if rank["next_points"] < 0:
		return 1.0
	return clampf(float(points - int(rank["points"])) / float(int(rank["next_points"]) - int(rank["points"])), 0.0, 1.0)
