extends RefCounted
## Lines of 3+ gems and 2x2 squares. Boosters do not form color matches.

const BoardModel := preload("res://scripts/puzzle/board_model.gd")


static func find_match_cells(board: RefCounted) -> Array[Vector2i]:
	var marked: Dictionary = {}
	_mark_runs(board, true, marked)
	_mark_runs(board, false, marked)
	_mark_squares(board, marked)
	var cells: Array[Vector2i] = []
	for key in marked.keys():
		cells.append(key as Vector2i)
	return cells


static func has_match(board: RefCounted) -> bool:
	return not find_match_cells(board).is_empty()


static func has_valid_move(board: RefCounted) -> bool:
	if board.has_any_booster():
		return true
	for y in board.rows:
		for x in board.cols:
			var here := Vector2i(x, y)
			var right := Vector2i(x + 1, y)
			var down := Vector2i(x, y + 1)
			if board.in_bounds(right) and _swap_would_match(board, here, right):
				return true
			if board.in_bounds(down) and _swap_would_match(board, here, down):
				return true
	return false


static func _swap_would_match(board: RefCounted, a: Vector2i, b: Vector2i) -> bool:
	if BoardModel.is_booster(board.get_cell(a)) or BoardModel.is_booster(board.get_cell(b)):
		return true
	board.swap(a, b)
	var matched := has_match(board)
	board.swap(a, b)
	return matched


static func _mark_runs(board: RefCounted, horizontal: bool, marked: Dictionary) -> void:
	var major: int = board.rows if horizontal else board.cols
	var minor: int = board.cols if horizontal else board.rows
	for i in major:
		var run_type: int = BoardModel.EMPTY
		var run_len := 0
		var run_start := 0
		for j in minor + 1:
			var cell := Vector2i(j, i) if horizontal else Vector2i(i, j)
			var tile_type: int = board.get_cell(cell) if j < minor else BoardModel.EMPTY - 1
			if BoardModel.is_gem(tile_type) and tile_type == run_type:
				run_len += 1
				continue
			if BoardModel.is_gem(run_type) and run_len >= 3:
				for k in run_len:
					var hit := Vector2i(run_start + k, i) if horizontal else Vector2i(i, run_start + k)
					marked[hit] = true
			run_type = tile_type
			run_len = 1
			run_start = j


static func _mark_squares(board: RefCounted, marked: Dictionary) -> void:
	for y in board.rows - 1:
		for x in board.cols - 1:
			var origin := Vector2i(x, y)
			var tile_type: int = board.get_cell(origin)
			if not BoardModel.is_gem(tile_type):
				continue
			if (
				board.get_cell(Vector2i(x + 1, y)) == tile_type
				and board.get_cell(Vector2i(x, y + 1)) == tile_type
				and board.get_cell(Vector2i(x + 1, y + 1)) == tile_type
			):
				marked[origin] = true
				marked[Vector2i(x + 1, y)] = true
				marked[Vector2i(x, y + 1)] = true
				marked[Vector2i(x + 1, y + 1)] = true
