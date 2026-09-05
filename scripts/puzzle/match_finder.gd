extends RefCounted
## Phase 1: contiguous lines of 3+ only. No L/T, 2x2, or 4/5 boosters yet.

const BoardModel := preload("res://scripts/puzzle/board_model.gd")


static func find_line_cells(board: RefCounted) -> Array[Vector2i]:
	var marked: Dictionary = {}
	_mark_runs(board, true, marked)
	_mark_runs(board, false, marked)
	var cells: Array[Vector2i] = []
	for key in marked.keys():
		cells.append(key as Vector2i)
	return cells


static func has_line_match(board: RefCounted) -> bool:
	return not find_line_cells(board).is_empty()


static func has_valid_swap(board: RefCounted) -> bool:
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
	board.swap(a, b)
	var matched := has_line_match(board)
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
			if tile_type != BoardModel.EMPTY and tile_type == run_type:
				run_len += 1
				continue
			if run_type != BoardModel.EMPTY and run_len >= 3:
				for k in run_len:
					var hit := Vector2i(run_start + k, i) if horizontal else Vector2i(i, run_start + k)
					marked[hit] = true
			run_type = tile_type
			run_len = 1
			run_start = j
