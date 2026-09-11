extends Control
## Illustrated valley hub plus naturalist layer.

const VALLEY_STAGES: Array[Texture2D] = [
	preload("res://assets/art/valley_stage0.png"),
	preload("res://assets/art/valley_stage1.png"),
	preload("res://assets/art/valley_stage2.png"),
	preload("res://assets/art/valley_stage3.png"),
]
const BLOOM_SEC := 2.2

@onready var _sky: TextureRect = $Sky
@onready var _stars: Label = $Hud/Stars
@onready var _note: Label = $Note
@onready var _bloom: ColorRect = $Bloom
@onready var _dev: MenuButton = $Hud/Title
@onready var _dam: TextureRect = $Dam
@onready var _lodge: TextureRect = $Lodge
@onready var _upgrade: Button = $Upgrade
@onready var _chops: Button = $Chops
@onready var _play: Button = $PlayRow/Play
@onready var _play_other: Button = $PlayRow/PlayOther
@onready var _log: Button = $FallenLog
@onready var _seep_a: Button = $SeepA
@onready var _seep_b: Button = $SeepB
@onready var _otter: Button = $Otter
@onready var _frog: Button = $Frog


func _ready() -> void:
	GameState.progress_changed.connect(_refresh)
	resized.connect(_on_resized)
	_upgrade.pressed.connect(_on_upgrade)
	_chops.pressed.connect(_on_chops)
	_play.pressed.connect(_on_play)
	_play_other.pressed.connect(_on_play_other)
	_log.pressed.connect(_on_log)
	_seep_a.pressed.connect(_on_seep.bind(_seep_a))
	_seep_b.pressed.connect(_on_seep.bind(_seep_b))
	_otter.pressed.connect(_on_otter)
	_frog.pressed.connect(_on_frog)
	for item in [$Mess/Boot, $Mess/Weeds, $Mess/Can]:
		item.pressed.connect(_on_tidy.bind(item))
	await get_tree().process_frame
	_style_wood_button(_chops)
	_style_wood_button(_upgrade)
	_style_wood_button(_play)
	_style_wood_button(_play_other)
	_style_wood_button(_dev)
	_setup_dev_menu()
	GameState.collect_idle()
	_refresh()


func _style_wood_button(btn: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.36, 0.26, 0.16, 0.94)
	box.set_corner_radius_all(22)
	box.set_border_width_all(3)
	box.border_color = Color(0.58, 0.44, 0.28)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	var pressed := box.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.2, 0.12, 0.96)
	var disabled := box.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.36, 0.28, 0.2, 0.55)
	disabled.border_color = Color(0.5, 0.42, 0.32, 0.5)
	for key in ["normal", "hover", "focus", "hover_pressed"]:
		btn.add_theme_stylebox_override(key, box)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.84))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.9))
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.82, 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.86, 0.8, 0.72, 0.75))


func _setup_dev_menu() -> void:
	var pop := _dev.get_popup()
	pop.clear()
	pop.add_item("Reset sticks", 0)
	pop.add_item("Reset chops", 1)
	pop.add_item("Reset dam", 2)
	pop.add_item("Reset puzzles", 3)
	pop.add_separator()
	pop.add_item("Reset all four", 4)
	pop.add_theme_font_size_override("font_size", 32)
	pop.id_pressed.connect(_on_dev_item)


func _on_dev_item(id: int) -> void:
	match id:
		0:
			GameState.debug_reset_sticks()
			_say("Sticks reset to 0.")
		1:
			GameState.debug_reset_chops()
			_say("Chops reset to rank 1.")
		2:
			GameState.debug_reset_dam()
			_say("Dam reset to dry creek.")
		3:
			GameState.debug_reset_puzzles()
			_say("Puzzles reset to level 1.")
		4:
			GameState.debug_reset_sticks()
			GameState.debug_reset_chops()
			GameState.debug_reset_dam()
			GameState.debug_reset_puzzles()
			_say("Sticks, chops, dam, and puzzles reset.")
	_refresh()


func _on_resized() -> void:
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_WM_SIZE_CHANGED:
		_refresh()


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_play_other() -> void:
	get_tree().change_scene_to_file("res://scenes/other_puzzle.tscn")


func _say(line: String) -> void:
	if not line.is_empty():
		_note.text = line


func _on_upgrade() -> void:
	if GameState.raise_dam():
		Sfx.tap()
		_say("The dam holds. Water climbs.")
		var fact := GameState.first_hear(
			"dam",
			"They stop dripping, not because they planned a pond — the sound itself drives them."
		)
		if not fact.is_empty():
			_say(fact)
		_bloom_to_stage()
	elif GameState.dam_stage >= GameState.MAX_DAM:
		_say("The lodge pond is as full as it gets for now.")
	else:
		_say("Need %d sticks to raise the dam." % GameState.dam_cost())


func _on_chops() -> void:
	if GameState.raise_chops():
		Sfx.tap()
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
		Sfx.tap()
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
		Sfx.tap()
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
		Sfx.tap()
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
	Sfx.tap()
	item.visible = false
	var intro := GameState.first_hear("tidy", "Clean banks, safer shallows.")
	_say(intro if not intro.is_empty() else "Bank looks better. +1 stick.")
	_refresh()


func _bloom_to_stage() -> void:
	_bloom.visible = true
	_bloom.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_bloom, "modulate:a", 0.82, 0.4)
	tw.tween_callback(_refresh)
	tw.tween_property(_bloom, "modulate:a", 0.0, BLOOM_SEC - 0.4)
	tw.tween_callback(func() -> void:
		_bloom.visible = false
	)


func _refresh() -> void:
	_stars.text = "Sticks %d · Chops %d" % [GameState.stars, GameState.chops]
	if GameState.last_idle > 0:
		_note.text = "While you were away, the dam gathered %d sticks." % GameState.last_idle
		GameState.last_idle = 0
	elif GameState.last_payout > 0:
		_note.text = "The puzzle brought %d sticks." % GameState.last_payout
		GameState.last_payout = 0
	elif _note.text.is_empty():
		_note.text = "Tidy, chop, silence drips, then puzzle."
	if GameState.dam_stage >= GameState.MAX_DAM:
		_upgrade.text = "Dam complete"
		_upgrade.disabled = true
	else:
		_upgrade.text = "Raise dam · %d sticks" % GameState.dam_cost()
		_upgrade.disabled = false
	if GameState.chops >= GameState.MAX_CHOPS:
		_chops.text = "Chops max"
		_chops.disabled = true
	else:
		_chops.text = "Rank Chops · %d sticks" % GameState.chops_cost()
		_chops.disabled = false
	var stage := clampi(GameState.dam_stage, 0, VALLEY_STAGES.size() - 1)
	_sky.texture = VALLEY_STAGES[stage]
	_place_dam(stage)
	for item in [$Mess/Boot, $Mess/Weeds, $Mess/Can]:
		item.visible = not GameState.is_tidied(item.name)
	_log.visible = not GameState.log_cleared
	_seep_a.visible = stage >= 1 and not GameState.is_seep_patched(_seep_a.name)
	_seep_b.visible = stage >= 1 and not GameState.is_seep_patched(_seep_b.name)
	_otter.visible = GameState.otter_unlocked()
	_frog.visible = GameState.frog_unlocked()
	if GameState.otter_unlocked() and GameState.can_claim_otter():
		_otter.text = "Otter gift"
	elif GameState.otter_unlocked():
		_otter.text = "Otter (later)"


func _place_dam(stage: int) -> void:
	var built := stage >= 1
	_dam.visible = built
	_lodge.visible = built
	if not built:
		return
	var w := size.x if size.x > 1.0 else 1080.0
	var h := size.y if size.y > 1.0 else 1920.0
	# Sit on the near shore just above Rank Chops, not over the buttons.
	var dam_w := minf(w - 40.0, 720.0 + float(stage - 1) * 80.0)
	var dam_h := 260.0 + float(stage - 1) * 16.0
	var chops_top := _chops.position.y if _chops.position.y > 1.0 else h - 400.0
	var dam_bottom := chops_top - 12.0
	_dam.size = Vector2(dam_w, dam_h)
	_dam.position = Vector2((w - dam_w) * 0.5, dam_bottom - dam_h)
	var lodge_w := 250.0
	var lodge_h := 280.0
	_lodge.size = Vector2(lodge_w, lodge_h)
	_lodge.position = Vector2(6.0, dam_bottom - lodge_h + 24.0)
	_seep_a.z_index = 8
	_seep_b.z_index = 8
	_seep_a.position = Vector2(_dam.position.x + dam_w * 0.18, _dam.position.y + dam_h * 0.22)
	_seep_b.position = Vector2(_dam.position.x + dam_w * 0.58, _dam.position.y + dam_h * 0.22)
	_otter.z_index = 9
	_frog.z_index = 9
	_otter.position = Vector2(16.0, _lodge.position.y - 36.0)
	_frog.position = Vector2(w - 250.0, dam_bottom - 220.0)
