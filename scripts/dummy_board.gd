extends Control
## Phase 0: portrait board that registers a swipe between neighboring tiles.

const COLS := 4
const ROWS := 4
const GAP := 12.0
const PALETTE: Array[Color] = [
	Color("4A7C59"),
	Color("2E86AB"),
	Color("C4A35A"),
	Color("8B5E3C"),
]

var _types: Array[int] = []
var _tiles: Array[ColorRect] = []
var _cell_px := 0.0
var _press_cell := Vector2i(-1, -1)
var _consumed := false

@onready var _status: Label = $Status
@onready var _grid_host: Control = $GridHost


func _ready() -> void:
	_types.resize(COLS * ROWS)
	for i in COLS * ROWS:
		_types[i] = i % PALETTE.size()
	resized.connect(_rebuild_grid)
	_status.text = "Swipe two neighboring tiles"
	await get_tree().process_frame
	_rebuild_grid()


func _rebuild_grid() -> void:
	for child in _grid_host.get_children():
		child.queue_free()
	_tiles.clear()
	var host := _grid_host.size
	if host.x <= 1.0 or host.y <= 1.0:
		return
	_cell_px = minf(
		(host.x - GAP * float(COLS - 1)) / float(COLS),
		(host.y - GAP * float(ROWS - 1)) / float(ROWS)
	)
	for y in ROWS:
		for x in COLS:
			var tile := ColorRect.new()
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.position = Vector2(
				float(x) * (_cell_px + GAP),
				float(y) * (_cell_px + GAP)
			)
			tile.size = Vector2(_cell_px, _cell_px)
			tile.color = PALETTE[_types[_index(x, y)]]
			_grid_host.add_child(tile)
			_tiles.append(tile)


func _gui_input(event: InputEvent) -> void:
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
	if _consumed or _press_cell.x < 0:
		return
	var dest := _cell_at(main_local)
	if dest == _press_cell:
		return
	if _is_neighbor(_press_cell, dest):
		_swap(_press_cell, dest)
		_consumed = true
		_press_cell = Vector2i(-1, -1)


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


func _swap(a: Vector2i, b: Vector2i) -> void:
	var ia := _index(a.x, a.y)
	var ib := _index(b.x, b.y)
	var tmp := _types[ia]
	_types[ia] = _types[ib]
	_types[ib] = tmp
	_tiles[ia].color = PALETTE[_types[ia]]
	_tiles[ib].color = PALETTE[_types[ib]]
	_status.text = "Swiped (%d, %d) → (%d, %d)" % [a.x, a.y, b.x, b.y]


func _index(x: int, y: int) -> int:
	return y * COLS + x
