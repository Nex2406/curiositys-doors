extends SceneTree

# Try candidate NEW platform variants by extracting clean sub-pieces / different
# materials from Advika's existing modules, and stamp them isolated in a test
# strip so we can screenshot which look good. Clears prior test stamps first.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const FLOOR_TOP := 40
const CLEAR_FROM_COL := 130

# Candidate variants: [name, src_bbox [c0,r0,c1,r1], dest_col, dest_row].
const CANDIDATES := [
	["narrow-step",   [104, 34, 108, 35], 190, 34],   # one segment of the long ledge
	["mid-step",      [109, 34, 114, 35], 205, 34],   # next segment (different caps)
	["wood-plank",    [49, 33, 60, 33],   222, 33],   # pillar's plank top, 1 row (wood)
	["tall-column",   [73, 25, 76, 30],   240, 28],   # left slice of the tall structure
	["short-narrow",  [12, 33, 16, 34],   252, 34],   # left half of the short ledge
]


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	var cells := {}
	for i in range(n):
		var off := 2 + i * CELL
		cells[Vector2i(data.decode_s16(off), data.decode_s16(off + 2))] = data.slice(off, off + CELL)

	for key in cells.keys():
		if key.y < FLOOR_TOP and key.x >= CLEAR_FROM_COL:
			cells.erase(key)

	for cand in CANDIDATES:
		var b = cand[1]
		var dc: int = cand[2]
		var dr: int = cand[3]
		for col in range(b[0], b[2] + 1):
			for row in range(b[1], b[3] + 1):
				var src := Vector2i(col, row)
				if not cells.has(src):
					continue
				var pos := Vector2i(dc + (col - b[0]), dr + (row - b[1]))
				var c: PackedByteArray = (cells[src] as PackedByteArray).duplicate()
				c.encode_s16(0, pos.x)
				c.encode_s16(2, pos.y)
				cells[pos] = c

	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, 0)
	for key in cells:
		out.append_array(cells[key])
	var new_text := text.substr(0, start) + Marshalls.raw_to_base64(out) + text.substr(ce)
	var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w.store_string(new_text)
	w.close()
	print("placed %d candidate variants" % CANDIDATES.size())
	quit()
