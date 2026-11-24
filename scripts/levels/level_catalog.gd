class_name LevelCatalog
extends Resource
## The hand-made levels, in play order. They open the game and teach the
## rules; LevelSequence continues with generated levels after them.

@export var levels: Array[LevelData] = []


func count() -> int:
	return levels.size()


## [param index] is 0-based. Returns null when out of range.
func get_level(index: int) -> LevelData:
	if index < 0 or index >= levels.size():
		return null
	return levels[index]
