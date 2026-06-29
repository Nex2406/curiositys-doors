extends Node2D

# Number every movable piece (floating plank OR floating structure) so Advika can
# assign motion per piece by number. Reads the ORIGINAL tile components before the
# realm's _ready() extracts anything, draws a numbered box over each, and prints a
# reference table (number, kind, top-left cell, center world pos, tile size).

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"

# A component this big/wide is the painted floor+terrain, not a movable piece.
const FLOOR_MIN_CELLS := 150
const FLOOR_MIN_W := 45
const PLANK_MAX_H := 4

var _pieces: Array = []   # {mn, mx, kind}
var _tiles: TileMapLayer


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	_tiles = realm.get_node("TileMapLayer")
	# Components from the ORIGINAL cells (before extraction runs on add_child).
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
			continue   # the floor / main terrain
		var kind: String = "plank" if h <= PLANK_MAX_H else "structure"
		_pieces.append({"mn": mn, "mx": mx, "kind": kind})
	_pieces.sort_custom(func(a, b):
		var pa: Vector2i = a["mn"]; var pb: Vector2i = b["mn"]
		return (pa.x * 100000 + pa.y) < (pb.x * 100000 + pb.y))

	add_child(realm)              # now _ready() runs (extracts planks)
	await get_tree().process_frame
	await get_tree().process_frame
	queue_redraw()

	var tsize := Vector2(_tiles.tile_set.tile_size)
	print("PIECES=%d" % _pieces.size())
	for i in range(_pieces.size()):
		var p = _pieces[i]
		var center := _tiles.to_global((Vector2(p["mn"]) + Vector2(p["mx"]) + Vector2.ONE) * 0.5 * tsize)
		print("#%d  %s  topleft_cell=%s  center_world=(%d,%d)" % [
			i, p["kind"], str(p["mn"]), int(center.x), int(center.y)])

	# Render the left portion (where Advika is) big enough to read the numbers.
	var cam := Camera2D.new()
	add_child(cam)
	cam.global_position = Vector2(90.0 * tsize.x, 34.0 * tsize.y)
	cam.zoom = Vector2(0.5, 0.5)
	cam.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/pieces.png")
	print("PIECES_DONE")
	get_tree().quit()


func _draw() -> void:
	if _tiles == null:
		return
	var tsize := Vector2(_tiles.tile_set.tile_size)
	var font := ThemeDB.fallback_font
	for i in range(_pieces.size()):
		var p = _pieces[i]
		var col := Color(1, 0.3, 0.3) if p["kind"] == "plank" else Color(0.4, 0.8, 1.0)
		var tl := _tiles.to_global(Vector2(p["mn"]) * tsize)
		var br := _tiles.to_global((Vector2(p["mx"]) + Vector2.ONE) * tsize)
		draw_rect(Rect2(tl, br - tl), col, false, 2.0)
		var label_pos := Vector2((tl.x + br.x) * 0.5 - 14.0, tl.y - 6.0)
		draw_string(font, label_pos, "#%d" % i, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)
