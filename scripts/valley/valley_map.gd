extends Control
## Lodge plus naturalist layer: chops, log, seeps, otter gift, frog comments.

@onready var _stars: Label = $Hud/Stars
@onready var _note: Label = $Note
@onready var _water: ColorRect = $Water
@onready var _dam: ColorRect = $Dam
@onready var _lodge: ColorRect = $Lodge
@onready var _upgrade: Button = $Upgrade
@onready var _chops: Button = $Chops
@onready var _play: Button = $Play
@onready var _plant1: ColorRect = $Plant1
@onready var _plant2: ColorRect = $Plant2
@onready var _plant3: ColorRect = $Plant3
@onready var _log: Button = $FallenLog
@onready var _seep_a: Button = $SeepA
@onready var _seep_b: Button = $SeepB
@onready var _otter: Button = $Otter
@onready var _frog: Button = $Frog


func _ready() -> void:
	_upgrade.pressed.connect(_on_upgrade)
	_chops.pressed.connect(_on_chops)
	_play.pressed.connect(_on_play)
	_log.pressed.connect(_on_log)
	_seep_a.pressed.connect(_on_seep.bind(_seep_a))
	_seep_b.pressed.connect(_on_seep.bind(_seep_b))
	_otter.pressed.connect(_on_otter)
	_frog.pressed.connect(_on_frog)
	for item in [$Mess/Boot, $Mess/Weeds, $Mess/Can]:
		item.pressed.connect(_on_tidy.bind(item))
	await get_tree().process_frame
	_refresh()


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _say(line: String) -> void:
	if not line.is_empty():
		_note.text = line


func _on_upgrade() -> void:
	if GameState.raise_dam():
		_say("The dam holds. Water climbs.")
		var fact := GameState.first_hear(
			"dam",
			"They stop dripping, not because they planned a pond — the sound itself drives them."
		)
		if not fact.is_empty():
			_say(fact)
		_refresh()
	elif GameState.dam_stage >= GameState.MAX_DAM:
		_say("The lodge pond is as full as it gets for now.")
	else:
		_say("Need %d sticks to raise the dam." % GameState.dam_cost())


func _on_chops() -> void:
	if GameState.raise_chops():
		var fact := GameState.first_hear(
			"chops",
			"Those orange teeth are iron-hard, and they never stop growing."
		)
		_say(fact if not fact.is_empty() else "Chops rank %d. Bigger timber, later." % GameState.chops)
		_refresh()
	elif GameState.chops >= GameState.MAX_CHOPS:
		_say("Chops are as sharp as they get for now.")
	else:
		_say("Need %d sticks to rank up Chops." % GameState.chops_cost())


func _on_log() -> void:
	if GameState.log_cleared:
		return
	if GameState.chop_log():
		_say("The log is kindling now. +2 sticks.")
		_refresh()
		return
	_say("Teeth aren't iron enough yet. Rank Chops to %d." % GameState.LOG_CHOPS_NEED)


func _on_seep(item: Button) -> void:
	var fact := GameState.first_hear(
		"seep",
		"They cannot stand dripping. Neither can we."
	)
	if GameState.is_seep_patched(item.name):
		return
	if GameState.patch_seep(item.name):
		_say("Quiet. Mud and sticks over the leak.")
		if not fact.is_empty():
			_say(fact)
		_refresh()
		return
	if not fact.is_empty():
		_say(fact)
	else:
		_say("Need %d sticks to silence this seep." % GameState.SEEP_COST)


func _on_otter() -> void:
	if not GameState.otter_unlocked():
		_say("An old lodge stays empty until the pond is real.")
		return
	var intro := GameState.first_hear(
		"otter",
		"Otters move into spare lodges and help themselves to the fish."
	)
	var gift := GameState.claim_otter()
	if gift > 0:
		_say("The otter left a gift. +%d sticks." % gift)
		if not intro.is_empty():
			_say(intro)
		_refresh()
		return
	if not intro.is_empty():
		_say(intro)
	else:
		_say("The otter already visited today. Come back tomorrow.")


func _on_frog() -> void:
	if not GameState.frog_unlocked():
		_say("The shallows are still too dry for eggs.")
		return
	var intro := GameState.first_hear(
		"frog",
		"Warm, slow water is a nursery. The frogs noticed the tidy banks."
	)
	_say(intro if not intro.is_empty() else "The frog peeps from the shallows. The pond is doing its job.")


func _on_tidy(item: Button) -> void:
	GameState.tidy(item.name)
	item.visible = false
	var intro := GameState.first_hear("tidy", "Clean banks, safer shallows.")
	_say(intro if not intro.is_empty() else "Bank looks better. +1 stick.")
	_refresh()


func _refresh() -> void:
	_stars.text = "Sticks %d · Chops %d" % [GameState.stars, GameState.chops]
	if GameState.last_payout > 0:
		_note.text = "The puzzle brought %d sticks." % GameState.last_payout
		GameState.last_payout = 0
	elif _note.text.is_empty():
		_note.text = "Tidy, chop, silence drips, then puzzle."
	if GameState.dam_stage >= GameState.MAX_DAM:
		_upgrade.text = "Dam complete"
		_upgrade.disabled = true
	else:
		_upgrade.text = "Raise dam · %d sticks" % GameState.dam_cost()
		_upgrade.disabled = not GameState.can_raise_dam()
	if GameState.chops >= GameState.MAX_CHOPS:
		_chops.text = "Chops max"
		_chops.disabled = true
	else:
		_chops.text = "Rank Chops · %d sticks" % GameState.chops_cost()
		_chops.disabled = not GameState.can_raise_chops()
	var stage := GameState.dam_stage
	var hush := float(GameState.patched_seep_count()) * 36.0
	_water.offset_top = -220.0 - float(stage) * 110.0 - hush
	_dam.size = Vector2(220.0 + float(stage) * 70.0, 70.0 + float(stage) * 28.0)
	_dam.position.x = (size.x - _dam.size.x) * 0.5 if size.x > 1.0 else 430.0
	_lodge.modulate = Color(1, 1, 1, 1).lerp(Color(1.08, 1.05, 0.9), float(stage) / 3.0)
	var plants := [_plant1, _plant2, _plant3]
	for i in plants.size():
		plants[i].visible = stage > i
	for item in [$Mess/Boot, $Mess/Weeds, $Mess/Can]:
		item.visible = not GameState.is_tidied(item.name)
	_log.visible = not GameState.log_cleared
	_seep_a.visible = not GameState.is_seep_patched(_seep_a.name)
	_seep_b.visible = not GameState.is_seep_patched(_seep_b.name)
	_otter.visible = GameState.otter_unlocked()
	_frog.visible = GameState.frog_unlocked()
	if GameState.otter_unlocked() and GameState.can_claim_otter():
		_otter.text = "Otter gift"
	elif GameState.otter_unlocked():
		_otter.text = "Otter (later)"
