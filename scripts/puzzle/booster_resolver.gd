extends RefCounted
## Turns boosters and combos into a set of cells to clear. Chain-fires boosters hit by a blast.

const BoardModel := preload("res://scripts/puzzle/board_model.gd")


static func clears_from_booster(board: RefCounted, origin: Vector2i, flood_color: int = -1) -> Array[Vector2i]:
	return _resolve(board, [origin], {}, flood_color)


static func clears_from_combo(board: RefCounted, a: Vector2i, b: Vector2i, dest: Vector2i) -> Array[Vector2i]:
	var ta: int = board.get_cell(a)
	var tb: int = board.get_cell(b)
	var seeds: Dictionary = {}
	seeds[a] = true
	seeds[b] = true
	var flood_color := -1
	if ta == BoardModel.FLOOD and tb == BoardModel.FLOOD:
		for y in board.rows:
			for x in board.cols:
				var cell := Vector2i(x, y)
				if BoardModel.is_gem(board.get_cell(cell)):
					seeds[cell] = true
		return _resolve(board, [], seeds, -1)
	if ta == BoardModel.FLOOD or tb == BoardModel.FLOOD:
		flood_color = board.most_common_gem()
		_paint_cross_or_color(board, ta, tb, dest, seeds)
		var flood_origin := a if ta == BoardModel.FLOOD else b
		return _resolve(board, [flood_origin], seeds, flood_color)
	if BoardModel.is_canal(ta) and BoardModel.is_canal(tb):
		_add_row(board, dest.y, seeds)
		_add_col(board, dest.x, seeds)
		return _resolve(board, [], seeds, -1)
	if (BoardModel.is_canal(ta) and tb == BoardModel.BLAST) or (BoardModel.is_canal(tb) and ta == BoardModel.BLAST):
		for dy in range(-1, 2):
			_add_row(board, dest.y + dy, seeds)
		for dx in range(-1, 2):
			_add_col(board, dest.x + dx, seeds)
		return _resolve(board, [], seeds, -1)
	if (ta == BoardModel.BLAST and tb == BoardModel.DRAGONFLY) or (tb == BoardModel.BLAST and ta == BoardModel.DRAGONFLY):
		_add_disk(board, dest, 2, seeds)
		_add_random_gems(board, seeds, 3)
		return _resolve(board, [], seeds, -1)
	return _resolve(board, [a, b], {}, -1)


static func _paint_cross_or_color(board: RefCounted, ta: int, tb: int, dest: Vector2i, seeds: Dictionary) -> void:
	var other: int = tb if ta == BoardModel.FLOOD else ta
	if BoardModel.is_canal(other):
		_add_row(board, dest.y, seeds)
		_add_col(board, dest.x, seeds)
	elif other == BoardModel.BLAST:
		_add_disk(board, dest, 2, seeds)
	elif other == BoardModel.DRAGONFLY:
		_add_random_gems(board, seeds, 5)


static func _resolve(board: RefCounted, fire_list: Array, seeds: Dictionary, flood_color: int) -> Array[Vector2i]:
	var fire: Array[Vector2i] = []
	for item in fire_list:
		fire.append(item)
	for key in seeds.keys():
		var seeded: Vector2i = key
		if BoardModel.is_booster(board.get_cell(seeded)):
			fire.append(seeded)
	var seen_fire: Dictionary = {}
	while not fire.is_empty():
		var origin: Vector2i = fire.pop_back()
		if seen_fire.has(origin):
			continue
		seen_fire[origin] = true
		var tile_type: int = board.get_cell(origin)
		seeds[origin] = true
		if not BoardModel.is_booster(tile_type):
			continue
		match tile_type:
			BoardModel.CANAL_H:
				_add_row(board, origin.y, seeds)
			BoardModel.CANAL_V:
				_add_col(board, origin.x, seeds)
			BoardModel.BLAST:
				_add_disk(board, origin, 1, seeds)
				_add_disk(board, origin, 1, seeds)
			BoardModel.DRAGONFLY:
				_add_disk(board, origin, 1, seeds)
				_add_random_gems(board, seeds, 1)
			BoardModel.FLOOD:
				var color: int = flood_color if flood_color >= 0 else int(board.most_common_gem())
				_add_color(board, color, seeds)
		for key in seeds.keys():
			var cell: Vector2i = key
			if seen_fire.has(cell):
				continue
			if BoardModel.is_booster(board.get_cell(cell)):
				fire.append(cell)
	var out: Array[Vector2i] = []
	for key in seeds.keys():
		out.append(key as Vector2i)
	return out


static func _add_row(board: RefCounted, y: int, seeds: Dictionary) -> void:
	if y < 0 or y >= board.rows:
		return
	for x in board.cols:
		seeds[Vector2i(x, y)] = true


static func _add_col(board: RefCounted, x: int, seeds: Dictionary) -> void:
	if x < 0 or x >= board.cols:
		return
	for y in board.rows:
		seeds[Vector2i(x, y)] = true


static func _add_disk(board: RefCounted, center: Vector2i, radius: int, seeds: Dictionary) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if board.in_bounds(cell):
				seeds[cell] = true


static func _add_color(board: RefCounted, color: int, seeds: Dictionary) -> void:
	for y in board.rows:
		for x in board.cols:
			var cell := Vector2i(x, y)
			if board.get_cell(cell) == color:
				seeds[cell] = true


static func _add_random_gems(board: RefCounted, seeds: Dictionary, count: int) -> void:
	var candidates: Array[Vector2i] = []
	for y in board.rows:
		for x in board.cols:
			var cell := Vector2i(x, y)
			if seeds.has(cell):
				continue
			if BoardModel.is_gem(board.get_cell(cell)):
				candidates.append(cell)
	candidates.shuffle()
	for i in mini(count, candidates.size()):
		seeds[candidates[i]] = true
