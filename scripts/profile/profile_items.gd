class_name ProfileItems
extends RefCounted
## The avatars and frames a player can pick on the Profile screen. All are
## earned by playing (a rank, or an achievement); none are sold in v1.0
## (CLAUDE.md: paid cosmetics wait until other players can see them).
##
## "unlock" is {} (free), {"rank": "<rank name>"} or {"achievement": "<id>"}.

const AVATARS: Array[Dictionary] = [
	{"id": "arrow", "name": "Arrow", "color": Color("1F5E7A"), "unlock": {}},
	{"id": "key", "name": "Key", "color": Color("2E6B4F"), "unlock": {}},
	{"id": "padlock", "name": "Padlock", "color": Color("5B3A7A"), "unlock": {}},
	{"id": "chain", "name": "Chain", "color": Color("7A3A3A"), "unlock": {}},
	{"id": "compass", "name": "Compass", "color": Color("23557A"), "unlock": {"rank": "Keyholder"}},
	{"id": "gem", "name": "Gem", "color": Color("1F6E6A"), "unlock": {"achievement": "escape_artist"}},
	{"id": "bolt", "name": "Bolt", "color": Color("6E3F1F"), "unlock": {"achievement": "chain_reaction"}},
	{"id": "hourglass", "name": "Hourglass", "color": Color("3E4A6E"), "unlock": {"achievement": "clean_hands"}},
	{"id": "vault", "name": "Vault", "color": Color("2F3A4F"), "unlock": {"achievement": "vault_breaker"}},
	{"id": "crown", "name": "Crown", "color": Color("6E1F4A"), "unlock": {"rank": "Vaultbreaker"}},
]

## "style" picks how AvatarBadge draws the ring.
const FRAMES: Array[Dictionary] = [
	{"id": "steel", "name": "Steel", "style": "steel", "unlock": {}},
	{"id": "bronze", "name": "Bronze", "style": "bronze", "unlock": {"rank": "Keyholder"}},
	{"id": "silver", "name": "Silver", "style": "silver", "unlock": {"rank": "Locksmith"}},
	{"id": "gold", "name": "Gold", "style": "gold", "unlock": {"rank": "Vaultbreaker"}},
	{"id": "chain", "name": "Chain", "style": "chain", "unlock": {"achievement": "locksmith"}},
	{"id": "vault", "name": "Vault", "style": "vault", "unlock": {"achievement": "master_escape"}},
	{"id": "emerald", "name": "Emerald", "style": "emerald", "unlock": {"rank": "Master Locksmith"}},
]

const DEFAULT_AVATAR := "arrow"
const DEFAULT_FRAME := "steel"


static func avatar_texture(avatar_id: String) -> Texture2D:
	var path := "res://assets/avatars/%s.svg" % avatar_id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func find(items: Array[Dictionary], id: String) -> Dictionary:
	for item: Dictionary in items:
		if item["id"] == id:
			return item
	return {}


static func rank_points(rank_name: String) -> int:
	for rank: Dictionary in Rank.RANKS:
		if rank["name"] == rank_name:
			return int(rank["points"])
	return -1


static func is_unlocked(item: Dictionary, points: int, tracker: AchievementTracker) -> bool:
	var unlock: Dictionary = item.get("unlock", {})
	if unlock.has("rank"):
		var needed := rank_points(unlock["rank"])
		return needed >= 0 and points >= needed
	if unlock.has("achievement"):
		return tracker != null and tracker.is_unlocked(unlock["achievement"])
	return true


## How to earn a locked item, e.g. "Reach Keyholder rank".
static func unlock_text(item: Dictionary) -> String:
	var unlock: Dictionary = item.get("unlock", {})
	if unlock.has("rank"):
		return "Reach %s rank" % unlock["rank"]
	if unlock.has("achievement"):
		for definition: Dictionary in AchievementTracker.DEFINITIONS:
			if definition["id"] == unlock["achievement"]:
				return String(definition["description"])
	return "Free"


## The chosen item if it exists and is unlocked, otherwise the first (free) one.
static func resolve(items: Array[Dictionary], id: String, points: int, tracker: AchievementTracker) -> Dictionary:
	var item := find(items, id)
	if item.is_empty() or not is_unlocked(item, points, tracker):
		return items[0]
	return item


static func unlocked_count(items: Array[Dictionary], points: int, tracker: AchievementTracker) -> int:
	return items.filter(func(item: Dictionary) -> bool: return is_unlocked(item, points, tracker)).size()
