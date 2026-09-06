extends RefCounted
## Forty levels: twenty lessons, then a longer valley session.


static func all_levels() -> Array[Dictionary]:
	var levels: Array[Dictionary] = [
		_lv(1, 22, &"gems", 10, 0, "Match three of the same color in a line."),
		_lv(2, 22, &"gems", 16, 0, "Cascades count. Keep matching."),
		_lv(3, 24, &"gems", 22, 0, "Longer lines are fine. Three is enough."),
		_lv(4, 20, &"gems", 20, 0, "A little tighter. Same idea."),
		_lv(5, 28, &"canal", 1, 0, "Match four in a line to make a Canal. Tap it."),
		_lv(6, 26, &"canal", 1, 0, "Horizontal four clears a row. Vertical four clears a column."),
		_lv(7, 30, &"canal", 2, 0, "Make two Canals. Swap them for a cross."),
		_lv(8, 24, &"gems", 18, 0, "Warm-up. Four still makes a Canal if you want it."),
		_lv(9, 28, &"dragonfly", 1, 0, "Match a 2x2 square for a Dragonfly. Tap it."),
		_lv(10, 26, &"dragonfly", 1, 0, "It pops neighbors, then one more gem elsewhere."),
		_lv(11, 30, &"dragonfly", 2, 0, "Two Dragonflies. Squares, not lines."),
		_lv(12, 32, &"blast", 1, 0, "An L or T of five makes a Lodge blast."),
		_lv(13, 28, &"blast", 1, 0, "Three in a row plus three in a column, sharing a corner."),
		_lv(14, 32, &"blast", 2, 0, "Two Lodge blasts. Swap with a Canal for three rows and columns."),
		_lv(15, 34, &"flood", 1, 0, "Five in a line makes Flood bloom. Swap it onto a color."),
		_lv(16, 30, &"flood", 1, 0, "Or tap it to wash the most common color."),
		_lv(17, 26, &"oil", 4, 4, "Dark stains are oil. Match on that tile to clean it."),
		_lv(18, 24, &"oil", 6, 6, "Oil stays on the bank while gems fall. Clean the puddle."),
		_lv(19, 28, &"oil", 8, 8, "Boosters clean oil too. Canals are handy here."),
		_lv(20, 30, &"oil", 10, 10, "Last lesson. Clear every stain."),
		_lv(21, 24, &"gems", 24, 0, "The valley is open. Keep the pond fed."),
		_lv(22, 26, &"canal", 2, 3, "Canals through a little oil."),
		_lv(23, 26, &"dragonfly", 2, 0, "Two squares. Let them fly."),
		_lv(24, 28, &"blast", 1, 5, "A Lodge blast over stained tiles."),
		_lv(25, 32, &"flood", 1, 0, "Wash a whole color when the board is busy."),
		_lv(26, 22, &"gems", 28, 0, "Tighter moves. Cascades are your friend."),
		_lv(27, 26, &"oil", 8, 8, "Another messy bank."),
		_lv(28, 28, &"canal", 2, 0, "Two Canals. Combo if you can."),
		_lv(29, 28, &"oil", 10, 10, "Boosters count. The stains do not care how."),
		_lv(30, 30, &"dragonfly", 2, 4, "Squares and oil. Clean as you fly."),
		_lv(31, 30, &"blast", 2, 0, "Two L or T shapes."),
		_lv(32, 32, &"flood", 1, 6, "Flood the oil away."),
		_lv(33, 20, &"gems", 26, 0, "Short on moves. Be picky."),
		_lv(34, 28, &"oil", 12, 12, "A wider spill."),
		_lv(35, 32, &"canal", 3, 0, "Three Canals. The dam will thank you."),
		_lv(36, 28, &"dragonfly", 2, 0, "More habitat in the air."),
		_lv(37, 30, &"blast", 2, 6, "Explosions over the stain."),
		_lv(38, 30, &"flood", 1, 0, "One clean bloom."),
		_lv(39, 28, &"oil", 12, 12, "Almost honest water."),
		_lv(40, 32, &"oil", 14, 14, "Clear the last of this creek's mess."),
	]
	return levels


static func _lv(
	id: int,
	moves: int,
	goal: StringName,
	count: int,
	oil: int,
	teach: String
) -> Dictionary:
	return {
		&"id": id,
		&"moves": moves,
		&"goal": goal,
		&"count": count,
		&"oil": oil,
		&"teach": teach,
	}
