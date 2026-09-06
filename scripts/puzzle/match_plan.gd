extends RefCounted
## Priority: line of 5, L/T, line of 4, 2x2, line of 3.
## Spawn prefers the swipe-end cell when it is in the group.

const BoardModel := preload("res://scripts/puzzle/board_model.gd")
const MatchFinder := preload("res://scripts/puzzle/match_finder.gd")


static func build(board: RefCounted, focus: Vector2i) -> Dictionary:
	var match_cells := MatchFinder.find_match_cells(board)
	var plan := {&"clear": match_cells, &"spawns": []}
	if match_cells.is_empty():
		return plan
	var remaining: Dictionary = {}
	for cell in match_cells:
		remaining[cell] = true
	for cell in match_cells:
		if not remaining.has(cell):
			continue
		var color: int = board.get_cell(cell)
		var component: Array[Vector2i] = []
		var stack: Array[Vector2i] = [cell]
		remaining.erase(cell)
		while not stack.is_empty():
			var here: Vector2i = stack.pop_back()
			component.append(here)
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = here + offset
				if remaining.has(next) and board.get_cell(next) == color:
					remaining.erase(next)
					stack.append(next)
		var booster := _classify(component)
		if booster == BoardModel.EMPTY:
			continue
		var spawn := focus if _contains(component, focus) else component[component.size() / 2]
		plan[&"spawns"].append({&"cell": spawn, &"booster": booster})
	return plan


static func _contains(cells: Array[Vector2i], needle: Vector2i) -> bool:
	for cell in cells:
		if cell == needle:
			return true
	return false


static func _classify(component: Array[Vector2i]) -> int:
	var in_group: Dictionary = {}
	for cell in component:
		in_group[cell] = true
	var max_h := _max_axis_run(in_group, true)
	var max_v := _max_axis_run(in_group, false)
	var has_square := _has_square(in_group)
	if max_h >= 5 or max_v >= 5:
		return BoardModel.FLOOD
	if max_h >= 3 and max_v >= 3:
		return BoardModel.BLAST
	if max_h >= 4:
		return BoardModel.CANAL_H
	if max_v >= 4:
		return BoardModel.CANAL_V
	if has_square:
		return BoardModel.DRAGONFLY
	return BoardModel.EMPTY


static func _max_axis_run(in_group: Dictionary, horizontal: bool) -> int:
	var best := 1
	var keys: Array = in_group.keys()
	if keys.is_empty():
		return 0
	if horizontal:
		var by_row: Dictionary = {}
		for key in keys:
			var cell: Vector2i = key
			if not by_row.has(cell.y):
				by_row[cell.y] = []
			by_row[cell.y].append(cell.x)
		for row_xs: Array in by_row.values():
			row_xs.sort()
			best = maxi(best, _longest_consecutive(row_xs))
	else:
		var by_col: Dictionary = {}
		for key in keys:
			var cell: Vector2i = key
			if not by_col.has(cell.x):
				by_col[cell.x] = []
			by_col[cell.x].append(cell.y)
		for col_ys: Array in by_col.values():
			col_ys.sort()
			best = maxi(best, _longest_consecutive(col_ys))
	return best


static func _longest_consecutive(sorted_vals: Array) -> int:
	if sorted_vals.is_empty():
		return 0
	var best := 1
	var run := 1
	for i in range(1, sorted_vals.size()):
		if int(sorted_vals[i]) == int(sorted_vals[i - 1]) + 1:
			run += 1
			best = maxi(best, run)
		else:
			run = 1
	return best


static func _has_square(in_group: Dictionary) -> bool:
	for key in in_group.keys():
		var cell: Vector2i = key
		if (
			in_group.has(cell + Vector2i(1, 0))
			and in_group.has(cell + Vector2i(0, 1))
			and in_group.has(cell + Vector2i(1, 1))
		):
			return true
	return false
