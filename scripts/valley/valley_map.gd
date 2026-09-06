extends Control
## Township-style lodge: spend sticks, raise the dam, tidy the banks, then puzzle.

@onready var _stars: Label = $Hud/Stars
@onready var _note: Label = $Note
@onready var _water: ColorRect = $Water
@onready var _dam: ColorRect = $Dam
@onready var _lodge: ColorRect = $Lodge
@onready var _upgrade: Button = $Upgrade
@onready var _play: Button = $Play
@onready var _plant1: ColorRect = $Plant1
@onready var _plant2: ColorRect = $Plant2
@onready var _plant3: ColorRect = $Plant3


func _ready() -> void:
	_upgrade.pressed.connect(_on_upgrade)
	_play.pressed.connect(_on_play)
	for item in [$Mess/Boot, $Mess/Weeds, $Mess/Can]:
		item.pressed.connect(_on_tidy.bind(item))
	await get_tree().process_frame
	_refresh()


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_upgrade() -> void:
	if GameState.raise_dam():
		_note.text = "The dam holds. Water climbs."
		_refresh()
	elif GameState.dam_stage >= GameState.MAX_DAM:
		_note.text = "The lodge pond is as full as it gets for now."
	else:
		_note.text = "Need %d sticks to raise the dam." % GameState.dam_cost()


func _on_tidy(item: Button) -> void:
	GameState.tidy(item.name)
	item.visible = false
	_note.text = "Bank looks better. +1 stick."
	_refresh()


func _refresh() -> void:
	_stars.text = "Sticks %d" % GameState.stars
	if GameState.last_payout > 0:
		_note.text = "The puzzle brought %d sticks." % GameState.last_payout
		GameState.last_payout = 0
	elif _note.text.is_empty():
		_note.text = "Tidy the banks, raise the dam, then puzzle."
	if GameState.dam_stage >= GameState.MAX_DAM:
		_upgrade.text = "Dam complete"
		_upgrade.disabled = true
	else:
		_upgrade.text = "Raise dam · %d sticks" % GameState.dam_cost()
		_upgrade.disabled = not GameState.can_raise_dam()
	var stage := GameState.dam_stage
	_water.offset_top = -220.0 - float(stage) * 110.0
	_dam.size = Vector2(220.0 + float(stage) * 70.0, 70.0 + float(stage) * 28.0)
	_dam.position.x = (size.x - _dam.size.x) * 0.5 if size.x > 1.0 else 430.0
	_lodge.modulate = Color(1, 1, 1, 1).lerp(Color(1.08, 1.05, 0.9), float(stage) / 3.0)
	var plants := [_plant1, _plant2, _plant3]
	for i in plants.size():
		plants[i].visible = stage > i
	for item in [$Mess/Boot, $Mess/Weeds, $Mess/Can]:
		item.visible = not GameState.is_tidied(item.name)
