class_name BoardModel
extends RefCounted
## Integer grid. EMPTY is a hole. Types are 0 .. type_count-1.

const EMPTY := -1

var cols: int
var rows: int
var type_count: int
var cells: Array[int] = []


func _init(p_cols: int = 8, p_rows: int = 8, p_type_count: int = 5) -> void:
	cols = p_cols
	rows = p_rows
	type_count = p_type_count
	cells.resize(cols * rows)
	cells.fill(EMPTY)


func index_of(cell: Vector2i) -> int:
	return cell.y * cols + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func get_cell(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return EMPTY
	return cells[index_of(cell)]


func set_cell(cell: Vector2i, tile_type: int) -> void:
	if in_bounds(cell):
		cells[index_of(cell)] = tile_type


func swap(a: Vector2i, b: Vector2i) -> void:
	var tmp := get_cell(a)
	set_cell(a, get_cell(b))
	set_cell(b, tmp)


func fill_without_matches() -> void:
	for y in rows:
		for x in cols:
			set_cell(Vector2i(x, y), _random_type_avoiding(x, y))


func _random_type_avoiding(x: int, y: int) -> int:
	var banned: Array[int] = []
	if x >= 2:
		var left := get_cell(Vector2i(x - 1, y))
		if left == get_cell(Vector2i(x - 2, y)) and left != EMPTY:
			banned.append(left)
	if y >= 2:
		var up := get_cell(Vector2i(x, y - 1))
		if up == get_cell(Vector2i(x, y - 2)) and up != EMPTY:
			banned.append(up)
	var pick := randi() % type_count
	var guard := 0
	while banned.has(pick) and guard < 12:
		pick = randi() % type_count
		guard += 1
	return pick


## Compact each column downward. Returns moved tiles (from → to).
func collapse() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for x in cols:
		var write_y := rows - 1
		for y in range(rows - 1, -1, -1):
			var here := Vector2i(x, y)
			var tile_type := get_cell(here)
			if tile_type == EMPTY:
				continue
			var dest := Vector2i(x, write_y)
			if dest != here:
				moves.append({&"from": here, &"to": dest, &"type": tile_type})
				set_cell(dest, tile_type)
				set_cell(here, EMPTY)
			write_y -= 1
	return moves


## Fill EMPTY cells from the top. spawn_offset is how far above `to` the tile starts.
func fill_empties() -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	for x in cols:
		var empty_in_col := 0
		for y in rows:
			if get_cell(Vector2i(x, y)) == EMPTY:
				empty_in_col += 1
		for y in rows:
			var dest := Vector2i(x, y)
			if get_cell(dest) != EMPTY:
				continue
			var tile_type := randi() % type_count
			set_cell(dest, tile_type)
			spawns.append({
				&"to": dest,
				&"type": tile_type,
				&"spawn_offset": empty_in_col,
			})
	return spawns
