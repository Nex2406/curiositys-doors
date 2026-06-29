extends SceneTree

# Build NEW platform elements by COMBINING Advika's existing pieces (verbatim
# tiles, so everything stays clean): ledges + wood posts + the brazier. Places
# each combo in a test strip so we can screenshot which work.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const FLOOR_TOP := 40
const CLEAR_FROM_COL := 130

# Source pieces (absolute bbox in her painted modules):
#   LEDGE_A = [12,33,21,34]   short stone ledge
#   LEDGE_B = [25,29,35,30]   medium stone ledge
#   LEDGE_C = [104,34,123,35] long stone ledge
#   POST    = [49,34,51,39]   3-wide wood frame column (from the pillar side)
#   BRAZIER = [52,34,57,38]   glowing coal core (from the pillar centre)
#
# Combo = [name, dest_col, dest_row, [ [src_bbox, off_col, off_row], ... ] ]
const COMBOS := [
	["stem-platform", 188, 30, [
		[[12, 33, 21, 34], 0, 0],
		[[49, 34, 51, 39], 3, 2],
	]],
	["tower", 212, 26, [
		[[25, 29, 35, 30], 0, 0],
		[[12, 33, 21, 34], 1, 5],
	]],
	["arch", 238, 27, [
		[[104, 34, 123, 35], 0, 0],
		[[49, 34, 51, 39], 1, 2],
		[[49, 34, 51, 39], 16, 2],
	]],
	["brazier-ledge", 282, 32, [
		[[12, 33, 21, 34], 0, 3],
		[[52, 34, 57, 38], 3, -2],
	]],
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

	for combo in COMBOS:
		var dc: int = combo[1]
		var dr: int = combo[2]
		for piece in combo[3]:
			var b = piece[0]
			var pc: int = piece[1]
			var pr: int = piece[2]
			for col in range(b[0], b[2] + 1):
				for row in range(b[1], b[3] + 1):
					var src := Vector2i(col, row)
					if not cells.has(src):
						continue
					var pos := Vector2i(dc + pc + (col - b[0]), dr + pr + (row - b[1]))
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
	print("placed %d combos" % COMBOS.size())
	quit()
