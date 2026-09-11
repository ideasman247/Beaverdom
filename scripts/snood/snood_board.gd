extends Control
## Snood-style rescue: hang, match, drop, keep the dam.

const Model := preload("res://scripts/snood/snood_model.gd")
const Art := preload("res://scripts/snood/snood_art.gd")
const SHOT_SPEED := 2200.0
const MATCH_MIN := 3
const SHOTS_PER_DROP := 5
const DAM_TOP := 1520.0
const HUD_PAD := 32.0
const HUD_H := 72.0
const ICON_GAP := 20.0
const DRIP_HANG := 0.22
const MIN_INSET_TOP := 56.0
const MIN_INSET_BOTTOM := 40.0
const LOB_GRAVITY := 2800.0
const LOB_MAX_SEC := 1.8

var _model := Model.new()
var _views: Dictionary = {}
var _cell := 92.0
var _row_h := 80.0
var _origin := Vector2(80.0, 210.0)
var _hang_y := 90.0
var _sludge_rows := 0
var _shot_type := 0
var _next_type := 0
var _flying := false
var _shot_pos := Vector2.ZERO
var _shot_vel := Vector2.ZERO
var _aim := Vector2.UP
var _aiming := false
var _busy := false
var _resolved := false
var _shots_until_drop := SHOTS_PER_DROP
var _rescued := 0
var _bits := 0
var _chomp_next := false
var _slap_next := false
var _flush_left := 1
var _chomp_left := 1
var _slap_left := 1
var _mode := &"normal"

@onready var _grid: Control = $GridHost
@onready var _sludge: TextureRect = $Sludge
@onready var _sludge_body: TextureRect = $SludgeBody
@onready var _shot: TextureRect = $Shot
@onready var _beaver: TextureRect = $Beaver
@onready var _aim_line: Line2D = $AimLine
@onready var _hud: Label = $Hud
@onready var _queue: TextureRect = $Queue
@onready var _home: Button = $Home
@onready var _slap: Button = $Powers/Slap
@onready var _chomp: Button = $Powers/Chomp
@onready var _flush: Button = $Powers/Flush
@onready var _overlay: ColorRect = $Overlay
@onready var _banner: Label = $Overlay/Banner
@onready var _action: Button = $Overlay/Action


func _ready() -> void:
	randomize()
	_home.pressed.connect(_go_lodge)
	_action.pressed.connect(_on_overlay)
	_slap.pressed.connect(_arm_slap)
	_chomp.pressed.connect(_arm_chomp)
	_flush.pressed.connect(_do_flush)
	_style_wood_button(_home)
	_style_wood_button(_action)
	_style_wood_button(_slap)
	_style_wood_button(_chomp)
	_style_wood_button(_flush)
	_style_wood_chip(_hud)
	_style_wood_chip(_banner)
	_model.fill_level(5)
	_deal_queue()
	_rebuild_views()
	_refresh_hud()
	_overlay.visible = false
	resized.connect(_on_resized)
	await get_tree().process_frame
	_layout_board()
	_rebuild_views()


func _on_resized() -> void:
	_layout_board()
	_rebuild_views()


func _layout_board() -> void:
	var w := size.x if size.x > 1.0 else 1080.0
	# Even rows are 8 icons; fill the screen so banks happen at the visible edges.
	_cell = w / 8.0
	_row_h = _cell * 0.86
	_origin.x = 0.0
	_sync_sludge()
	_shot.size = Vector2(_cell, _cell)
	_queue.size = Vector2(_cell * 0.85, _cell * 0.85)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_lodge()
	elif what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_board()
		_rebuild_views()


func _screen_insets() -> Vector2:
	var vis := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if vis.y <= 1.0:
		vis = Vector2(1080.0, 1920.0)
	var top := 0.0
	var bottom := 0.0
	var safe := DisplayServer.get_display_safe_area()
	if win.y > 1.0 and safe.size.y > 0:
		var sy := vis.y / win.y
		top = maxf(float(safe.position.y) * sy, 0.0)
		bottom = maxf(float(win.y - safe.end.y) * sy, 0.0)
	return Vector2(maxf(top, MIN_INSET_TOP), maxf(bottom, MIN_INSET_BOTTOM))


func _go_lodge() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/valley.tscn")


func _deal_queue() -> void:
	var types := _model.types_in_play()
	_shot_type = _model.random_shot(types)
	_next_type = _model.random_shot(types)
	_paint_queue()


func _paint_queue() -> void:
	_shot.texture = Art.texture_for(_shot_type)
	_queue.texture = Art.texture_for(_next_type)
	_shot.visible = not _flying
	_place_chamber()


func _place_chamber() -> void:
	var mouth := _beaver_mouth()
	_shot.position = mouth - _shot.size * 0.5
	_shot.pivot_offset = _shot.size * 0.5


func _beaver_mouth() -> Vector2:
	var w := size.x if size.x > 1.0 else 1080.0
	return Vector2(w * 0.5, _beaver.position.y + _beaver.size.y * 0.16)


func _hex_pos(col: int, row: int) -> Vector2:
	var x := _origin.x + float(col) * _cell
	if row % 2 == 1:
		x += _cell * 0.5
	var y := _origin.y + float(row) * _row_h
	return Vector2(x, y)


func _rebuild_views() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_views.clear()
	for cell in _model.occupied_keys():
		_spawn_view(cell, _model.get_cell(cell.x, cell.y))


func _spawn_view(cell: Vector2i, icon_type: int) -> void:
	var node := TextureRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.size = Vector2(_cell, _cell)
	node.position = _hex_pos(cell.x, cell.y)
	node.texture = Art.texture_for(icon_type)
	_grid.add_child(node)
	_views["%d,%d" % [cell.x, cell.y]] = node


func _gui_input(event: InputEvent) -> void:
	if _busy or _resolved or _overlay.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_aiming = true
			_aim_at(t.position)
		else:
			if _aiming:
				_fire()
			_aiming = false
	elif event is InputEventScreenDrag:
		_aim_at((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index != MOUSE_BUTTON_LEFT:
			return
		if b.pressed:
			_aiming = true
			_aim_at(b.position)
		else:
			if _aiming:
				_fire()
			_aiming = false
	elif event is InputEventMouseMotion and _aiming:
		_aim_at((event as InputEventMouseMotion).position)


func _aim_at(pos: Vector2) -> void:
	var mouth := _beaver_mouth()
	var dir := (pos - mouth)
	if dir.y > -8.0:
		dir.y = -8.0
	if dir.length() < 8.0:
		dir = Vector2.UP
	_aim = dir.normalized()
	_aim_line.clear_points()
	_aim_line.add_point(mouth)
	_aim_line.add_point(mouth + _aim * 220.0)


func _fire() -> void:
	if _flying or _busy:
		return
	_flying = true
	_shot.visible = true
	_shot_pos = _beaver_mouth()
	_shot_vel = _aim * SHOT_SPEED
	_shot.position = _shot_pos - _shot.size * 0.5
	Sfx.shoot()


func _process(delta: float) -> void:
	if not _flying:
		_place_chamber()
		return
	_shot_pos += _shot_vel * delta
	var half := _cell * 0.5
	var left := half
	var right := (size.x if size.x > 1.0 else 1080.0) - half
	var bounced := false
	if _shot_pos.x < left:
		_shot_pos.x = left
		_shot_vel.x = absf(_shot_vel.x)
		bounced = true
	elif _shot_pos.x > right:
		_shot_pos.x = right
		_shot_vel.x = -absf(_shot_vel.x)
		bounced = true
	if bounced:
		Sfx.bounce()
	_shot.position = _shot_pos - _shot.size * 0.5
	if _shot_pos.y < _hang_y - _cell:
		_stick_to_ceiling()
		return
	var hit := _hit_occupied()
	if hit != Vector2i(-1, -1):
		_stick_near(hit)


func _hit_occupied() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := _cell * 0.58
	for cell in _model.occupied_keys():
		var p := _hex_pos(cell.x, cell.y) + Vector2(_cell, _cell) * 0.5
		var d := _shot_pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = cell
	return best


func _stick_to_ceiling() -> void:
	var col := clampi(int((_shot_pos.x - _origin.x) / _cell + 0.5), 0, Model.COLS - 1)
	if _model.get_cell(col, 0) != Model.EMPTY:
		var n := _nearest_empty_beside(Vector2i(col, 0))
		if n.x < 0:
			_flying = false
			_paint_queue()
			return
		_land(n)
	else:
		_land(Vector2i(col, 0))


func _stick_near(hit: Vector2i) -> void:
	var n := _nearest_empty_beside(hit)
	if n.x < 0:
		_flying = false
		_paint_queue()
		return
	_land(n)


func _nearest_empty_beside(hit: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1.0e9
	for n in _model.neighbors(hit.x, hit.y):
		if _model.get_cell(n.x, n.y) != Model.EMPTY:
			continue
		var p := _hex_pos(n.x, n.y) + Vector2(_cell, _cell) * 0.5
		var d := _shot_pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = n
	if best.x < 0 and hit.y == 0:
		for c in Model.COLS:
			if _model.get_cell(c, 0) == Model.EMPTY:
				var p := _hex_pos(c, 0) + Vector2(_cell, _cell) * 0.5
				var d := _shot_pos.distance_to(p)
				if d < best_d:
					best_d = d
					best = Vector2i(c, 0)
	return best


func _land(cell: Vector2i) -> void:
	_busy = true
	_flying = false
	var landed := _shot_type
	if _mode == &"chomp":
		var hit_type := Model.EMPTY
		for n in _model.neighbors(cell.x, cell.y):
			var t := _model.get_cell(n.x, n.y)
			if Model.is_playable(t):
				hit_type = t
				break
		landed = hit_type if hit_type != Model.EMPTY else _next_type
		_mode = &"normal"
	_model.set_cell(cell.x, cell.y, landed)
	_shot_type = _next_type
	_next_type = _model.random_shot(_model.types_in_play())
	_paint_queue()
	_busy = true
	if _mode == &"slap" or _slap_next:
		_slap_next = false
		_mode = &"normal"
		await _resolve_row(cell.y)
	else:
		await _resolve_match(cell, landed)
	_shots_until_drop -= 1
	if _shots_until_drop <= 0:
		_shots_until_drop = SHOTS_PER_DROP
		_drop_ceiling()
	_rebuild_views()
	_refresh_hud()
	_check_outcome()
	_busy = false


func _resolve_match(cell: Vector2i, icon_type: int) -> void:
	var group := _model.group_of(cell.x, cell.y, icon_type)
	if group.size() >= MATCH_MIN:
		for g in group:
			_reward_match(_model.get_cell(g.x, g.y))
			_model.set_cell(g.x, g.y, Model.EMPTY)
		Sfx.tap()
		_rebuild_views()
	await _drop_severed()


func _resolve_row(row: int) -> void:
	for c in Model.COLS:
		var t := _model.get_cell(c, row)
		if t != Model.EMPTY:
			_reward_match(t)
	_model.clear_row(row)
	Sfx.tap()
	_rebuild_views()
	await _drop_severed()


func _drop_severed() -> void:
	var fall := _model.severed_cells()
	if fall.is_empty():
		return
	var payloads: Array[Dictionary] = []
	for cell in fall:
		var icon_type := _model.get_cell(cell.x, cell.y)
		payloads.append({
			&"type": icon_type,
			&"pos": _hex_pos(cell.x, cell.y),
		})
		_reward_drop(icon_type)
		_model.set_cell(cell.x, cell.y, Model.EMPTY)
	_rebuild_views()
	await _lob_icons(payloads)


func _lob_icons(payloads: Array[Dictionary]) -> void:
	var lobs: Array[Dictionary] = []
	var mid := size.x * 0.5 if size.x > 1.0 else 540.0
	for piece in payloads:
		var node := TextureRect.new()
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node.size = Vector2(_cell, _cell)
		node.position = piece[&"pos"]
		node.pivot_offset = node.size * 0.5
		node.z_index = 7
		node.texture = Art.texture_for(int(piece[&"type"]))
		add_child(node)
		var away := (node.position.x + _cell * 0.5) - mid
		lobs.append({
			&"node": node,
			&"vel": Vector2(away * 1.4 + randf_range(-160.0, 160.0), randf_range(-520.0, -180.0)),
			&"spin": randf_range(-9.0, 9.0),
		})
	Sfx.bounce()
	var elapsed := 0.0
	while elapsed < LOB_MAX_SEC and not lobs.is_empty():
		var dt := get_process_delta_time()
		await get_tree().process_frame
		elapsed += dt
		var next: Array[Dictionary] = []
		var floor_y := (size.y if size.y > 1.0 else 1920.0) + _cell
		for lob in lobs:
			var node: TextureRect = lob[&"node"]
			if not is_instance_valid(node):
				continue
			var vel: Vector2 = lob[&"vel"]
			vel.y += LOB_GRAVITY * dt
			lob[&"vel"] = vel
			node.position += vel * dt
			node.rotation += float(lob[&"spin"]) * dt
			if node.position.y < floor_y and node.position.x > -_cell * 2.0 and node.position.x < size.x + _cell:
				next.append(lob)
			else:
				node.queue_free()
		lobs = next
	for lob in lobs:
		var node: TextureRect = lob[&"node"]
		if is_instance_valid(node):
			node.queue_free()


func _reward_match(icon_type: int) -> void:
	match Model.kind_of(icon_type):
		Model.KIND_FRIEND:
			_rescued += 1
		Model.KIND_RESOURCE:
			_bits += 1
			GameState.stars += 1
		_:
			pass


func _reward_drop(icon_type: int) -> void:
	match Model.kind_of(icon_type):
		Model.KIND_FRIEND:
			_rescued += 1
		Model.KIND_RESOURCE:
			_bits += 1
			GameState.stars += 1
		_:
			pass


func _sync_sludge() -> void:
	var inset := _screen_insets()
	var hud_top := 12.0 + inset.x
	var hud_bottom := hud_top + HUD_H
	_hud.offset_left = HUD_PAD
	_hud.offset_right = -HUD_PAD
	_hud.offset_top = hud_top
	_hud.offset_bottom = hud_bottom
	# Row 0 is the HUD band: tiled fill with no drips. Lead drip is row 1.
	# Extra sludge advances duplicate row 0 downward; drip stays flush under it.
	var drip_y := hud_bottom + float(_sludge_rows) * _row_h
	_sludge_body.visible = true
	_sludge_body.offset_top = 0.0
	_sludge_body.offset_bottom = drip_y + 4.0
	_sludge_body.offset_left = 0.0
	_sludge_body.offset_right = 0.0
	_sludge.offset_left = 0.0
	_sludge.offset_right = 0.0
	_sludge.offset_top = drip_y
	_sludge.offset_bottom = drip_y + _row_h * (1.0 + DRIP_HANG)
	_hang_y = drip_y + _row_h + ICON_GAP
	_origin.y = _hang_y


func _drop_ceiling() -> void:
	_sludge_rows += 1
	_sync_sludge()
	_rebuild_views()


func _arm_slap() -> void:
	if _slap_left <= 0 or _busy or _flying:
		return
	_slap_left -= 1
	_slap_next = true
	_mode = &"slap"
	_refresh_hud()


func _arm_chomp() -> void:
	if _chomp_left <= 0 or _busy or _flying:
		return
	_chomp_left -= 1
	_shot_type = Model.CHOMP
	_mode = &"chomp"
	_paint_queue()
	_refresh_hud()


func _do_flush() -> void:
	if _flush_left <= 0 or _busy:
		return
	_flush_left -= 1
	_sludge_rows = maxi(0, _sludge_rows - 2)
	_sync_sludge()
	_rebuild_views()
	_refresh_hud()
	Sfx.tap()


func _lowest_bottom() -> float:
	var low := -1
	for cell in _model.occupied_keys():
		low = maxi(low, cell.y)
	if low < 0:
		return 0.0
	return _hex_pos(0, low).y + _cell


func _check_outcome() -> void:
	if _resolved:
		return
	if _lowest_bottom() >= DAM_TOP:
		_resolved = true
		_show_overlay("The dam is breached", "Try again")
		Sfx.fail()
		return
	if not _model.friends_or_threats_left():
		for cell in _model.occupied_keys():
			_reward_drop(_model.get_cell(cell.x, cell.y))
			_model.set_cell(cell.x, cell.y, Model.EMPTY)
		_rebuild_views()
		_resolved = true
		var payout := GameState.award_snood_win(_rescued, _bits)
		_show_overlay("Sludge diverted · +%d sticks" % payout, "Lodge")
		Sfx.win()


func _show_overlay(banner: String, action: String) -> void:
	_banner.text = banner
	_action.text = action
	_overlay.visible = true


func _on_overlay() -> void:
	if _action.text == "Lodge":
		_go_lodge()
	else:
		get_tree().reload_current_scene()


func _refresh_hud() -> void:
	_hud.text = "Rescued %d · Sticks +%d · Drop in %d" % [_rescued, _bits, _shots_until_drop]
	_slap.text = "Tail slap · %d" % _slap_left
	_chomp.text = "Chomp · %d" % _chomp_left
	_flush.text = "Flush · %d" % _flush_left
	_slap.disabled = _slap_left <= 0
	_chomp.disabled = _chomp_left <= 0
	_flush.disabled = _flush_left <= 0


func _style_wood_button(btn: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.36, 0.26, 0.16, 0.94)
	box.set_corner_radius_all(18)
	box.set_border_width_all(3)
	box.border_color = Color(0.58, 0.44, 0.28)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	var pressed := box.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.2, 0.12, 0.96)
	for key in ["normal", "hover", "focus"]:
		btn.add_theme_stylebox_override(key, box)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.84))
	btn.add_theme_color_override("font_disabled_color", Color(0.86, 0.8, 0.72, 0.55))


func _style_wood_chip(label: Label) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.36, 0.26, 0.16, 0.94)
	box.set_corner_radius_all(16)
	box.set_border_width_all(3)
	box.border_color = Color(0.58, 0.44, 0.28)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	label.add_theme_stylebox_override("normal", box)
	label.add_theme_color_override("font_color", Color(0.97, 0.93, 0.84))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
