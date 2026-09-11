extends RefCounted
## Hex (odd-r) hanging grid for the dam snood.

const EMPTY := -1
const FROG := 0
const DUCK := 1
const TURTLE := 2
const FISH := 3
const KIT := 4
const STICKS := 5
const LOG := 6
const MUD := 7
const BARREL := 8
const TRASH := 9
const DOZER := 10
const CHOMP := 11

const KIND_FRIEND := 0
const KIND_RESOURCE := 1
const KIND_THREAT := 2
const KIND_SPECIAL := 3

const COLS := 8
const ROWS := 14


static func kind_of(icon_type: int) -> int:
	if icon_type >= 0 and icon_type <= 4:
		return KIND_FRIEND
	if icon_type >= 5 and icon_type <= 7:
		return KIND_RESOURCE
	if icon_type >= 8 and icon_type <= 10:
		return KIND_THREAT
	return KIND_SPECIAL


static func is_playable(icon_type: int) -> bool:
	return icon_type >= 0 and icon_type <= 10


var cells: Array = []


func _init() -> void:
	clear()


func clear() -> void:
	cells.clear()
	for _r in ROWS:
		var row: Array[int] = []
		row.resize(COLS)
		row.fill(EMPTY)
		cells.append(row)


func in_bounds(col: int, row: int) -> bool:
	if row < 0 or row >= ROWS or col < 0 or col >= COLS:
		return false
	if row % 2 == 1 and col >= COLS - 1:
		return false
	return true


func get_cell(col: int, row: int) -> int:
	if not in_bounds(col, row):
		return EMPTY
	return int(cells[row][col])


func set_cell(col: int, row: int, icon_type: int) -> void:
	if in_bounds(col, row):
		cells[row][col] = icon_type


func neighbors(col: int, row: int) -> Array[Vector2i]:
	var deltas: Array[Vector2i]
	if row % 2 == 0:
		deltas = [
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(-1, -1), Vector2i(0, -1),
			Vector2i(-1, 1), Vector2i(0, 1),
		]
	else:
		deltas = [
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(0, 1), Vector2i(1, 1),
		]
	var out: Array[Vector2i] = []
	for d in deltas:
		var n := Vector2i(col + d.x, row + d.y)
		if in_bounds(n.x, n.y):
			out.append(n)
	return out


func fill_level(seed_rows: int = 5) -> void:
	clear()
	var bag: Array[int] = [FROG, DUCK, TURTLE, FISH, KIT, STICKS, LOG, MUD, BARREL, TRASH, DOZER]
	for r in mini(seed_rows, ROWS):
		var cols := COLS if r % 2 == 0 else COLS - 1
		for c in cols:
			var pick: int = bag[randi() % bag.size()]
			if randf() < 0.08 and r == seed_rows - 1:
				continue
			set_cell(c, r, pick)


func occupied_keys() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in ROWS:
		for c in COLS:
			if get_cell(c, r) != EMPTY:
				out.append(Vector2i(c, r))
	return out


func types_in_play() -> Array[int]:
	var seen: Dictionary = {}
	for cell in occupied_keys():
		var t := get_cell(cell.x, cell.y)
		if is_playable(t):
			seen[t] = true
	var out: Array[int] = []
	for k in seen.keys():
		out.append(int(k))
	if out.is_empty():
		out = [FROG, DUCK, TURTLE]
	return out


func random_shot(types: Array[int]) -> int:
	if types.is_empty():
		return FROG
	return types[randi() % types.size()]


func group_of(col: int, row: int, as_type: int = EMPTY) -> Array[Vector2i]:
	var start := get_cell(col, row)
	var want := as_type if as_type != EMPTY else start
	if want == EMPTY:
		return []
	var stack: Array[Vector2i] = [Vector2i(col, row)]
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		var key := "%d,%d" % [cur.x, cur.y]
		if seen.has(key):
			continue
		seen[key] = true
		var here := get_cell(cur.x, cur.y)
		if here == EMPTY:
			continue
		if here != want and here != CHOMP:
			continue
		out.append(cur)
		for n in neighbors(cur.x, cur.y):
			stack.append(n)
	return out


func hanging_from_ceiling() -> Dictionary:
	var hang: Dictionary = {}
	var stack: Array[Vector2i] = []
	for c in COLS:
		if get_cell(c, 0) != EMPTY:
			stack.append(Vector2i(c, 0))
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		var key := "%d,%d" % [cur.x, cur.y]
		if hang.has(key):
			continue
		if get_cell(cur.x, cur.y) == EMPTY:
			continue
		hang[key] = cur
		for n in neighbors(cur.x, cur.y):
			stack.append(n)
	return hang


func severed_cells() -> Array[Vector2i]:
	var hang := hanging_from_ceiling()
	var out: Array[Vector2i] = []
	for cell in occupied_keys():
		var key := "%d,%d" % [cell.x, cell.y]
		if not hang.has(key):
			out.append(cell)
	return out


func lowest_occupied_row() -> int:
	var low := -1
	for r in ROWS:
		for c in COLS:
			if get_cell(c, r) != EMPTY:
				low = r
	return low


func friends_or_threats_left() -> bool:
	for cell in occupied_keys():
		var k := kind_of(get_cell(cell.x, cell.y))
		if k == KIND_FRIEND or k == KIND_THREAT:
			return true
	return false


func clear_row(row: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in COLS:
		if get_cell(c, row) != EMPTY:
			out.append(Vector2i(c, row))
			set_cell(c, row, EMPTY)
	return out
