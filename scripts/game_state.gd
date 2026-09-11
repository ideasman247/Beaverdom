extends Node
## Lodge economy and campaign cursor. Lives across valley ↔ puzzle.

const DAM_COSTS: Array[int] = [8, 12, 16]
const MAX_DAM := 3
const CHOPS_COSTS: Array[int] = [6, 10]
const MAX_CHOPS := 3
const LOG_CHOPS_NEED := 2
const SEEP_COST := 7
const OTTER_GIFT := 3
const SAVE_PATH := "user://beaverdom.cfg"
const IDLE_SECS_PER_STICK := 480
const PRACTICE_INDEX := 20

var stars := 0
var dam_stage := 0
var chops := 1
var puzzle_index := 0
var last_payout := 0
var last_idle := 0
var last_seen := 0.0
var tidied: Dictionary = {}
var seeps_patched: Dictionary = {}
var log_cleared := false
var otter_claimed_day := -1
var heard: Dictionary = {}

signal progress_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	tree_exiting.connect(save_game)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			save_game()
		NOTIFICATION_APPLICATION_RESUMED:
			collect_idle()
			progress_changed.emit()


func save_game() -> void:
	last_seen = Time.get_unix_time_from_system()
	var cfg := ConfigFile.new()
	cfg.set_value("g", "stars", stars)
	cfg.set_value("g", "dam_stage", dam_stage)
	cfg.set_value("g", "chops", chops)
	cfg.set_value("g", "puzzle_index", puzzle_index)
	cfg.set_value("g", "log_cleared", log_cleared)
	cfg.set_value("g", "otter_claimed_day", otter_claimed_day)
	cfg.set_value("g", "last_seen", int(last_seen))
	cfg.set_value("g", "tidied", PackedStringArray(tidied.keys()))
	cfg.set_value("g", "seeps", PackedStringArray(seeps_patched.keys()))
	cfg.set_value("g", "heard", PackedStringArray(heard.keys()))
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Save failed (%s) at %s" % [error_string(err), OS.get_user_data_dir()])


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		last_seen = Time.get_unix_time_from_system()
		return
	stars = int(cfg.get_value("g", "stars", 0))
	dam_stage = int(cfg.get_value("g", "dam_stage", 0))
	chops = int(cfg.get_value("g", "chops", 1))
	puzzle_index = int(cfg.get_value("g", "puzzle_index", 0))
	log_cleared = bool(cfg.get_value("g", "log_cleared", false))
	otter_claimed_day = int(cfg.get_value("g", "otter_claimed_day", -1))
	last_seen = float(cfg.get_value("g", "last_seen", Time.get_unix_time_from_system()))
	tidied.clear()
	for key in cfg.get_value("g", "tidied", PackedStringArray()):
		tidied[str(key)] = true
	seeps_patched.clear()
	for key in cfg.get_value("g", "seeps", PackedStringArray()):
		seeps_patched[str(key)] = true
	heard.clear()
	for key in cfg.get_value("g", "heard", PackedStringArray()):
		heard[str(key)] = true


func idle_cap() -> int:
	return 12 + dam_stage * 4 + patched_seep_count() * 2


func collect_idle() -> int:
	var now := Time.get_unix_time_from_system()
	if last_seen <= 1.0:
		last_seen = now
		last_idle = 0
		save_game()
		return 0
	var elapsed := now - last_seen
	var gain := mini(int(elapsed / float(IDLE_SECS_PER_STICK)), idle_cap())
	last_seen = now
	if gain > 0:
		last_idle = gain
		stars += gain
	save_game()
	return gain


func advance_after_win(level_index: int, level_count: int) -> void:
	if level_index >= level_count - 1:
		puzzle_index = mini(PRACTICE_INDEX, level_count - 1)
	else:
		puzzle_index = level_index + 1
	save_game()


func payout_for(moves_left: int) -> int:
	return 5 + int(moves_left / 3.0)


func award_win(moves_left: int) -> int:
	var gain := payout_for(moves_left)
	stars += gain
	last_payout = gain
	save_game()
	return gain


func award_snood_win(rescued: int, bits: int) -> int:
	var gain := 4 + bits + int(rescued / 2)
	stars += gain
	last_payout = gain
	save_game()
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
	save_game()
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
	save_game()
	return true


func is_tidied(id: String) -> bool:
	return tidied.has(id)


func tidy(id: String) -> void:
	if tidied.has(id):
		return
	tidied[id] = true
	stars += 1
	save_game()


func can_chop_log() -> bool:
	return not log_cleared and chops >= LOG_CHOPS_NEED


func chop_log() -> bool:
	if not can_chop_log():
		return false
	log_cleared = true
	stars += 2
	save_game()
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
	save_game()
	return true


func otter_unlocked() -> bool:
	return dam_stage >= 3


func frog_unlocked() -> bool:
	return dam_stage >= 2


func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func can_claim_otter() -> bool:
	return otter_unlocked() and otter_claimed_day != _today()


func claim_otter() -> int:
	if not can_claim_otter():
		return 0
	otter_claimed_day = _today()
	stars += OTTER_GIFT
	save_game()
	return OTTER_GIFT


func first_hear(id: String, line: String) -> String:
	if heard.has(id):
		return ""
	heard[id] = true
	save_game()
	return line


func debug_reset_sticks() -> void:
	stars = 0
	last_payout = 0
	last_idle = 0
	save_game()
	progress_changed.emit()


func debug_reset_chops() -> void:
	chops = 1
	save_game()
	progress_changed.emit()


func debug_reset_dam() -> void:
	dam_stage = 0
	save_game()
	progress_changed.emit()


func debug_reset_puzzles() -> void:
	puzzle_index = 0
	save_game()
	progress_changed.emit()
