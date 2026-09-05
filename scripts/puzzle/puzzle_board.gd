extends Control
## Phase 1 endless board: neighbor swap, line-of-3, gravity, refill, cascade.

const COLS := 8
const ROWS := 8
const TYPE_COUNT := 5
const GAP := 8.0
const CLEAR_SEC := 0.16
const FALL_SEC := 0.2
const SWAP_SEC := 0.12
const BoardModel := preload("res://scripts/puzzle/board_model.gd")
const MatchFinder := preload("res://scripts/puzzle/match_finder.gd")
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

@onready var _status: Label = $Status
@onready var _grid_host: Control = $GridHost


func _ready() -> void:
	randomize()
	_board.fill_without_matches()
	resized.connect(_relayout_existing)
	_status.text = "Match 3 in a line · swipe neighbors"
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
			_tiles[cell] = _make_tile(cell, _board.get_cell(cell), cell)


func _make_tile(cell: Vector2i, tile_type: int, visual_cell: Vector2i) -> ColorRect:
	var tile := ColorRect.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size = Vector2(_cell_px, _cell_px)
	tile.pivot_offset = tile.size * 0.5
	tile.position = _cell_pos(visual_cell)
	tile.color = PALETTE[tile_type]
	_grid_host.add_child(tile)
	return tile


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
	if _consumed or _press_cell.x < 0:
		_press_cell = Vector2i(-1, -1)
		return
	_try_swipe(main_local)
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
	_board.swap(a, b)
	await _tween_swap_visuals(a, b)
	if not MatchFinder.has_line_match(_board):
		_board.swap(a, b)
		await _tween_swap_visuals(a, b)
		_status.text = "No match"
		_busy = false
		return
	_status.text = "Match"
	await _run_cascade()
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


func _run_cascade() -> void:
	var chain := 0
	while true:
		var matches := MatchFinder.find_line_cells(_board)
		if matches.is_empty():
			break
		chain += 1
		await _clear_matches(matches)
		var moves := _board.collapse()
		await _animate_collapse(moves)
		var spawns := _board.fill_empties()
		await _animate_spawns(spawns)
	if chain > 1:
		_status.text = "Avalanche x%d" % chain
	else:
		_status.text = "Match"
	if not MatchFinder.has_valid_swap(_board):
		_board.fill_without_matches()
		_spawn_all_tiles()
		_status.text = "No moves · shuffled"


func _clear_matches(matches: Array[Vector2i]) -> void:
	var tween := create_tween().set_parallel(true)
	var any_tween := false
	for cell in matches:
		var tile: ColorRect = _tiles.get(cell)
		if tile == null:
			continue
		any_tween = true
		tween.tween_property(tile, "scale", Vector2(0.15, 0.15), CLEAR_SEC)
		tween.tween_property(tile, "modulate:a", 0.0, CLEAR_SEC)
	if any_tween:
		await tween.finished
	for cell in matches:
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
		var tile := _make_tile(dest, tile_type, start)
		_tiles[dest] = tile
		tween.tween_property(tile, "position", _cell_pos(dest), FALL_SEC)
	await tween.finished
