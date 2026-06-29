extends SceneTree

# Extend Advika's floating-platform style: copy her hand-painted platform modules
# (exact tiles) and stamp them at new positions down the next stretch. Writes the
# new blob back into the .tscn surgically.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12

# Source modules by bounding box [col0, row0, col1, row1] (from dump_platforms).
const SOURCES := {
	"A": [12, 33, 21, 34],    # short stone ledge
	"B": [25, 29, 35, 30],    # medium stone ledge
	"C": [104, 34, 123, 35],  # long stone ledge
	"P": [49, 33, 60, 39],    # pillar + brazier accent
	"H": [73, 25, 91, 30],    # big tall structure
}

# Clear my own previous stamps (above-floor cells at/after this col) before
# re-stamping, so re-runs are idempotent and Advika's section (cols <130) is kept.
const CLEAR_FROM_COL := 130
const FLOOR_TOP := 40

# Placements: [module, dest_col, dest_row]. Empty for now — clearing my
# placeholder layout so Advika can paint new platform variants on a clean canvas.
# (Earlier varied layout kept in git history; re-add once the module set is set.)
const PLACEMENTS := []


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	# Index every existing cell by position (so stamps overwrite cleanly).
	var cells := {}  # Vector2i -> PackedByteArray(12)
	for i in range(n):
		var off := 2 + i * CELL
		cells[Vector2i(data.decode_s16(off), data.decode_s16(off + 2))] = data.slice(off, off + CELL)

	# Clear my own prior stamps so re-runs don't accumulate (keep Advika's <130).
	for key in cells.keys():
		if key.y < FLOOR_TOP and key.x >= CLEAR_FROM_COL:
			cells.erase(key)

	# Extract source module cells (above-floor cells inside each bbox).
	var modules := {}
	for name in SOURCES:
		var b = SOURCES[name]
		var list := []
		for col in range(b[0], b[2] + 1):
			for row in range(b[1], b[3] + 1):
				var key := Vector2i(col, row)
				if cells.has(key):
					list.append([Vector2i(col - b[0], row - b[1]), cells[key]])
		modules[name] = list

	# Stamp each placement.
	var added := 0
	for pl in PLACEMENTS:
		var mod = modules[pl[0]]
		var dest := Vector2i(pl[1], pl[2])
		for entry in mod:
			var rel: Vector2i = entry[0]
			var pos := dest + rel
			var c: PackedByteArray = (entry[1] as PackedByteArray).duplicate()
			c.encode_s16(0, pos.x)
			c.encode_s16(2, pos.y)
			cells[pos] = c
			added += 1

	# Rebuild blob.
	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, 0)
	for key in cells:
		out.append_array(cells[key])

	var new_b64 := Marshalls.raw_to_base64(out)
	var new_text := text.substr(0, start) + new_b64 + text.substr(ce)
	var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w.store_string(new_text)
	w.close()
	print("stamped %d placements, +%d cells -> %d total" % [PLACEMENTS.size(), added, cells.size()])
	quit()
