extends TestSuite
## Generated levels and the endless LevelSequence.

const CATALOG_PATH := "res://levels/level_catalog.tres"
## Generated levels checked in depth. Covers the whole difficulty ramp and
## well past it.
const CHECKED_LEVEL_COUNT := 150

var _sequence: LevelSequence


func _get_sequence() -> LevelSequence:
	if _sequence == null:
		_sequence = LevelSequence.new(load(CATALOG_PATH))
	return _sequence


func test_sequence_starts_with_handmade_levels() -> void:
	var sequence := _get_sequence()
	var catalog: LevelCatalog = load(CATALOG_PATH)
	check(sequence.handmade_count() > 0, "has hand-made levels")
	check(sequence.get_level(1) == catalog.get_level(0), "level 1 is the first hand-made level")
	check(sequence.get_level(sequence.handmade_count()) == catalog.get_level(catalog.count() - 1), "last hand-made level")
	check(not sequence.is_generated(sequence.handmade_count()), "hand-made range")
	check(sequence.is_generated(sequence.handmade_count() + 1), "generated range starts right after")
	check(sequence.get_level(0) == null and sequence.get_level(-5) == null, "numbers below 1 have no level")


func test_generation_is_deterministic() -> void:
	var sequence := _get_sequence()
	var level_number := sequence.handmade_count() + 17
	var first := sequence.get_level(level_number)
	var second := sequence.get_level(level_number)
	check(first != null and second != null, "level generated")
	if first != null and second != null:
		check_eq(second.layout, first.layout, "same layout every time")
		check_eq(second.dependencies, first.dependencies, "same dependencies every time")


func test_different_levels_differ() -> void:
	var sequence := _get_sequence()
	var start := sequence.handmade_count() + 1
	var layouts: Dictionary[String, bool] = {}
	for level_number: int in range(start, start + 30):
		layouts[sequence.get_level(level_number).layout] = true
	check_eq(layouts.size(), 30, "30 consecutive generated levels are all distinct")


func test_generated_levels_are_valid_solvable_and_challenging() -> void:
	var sequence := _get_sequence()
	var start := sequence.handmade_count() + 1
	for level_number: int in range(start, start + CHECKED_LEVEL_COUNT):
		var label := "level %d" % level_number
		var level := sequence.get_level(level_number)
		check(level != null, "%s generated" % label)
		if level == null:
			continue
		var errors := PackedStringArray()
		var board := level.build_board(errors)
		check(board != null, "%s builds: %s" % [label, errors])
		if board == null:
			continue
		check(board.size.x >= LevelGenerator.MIN_COLUMNS and board.size.x <= LevelGenerator.MAX_COLUMNS + LevelGenerator.EXTRA_COLUMNS, "%s width in range" % label)
		check(board.size.y > board.size.x and board.size.y <= LevelGenerator.MAX_ROWS + LevelGenerator.EXTRA_ROWS, "%s is portrait and fits" % label)
		var free_count := 0
		for arrow: Arrow in board.get_arrows():
			if board.can_exit(arrow.id):
				free_count += 1
		check(free_count > 0, "%s has a first move" % label)
		check(float(free_count) / board.arrow_count() <= 0.5, "%s: at most half the arrows free at start (%d/%d)" % [label, free_count, board.arrow_count()])
		check(BoardSolver.count_solution_rounds(board) >= 3, "%s needs at least 3 rounds" % label)


func test_generated_dependencies_are_short_and_meaningful() -> void:
	var sequence := _get_sequence()
	var start := sequence.handmade_count() + 1
	var total_dependencies := 0
	for level_number: int in range(start, start + CHECKED_LEVEL_COUNT):
		var level := sequence.get_level(level_number)
		var board := level.build_board()
		var max_keys := 2 if level.has_twist(LevelData.TWIST_DOUBLE_LOCKS) or level.master_cell != LevelData.NO_CELL else 1
		var key_counts: Dictionary[Vector2i, int] = {}
		for link: Vector4i in level.dependencies:
			var waiting := Vector2i(link.x, link.y)
			var required := Vector2i(link.z, link.w)
			var offset := required - waiting
			check(maxi(absi(offset.x), absi(offset.y)) == 1, "level %d: dependency %s links neighbours" % [level_number, link])
			var waiting_arrow := board.get_arrow_at(waiting)
			check(Arrow.direction_to_vector(waiting_arrow.direction) != offset, "level %d: dependency %s isn't already a path block" % [level_number, link])
			key_counts[waiting] = key_counts.get(waiting, 0) + 1
			check(key_counts[waiting] <= max_keys, "level %d: arrow %s waits for at most %d arrows" % [level_number, waiting, max_keys])
		total_dependencies += level.dependencies.size()
	check(total_dependencies > CHECKED_LEVEL_COUNT, "dependencies are common in generated levels (%d)" % total_dependencies)


func test_difficulty_increases_then_holds() -> void:
	var sequence := _get_sequence()
	var start := sequence.handmade_count() + 1
	var ramp_end := start + LevelSequence.DIFFICULTY_RAMP_LEVELS
	check_eq(sequence.difficulty_for(start), 0.0, "first generated level is the gentlest")
	check_eq(sequence.difficulty_for(ramp_end), 1.0, "hardest settings reached at end of ramp")
	check_eq(sequence.difficulty_for(ramp_end + 5000), 1.0, "and held there")
	var early := _average_arrows(sequence, start, 15)
	var late := _average_arrows(sequence, ramp_end, 15)
	check(late > early * 1.4, "late levels have clearly more arrows (%.1f vs %.1f)" % [late, early])


func test_far_levels_generate() -> void:
	var sequence := _get_sequence()
	for level_number: int in [1000, 99999, 1000000]:
		var level := sequence.get_level(level_number)
		check(level != null and BoardSolver.is_solvable(level.build_board()), "level %d playable" % level_number)


func test_next_level_is_prepared_in_the_background() -> void:
	var sequence := _get_sequence()
	sequence.prefetch(400)
	var started_at := Time.get_ticks_usec()
	while not sequence.is_cached(400) and Time.get_ticks_usec() - started_at < 5000000:
		await wait_frames(1)
	check(sequence.is_cached(400), "level 400 generated on a worker thread")
	var direct := LevelSequence.new(load("res://levels/level_catalog.tres")).get_level(400)
	check_eq(sequence.get_level(400).layout, direct.layout, "same level as generating it directly")
	sequence.finish_prefetch()


func test_generation_is_fast_enough() -> void:
	var sequence := _get_sequence()
	var start := sequence.handmade_count() + LevelSequence.DIFFICULTY_RAMP_LEVELS
	var started_at := Time.get_ticks_usec()
	for level_number: int in range(start, start + 20):
		sequence.get_level(level_number)
	var average_ms := (Time.get_ticks_usec() - started_at) / 20000.0
	print("  hardest-tier generation: %.1f ms per level (desktop)" % average_ms)
	# Generated on a worker thread while the previous level is played, so the
	# budget is "ready long before the player finishes", not "instant".
	check(average_ms < 150.0, "hard levels generate in under 150 ms on desktop (%.1f ms)" % average_ms)
	var fresh := LevelSequence.new(load("res://levels/level_catalog.tres"))
	var big_started := Time.get_ticks_usec()
	fresh.get_level(400)
	var big_ms := (Time.get_ticks_usec() - big_started) / 1000.0
	print("  largest boards: %.0f ms (desktop)" % big_ms)
	check(big_ms < 600.0, "largest boards generate in under 600 ms on desktop (%.0f ms)" % big_ms)


func _average_arrows(sequence: LevelSequence, first_level: int, count: int) -> float:
	var total := 0
	for level_number: int in range(first_level, first_level + count):
		total += sequence.get_level(level_number).build_board().arrow_count()
	return float(total) / count


func test_challenge_pacing() -> void:
	var sequence := _get_sequence()
	var challenges: Array[int] = []
	for level_number: int in range(1, 1000):
		if sequence.is_challenge(level_number):
			challenges.append(level_number)
	check_eq(challenges[0], LevelSequence.FIRST_CHALLENGE_LEVEL, "first challenge")
	check(challenges.all(func(n: int) -> bool: return sequence.is_generated(n)), "never a hand-made level")
	for index: int in range(1, challenges.size()):
		var gap := challenges[index] - challenges[index - 1]
		check(gap >= LevelSequence.CHALLENGE_GAP_MIN and gap <= LevelSequence.CHALLENGE_GAP_MAX, "gap %d between %d and %d" % [gap, challenges[index - 1], challenges[index]])
	check(challenges.size() >= 30, "challenges keep coming (%d by level 1000)" % challenges.size())


func test_twists_are_introduced_then_mixed() -> void:
	for index: int in LevelSequence.TWIST_ORDER.size():
		check_eq(LevelSequence.twists_for_challenge(index), PackedStringArray([LevelSequence.TWIST_ORDER[index]]), "challenge %d debuts one twist" % index)
	for index: int in range(LevelSequence.COMBINE_FROM_CHALLENGE, 40):
		var twists := LevelSequence.twists_for_challenge(index)
		check(twists.size() == 2 and twists[0] != twists[1], "later challenges merge two different twists")


func test_twist_schedule() -> void:
	var sequence := _get_sequence()
	for level_number: int in range(1, LevelSequence.FIRST_CHALLENGE_LEVEL):
		check(sequence.twists_for_level(level_number).is_empty(), "no twists before the first debut (level %d)" % level_number)
	for index: int in LevelSequence.TWIST_ORDER.size():
		var debut := sequence.debut_level(index)
		var twist := LevelSequence.TWIST_ORDER[index]
		check_eq(sequence.twists_for_level(debut), PackedStringArray([twist]), "%s debuts at %d" % [twist, debut])
		for practice: int in range(1, LevelSequence.PRACTICE_LEVELS + 1):
			check_eq(sequence.twists_for_level(debut + practice), PackedStringArray([twist]), "%s practice at %d" % [twist, debut + practice])
	var first_merge := sequence.first_merge_level()
	check_eq(sequence.twists_for_level(first_merge), PackedStringArray([LevelSequence.TWIST_ORDER[0], LevelSequence.TWIST_ORDER[1]]), "first merge at %d uses the first two twists" % first_merge)
	check(sequence.get_level(first_merge).is_first_merge, "first merge flagged")
	check(sequence.get_level(50).is_first_master and not sequence.get_level(100).is_first_master, "only level 50 is the first master")


func test_random_twists_follow_the_rules() -> void:
	var sequence := _get_sequence()
	var singles := 0
	var merges := 0
	var counted := 0
	var previous := PackedStringArray()
	for level_number: int in range(LevelSequence.FIRST_CHALLENGE_LEVEL, 600):
		var twists := sequence.twists_for_level(level_number)
		var known: Array[String] = []
		for index: int in LevelSequence.TWIST_ORDER.size():
			if sequence.debut_level(index) <= level_number:
				known.append(LevelSequence.TWIST_ORDER[index])
		for twist: String in twists:
			check(known.has(twist), "level %d only uses introduced twists (%s)" % [level_number, twist])
		check(twists.size() <= 2, "level %d has at most two twists" % level_number)
		if twists.size() == 2:
			check(twists[0] != twists[1], "level %d merges two different twists" % level_number)
		var scheduled: Variant = sequence._scheduled_twists(level_number)
		var previous_scheduled: Variant = sequence._scheduled_twists(level_number - 1)
		if scheduled == null:
			for twist: String in twists:
				check(not previous.has(twist), "level %d does not repeat %s from the level before" % [level_number, twist])
			if level_number > sequence.debut_level(3) + LevelSequence.PRACTICE_LEVELS:
				counted += 1
				if twists.size() == 1:
					singles += 1
				elif twists.size() == 2:
					merges += 1
		previous = twists
	var single_rate := float(singles) / counted
	var merge_rate := float(merges) / counted
	check(single_rate > 0.12 and single_rate < 0.35, "single twists on roughly a quarter of ordinary levels (%.2f)" % single_rate)
	check(merge_rate > 0.07 and merge_rate < 0.25, "merges on roughly one in six (%.2f)" % merge_rate)


func test_challenge_levels_show_their_twists() -> void:
	var sequence := _get_sequence()
	var level_number := LevelSequence.FIRST_CHALLENGE_LEVEL
	for index: int in 12:
		var level := sequence.get_level(level_number)
		var label := "challenge level %d" % level_number
		check(level.is_challenge, "%s flagged" % label)
		check(not level.twists.is_empty(), "%s has twists" % label)
		check_eq(level.new_twist, LevelSequence.TWIST_ORDER[index] if index < LevelSequence.TWIST_ORDER.size() else "", "%s new twist" % label)
		var board := level.build_board()
		check(board != null and BoardSolver.is_solvable(level.build_board()), "%s solvable" % label)
		var uses := LevelGenerator.count_tile_uses(level)
		if level.has_twist(LevelData.TWIST_MIRRORS):
			check(uses.x >= LevelGenerator.MIN_TILE_USES, "%s: %d arrows bounce off mirrors" % [label, uses.x])
		if level.has_twist(LevelData.TWIST_BLACK_HOLES):
			check(uses.y >= LevelGenerator.MIN_TILE_USES, "%s: %d arrows fly through black holes" % [label, uses.y])
		if level.has_twist(LevelData.TWIST_WALLS):
			check(board.get_walls().size() >= 3, "%s has walls" % label)
			check(board.get_arrows().all(func(a: Arrow) -> bool: return not board.is_walled_in(a.id)), "%s: no arrow walled in for good" % label)
		if level.has_twist(LevelData.TWIST_DOUBLE_LOCKS):
			check(LevelGenerator.count_double_locks(level) >= LevelGenerator.MIN_DOUBLE_LOCKS, "%s has double locks" % label)
		if level.has_twist(LevelData.TWIST_LONG_CHAINS):
			check(LevelGenerator.longest_chain(level) >= LevelGenerator.MIN_LONG_CHAIN, "%s has a long chain (%d)" % [label, LevelGenerator.longest_chain(level)])
		level_number += LevelSequence.challenge_gap(index)


func test_master_arrow_every_fiftieth_level() -> void:
	var sequence := _get_sequence()
	check(not sequence.get_level(49).master_cell != LevelData.NO_CELL, "no master on level 49")
	for level_number: int in [50, 100, 150, 200, 250, 300]:
		var level := sequence.get_level(level_number)
		var label := "level %d" % level_number
		check(level.master_cell != LevelData.NO_CELL, "%s has a master arrow" % label)
		var board := level.build_board()
		var master := board.get_master_id()
		check(not board.can_exit(master), "%s: master can't leave at the start" % label)
		check(board.get_pending_requirements(master).size() >= 2, "%s: master is double-locked" % label)
		var rounds := BoardSolver.exit_rounds(level.build_board())
		check(not rounds.has(-1), "%s solvable" % label)
		var total: int = rounds.values().max()
		check(float(rounds[master]) / total >= LevelGenerator.MASTER_ROUND_MIN - 0.01, "%s: master frees mid-solve (round %d of %d)" % [label, rounds[master], total])


func test_next_special_countdown() -> void:
	var sequence := _get_sequence()
	check_eq(sequence.next_special_after(1), {"level": LevelSequence.FIRST_CHALLENGE_LEVEL, "kind": "vault"}, "first vault")
	check_eq(sequence.next_special_label(20), "NEXT VAULT IN 7", "countdown")
	check_eq(sequence.next_special_label(26), "VAULT NEXT", "vault next")
	check_eq(sequence.next_special_after(49), {"level": 50, "kind": "master"}, "master level after the second vault")
	check_eq(sequence.next_special_label(49), "MASTER LEVEL NEXT", "master next")
	check_eq(sequence.next_special_after(LevelSequence.FIRST_CHALLENGE_LEVEL)["level"], sequence.challenge_level(1), "after a vault, the next one")


func test_upcoming_label_for_play_button() -> void:
	var sequence := _get_sequence()
	check_eq(sequence.upcoming_label(20), "VAULT IN 7", "countdown before the first vault")
	check_eq(sequence.upcoming_label(LevelSequence.FIRST_CHALLENGE_LEVEL), "VAULT CHALLENGE", "on the vault itself")
	check_eq(sequence.upcoming_label(50), "MASTER LEVEL", "on a master level")


func test_challenges_get_harder() -> void:
	var sequence := _get_sequence()
	var hardness: Array[float] = []
	for index: int in 15:
		hardness.append(sequence.hardness_for(sequence.challenge_level(index)))
	for index: int in range(1, hardness.size()):
		check(hardness[index] >= hardness[index - 1], "challenge %d at least as hard as the one before" % index)
	check(hardness[0] > 0.0 and hardness[14] == 1.0, "starts above ordinary levels and reaches the cap")
	var early := _average_challenge_stats(sequence, 0, 4)
	var late := _average_challenge_stats(sequence, 10, 4)
	check(late.x > early.x, "later challenges need more rounds (%.1f vs %.1f)" % [late.x, early.x])
	check(late.y > early.y, "later challenges have more dependencies (%.1f vs %.1f)" % [late.y, early.y])


func test_ordinary_levels_keep_getting_harder() -> void:
	var sequence := _get_sequence()
	check_eq(sequence.hardness_for(LevelSequence.HARDNESS_START_LEVEL - 1), 0.0, "no extra hardness early on")
	check(sequence.hardness_for(100) >= 0.4, "clearly harder by level 100 (%.2f)" % sequence.hardness_for(100))
	var previous := 0.0
	for level_number: int in [30, 60, 100, 150, 220, 300]:
		if sequence.challenge_index(level_number) >= 0:
			continue
		check(sequence.hardness_for(level_number) >= previous, "keeps rising at level %d" % level_number)
		previous = sequence.hardness_for(level_number)
	check(is_equal_approx(sequence.hardness_for(5001), LevelSequence.LATE_HARDNESS_MAX), "capped")
	for index: int in 10:
		var vault := sequence.challenge_level(index)
		check(sequence.hardness_for(vault) > sequence.hardness_for(vault - 1) + 0.2 or sequence.hardness_for(vault) == 1.0, "vault %d harder than the level before it" % index)


func test_boards_grow_with_more_smaller_arrows() -> void:
	var sequence := _get_sequence()
	check_eq(sequence.size_for(60), 0.0, "boards stay 8 x 10 at most early on")
	check_eq(sequence.size_for(1000), 1.0, "and grow to the largest size later")
	var biggest := Vector2i.ZERO
	var arrows := 0
	for level_number: int in range(400, 410):
		var board := sequence.get_level(level_number).build_board()
		biggest = Vector2i(maxi(biggest.x, board.size.x), maxi(biggest.y, board.size.y))
		arrows = maxi(arrows, board.arrow_count())
	check(biggest.x > LevelGenerator.MAX_COLUMNS and biggest.x <= LevelGenerator.MAX_COLUMNS + LevelGenerator.EXTRA_COLUMNS, "wider boards late (%d columns)" % biggest.x)
	check(biggest.y <= LevelGenerator.MAX_ROWS + LevelGenerator.EXTRA_ROWS, "never taller than the cap (%d rows)" % biggest.y)
	print("  late boards: up to %s with %d arrows" % [biggest, arrows])


## Average (rounds, dependencies) over [param count] challenges from [param first].
func _average_challenge_stats(sequence: LevelSequence, first: int, count: int) -> Vector2:
	var total := Vector2.ZERO
	for index: int in range(first, first + count):
		var level := sequence.get_level(sequence.challenge_level(index))
		total += Vector2(BoardSolver.count_solution_rounds(level.build_board()), level.dependencies.size())
	return total / count
