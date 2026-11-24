class_name LevelSequence
extends RefCounted
## The endless list of levels, numbered from 1: the hand-made catalog first,
## then generated levels that grow harder up to the generator's limits.
##
## Among the generated levels (everything seeded, the same for every player):
## - Vault challenges arrive every 20–30 levels. The first four each debut one
##   twist (double locks → walls → long chains → hidden links); from the fifth
##   on they always merge two twists.
## - After a debut, the next PRACTICE_LEVELS levels use that twist alone.
## - The level after the second twist's practice is the first merge (both).
## - From then on ordinary levels randomly get one known twist
##   (SINGLE_TWIST_CHANCE) or, once merging has started, two (MERGE_CHANCE).
##   Outside debuts and practice, no twist appears two levels in a row.
## - Every 50th level hides a master arrow.

## Generated levels it takes to reach the generator's hardest settings.
const DIFFICULTY_RAMP_LEVELS := 80
const FIRST_CHALLENGE_LEVEL := 27
const CHALLENGE_GAP_MIN := 20
const CHALLENGE_GAP_MAX := 30
const CHALLENGE_SEED_SALT := "chain-escape-vaults-v1"
const CHALLENGE_DIFFICULTY_BONUS := 0.2
## Challenges from this index on merge two twists.
const COMBINE_FROM_CHALLENGE := 4
const PRACTICE_LEVELS := 2
const SINGLE_TWIST_CHANCE := 0.25
const MERGE_CHANCE := 1.0 / 6.0
const TWIST_SEED_SALT := "chain-escape-twists-v1"
const MASTER_INTERVAL := 50
## Hardness keeps rising after the difficulty ramp: slowly for ordinary
## levels, faster and earlier for Vault challenges (each tighter than the last).
const LATE_HARDNESS_LEVELS := 600
const LATE_HARDNESS_MAX := 0.6
const CHALLENGE_HARDNESS_START := 0.2
const CHALLENGE_HARDNESS_STEP := 0.07
## The order in which twists are introduced.
const TWIST_ORDER: Array[String] = [
	LevelData.TWIST_DOUBLE_LOCKS,
	LevelData.TWIST_WALLS,
	LevelData.TWIST_LONG_CHAINS,
	LevelData.TWIST_HIDDEN_LINKS,
]

var _handmade: LevelCatalog


func _init(handmade: LevelCatalog) -> void:
	_handmade = handmade if handmade != null else LevelCatalog.new()


func handmade_count() -> int:
	return _handmade.count()


func is_generated(level_number: int) -> bool:
	return level_number > _handmade.count()


## Returns the level, or null for numbers below 1 (or a generator failure).
func get_level(level_number: int) -> LevelData:
	if level_number < 1:
		return null
	if not is_generated(level_number):
		return _handmade.get_level(level_number - 1)
	var challenge := challenge_index(level_number)
	var twists := twists_for_level(level_number)
	var difficulty := difficulty_for(level_number)
	if challenge >= 0:
		difficulty = minf(difficulty + CHALLENGE_DIFFICULTY_BONUS, 1.0)
	var level := LevelGenerator.generate(level_number, difficulty, twists, is_master_level(level_number), hardness_for(level_number))
	if level == null:
		return null
	if challenge >= 0:
		level.is_challenge = true
		level.new_twist = TWIST_ORDER[challenge] if challenge < TWIST_ORDER.size() else ""
	level.is_first_merge = level_number == first_merge_level()
	level.is_first_master = level_number == first_master_level()
	return level


## Twists used by [param level_number] (empty for hand-made levels).
func twists_for_level(level_number: int) -> PackedStringArray:
	if not is_generated(level_number):
		return PackedStringArray()
	var scheduled: Variant = _scheduled_twists(level_number)
	if scheduled != null:
		return scheduled
	var twists := _random_twists(level_number)
	var previous: Variant = _scheduled_twists(level_number - 1)
	var previous_twists: PackedStringArray = previous if previous != null else _random_twists(level_number - 1)
	var filtered := PackedStringArray()
	for twist: String in twists:
		if not previous_twists.has(twist):
			filtered.append(twist)
	return filtered


## Level where twist [param twist_index] (in TWIST_ORDER) debuts.
func debut_level(twist_index: int) -> int:
	return challenge_level(twist_index)


## Level number of the Vault challenge with [param index].
func challenge_level(index: int) -> int:
	var level := FIRST_CHALLENGE_LEVEL
	for step: int in index:
		level += challenge_gap(step)
	return level


func first_merge_level() -> int:
	return debut_level(1) + PRACTICE_LEVELS + 1


func first_master_level() -> int:
	var level := MASTER_INTERVAL
	while not is_generated(level):
		level += MASTER_INTERVAL
	return level


## Twists fixed by the schedule (challenge, practice, first merge), or null
## if the level is left to chance.
func _scheduled_twists(level_number: int) -> Variant:
	if not is_generated(level_number):
		return PackedStringArray()
	var challenge := challenge_index(level_number)
	if challenge >= 0:
		return twists_for_challenge(challenge)
	for index: int in TWIST_ORDER.size():
		var since_debut := level_number - debut_level(index)
		if since_debut >= 1 and since_debut <= PRACTICE_LEVELS:
			return PackedStringArray([TWIST_ORDER[index]])
	if level_number == first_merge_level():
		return PackedStringArray([TWIST_ORDER[0], TWIST_ORDER[1]])
	return null


## The seeded random roll for an ordinary level, before the "not the same
## twist two levels in a row" rule.
func _random_twists(level_number: int) -> PackedStringArray:
	var known: Array[String] = []
	for index: int in TWIST_ORDER.size():
		if debut_level(index) < level_number:
			known.append(TWIST_ORDER[index])
	if known.is_empty() or not is_generated(level_number):
		return PackedStringArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s:%d" % [TWIST_SEED_SALT, level_number]).hash()
	var roll := rng.randf()
	var can_merge := known.size() >= 2 and level_number > first_merge_level()
	if can_merge and roll < MERGE_CHANCE:
		return _pick_distinct(known, 2, rng)
	if roll < (MERGE_CHANCE if can_merge else 0.0) + SINGLE_TWIST_CHANCE:
		return _pick_distinct(known, 1, rng)
	return PackedStringArray()


static func _pick_distinct(pool: Array[String], count: int, rng: RandomNumberGenerator) -> PackedStringArray:
	var remaining := pool.duplicate()
	var picked := PackedStringArray()
	for index: int in mini(count, remaining.size()):
		picked.append(remaining.pop_at(rng.randi_range(0, remaining.size() - 1)))
	return picked


## 0.0 for the first generated level, rising to 1.0 over DIFFICULTY_RAMP_LEVELS.
func difficulty_for(level_number: int) -> float:
	var generated_index := level_number - _handmade.count() - 1
	return clampf(float(generated_index) / DIFFICULTY_RAMP_LEVELS, 0.0, 1.0)


## Extra hardness (0..1) beyond the difficulty ramp. Ordinary levels start
## at 0 and rise slowly once the ramp is complete; Vault challenge number k
## gets CHALLENGE_HARDNESS_START + k * CHALLENGE_HARDNESS_STEP (capped at 1).
func hardness_for(level_number: int) -> float:
	var challenge := challenge_index(level_number)
	if challenge >= 0:
		return minf(CHALLENGE_HARDNESS_START + challenge * CHALLENGE_HARDNESS_STEP, 1.0)
	var past_ramp := level_number - _handmade.count() - 1 - DIFFICULTY_RAMP_LEVELS
	return clampf(float(past_ramp) / LATE_HARDNESS_LEVELS, 0.0, 1.0) * LATE_HARDNESS_MAX


## 0-based index of the Vault challenge at [param level_number], or -1.
func challenge_index(level_number: int) -> int:
	if not is_generated(level_number) or level_number < FIRST_CHALLENGE_LEVEL:
		return -1
	var challenge_level := FIRST_CHALLENGE_LEVEL
	var index := 0
	while challenge_level < level_number:
		challenge_level += challenge_gap(index)
		index += 1
	return index if challenge_level == level_number else -1


## The next special level after [param level_number]: {"level": n,
## "kind": "vault" or "master"}. A master level wins if both coincide.
func next_special_after(level_number: int) -> Dictionary:
	var next_master := (level_number / MASTER_INTERVAL + 1) * MASTER_INTERVAL
	while not is_generated(next_master):
		next_master += MASTER_INTERVAL
	var next_vault := FIRST_CHALLENGE_LEVEL
	var index := 0
	while next_vault <= level_number:
		next_vault += challenge_gap(index)
		index += 1
	if next_master <= next_vault:
		return {"level": next_master, "kind": "master"}
	return {"level": next_vault, "kind": "vault"}


## Short countdown text, e.g. "NEXT VAULT IN 8" or "MASTER LEVEL NEXT".
func next_special_label(level_number: int) -> String:
	var special := next_special_after(level_number)
	var name := "MASTER LEVEL" if special["kind"] == "master" else "VAULT"
	var distance: int = special["level"] - level_number
	if distance <= 1:
		return "%s NEXT" % name
	return "NEXT %s IN %d" % [name, distance]


## Label for the Play button before playing [param level_number]: the
## special level itself ("VAULT CHALLENGE") or how far away the next one is.
func upcoming_label(level_number: int) -> String:
	var special := next_special_after(level_number - 1)
	var name := "MASTER LEVEL" if special["kind"] == "master" else "VAULT"
	var distance: int = special["level"] - level_number
	if distance == 0:
		return "MASTER LEVEL" if special["kind"] == "master" else "VAULT CHALLENGE"
	return "%s IN %d" % [name, distance]


func is_challenge(level_number: int) -> bool:
	return challenge_index(level_number) >= 0


func is_master_level(level_number: int) -> bool:
	return is_generated(level_number) and level_number % MASTER_INTERVAL == 0


## Levels between challenge [param index] and the next one.
static func challenge_gap(index: int) -> int:
	var spread := CHALLENGE_GAP_MAX - CHALLENGE_GAP_MIN + 1
	return CHALLENGE_GAP_MIN + absi(("%s:%d" % [CHALLENGE_SEED_SALT, index]).hash()) % spread


static func twists_for_challenge(index: int) -> PackedStringArray:
	if index < TWIST_ORDER.size():
		return PackedStringArray([TWIST_ORDER[index]])
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s:twists:%d" % [CHALLENGE_SEED_SALT, index]).hash()
	return _pick_distinct(TWIST_ORDER, 2, rng)
