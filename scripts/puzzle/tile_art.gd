extends RefCounted
## Atlas slices from the 3x3 wetland tile sheet.

const SHEET := preload("res://assets/art/puzzle_tiles.png")
const GRID := 3
const BoardModel := preload("res://scripts/puzzle/board_model.gd")


static func texture_for(tile_type: int) -> Texture2D:
	var col := 0
	var row := 0
	match tile_type:
		0:
			col = 0
			row = 0
		1:
			col = 1
			row = 0
		2:
			col = 2
			row = 0
		3:
			col = 0
			row = 1
		4:
			col = 1
			row = 1
		BoardModel.CANAL_H, BoardModel.CANAL_V:
			col = 2
			row = 1
		BoardModel.BLAST:
			col = 0
			row = 2
		BoardModel.DRAGONFLY:
			col = 1
			row = 2
		BoardModel.FLOOD:
			col = 2
			row = 2
		_:
			return null
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	var cell := float(SHEET.get_width()) / float(GRID)
	tex.region = Rect2(col * cell, row * cell, cell, cell)
	return tex
