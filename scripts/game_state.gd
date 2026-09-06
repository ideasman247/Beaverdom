extends Node
## Lodge economy and campaign cursor. Lives across valley ↔ puzzle.

const DAM_COSTS: Array[int] = [8, 12, 16]
const MAX_DAM := 3

var stars := 0
var dam_stage := 0
var puzzle_index := 0
var last_payout := 0
var tidied: Dictionary = {}


func payout_for(moves_left: int) -> int:
	return 5 + int(moves_left / 3.0)


func award_win(moves_left: int) -> int:
	var gain := payout_for(moves_left)
	stars += gain
	last_payout = gain
	return gain


func dam_cost() -> int:
	if dam_stage >= MAX_DAM:
		return 0
	return DAM_COSTS[dam_stage]


func can_raise_dam() -> bool:
	return dam_stage < MAX_DAM and stars >= dam_cost()


func raise_dam() -> bool:
	if not can_raise_dam():
		return false
	stars -= dam_cost()
	dam_stage += 1
	return true


func is_tidied(id: String) -> bool:
	return tidied.has(id)


func tidy(id: String) -> void:
	if tidied.has(id):
		return
	tidied[id] = true
	stars += 1
