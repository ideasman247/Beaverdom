extends Control
## Phase 2: cascade plus Canal / Lodge blast / Dragonfly / Flood bloom.

const COLS := 8
const ROWS := 8
const TYPE_COUNT := 5
const GAP := 8.0
const CLEAR_SEC := 0.16
const FALL_SEC := 0.2
const SWAP_SEC := 0.12
const BoardModel := preload("res://scripts/puzzle/board_model.gd")
const MatchFinder := preload("res://scripts/puzzle/match_finder.gd")
const MatchPlan := preload("res://scripts/puzzle/match_plan.gd")
const BoosterResolver := preload("res://scripts/puzzle/booster_resolver.gd")
const PALETTE: Array[Color] = [
	Color("4A7C59"),
	Color("2E86AB"),
	Color("C4A35A"),
	Color("8B5E3C"),
	Color("7A9E7E"),
]

var _board := BoardModel.new(COLS, ROWS, TYPE_COUNT)
var _tiles: Dictionary = {}
var _cell_px := 0.0
var _press_cell := Vector2i(-1, -1)
var _consumed := false
var _busy := false
var _booster_fill: Dictionary = {}

@onready var _status: Label = $Status
@onready var _grid_host: Control = $GridHost


func _ready() -> void:
	_booster_fill = {
		BoardModel.CANAL_H: Color("C5D6E8"),
		BoardModel.CANAL_V: Color("C5D6E8"),
		BoardModel.BLAST: Color("E07A3D"),
		BoardModel.DRAGONFLY: Color("4EB8B5"),
		BoardModel.FLOOD: Color("C85BD6"),
	}
	randomize()
	_board.fill_without_matches()
	resized.connect(_relayout_existing)
	_status.text = "4 / L-T / 2x2 / 5 make boosters · tap to fire"
	await get_tree().process_frame
	_spawn_all_tiles()


func _relayout_existing() -> void:
	_measure_cell()
	if _cell_px <= 0.0:
		return
	for cell: Vector2i in _tiles:
		var tile: ColorRect = _tiles[cell]
		tile.position = _cell_pos(cell)
		tile.size = Vector2(_cell_px, _cell_px)
		tile.pivot_offset = tile.size * 0.5
		_paint_tile(tile, _board.get_cell(cell))


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
	for child in _grid_host.get_children():
		child.queue_free()
	_tiles.clear()
	_measure_cell()
	if _cell_px <= 0.0:
		return
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			_tiles[cell] = _make_tile(_board.get_cell(cell), cell)


func _make_tile(tile_type: int, visual_cell: Vector2i) -> ColorRect:
	var tile := ColorRect.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size = Vector2(_cell_px, _cell_px)
	tile.pivot_offset = tile.size * 0.5
	tile.position = _cell_pos(visual_cell)
	_paint_tile(tile, tile_type)
	_grid_host.add_child(tile)
	return tile


func _paint_tile(tile: ColorRect, tile_type: int) -> void:
	var mark := tile.get_node_or_null("Mark")
	if mark:
		mark.queue_free()
	if BoardModel.is_booster(tile_type):
		tile.color = _booster_fill[tile_type]
		var label := Label.new()
		label.name = "Mark"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(maxi(18, int(_cell_px * 0.42))))
		label.add_theme_color_override("font_color", Color("1A2420"))
		label.text = BoardModel.booster_glyph(tile_type)
		tile.add_child(label)
	elif BoardModel.is_gem(tile_type):
		tile.color = PALETTE[tile_type]
	else:
		tile.color = Color.TRANSPARENT


func _cell_pos(cell: Vector2i) -> Vector2:
	var stride := _cell_px + GAP
	return Vector2(float(cell.x) * stride, float(cell.y) * stride)


func _gui_input(event: InputEvent) -> void:
	if _busy:
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
		_status.text = "Combo"
		var clears: Array[Vector2i] = BoosterResolver.clears_from_combo(_board, a, b, b)
		await _pop_cells(clears)
		await _settle_and_cascade()
		_busy = false
		return
	if BoardModel.is_booster(type_a) or BoardModel.is_booster(type_b):
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
	await _apply_match_plan(b)
	await _settle_and_cascade()
	_busy = false


func _activate_booster(cell: Vector2i) -> void:
	_busy = true
	_status.text = BoardModel.booster_name(_board.get_cell(cell))
	var clears: Array[Vector2i] = BoosterResolver.clears_from_booster(_board, cell)
	await _pop_cells(clears)
	await _settle_and_cascade()
	_busy = false


func _tween_swap_visuals(a: Vector2i, b: Vector2i) -> void:
	var tile_a: ColorRect = _tiles[a]
	var tile_b: ColorRect = _tiles[b]
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
		names.append(BoardModel.booster_name(spawn[&"booster"]))
	var to_pop: Array[Vector2i] = []
	for cell in clear:
		if spawn_at.has(cell):
			continue
		to_pop.append(cell)
	if not names.is_empty():
		_status.text = ", ".join(names)
	else:
		_status.text = "Match"
	await _pop_cells(to_pop)
	for spawn in spawns:
		var cell: Vector2i = spawn[&"cell"]
		var booster: int = spawn[&"booster"]
		_board.set_cell(cell, booster)
		var tile: ColorRect = _tiles.get(cell)
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
	if chain > 1:
		_status.text = "Avalanche x%d" % chain
	if not MatchFinder.has_valid_move(_board):
		_board.fill_without_matches()
		_spawn_all_tiles()
		_status.text = "No moves · shuffled"


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
		var tile: ColorRect = _tiles.get(cell)
		if tile == null:
			continue
		any_tween = true
		tween.tween_property(tile, "scale", Vector2(0.15, 0.15), CLEAR_SEC)
		tween.tween_property(tile, "modulate:a", 0.0, CLEAR_SEC)
	if any_tween:
		await tween.finished
	for cell in cells:
		_board.set_cell(cell, BoardModel.EMPTY)
		var tile: ColorRect = _tiles.get(cell)
		if tile:
			tile.queue_free()
		_tiles.erase(cell)


func _animate_collapse(moves: Array[Dictionary]) -> void:
	if moves.is_empty():
		return
	var tween := create_tween().set_parallel(true)
	for move in moves:
		var from: Vector2i = move[&"from"]
		var to: Vector2i = move[&"to"]
		var tile: ColorRect = _tiles.get(from)
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
