class_name LevelGenerator
extends RefCounted
## Creates levels on demand for the endless part of the game.
##
## Deterministic: the same level number always produces the same puzzle, on
## every device, so restarting a level or reinstalling the game is fair.
##
## Solvable by construction. Arrows are placed in the reverse of a valid
## removal order: each new arrow needs a clear exit path past every arrow
## already placed, because it will leave before all of them. Dependencies
## only ever make an earlier-placed arrow wait for a newer one, which agrees
## with that order and therefore can never deadlock or form a cycle.
## Every result is still verified with BoardSolver before it is returned.
##
## Difficulty comes from blocking: each new arrow is preferably placed on a
## cell that lies in the exit path of arrows already placed, so those arrows
## end up waiting for it. Few arrows are free at the start, and clearing the
## board takes several rounds of discovery.
##
## Vault challenge twists (only when requested, so ordinary levels are
## generated exactly as before):
##   walls        solid cells placed first; every arrow's path must avoid them.
##   double_locks arrows may wait for two keys.
##   long_chains  new keys prefer neighbours that are already keys, building
##                chains of four or more.
##   hidden_links presentation only (BoardView hides the chains).
## Master arrow (every 50th level): chosen after generation among arrows that
## leave around the middle of the solve, then double-locked to two neighbours
## that leave earlier; the result is re-verified.

## Part of every seed. Changing it (or the algorithm) changes every generated
## level, so only do so deliberately.
const SEED_SALT := "chain-escape-levels-v1"
## Candidates built per level; the one closest to the target difficulty wins.
const CANDIDATE_COUNT := 8
## Board width range. Height is width + 1..2, capped at MAX_ROWS, so boards
## stay portrait and arrows stay comfortably tappable on phones.
const MIN_COLUMNS := 6
const MAX_COLUMNS := 8
const MAX_ROWS := 10
## Late levels grow past MAX_COLUMNS x MAX_ROWS by up to this much ("size"
## 0..1): denser boards with many more, smaller arrows. 10 x 13 keeps cells
## big enough to tap reliably on a phone.
const EXTRA_COLUMNS := 2
const EXTRA_ROWS := 5
const MIN_FILL_RATIO := 0.55
const MAX_FILL_RATIO := 0.75
const MIN_DEPENDENCY_CHANCE := 0.12
const MAX_DEPENDENCY_CHANCE := 0.38
## How far a chain may reach (in cells, any direction): 1 = neighbours only,
## growing with hardness to MAX_CHAIN_REACH. Far links are preferred more
## as levels get harder, so chains cross the board instead of only joining
## next-door arrows.
const MAX_CHAIN_REACH := 4
const FAR_LINK_PREFERENCE := 0.3
const HARDNESS_FAR_LINK_PREFERENCE := 0.35
## From this hardness, any arrow may wait for two keys.
const DOUBLE_KEYS_FROM_HARDNESS := 0.5
const MIN_TARGET_ROUNDS := 5.0
const MAX_TARGET_ROUNDS := 10.0
## Share of arrows that may be free at the start before a candidate is penalised.
const MAX_TARGET_FREE_RATIO := 0.3
const MIN_TARGET_FREE_RATIO := 0.18
## Weight of excess free arrows against the rounds target when scoring.
const FREE_RATIO_WEIGHT := 20.0
## Empty cells compared per placement; the one blocking most arrows wins.
const CELL_SAMPLE_SIZE := 4
## Chance to take the direction with the longest exit path rather than a
## random valid one. Long paths leave room for later arrows to block them.
const LONG_PATH_PREFERENCE := 0.7
const DIRECTIONS: Array[Arrow.Direction] = [
	Arrow.Direction.UP, Arrow.Direction.DOWN, Arrow.Direction.LEFT, Arrow.Direction.RIGHT,
]
## Dependencies link neighbours only; long links across the board are hard to read.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
## Twist tuning.
const WALL_RATIO := 0.08
const DOUBLE_LOCK_EXTRA_CHANCE := 0.15
const LONG_CHAIN_EXTRA_CHANCE := 0.12
const MIN_DOUBLE_LOCKS := 2
const MIN_LONG_CHAIN := 4
const MISSING_TWIST_PENALTY := 6.0
## Mirrors per cell, and black hole pairs (more on big boards).
const MIRROR_RATIO := 0.05
const MIN_MIRRORS := 3
const BIG_BOARD_CELLS := 80
## A twist only counts if at least this many arrows' paths use its cells.
const MIN_TILE_USES := 3
## Hardness (0..1) tightens a level beyond the difficulty ramp without making
## the board bigger: fewer free arrows at the start, longer solves, more
## dependencies and walls. 0 leaves generation exactly as before.
const HARDNESS_EXTRA_ROUNDS := 4.0
const HARDNESS_MIN_FREE_RATIO := 0.1
const HARDNESS_EXTRA_DEPENDENCY_CHANCE := 0.12
const HARDNESS_EXTRA_WALL_RATIO := 0.05
## At full hardness, this many times CANDIDATE_COUNT extra candidates are tried.
const HARDNESS_EXTRA_CANDIDATES := 0.5
## Weight of excess free arrows when hardness is high (on top of FREE_RATIO_WEIGHT).
const HARDNESS_FREE_RATIO_WEIGHT := 30.0
## Tightening (hardness > 0): free-at-start arrows are chained to a
## neighbour that leaves later, until only this share of arrows is free
## (from the first value at low hardness to the second at full hardness).
const TIGHT_FREE_RATIO_EASY := 0.26
const TIGHT_FREE_RATIO_HARD := 0.08
const MIN_FREE_ARROWS := 3
## Master arrow: it should become free between these fractions of the solve.
const MASTER_ROUND_MIN := 0.4
const MASTER_ROUND_MAX := 0.75
## How far the master's two keys may be.
const MASTER_KEY_REACH := 3


## Builds the level for [param level_number]. [param difficulty] runs from
## 0.0 (gentlest generated level) to 1.0 (hardest settings). Returns null
## only if every candidate failed verification, which indicates a bug.
static func generate(level_number: int, difficulty: float, twists: PackedStringArray = PackedStringArray(), with_master: bool = false, hardness: float = 0.0, size: float = 0.0) -> LevelData:
	return generate_from_seed("%s:%d" % [SEED_SALT, level_number], difficulty, twists, with_master, hardness, size)


## Same as generate(), seeded by any text (used for daily puzzles, which
## must never repeat a numbered level).
static func generate_from_seed(seed_text: String, difficulty: float, twists: PackedStringArray = PackedStringArray(), with_master: bool = false, hardness: float = 0.0, size: float = 0.0) -> LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_text.hash()
	difficulty = clampf(difficulty, 0.0, 1.0)
	hardness = clampf(hardness, 0.0, 1.0)
	var target_rounds := lerpf(MIN_TARGET_ROUNDS, MAX_TARGET_ROUNDS, difficulty) + HARDNESS_EXTRA_ROUNDS * hardness
	var target_free_ratio := lerpf(lerpf(MAX_TARGET_FREE_RATIO, MIN_TARGET_FREE_RATIO, difficulty), HARDNESS_MIN_FREE_RATIO, hardness)

	var best_level: LevelData = null
	var best_score := INF
	# Harder levels search more candidates to find a tighter board.
	var candidate_count := CANDIDATE_COUNT + roundi(CANDIDATE_COUNT * HARDNESS_EXTRA_CANDIDATES * hardness)
	for attempt: int in candidate_count:
		var candidate := _build_candidate(difficulty, rng, twists, hardness, size)
		remove_unclear_links(candidate)
		repair_chain_blocks(candidate)
		var board := candidate.build_board()
		if board == null:
			push_error("LevelGenerator: %s candidate %d produced invalid data." % [seed_text, attempt])
			continue
		var free_ratio := float(_count_free_arrows(board)) / board.arrow_count()
		var rounds := BoardSolver.count_solution_rounds(board)
		if rounds < 0:
			push_error("LevelGenerator: %s candidate %d is unsolvable." % [seed_text, attempt])
			continue
		var score := absf(rounds - target_rounds) + maxf(free_ratio - target_free_ratio, 0.0) * (FREE_RATIO_WEIGHT + HARDNESS_FREE_RATIO_WEIGHT * hardness)
		score += _missing_twist_penalty(candidate, twists)
		if score < best_score:
			best_score = score
			best_level = candidate
	if best_level != null:
		best_level.twists = twists
		# The master comes first: tightening only chains arrows that are free
		# at the start, so it never touches the master's own keys.
		if with_master and not _add_master(best_level):
			push_warning("LevelGenerator: %s has no suitable master arrow." % seed_text)
		if hardness > 0.0:
			tighten(best_level, hardness, rng)
	return best_level


static func _build_candidate(difficulty: float, rng: RandomNumberGenerator, twists: PackedStringArray, hardness: float = 0.0, size: float = 0.0) -> LevelData:
	var max_columns := MAX_COLUMNS + roundi(EXTRA_COLUMNS * clampf(size, 0.0, 1.0))
	var max_rows := MAX_ROWS + roundi(EXTRA_ROWS * clampf(size, 0.0, 1.0))
	var columns := clampi(roundi(lerpf(MIN_COLUMNS, max_columns, difficulty)) - rng.randi_range(0, 1), MIN_COLUMNS, max_columns)
	var extra_rows := 2 if size <= 0.0 else (3 if size < 0.5 else 5)
	var rows := mini(columns + rng.randi_range(1, extra_rows), max_rows)
	var board_size := Vector2i(columns, rows)
	var target_arrow_count := roundi(columns * rows * lerpf(MIN_FILL_RATIO, MAX_FILL_RATIO, difficulty))
	var dependency_chance := lerpf(MIN_DEPENDENCY_CHANCE, MAX_DEPENDENCY_CHANCE, difficulty) + HARDNESS_EXTRA_DEPENDENCY_CHANCE * hardness
	var max_keys_per_arrow := 2 if hardness >= DOUBLE_KEYS_FROM_HARDNESS else 1
	var reach := chain_reach(hardness)
	var far_preference := FAR_LINK_PREFERENCE + HARDNESS_FAR_LINK_PREFERENCE * hardness
	var prefer_chain_ends := twists.has(LevelData.TWIST_LONG_CHAINS)
	if twists.has(LevelData.TWIST_DOUBLE_LOCKS):
		dependency_chance += DOUBLE_LOCK_EXTRA_CHANCE
		max_keys_per_arrow = 2
	if prefer_chain_ends:
		dependency_chance += LONG_CHAIN_EXTRA_CHANCE

	var placed: Dictionary[Vector2i, Arrow.Direction] = {}
	## How many keys each placed arrow already waits for.
	var waiting_counts: Dictionary[Vector2i, int] = {}
	## Arrows that some other arrow waits for.
	var key_cells: Dictionary[Vector2i, bool] = {}
	var dependencies: Array[Vector4i] = []
	## How many placed arrows have each cell in their exit path.
	var path_coverage: Dictionary[Vector2i, int] = {}
	var open_cells := _shuffled_cells(board_size, rng)
	var walls: Dictionary[Vector2i, bool] = {}
	if twists.has(LevelData.TWIST_WALLS):
		for index: int in roundi(columns * rows * (WALL_RATIO + HARDNESS_EXTRA_WALL_RATIO * hardness)):
			walls[open_cells.pop_back()] = true
	## Special cells: mirrors (cell -> kind) and black holes (cell -> white hole).
	var mirrors: Dictionary = {}
	var portals: Dictionary = {}
	if twists.has(LevelData.TWIST_MIRRORS):
		for index: int in maxi(MIN_MIRRORS, roundi(columns * rows * MIRROR_RATIO)):
			mirrors[open_cells.pop_back()] = rng.randi_range(0, 1)
	if twists.has(LevelData.TWIST_BLACK_HOLES):
		for pair: int in (2 if columns * rows >= BIG_BOARD_CELLS else 1):
			var black := open_cells.pop_back() as Vector2i
			# The white hole goes well away from its black hole.
			for attempt: int in open_cells.size():
				var candidate: Vector2i = open_cells[open_cells.size() - 1 - attempt]
				if absi(candidate.x - black.x) + absi(candidate.y - black.y) >= 4:
					portals[black] = candidate
					open_cells.erase(candidate)
					break
	# Plain boards keep the fast straight-line paths.
	var tiles := {"mirrors": mirrors, "portals": portals} if not (mirrors.is_empty() and portals.is_empty()) else {}
	while placed.size() < target_arrow_count and not open_cells.is_empty():
		var cell_index := _pick_most_covered_cell(open_cells, path_coverage, rng)
		var cell := open_cells[cell_index]
		open_cells.remove_at(cell_index)
		var options: Array[Arrow.Direction] = []
		for direction: Arrow.Direction in DIRECTIONS:
			if _is_exit_path_clear(cell, direction, board_size, placed, walls, tiles):
				options.append(direction)
		if options.is_empty():
			continue
		if rng.randf() < dependency_chance:
			var waiting_cell := _pick_waiting_neighbour(cell, placed, waiting_counts, max_keys_per_arrow, key_cells if prefer_chain_ends else {}, rng, reach, far_preference, board_size, tiles)
			if waiting_cell != cell:
				dependencies.append(Vector4i(waiting_cell.x, waiting_cell.y, cell.x, cell.y))
				waiting_counts[waiting_cell] = waiting_counts.get(waiting_cell, 0) + 1
				key_cells[cell] = true
		var direction := _pick_direction(cell, options, board_size, rng, tiles)
		placed[cell] = direction
		for path_cell: Vector2i in _exit_path(cell, direction, board_size, tiles):
			path_coverage[path_cell] = path_coverage.get(path_cell, 0) + 1

	var level := LevelData.new()
	level.layout = _layout_text(board_size, placed, walls, mirrors)
	for black: Vector2i in portals:
		var white: Vector2i = portals[black]
		level.portals.append(Vector4i(black.x, black.y, white.x, white.y))
	level.dependencies = dependencies
	return level


## True if no already-placed arrow or wall stands between [param cell] and the edge.
static func _is_exit_path_clear(cell: Vector2i, direction: Arrow.Direction, board_size: Vector2i, placed: Dictionary[Vector2i, Arrow.Direction], walls: Dictionary[Vector2i, bool], tiles: Dictionary = {}) -> bool:
	if not tiles.is_empty() and not _trace(cell, direction, board_size, tiles)["escaped"]:
		return false
	for path_cell: Vector2i in _exit_path(cell, direction, board_size, tiles):
		if placed.has(path_cell) or walls.has(path_cell):
			return false
	return true


static func _trace(cell: Vector2i, direction: Arrow.Direction, board_size: Vector2i, tiles: Dictionary) -> Dictionary:
	return PathTracer.trace(cell, direction, board_size, tiles.get("mirrors", {}), tiles.get("portals", {}))


static func _exit_path(cell: Vector2i, direction: Arrow.Direction, board_size: Vector2i, tiles: Dictionary = {}) -> Array[Vector2i]:
	if not tiles.is_empty():
		var traced: Array[Vector2i] = []
		traced.assign(_trace(cell, direction, board_size, tiles)["cells"])
		return traced
	var path: Array[Vector2i] = []
	var step := Arrow.direction_to_vector(direction)
	var current := cell + step
	while current.x >= 0 and current.y >= 0 and current.x < board_size.x and current.y < board_size.y:
		path.append(current)
		current += step
	return path


## Index into [param open_cells] of the best of a few random samples: the cell
## lying in the most placed arrows' paths, so placing there blocks them.
static func _pick_most_covered_cell(open_cells: Array[Vector2i], path_coverage: Dictionary[Vector2i, int], rng: RandomNumberGenerator) -> int:
	var best_index := rng.randi_range(0, open_cells.size() - 1)
	for sample: int in CELL_SAMPLE_SIZE - 1:
		var index := rng.randi_range(0, open_cells.size() - 1)
		if path_coverage.get(open_cells[index], 0) > path_coverage.get(open_cells[best_index], 0):
			best_index = index
	return best_index


## Usually the valid direction with the longest exit path, sometimes a random
## one so boards don't all point outward the same way.
static func _pick_direction(cell: Vector2i, options: Array[Arrow.Direction], board_size: Vector2i, rng: RandomNumberGenerator, tiles: Dictionary = {}) -> Arrow.Direction:
	if rng.randf() >= LONG_PATH_PREFERENCE:
		return options[rng.randi_range(0, options.size() - 1)]
	var best := options[0]
	for direction: Arrow.Direction in options:
		if _exit_path(cell, direction, board_size, tiles).size() > _exit_path(cell, best, board_size, tiles).size():
			best = direction
	return best


## Makes [param level] harder in place: arrows that are free at the start
## wait for a neighbour that leaves later, verified solvable after every
## link. Fewer obvious first moves and longer chains of steps.
static func tighten(level: LevelData, hardness: float, rng: RandomNumberGenerator) -> void:
	var board := level.build_board()
	if board == null:
		return
	var cells_by_id: Dictionary[int, Vector2i] = {}
	var ids_by_cell: Dictionary[Vector2i, int] = {}
	for arrow: Arrow in board.get_arrows():
		cells_by_id[arrow.id] = arrow.cell
		ids_by_cell[arrow.cell] = arrow.id
	var reach := chain_reach(hardness)
	var target_free := maxi(MIN_FREE_ARROWS, roundi(board.arrow_count() * lerpf(TIGHT_FREE_RATIO_EASY, TIGHT_FREE_RATIO_HARD, hardness)))
	var rounds := BoardSolver.exit_rounds(level.build_board())
	if rounds.has(-1):
		return
	var free_ids: Array[int] = []
	for id: int in rounds:
		if rounds[id] == 1:
			free_ids.append(id)
	# Deterministic shuffle with the level's own generator.
	for index: int in range(free_ids.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var temporary := free_ids[index]
		free_ids[index] = free_ids[swap]
		free_ids[swap] = temporary
	var free_count := free_ids.size()
	for id: int in free_ids:
		if free_count <= target_free:
			break
		if rounds.get(id, 0) != 1:
			continue
		var cell := cells_by_id[id]
		# Arrows within reach that leave later: latest first, then farthest.
		var options: Array[int] = []
		for offset: Vector2i in offsets_within(reach):
			var other: int = ids_by_cell.get(cell + offset, -1)
			if other != -1 and rounds.get(other, 0) >= 2 and not board.get_exit_path(other).has(cell) \
					and is_clear_link(cell, cells_by_id[other], ids_by_cell, level.dependencies):
				options.append(other)
		options.sort_custom(func(a: int, b: int) -> bool:
			if rounds[a] != rounds[b]:
				return rounds[a] > rounds[b]
			return _cell_distance(cells_by_id[a], cell) > _cell_distance(cells_by_id[b], cell))
		# Same near/far mix as during building.
		if reach > 1:
			var want_far := rng.randf() < FAR_LINK_PREFERENCE + HARDNESS_FAR_LINK_PREFERENCE * hardness
			var kind := options.filter(func(o: int) -> bool: return (_cell_distance(cells_by_id[o], cell) >= 2) == want_far)
			if not kind.is_empty():
				options.assign(kind)
		for other: int in options.slice(0, 3):
			var key_cell := cells_by_id[other]
			var link := Vector4i(cell.x, cell.y, key_cell.x, key_cell.y)
			level.dependencies.append(link)
			var check_board := level.build_board()
			var new_rounds := BoardSolver.exit_rounds(check_board) if check_board != null else ({-1: 0} as Dictionary[int, int])
			if new_rounds.has(-1):
				level.dependencies.pop_back()
				continue
			rounds = new_rounds
			free_count = rounds.values().filter(func(r: int) -> bool: return r == 1).size()
			break


static func _count_free_arrows(board: BoardState) -> int:
	var free_count := 0
	for arrow: Arrow in board.get_arrows():
		if board.can_exit(arrow.id):
			free_count += 1
	return free_count


## An already-placed neighbour that could be made to wait for the arrow being
## placed at [param cell], or [param cell] itself if there is none. Skips
## neighbours already waiting for [param max_keys] keys (one per arrow keeps
## ordinary boards readable; double locks allow two) and neighbours whose path
## already runs through [param cell] (a dependency there would add nothing).
## Neighbours in [param preferred] (existing keys) are chosen first, which
## extends chains.
static func _pick_waiting_neighbour(cell: Vector2i, placed: Dictionary[Vector2i, Arrow.Direction], waiting_counts: Dictionary[Vector2i, int], max_keys: int, preferred: Dictionary, rng: RandomNumberGenerator, reach: int = 1, far_preference: float = 0.0, board_size: Vector2i = Vector2i.ZERO, tiles: Dictionary = {}) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for offset: Vector2i in offsets_within(reach):
		var neighbour := cell + offset
		if not placed.has(neighbour) or waiting_counts.get(neighbour, 0) >= max_keys:
			continue
		if _points_at(neighbour, placed[neighbour], cell):
			continue
		# With mirrors or black holes the real path bends: check that too.
		if not tiles.is_empty() and _exit_path(neighbour, placed[neighbour], board_size, tiles).has(cell):
			continue
		candidates.append(neighbour)
	if candidates.is_empty():
		return cell
	if not preferred.is_empty():
		var chain_ends := candidates.filter(func(c: Vector2i) -> bool: return preferred.has(c))
		if not chain_ends.is_empty():
			candidates.assign(chain_ends)
	# Far cells outnumber near ones, so pick the kind first: far with
	# [param far_preference], otherwise a neighbour (when there is one).
	if reach > 1:
		var want_far := rng.randf() < far_preference
		var kind := candidates.filter(func(c: Vector2i) -> bool: return (_cell_distance(c, cell) >= 2) == want_far)
		if not kind.is_empty():
			candidates.assign(kind)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## A chain must read clearly: it may not pass over another arrow, and
## chains never cross each other (MAX_LINK_CROSSINGS).
const MAX_LINK_CROSSINGS := 0
## A chain passing closer than this (in cells) to an arrow's centre covers it.
const LINK_CLEARANCE := 0.42


static func is_clear_link(a: Vector2i, b: Vector2i, arrows: Dictionary, links: Array[Vector4i]) -> bool:
	var start := Vector2(a)
	var end := Vector2(b)
	for cell: Vector2i in arrows:
		if cell == a or cell == b:
			continue
		if Geometry2D.get_closest_point_to_segment(Vector2(cell), start, end).distance_to(Vector2(cell)) < LINK_CLEARANCE:
			return false
	var crossings := 0
	for link: Vector4i in links:
		var c := Vector2i(link.x, link.y)
		var d := Vector2i(link.z, link.w)
		if c == a or c == b or d == a or d == b:
			continue
		if Geometry2D.segment_intersects_segment(start, end, Vector2(c), Vector2(d)) != null:
			crossings += 1
			if crossings > MAX_LINK_CROSSINGS:
				return false
	return true


## Chains block flight paths, so a level built for arrows alone can end up
## sealed by a chain. While the level is stuck, drop the chain lying across a
## stuck arrow's path (dropping a chain only ever frees arrows). Returns
## whether the level is solvable afterwards.
static func repair_chain_blocks(level: LevelData) -> bool:
	for attempt: int in 64:
		var board := level.build_board()
		if board == null:
			return false
		var rounds := BoardSolver.exit_rounds(board)
		if not rounds.has(-1):
			return true
		# The board is left at the stuck point: find a chain blocking someone.
		var removed := false
		for arrow: Arrow in board.get_arrows():
			if board.is_locked(arrow.id) or board.find_blocker(arrow.id) != null or board.is_walled_in(arrow.id):
				continue
			var link := board.find_blocking_link(arrow.id)
			if link != BoardState.NO_LINK and level.dependencies.has(link):
				level.dependencies.erase(link)
				removed = true
				break
		if not removed:
			return false
	return false


## Drops chains that would be hard to read (over an arrow, or crossing too
## many chains). Removing a chain never makes a level unsolvable.
static func remove_unclear_links(level: LevelData) -> void:
	var board := level.build_board()
	if board == null:
		return
	var arrows: Dictionary = {}
	for arrow: Arrow in board.get_arrows():
		arrows[arrow.cell] = true
	var kept: Array[Vector4i] = []
	for link: Vector4i in level.dependencies:
		if is_clear_link(Vector2i(link.x, link.y), Vector2i(link.z, link.w), arrows, kept):
			kept.append(link)
	level.dependencies = kept


## Chain reach for a hardness (see MAX_CHAIN_REACH).
static func chain_reach(hardness: float) -> int:
	return clampi(1 + roundi((MAX_CHAIN_REACH - 1) * hardness), 1, MAX_CHAIN_REACH)


## Every offset within [param reach] cells (Chebyshev distance), nearest first.
static func offsets_within(reach: int) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			if dx != 0 or dy != 0:
				offsets.append(Vector2i(dx, dy))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return maxi(absi(a.x), absi(a.y)) < maxi(absi(b.x), absi(b.y)))
	return offsets


static func _cell_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## True if an arrow at [param from] facing [param direction] has [param target]
## straight ahead (a dependency there would add nothing: it already blocks).
static func _points_at(from: Vector2i, direction: Arrow.Direction, target: Vector2i) -> bool:
	var step := Arrow.direction_to_vector(direction)
	var delta := target - from
	return step.x * delta.y - step.y * delta.x == 0 and step.x * delta.x + step.y * delta.y > 0


## All cells in a random order, using [param rng] (Array.shuffle would use the
## global generator and break determinism).
static func _shuffled_cells(board_size: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in board_size.y:
		for x: int in board_size.x:
			cells.append(Vector2i(x, y))
	for index: int in range(cells.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := cells[index]
		cells[index] = cells[swap_index]
		cells[swap_index] = temporary
	return cells


static func _layout_text(board_size: Vector2i, placed: Dictionary[Vector2i, Arrow.Direction], walls: Dictionary[Vector2i, bool], mirrors: Dictionary = {}) -> String:
	var lines := PackedStringArray()
	for y: int in board_size.y:
		var symbols := PackedStringArray()
		for x: int in board_size.x:
			var cell := Vector2i(x, y)
			if placed.has(cell):
				symbols.append(LevelData.symbol_for(placed[cell]))
			elif walls.has(cell):
				symbols.append(LevelData.WALL_SYMBOL)
			elif mirrors.has(cell):
				symbols.append(LevelData.MIRROR_SYMBOLS.find_key(mirrors[cell]))
			else:
				symbols.append(LevelData.EMPTY_SYMBOL)
		lines.append(" ".join(symbols))
	return "\n".join(lines)


static func _directions_by_cell(level: LevelData) -> Dictionary[Vector2i, Arrow.Direction]:
	var directions: Dictionary[Vector2i, Arrow.Direction] = {}
	var board := level.build_board()
	for arrow: Arrow in board.get_arrows():
		directions[arrow.cell] = arrow.direction
	return directions


## Score penalty when a candidate fails to show a requested twist clearly.
static func _missing_twist_penalty(level: LevelData, twists: PackedStringArray) -> float:
	var penalty := 0.0
	if twists.has(LevelData.TWIST_DOUBLE_LOCKS):
		penalty += maxi(MIN_DOUBLE_LOCKS - count_double_locks(level), 0) * MISSING_TWIST_PENALTY
	if twists.has(LevelData.TWIST_LONG_CHAINS):
		penalty += maxi(MIN_LONG_CHAIN - longest_chain(level), 0) * MISSING_TWIST_PENALTY
	if twists.has(LevelData.TWIST_MIRRORS) or twists.has(LevelData.TWIST_BLACK_HOLES):
		var uses := count_tile_uses(level)
		if twists.has(LevelData.TWIST_MIRRORS):
			penalty += maxi(MIN_TILE_USES - uses.x, 0) * MISSING_TWIST_PENALTY
		if twists.has(LevelData.TWIST_BLACK_HOLES):
			penalty += maxi(MIN_TILE_USES - uses.y, 0) * MISSING_TWIST_PENALTY
	return penalty


## How many arrows bounce off a mirror (x) and fly through a black hole (y)
## on their way out.
static func count_tile_uses(level: LevelData) -> Vector2i:
	var uses := Vector2i.ZERO
	var board := level.build_board()
	if board == null:
		return uses
	for arrow: Arrow in board.get_arrows():
		var kinds := board.get_exit_waypoints(arrow.id).map(func(point: Dictionary) -> String: return point["kind"])
		if kinds.has(PathTracer.TURN):
			uses.x += 1
		if kinds.has(PathTracer.ENTER):
			uses.y += 1
	return uses


## Arrows that wait for two or more keys.
static func count_double_locks(level: LevelData) -> int:
	var counts: Dictionary[Vector2i, int] = {}
	for link: Vector4i in level.dependencies:
		var cell := Vector2i(link.x, link.y)
		counts[cell] = counts.get(cell, 0) + 1
	return counts.values().filter(func(count: int) -> bool: return count >= 2).size()


## Arrows in the longest chain (A waits for B waits for C … counts each arrow).
static func longest_chain(level: LevelData) -> int:
	var keys_of: Dictionary[Vector2i, Array] = {}
	for link: Vector4i in level.dependencies:
		var waiting := Vector2i(link.x, link.y)
		if not keys_of.has(waiting):
			keys_of[waiting] = []
		keys_of[waiting].append(Vector2i(link.z, link.w))
	var memo: Dictionary[Vector2i, int] = {}
	var best := 0
	for cell: Vector2i in keys_of:
		best = maxi(best, _chain_length(cell, keys_of, memo))
	return best


static func _chain_length(cell: Vector2i, keys_of: Dictionary[Vector2i, Array], memo: Dictionary[Vector2i, int]) -> int:
	if memo.has(cell):
		return memo[cell]
	var length := 1
	for key: Vector2i in keys_of.get(cell, []):
		length = maxi(length, 1 + _chain_length(key, keys_of, memo))
	memo[cell] = length
	return length


## Picks the master arrow and double-locks it. Candidates are arrows that
## become free between MASTER_ROUND_MIN and MASTER_ROUND_MAX of the solve and
## have at least two neighbours that leave earlier; the most central wins.
## Keeps the level unchanged and returns false if none works.
static func _add_master(level: LevelData) -> bool:
	var board := level.build_board()
	if board == null:
		return false
	var cells_by_id: Dictionary[int, Vector2i] = {}
	for arrow: Arrow in board.get_arrows():
		cells_by_id[arrow.id] = arrow.cell
	var size := board.size
	var rounds := BoardSolver.exit_rounds(board)
	if rounds.has(-1) or rounds.is_empty():
		return false
	var total_rounds: int = rounds.values().max()
	var round_by_cell: Dictionary[Vector2i, int] = {}
	for id: int in rounds:
		round_by_cell[cells_by_id[id]] = rounds[id]
	var center := (Vector2(size) - Vector2.ONE) * 0.5
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in round_by_cell:
		var fraction := float(round_by_cell[cell]) / total_rounds
		if fraction >= MASTER_ROUND_MIN and fraction <= MASTER_ROUND_MAX:
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(center) < Vector2(b).distance_to(center))
	var directions := _directions_by_cell(level)
	# The master gets its own two keys, so skip arrows that already wait.
	var already_waiting: Dictionary[Vector2i, bool] = {}
	for link: Vector4i in level.dependencies:
		already_waiting[Vector2i(link.x, link.y)] = true
	for cell: Vector2i in candidates:
		if already_waiting.has(cell):
			continue
		var keys: Array[Vector2i] = []
		# Nearest keys first, up to MASTER_KEY_REACH cells away.
		for offset: Vector2i in offsets_within(MASTER_KEY_REACH):
			var neighbour := cell + offset
			# A key already in the master's path blocks it anyway: skip it.
			if _points_at(cell, directions[cell], neighbour):
				continue
			if round_by_cell.has(neighbour) and round_by_cell[neighbour] < round_by_cell[cell] \
					and is_clear_link(cell, neighbour, round_by_cell, level.dependencies):
				keys.append(neighbour)
		if keys.size() < 2:
			continue
		keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if _cell_distance(a, cell) != _cell_distance(b, cell):
				return _cell_distance(a, cell) < _cell_distance(b, cell)
			return round_by_cell[a] > round_by_cell[b])
		var trial := level.duplicate() as LevelData
		trial.dependencies = level.dependencies.duplicate()
		for key: Vector2i in keys.slice(0, 2):
			var link := Vector4i(cell.x, cell.y, key.x, key.y)
			if not trial.dependencies.has(link):
				trial.dependencies.append(link)
		trial.master_cell = cell
		var check := trial.build_board()
		if check == null or check.can_exit(check.get_master_id()) or not BoardSolver.is_solvable(check):
			continue
		level.dependencies = trial.dependencies
		level.master_cell = cell
		return true
	return false
