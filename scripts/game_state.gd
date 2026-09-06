extends Node
## Lodge economy and campaign cursor. Lives across valley ↔ puzzle.

const DAM_COSTS: Array[int] = [8, 12, 16]
const MAX_DAM := 3
const CHOPS_COSTS: Array[int] = [6, 10]
const MAX_CHOPS := 3
const LOG_CHOPS_NEED := 2
const SEEP_COST := 7
const OTTER_GIFT := 3


var stars := 0
var dam_stage := 0
var chops := 1
var puzzle_index := 0
var last_payout := 0
var tidied: Dictionary = {}
var seeps_patched: Dictionary = {}
var log_cleared := false
var otter_claimed_day := -1
var heard: Dictionary = {}


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


func chops_cost() -> int:
	if chops >= MAX_CHOPS:
		return 0
	return CHOPS_COSTS[chops - 1]


func can_raise_chops() -> bool:
	return chops < MAX_CHOPS and stars >= chops_cost()


func raise_chops() -> bool:
	if not can_raise_chops():
		return false
	stars -= chops_cost()
	chops += 1
	return true


func is_tidied(id: String) -> bool:
	return tidied.has(id)


func tidy(id: String) -> void:
	if tidied.has(id):
		return
	tidied[id] = true
	stars += 1


func can_chop_log() -> bool:
	return not log_cleared and chops >= LOG_CHOPS_NEED


func chop_log() -> bool:
	if not can_chop_log():
		return false
	log_cleared = true
	stars += 2
	return true


func is_seep_patched(id: String) -> bool:
	return seeps_patched.has(id)


func patched_seep_count() -> int:
	return seeps_patched.size()


func can_patch_seep(id: String) -> bool:
	return not seeps_patched.has(id) and stars >= SEEP_COST


func patch_seep(id: String) -> bool:
	if not can_patch_seep(id):
		return false
	stars -= SEEP_COST
	seeps_patched[id] = true
	return true


func otter_unlocked() -> bool:
	return dam_stage >= 1


func frog_unlocked() -> bool:
	return dam_stage >= 1 or tidied.size() > 0


func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func can_claim_otter() -> bool:
	return otter_unlocked() and otter_claimed_day != _today()


func claim_otter() -> int:
	if not can_claim_otter():
		return 0
	otter_claimed_day = _today()
	stars += OTTER_GIFT
	return OTTER_GIFT


func first_hear(id: String, line: String) -> String:
	if heard.has(id):
		return ""
	heard[id] = true
	return line
