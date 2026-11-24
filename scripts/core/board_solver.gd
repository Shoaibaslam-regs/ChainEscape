class_name BoardSolver
extends RefCounted
## Solvability check for a board.
##
## Exact for this game's rules: removing an arrow never blocks or locks any
## other arrow, so removing every free arrow each round can never lead into
## a dead end. If this greedy approach gets stuck, no order would work.


## Clears [param board] round by round, where each round removes every arrow
## that is free at the start of that round. The board is modified, so pass
## a fresh copy. Returns the number of rounds needed (0 for an empty board),
## or -1 if some arrows can never leave.
static func count_solution_rounds(board: BoardState) -> int:
	var rounds := exit_rounds(board)
	if rounds.has(-1):
		return -1
	var highest := 0
	for value: int in rounds.values():
		highest = maxi(highest, value)
	return highest


## Clears [param board] round by round and returns, for each arrow id, the
## round (1-based) in which it left. If arrows get stuck the result has the
## key -1. A master arrow's release ends the solve: everything left leaves in
## that round. The board is modified, so pass a fresh copy.
static func exit_rounds(board: BoardState) -> Dictionary[int, int]:
	var rounds: Dictionary[int, int] = {}
	var round_number := 0
	while not board.is_cleared():
		round_number += 1
		var free_arrows: Array[Arrow] = []
		for arrow: Arrow in board.get_arrows():
			if board.can_exit(arrow.id):
				free_arrows.append(arrow)
		if free_arrows.is_empty():
			rounds[-1] = round_number
			return rounds
		for arrow: Arrow in free_arrows:
			if board.get_arrow(arrow.id) == null:
				continue
			var remaining := board.get_arrows() if board.is_master(arrow.id) else ([arrow] as Array[Arrow])
			board.try_exit(arrow.id)
			for gone: Arrow in remaining:
				rounds[gone.id] = round_number
	return rounds


static func is_solvable(board: BoardState) -> bool:
	return count_solution_rounds(board) >= 0
