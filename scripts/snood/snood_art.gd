extends RefCounted
## Atlas slices for the 4x3 snood icon sheet.

const SHEET := preload("res://assets/art/snood_icons.png")
const GRID_W := 4
const GRID_H := 3


static func texture_for(icon_type: int) -> Texture2D:
	if icon_type < 0:
		return null
	var col := icon_type % GRID_W
	var row := icon_type / GRID_W
	if row >= GRID_H:
		return null
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.filter_clip = true
	var cw := float(SHEET.get_width()) / float(GRID_W)
	var ch := float(SHEET.get_height()) / float(GRID_H)
	var inset := 4.0
	tex.region = Rect2(col * cw + inset, row * ch + inset, cw - inset * 2.0, ch - inset * 2.0)
	return tex
