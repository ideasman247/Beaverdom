class_name BoardModel
extends RefCounted
## Gems are 0 .. type_count-1. Boosters are negative ids. EMPTY is a hole.

const EMPTY := -1
const CANAL_H := -10
const CANAL_V := -11
const BLAST := -12
const DRAGONFLY := -13
const FLOOD := -14

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


static func is_gem(tile_type: int) -> bool:
	return tile_type >= 0


static func is_booster(tile_type: int) -> bool:
	return tile_type <= CANAL_H


static func is_canal(tile_type: int) -> bool:
	return tile_type == CANAL_H or tile_type == CANAL_V


static func booster_name(tile_type: int) -> String:
	match tile_type:
		CANAL_H, CANAL_V:
			return "Canal"
		BLAST:
			return "Lodge blast"
		DRAGONFLY:
			return "Dragonfly"
		FLOOD:
			return "Flood bloom"
		_:
			return "Match"


static func booster_glyph(tile_type: int) -> String:
	match tile_type:
		CANAL_H:
			return "—"
		CANAL_V:
			return "|"
		BLAST:
			return "◉"
		DRAGONFLY:
			return "»"
		FLOOD:
			return "✽"
		_:
			return ""


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


func has_any_booster() -> bool:
	for tile_type in cells:
		if is_booster(tile_type):
			return true
	return false


func most_common_gem() -> int:
	var counts: Array[int] = []
	counts.resize(type_count)
	counts.fill(0)
	var best := 0
	var best_n := -1
	for tile_type in cells:
		if not is_gem(tile_type):
			continue
		counts[tile_type] += 1
		if counts[tile_type] > best_n:
			best_n = counts[tile_type]
			best = tile_type
	return best if best_n > 0 else 0


func fill_without_matches() -> void:
	for y in rows:
		for x in cols:
			set_cell(Vector2i(x, y), _random_type_avoiding(x, y))


func _random_type_avoiding(x: int, y: int) -> int:
	var banned: Array[int] = []
	if x >= 2:
		var left := get_cell(Vector2i(x - 1, y))
		if is_gem(left) and left == get_cell(Vector2i(x - 2, y)):
			banned.append(left)
	if y >= 2:
		var up := get_cell(Vector2i(x, y - 1))
		if is_gem(up) and up == get_cell(Vector2i(x, y - 2)):
			banned.append(up)
	if x >= 1 and y >= 1:
		var corner := get_cell(Vector2i(x - 1, y - 1))
		if (
			is_gem(corner)
			and corner == get_cell(Vector2i(x - 1, y))
			and corner == get_cell(Vector2i(x, y - 1))
		):
			banned.append(corner)
	var pick := randi() % type_count
	var guard := 0
	while banned.has(pick) and guard < 16:
		pick = randi() % type_count
		guard += 1
	return pick


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
