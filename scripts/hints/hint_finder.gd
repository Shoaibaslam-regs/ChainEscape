class_name HintFinder
extends RefCounted
## Picks the arrow a hint should show: one that can leave right now, chosen
## to be the most useful move, i.e. the one that frees the most other
## arrows (keys of locks, keys of chains lying across paths, arrows standing
## in other arrows' way). Any free arrow is a safe move in this game:
## leaving never blocks anything, so a hint can never lead into a dead end.


## The id of the arrow to show, or -1 if nothing can move.
static func best_arrow(board: BoardState) -> int:
	var best := -1
	var best_score := -1
	for arrow: Arrow in board.get_arrows():
		if not board.can_exit(arrow.id):
			continue
		var score := _frees(board, arrow)
		if score > best_score:
			best_score = score
			best = arrow.id
	return best


## How many other arrows are held back by [param candidate] (as a key, a
## chain's key, or by standing in their path).
static func _frees(board: BoardState, candidate: Arrow) -> int:
	var count := 0
	for other: Arrow in board.get_arrows():
		if other.id == candidate.id:
			continue
		if board.get_pending_requirements(other.id).has(candidate):
			count += 1
		elif board.find_blocker(other.id) == candidate:
			count += 1
		elif board.find_blocking_chain(other.id) == candidate:
			count += 1
	return count
