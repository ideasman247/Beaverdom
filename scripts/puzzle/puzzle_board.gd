extends Control
## Forty levels with illustrated wetland tiles.

const COLS := 8
const ROWS := 8
const TYPE_COUNT := 5
const GAP := 8.0
const CLEAR_SEC := 0.16
const FALL_SEC := 0.2
const SWAP_SEC := 0.12
const HUD_PAD := 32.0
const HUD_TOP := 36.0
const HUD_BOTTOM := 124.0
const STATUS_TOP := 136.0
const STATUS_BOTTOM := 228.0
const HINT_TOP := -248.0
const HINT_BOTTOM := -140.0
const HOME_TOP := -124.0
const HOME_BOTTOM := -24.0
const MIN_INSET_TOP := 56.0
const MIN_INSET_BOTTOM := 40.0
const TRAY_INNER_RATIO := 0.74
const BoardModel := preload("res://scripts/puzzle/board_model.gd")
const MatchFinder := preload("res://scripts/puzzle/match_finder.gd")
const MatchPlan := preload("res://scripts/puzzle/match_plan.gd")
const BoosterResolver := preload("res://scripts/puzzle/booster_resolver.gd")
const LevelCatalog := preload("res://scripts/puzzle/level_catalog.gd")
const TileArt := preload("res://scripts/puzzle/tile_art.gd")
const OIL_FRAME := preload("res://assets/art/oil_frame.png")

var _board := BoardModel.new(COLS, ROWS, TYPE_COUNT)
var _tiles: Dictionary = {}
var _cell_px := 0.0
var _press_cell := Vector2i(-1, -1)
var _consumed := false
var _busy := false
var _levels: Array[Dictionary] = []
var _level_index := 0
var _moves_left := 0
var _gems_cleared := 0
var _oil_cleared := 0
var _made: Dictionary = {}
var _resolved := false
var _won := false
var _oil_views: Dictionary = {}

@onready var _hud: HBoxContainer = $Hud
@onready var _home: Button = $Home
@onready var _status: Label = $Status
@onready var _hint: Label = $Hint
@onready var _hud_level: Label = $Hud/Level
@onready var _hud_moves: Label = $Hud/Moves
@onready var _hud_goal: Label = $Hud/Goal
@onready var _grid_host: Control = $GridHost
@onready var _tray: TextureRect = $Tray
@onready var _oil_layer: Control = $OilLayer
@onready var _overlay: ColorRect = $Overlay
@onready var _overlay_banner: Label = $Overlay/Banner
@onready var _overlay_action: Button = $Overlay/Action


func _ready() -> void:
	randomize()
	_levels = LevelCatalog.all_levels()
	resized.connect(_relayout_existing)
	_overlay_action.pressed.connect(_on_overlay_action)
	_home.pressed.connect(_go_lodge)
	_style_wood_button(_home)
	_style_wood_button(_overlay_action)
	_style_wood_chip(_hud_level)
	_style_wood_chip(_hud_moves)
	_style_wood_chip(_hud_goal)
	_style_wood_chip(_status)
	_style_wood_chip(_hint)
	_style_wood_chip(_overlay_banner)
	await get_tree().process_frame
	_apply_safe_layout()
	_start_level(GameState.puzzle_index)


func _style_wood_button(btn: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.48, 0.33, 0.18, 0.98)
	box.set_corner_radius_all(28)
	box.border_color = Color(0.82, 0.64, 0.38)
	box.set_border_width(SIDE_LEFT, 3)
	box.set_border_width(SIDE_RIGHT, 3)
	box.set_border_width(SIDE_TOP, 3)
	box.set_border_width(SIDE_BOTTOM, 8)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 14
	box.content_margin_bottom = 16
	box.shadow_color = Color(0.05, 0.03, 0.01, 0.55)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 5)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.55, 0.38, 0.2, 1.0)
	var pressed := box.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.22, 0.12, 0.98)
	pressed.set_border_width(SIDE_BOTTOM, 3)
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 1)
	pressed.content_margin_top = 18
	pressed.content_margin_bottom = 12
	for key in ["normal", "focus"]:
		btn.add_theme_stylebox_override(key, box)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.92))
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 0.84, 0.7))
	btn.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.05, 0.7))
	btn.add_theme_constant_override("outline_size", 4)


func _style_wood_chip(label: Label) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.36, 0.26, 0.16, 0.94)
	box.set_corner_radius_all(18)
	box.set_border_width_all(3)
	box.border_color = Color(0.58, 0.44, 0.28)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal", box)
	label.add_theme_color_override("font_color", Color(0.97, 0.93, 0.84))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_lodge()
	elif what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_safe_layout()


func _screen_insets() -> Vector2:
	var vis := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if vis.y <= 1.0:
		vis = Vector2(1080.0, 1920.0)
	var top := 0.0
	var bottom := 0.0
	var safe := DisplayServer.get_display_safe_area()
	if win.y > 1.0 and safe.size.y > 0:
		var sy := vis.y / win.y
		top = maxf(float(safe.position.y) * sy, 0.0)
		bottom = maxf(float(win.y - safe.end.y) * sy, 0.0)
	return Vector2(maxf(top, MIN_INSET_TOP), maxf(bottom, MIN_INSET_BOTTOM))


func _apply_safe_layout() -> void:
	if _hud == null:
		return
	var inset := _screen_insets()
	_hud.offset_left = HUD_PAD
	_hud.offset_right = -HUD_PAD
	_hud.offset_top = HUD_TOP + inset.x
	_hud.offset_bottom = HUD_BOTTOM + inset.x
	_status.offset_top = STATUS_TOP + inset.x
	_status.offset_bottom = STATUS_BOTTOM + inset.x
	_hint.offset_top = HINT_TOP - inset.y
	_hint.offset_bottom = HINT_BOTTOM - inset.y
	_home.offset_top = HOME_TOP - inset.y
	_home.offset_bottom = HOME_BOTTOM - inset.y
	_fit_tray()


func _fit_tray() -> void:
	if _tray == null or _grid_host == null:
		return
	var grid := _grid_host.size.x
	if grid <= 1.0:
		return
	var half := (grid / TRAY_INNER_RATIO) * 0.5
	_tray.offset_left = -half
	_tray.offset_top = -half
	_tray.offset_right = half
	_tray.offset_bottom = half


func _go_lodge() -> void:
	if _won and _overlay.visible:
		_on_overlay_action()
		return
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/valley.tscn")


func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, _levels.size() - 1)
	var spec: Dictionary = _levels[_level_index]
	_moves_left = int(spec[&"moves"])
	_gems_cleared = 0
	_oil_cleared = 0
	_made = {
		BoardModel.CANAL_H: 0,
		BoardModel.CANAL_V: 0,
		BoardModel.BLAST: 0,
		BoardModel.DRAGONFLY: 0,
		BoardModel.FLOOD: 0,
	}
	_resolved = false
	_won = false
	_busy = false
	_overlay.visible = false
	_board.fill_without_matches()
	_board.scatter_oil(int(spec[&"oil"]))
	_hint.text = str(spec[&"teach"])
	_status.text = "Level %d" % int(spec[&"id"])
	_spawn_all_tiles()
	_rebuild_oil_views()
	_refresh_hud()


func _current_level() -> Dictionary:
	return _levels[_level_index]


func _refresh_hud() -> void:
	var spec := _current_level()
	_hud_level.text = "Lvl %d/%d" % [int(spec[&"id"]), _levels.size()]
	_hud_moves.text = "Moves %d" % _moves_left
	_hud_goal.text = _goal_label()


func _goal_label() -> String:
	var spec := _current_level()
	var goal: StringName = spec[&"goal"]
	var need := int(spec[&"count"])
	match goal:
		&"gems":
			return "Clear %d / %d" % [_gems_cleared, need]
		&"canal":
			return "Canal %d / %d" % [_canal_made(), need]
		&"dragonfly":
			return "Dragonfly %d / %d" % [int(_made[BoardModel.DRAGONFLY]), need]
		&"blast":
			return "Blast %d / %d" % [int(_made[BoardModel.BLAST]), need]
		&"flood":
			return "Flood %d / %d" % [int(_made[BoardModel.FLOOD]), need]
		&"oil":
			return "Oil %d left" % _board.oil_remaining()
		_:
			return ""


func _canal_made() -> int:
	return int(_made[BoardModel.CANAL_H]) + int(_made[BoardModel.CANAL_V])


func _goal_met() -> bool:
	var spec := _current_level()
	var need := int(spec[&"count"])
	match spec[&"goal"]:
		&"gems":
			return _gems_cleared >= need
		&"canal":
			return _canal_made() >= need
		&"dragonfly":
			return int(_made[BoardModel.DRAGONFLY]) >= need
		&"blast":
			return int(_made[BoardModel.BLAST]) >= need
		&"flood":
			return int(_made[BoardModel.FLOOD]) >= need
		&"oil":
			return _board.oil_remaining() <= 0
		_:
			return false


func _note_booster(booster: int) -> void:
	if _made.has(booster):
		_made[booster] = int(_made[booster]) + 1
	elif BoardModel.is_canal(booster):
		_made[booster] = 1


func _spend_move() -> void:
	if _resolved:
		return
	_moves_left = maxi(0, _moves_left - 1)
	_refresh_hud()


func _check_outcome() -> void:
	if _resolved:
		return
	if _goal_met():
		_won = true
		_resolved = true
		var payout := GameState.payout_for(_moves_left)
		if _level_index >= _levels.size() - 1:
			_show_overlay("The creek is clear · +%d sticks" % payout, "Home")
		else:
			_show_overlay("Pond looks better · +%d sticks" % payout, "Home")
		Sfx.win()
		return
	if _moves_left <= 0:
		_resolved = true
		_show_overlay("Out of moves", "Try again")
		Sfx.fail()


func _show_overlay(banner: String, action: String) -> void:
	_overlay_banner.text = banner
	_overlay_action.text = action
	_overlay.visible = true


func _on_overlay_action() -> void:
	if _won:
		GameState.award_win(_moves_left)
		GameState.advance_after_win(_level_index, _levels.size())
		get_tree().change_scene_to_file("res://scenes/valley.tscn")
	else:
		_start_level(_level_index)


func _relayout_existing() -> void:
	_apply_safe_layout()
	_measure_cell()
	if _cell_px <= 0.0:
		return
	for cell: Vector2i in _tiles:
		var tile: TextureRect = _tiles[cell]
		tile.position = _cell_pos(cell)
		tile.size = Vector2(_cell_px, _cell_px)
		tile.pivot_offset = tile.size * 0.5
		_paint_tile(tile, _board.get_cell(cell))
	_rebuild_oil_views()


func _measure_cell() -> void:
	var host := _grid_host.size
	if host.x <= 1.0 or host.y <= 1.0:
		_cell_px = 0.0
		return
	_cell_px = minf(
		(host.x - GAP * float(COLS - 1)) / float(COLS),
		(host.y - GAP * float(ROWS - 1)) / float(ROWS)
	)


func _spawn_all_tiles() -> void:
	for tile in _tiles.values():
		if tile is TextureRect:
			(tile as TextureRect).queue_free()
	_tiles.clear()
	_measure_cell()
	if _cell_px <= 0.0:
		return
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			_tiles[cell] = _make_tile(_board.get_cell(cell), cell)


func _rebuild_oil_views() -> void:
	for child in _oil_layer.get_children():
		child.queue_free()
	_oil_views.clear()
	_measure_cell()
	if _cell_px <= 0.0:
		return
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if _board.get_oil(cell) <= 0:
				continue
			var blot := TextureRect.new()
			blot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			blot.texture = OIL_FRAME
			blot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			blot.stretch_mode = TextureRect.STRETCH_SCALE
			blot.position = _cell_pos(cell)
			blot.size = Vector2(_cell_px, _cell_px)
			_oil_layer.add_child(blot)
			_oil_views[cell] = blot


func _make_tile(tile_type: int, visual_cell: Vector2i) -> TextureRect:
	var tile := TextureRect.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_SCALE
	tile.size = Vector2(_cell_px, _cell_px)
	tile.pivot_offset = tile.size * 0.5
	tile.position = _cell_pos(visual_cell)
	_paint_tile(tile, tile_type)
	_grid_host.add_child(tile)
	return tile


func _paint_tile(tile: TextureRect, tile_type: int) -> void:
	tile.texture = TileArt.texture_for(tile_type)
	tile.modulate = Color.WHITE
	tile.rotation = PI * 0.5 if tile_type == BoardModel.CANAL_V else 0.0


func _cell_pos(cell: Vector2i) -> Vector2:
	var stride := _cell_px + GAP
	return Vector2(float(cell.x) * stride, float(cell.y) * stride)


func _gui_input(event: InputEvent) -> void:
	if _busy or _resolved:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin(touch.position)
		elif not _consumed:
			_finish(touch.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			_begin(mouse.position)
		elif not _consumed:
			_finish(mouse.position)
		return
	if event is InputEventScreenDrag:
		_try_swipe((event as InputEventScreenDrag).position)
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_swipe((event as InputEventMouseMotion).position)


func _begin(main_local: Vector2) -> void:
	_consumed = false
	_press_cell = _cell_at(main_local)
	if _press_cell.x >= 0:
		Sfx.tap()


func _try_swipe(main_local: Vector2) -> void:
	if _busy or _consumed or _press_cell.x < 0:
		return
	var dest := _cell_at(main_local)
	if dest == _press_cell or not _is_neighbor(_press_cell, dest):
		return
	_consumed = true
	var origin := _press_cell
	_press_cell = Vector2i(-1, -1)
	_resolve_swap(origin, dest)


func _finish(main_local: Vector2) -> void:
	if _consumed:
		_press_cell = Vector2i(-1, -1)
		return
	var dest := _cell_at(main_local)
	if _press_cell.x >= 0 and _is_neighbor(_press_cell, dest):
		_try_swipe(main_local)
	elif _press_cell.x >= 0 and BoardModel.is_booster(_board.get_cell(_press_cell)):
		var cell := _press_cell
		_press_cell = Vector2i(-1, -1)
		_consumed = true
		_activate_booster(cell)
	_press_cell = Vector2i(-1, -1)


func _cell_at(main_local: Vector2) -> Vector2i:
	if _cell_px <= 0.0:
		return Vector2i(-1, -1)
	var global := get_global_transform() * main_local
	var in_grid: Vector2 = _grid_host.get_global_transform().affine_inverse() * global
	var stride := _cell_px + GAP
	var x := int(floor(in_grid.x / stride))
	var y := int(floor(in_grid.y / stride))
	var in_cell_x: float = in_grid.x - float(x) * stride
	var in_cell_y: float = in_grid.y - float(y) * stride
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return Vector2i(-1, -1)
	if in_cell_x > _cell_px or in_cell_y > _cell_px:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _is_neighbor(a: Vector2i, b: Vector2i) -> bool:
	if a.x < 0 or b.x < 0:
		return false
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _resolve_swap(a: Vector2i, b: Vector2i) -> void:
	_busy = true
	var type_a: int = _board.get_cell(a)
	var type_b: int = _board.get_cell(b)
	_board.swap(a, b)
	await _tween_swap_visuals(a, b)
	if BoardModel.is_booster(type_a) and BoardModel.is_booster(type_b):
		_spend_move()
		_status.text = "Combo"
		var clears: Array[Vector2i] = BoosterResolver.clears_from_combo(_board, a, b, b)
		await _pop_cells(clears)
		await _settle_and_cascade()
		_busy = false
		return
	if BoardModel.is_booster(type_a) or BoardModel.is_booster(type_b):
		_spend_move()
		var booster_now := b if BoardModel.is_booster(type_a) else a
		var other_was: int = type_b if BoardModel.is_booster(type_a) else type_a
		var flood_color := other_was if BoardModel.is_gem(other_was) else -1
		_status.text = BoardModel.booster_name(_board.get_cell(booster_now))
		var clears: Array[Vector2i] = BoosterResolver.clears_from_booster(
			_board, booster_now, flood_color
		)
		await _pop_cells(clears)
		await _settle_and_cascade()
		_busy = false
		return
	if not MatchFinder.has_match(_board):
		_board.swap(a, b)
		await _tween_swap_visuals(a, b)
		_status.text = "No match"
		_busy = false
		return
	_spend_move()
	await _apply_match_plan(b)
	await _settle_and_cascade()
	_busy = false


func _activate_booster(cell: Vector2i) -> void:
	_busy = true
	_spend_move()
	_status.text = BoardModel.booster_name(_board.get_cell(cell))
	var clears: Array[Vector2i] = BoosterResolver.clears_from_booster(_board, cell)
	await _pop_cells(clears)
	await _settle_and_cascade()
	_busy = false


func _tween_swap_visuals(a: Vector2i, b: Vector2i) -> void:
	var tile_a: TextureRect = _tiles[a]
	var tile_b: TextureRect = _tiles[b]
	_tiles[a] = tile_b
	_tiles[b] = tile_a
	var tween := create_tween().set_parallel(true)
	tween.tween_property(tile_a, "position", _cell_pos(b), SWAP_SEC)
	tween.tween_property(tile_b, "position", _cell_pos(a), SWAP_SEC)
	await tween.finished


func _apply_match_plan(focus: Vector2i) -> void:
	var plan: Dictionary = MatchPlan.build(_board, focus)
	var clear: Array[Vector2i] = plan[&"clear"]
	var spawns: Array = plan[&"spawns"]
	var spawn_at: Dictionary = {}
	var names: PackedStringArray = []
	for spawn in spawns:
		var cell: Vector2i = spawn[&"cell"]
		spawn_at[cell] = spawn[&"booster"]
		_note_booster(spawn[&"booster"])
		names.append(BoardModel.booster_name(spawn[&"booster"]))
	var to_pop: Array[Vector2i] = []
	for cell in clear:
		if spawn_at.has(cell):
			continue
		to_pop.append(cell)
	if not names.is_empty():
		_status.text = ", ".join(names)
		Sfx.boost()
	else:
		_status.text = "Match"
	for cell: Vector2i in spawn_at:
		_hit_oil(cell)
	await _pop_cells(to_pop)
	for spawn in spawns:
		var cell: Vector2i = spawn[&"cell"]
		var booster: int = spawn[&"booster"]
		if BoardModel.is_gem(_board.get_cell(cell)):
			_gems_cleared += 1
		_board.set_cell(cell, booster)
		var tile: TextureRect = _tiles.get(cell)
		if tile:
			tile.scale = Vector2.ONE
			tile.modulate.a = 1.0
			_paint_tile(tile, booster)


func _run_cascade() -> int:
	var chain := 0
	while true:
		if MatchFinder.find_match_cells(_board).is_empty():
			break
		chain += 1
		await _apply_match_plan(Vector2i(-1, -1))
		await _gravity_and_fill()
	return chain


func _settle_and_cascade() -> void:
	await _gravity_and_fill()
	var chain := await _run_cascade()
	if chain > 1 and not _resolved:
		_status.text = "Avalanche x%d" % chain
	if not _resolved and not MatchFinder.has_valid_move(_board):
		_board.fill_without_matches()
		_spawn_all_tiles()
		_status.text = "No moves · shuffled"
	_refresh_hud()
	_check_outcome()


func _gravity_and_fill() -> void:
	var moves := _board.collapse()
	await _animate_collapse(moves)
	var spawns := _board.fill_empties()
	await _animate_spawns(spawns)


func _pop_cells(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var tween := create_tween().set_parallel(true)
	var any_tween := false
	for cell in cells:
		var tile: TextureRect = _tiles.get(cell)
		if tile == null:
			continue
		any_tween = true
		tween.tween_property(tile, "scale", Vector2(0.15, 0.15), CLEAR_SEC)
		tween.tween_property(tile, "modulate:a", 0.0, CLEAR_SEC)
	if any_tween:
		Sfx.pop()
		await tween.finished
	for cell in cells:
		if BoardModel.is_gem(_board.get_cell(cell)):
			_gems_cleared += 1
		_hit_oil(cell)
		_board.set_cell(cell, BoardModel.EMPTY)
		var tile: TextureRect = _tiles.get(cell)
		if tile:
			tile.queue_free()
		_tiles.erase(cell)
	_refresh_hud()


func _hit_oil(cell: Vector2i) -> void:
	if not _board.damage_oil(cell):
		return
	_oil_cleared += 1
	if _board.get_oil(cell) > 0:
		return
	var blot: TextureRect = _oil_views.get(cell)
	if blot:
		blot.queue_free()
		_oil_views.erase(cell)


func _animate_collapse(moves: Array[Dictionary]) -> void:
	if moves.is_empty():
		return
	var tween := create_tween().set_parallel(true)
	for move in moves:
		var from: Vector2i = move[&"from"]
		var to: Vector2i = move[&"to"]
		var tile: TextureRect = _tiles.get(from)
		if tile == null:
			continue
		_tiles.erase(from)
		_tiles[to] = tile
		tween.tween_property(tile, "position", _cell_pos(to), FALL_SEC)
	await tween.finished


func _animate_spawns(spawns: Array[Dictionary]) -> void:
	if spawns.is_empty():
		return
	var tween := create_tween().set_parallel(true)
	for spawn in spawns:
		var dest: Vector2i = spawn[&"to"]
		var tile_type: int = spawn[&"type"]
		var offset: int = spawn[&"spawn_offset"]
		var start := Vector2i(dest.x, dest.y - offset)
		var tile := _make_tile(tile_type, start)
		_tiles[dest] = tile
		tween.tween_property(tile, "position", _cell_pos(dest), FALL_SEC)
	await tween.finished
