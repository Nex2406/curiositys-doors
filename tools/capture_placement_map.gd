extends Node2D

# PLACEMENT MAP — a labeled, numbered overview of all of Realm 1 so Advika can
# call out where enemies (golems) go by grid cell or element number.
#
# Draws, over the real level:
#   • a coordinate grid — numbered COLUMNS (0,1,2… every CELL_W tiles) across the
#     top and LETTERED ROWS (A,B,C… every CELL_H tiles) down the side, with each
#     cell faintly tagged "<col><row>" (e.g. "12C") at its centre.
#   • every movable piece boxed + numbered (#0..#n, yellow).
#   • every floor crate box (B#, cyan) and plank board (P#, orange).
#
# Captures the whole level in readable horizontal strips to tools/shots/, plus a
# full-width overview. Run WINDOWED (needs a renderer):
#   Godot_v4.6.2-stable_win64.exe --path . res://tools/CapturePlacementMap.tscn

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"

const CELL_W: int = 20   # tiles per labeled grid column
const CELL_H: int = 8    # tiles per labeled grid row
const STRIP_WORLD_W: float = 3600.0   # world px per capture strip (≈readable labels)
const VIEW_W: float = 1920.0
const VIEW_H: float = 1080.0

# A component this big/wide is the painted floor, not a movable piece.
const FLOOR_MIN_CELLS := 150
const FLOOR_MIN_W := 45
const PLANK_MAX_H := 4

var _realm: Node = null
var _tiles: TileMapLayer = null
var _ur: Rect2i
var _tsize: Vector2
var _pieces: Array = []     # {mn, mx, kind}
var _boxes: Array = []      # {mn_x, mx_x, top_y}
var _planks: Array = []     # {mn_x, mx_x, top_y}


func _ready() -> void:
	_realm = load(REALM).instantiate()
	_tiles = _realm.get_node("TileMapLayer")
	_tsize = Vector2(_tiles.tile_set.tile_size)
	_ur = _tiles.get_used_rect()
	_derive_pieces()                       # from ORIGINAL cells, before extraction
	add_child(_realm)                      # realm _ready() lifts moving pieces
	await get_tree().process_frame
	await get_tree().process_frame
	# Floor crate-boxes + plank boards stay in the floor; reuse the realm's own scan.
	var fe: Dictionary = _realm._find_floor_elements()
	_boxes = fe["boxes"]
	_planks = fe["planks"]
	queue_redraw()

	_print_reference()
	await _capture_all()
	print("PLACEMENT_MAP_DONE")
	get_tree().quit()


# Connected components of the original painted cells, minus the floor — the movable
# pieces, numbered left-to-right (matches Realm1._find_pieces ordering).
func _derive_pieces() -> void:
	var cells := {}
	for c in _tiles.get_used_cells():
		cells[c] = true
	var seen := {}
	for start in cells.keys():
		if seen.has(start):
			continue
		var stack: Array = [start]
		var group: Array = []
		var mn := Vector2i(1 << 30, 1 << 30)
		var mx := Vector2i(-(1 << 30), -(1 << 30))
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			if seen.has(c) or not cells.has(c):
				continue
			seen[c] = true
			group.append(c)
			mn.x = mini(mn.x, c.x); mn.y = mini(mn.y, c.y)
			mx.x = maxi(mx.x, c.x); mx.y = maxi(mx.y, c.y)
			stack.append(c + Vector2i(1, 0)); stack.append(c + Vector2i(-1, 0))
			stack.append(c + Vector2i(0, 1)); stack.append(c + Vector2i(0, -1))
		var w: int = mx.x - mn.x + 1
		var h: int = mx.y - mn.y + 1
		if group.size() >= FLOOR_MIN_CELLS or w >= FLOOR_MIN_W:
			continue
		_pieces.append({"mn": mn, "mx": mx, "kind": "plank" if h <= PLANK_MAX_H else "structure"})
	_pieces.sort_custom(func(a, b):
		var pa: Vector2i = a["mn"]; var pb: Vector2i = b["mn"]
		return (pa.x * 100000 + pa.y) < (pb.x * 100000 + pb.y))


# Print a full coordinate table so positions are addressable even from the console.
func _print_reference() -> void:
	var px_w := int(_ur.size.x * _tsize.x)
	var px_h := int(_ur.size.y * _tsize.y)
	print("BOUNDS used_rect=%s tsize=%s  level_px=%dx%d  cols=%d rows=%d" % [
		str(_ur), str(_tsize), px_w, px_h, _ur.size.x, _ur.size.y])
	print("GRID cell=%dx%d tiles  → %d grid-cols x %d grid-rows" % [
		CELL_W, CELL_H, ceili(float(_ur.size.x) / CELL_W), ceili(float(_ur.size.y) / CELL_H)])
	print("--- grid columns (world x at each numbered column line) ---")
	var col_idx := 0
	var tx := _ur.position.x
	while tx <= _ur.position.x + _ur.size.x:
		print("  col %d → tile_x=%d  world_x=%d" % [col_idx, tx, int(tx * _tsize.x)])
		tx += CELL_W; col_idx += 1
	print("--- pieces (# → center world) ---")
	for i in range(_pieces.size()):
		var p = _pieces[i]
		var cwx := int((float(p["mn"].x) + float(p["mx"].x) + 1.0) * 0.5 * _tsize.x)
		var cwy := int((float(p["mn"].y) + float(p["mx"].y) + 1.0) * 0.5 * _tsize.y)
		print("  #%d %s  cells=%s..%s  center_world=(%d,%d)" % [
			i, p["kind"], str(p["mn"]), str(p["mx"]), cwx, cwy])


func _capture_all() -> void:
	var left_px := float(_ur.position.x) * _tsize.x
	var px_w := float(_ur.size.x) * _tsize.x
	var mid_y := (float(_ur.position.y) + float(_ur.size.y) * 0.5) * _tsize.y
	var n := ceili(px_w / STRIP_WORLD_W)
	var zoom := VIEW_W / STRIP_WORLD_W
	for i in range(n):
		var cx := left_px + (float(i) + 0.5) * STRIP_WORLD_W
		await _shoot(Vector2(cx, mid_y), Vector2(zoom, zoom),
			"res://tools/shots/placement_strip_%d.png" % i)
	# Full-width overview (labels tiny, but shows whole layout + symmetry).
	var full_zoom := VIEW_W / px_w
	await _shoot(Vector2(left_px + px_w * 0.5, mid_y), Vector2(full_zoom, full_zoom),
		"res://tools/shots/placement_full.png")
	print("STRIPS=%d" % n)


func _shoot(cam_pos: Vector2, zoom: Vector2, path: String) -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.global_position = cam_pos
	cam.zoom = zoom
	cam.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	cam.queue_free()


func _draw() -> void:
	if _tiles == null:
		return
	var font := ThemeDB.fallback_font
	var ox: int = _ur.position.x
	var oy: int = _ur.position.y
	var ex: int = _ur.position.x + _ur.size.x
	var ey: int = _ur.position.y + _ur.size.y
	var x0: float = float(ox) * _tsize.x
	var x1: float = float(ex) * _tsize.x
	var y0: float = float(oy) * _tsize.y
	var y1: float = float(ey) * _tsize.y

	# Faint full-height grid lines + numbered column headers.
	var col_idx := 0
	var tx := ox
	while tx <= ex:
		var wx := float(tx) * _tsize.x
		draw_line(Vector2(wx, y0), Vector2(wx, y1), Color(1, 1, 1, 0.16), 1.0)
		draw_string(font, Vector2(wx + 4.0, y0 - 10.0), str(col_idx),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 0.95, 0.3))
		tx += CELL_W; col_idx += 1
	# Faint full-width grid lines + lettered row headers.
	var row_idx := 0
	var ty := oy
	while ty <= ey:
		var wy := float(ty) * _tsize.y
		draw_line(Vector2(x0, wy), Vector2(x1, wy), Color(1, 1, 1, 0.16), 1.0)
		draw_string(font, Vector2(x0 - 60.0, wy + 30.0), _row_letter(row_idx),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.6, 1, 0.6))
		ty += CELL_H; row_idx += 1
	# Per-cell coordinate tag at each cell centre (faint), e.g. "12C".
	var ci := 0
	tx = ox
	while tx < ex:
		var ri := 0
		ty = oy
		while ty < ey:
			var ctr := Vector2((float(tx) + CELL_W * 0.5) * _tsize.x - 18.0,
				(float(ty) + CELL_H * 0.5) * _tsize.y + 8.0)
			draw_string(font, ctr, "%d%s" % [ci, _row_letter(ri)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.33))
			ty += CELL_H; ri += 1
		tx += CELL_W; ci += 1

	# Movable pieces — boxed + numbered.
	for i in range(_pieces.size()):
		var p = _pieces[i]
		var col := Color(1, 0.85, 0.2) if p["kind"] == "plank" else Color(0.5, 0.8, 1.0)
		var tl := Vector2(p["mn"]) * _tsize
		var br := (Vector2(p["mx"]) + Vector2.ONE) * _tsize
		draw_rect(Rect2(tl, br - tl), col, false, 3.0)
		draw_string(font, Vector2((tl.x + br.x) * 0.5 - 20.0, tl.y - 8.0),
			"#%d" % i, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, col)
	# Floor crate boxes (B#) and plank boards (P#).
	_draw_floor_series(font, _boxes, "B", Color(0.4, 0.95, 1.0))
	_draw_floor_series(font, _planks, "P", Color(1, 0.62, 0.2))


func _draw_floor_series(font: Font, list: Array, prefix: String, col: Color) -> void:
	for i in range(list.size()):
		var e = list[i]
		var cx := (float(e["mn_x"]) + float(e["mx_x"]) + 1.0) * 0.5 * _tsize.x
		var y := float(e["top_y"]) * _tsize.y
		draw_string(font, Vector2(cx - 22.0, y - 6.0),
			"%s%d" % [prefix, i], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)


func _row_letter(idx: int) -> String:
	return String.chr(65 + (idx % 26))
