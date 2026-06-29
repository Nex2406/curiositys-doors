extends SceneTree

# Lay out the whole Realm 1 platforming from Advika's 5 existing elements, with as
# much variety as 5 pieces allow: height random-walk, varied spacing, ledges as
# the staple and the pillar/tall-structure as periodic landmarks. Stamps verbatim
# copies of her tiles (so it looks like her hand). Seeded for reproducibility.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const FLOOR_TOP := 40
const CLEAR_FROM_COL := 130
const START_COL := 136
const END_COL := 935

# module -> [bbox, width]
const SOURCES := {
	"A": [[12, 33, 21, 34], 10],
	"B": [[25, 29, 35, 30], 11],
	"C": [[104, 34, 123, 35], 20],
	"P": [[49, 33, 60, 39], 12],
	"H": [[73, 25, 91, 30], 19],
}


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

	# The FLOOR is the main path — Curiosity walks on the ground. Platforms come in
	# occasional SECTIONS (a climb, some hops, a peak, a tower) separated by open
	# ground, so it's not wall-to-wall platforms. Varied section types + big gaps.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var placements := []
	var col := START_COL
	while col < END_COL - 60:
		col += rng.randi_range(36, 72)            # open ground — walk on the floor
		if col >= END_COL - 60:
			break
		match rng.randi_range(0, 3):
			0: col = _section_climb(placements, rng, col)
			1: col = _section_hops(placements, rng, col)
			2: col = _section_peak(placements, rng, col)
			_: col = _section_tower(placements, rng, col)

	# Stamp.
	for pl in placements:
		var b = SOURCES[pl[0]][0]
		var dc: int = pl[1]
		var dr: int = pl[2]
		for c0 in range(b[0], b[2] + 1):
			for r0 in range(b[1], b[3] + 1):
				var src := Vector2i(c0, r0)
				if not cells.has(src):
					continue
				var pos := Vector2i(dc + (c0 - b[0]), dr + (r0 - b[1]))
				var cc: PackedByteArray = (cells[src] as PackedByteArray).duplicate()
				cc.encode_s16(0, pos.x)
				cc.encode_s16(2, pos.y)
				cells[pos] = cc

	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, 0)
	for key in cells:
		out.append_array(cells[key])
	var new_text := text.substr(0, start) + Marshalls.raw_to_base64(out) + text.substr(ce)
	var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w.store_string(new_text)
	w.close()
	print("built level: %d platforms over cols %d..%d" % [placements.size(), START_COL, END_COL])
	quit()


# ── platform sections (each a small, localized cluster; floor is open between) ──

# A short irregular climb up to a higher ledge.
func _section_climb(pl: Array, rng: RandomNumberGenerator, col: int) -> int:
	var row := 35
	for _i in range(rng.randi_range(3, 4)):
		var m := "A" if rng.randf() < 0.6 else "B"
		pl.append([m, col, row])
		row = clampi(row - rng.randi_range(4, 7), 15, 36)
		col += SOURCES[m][1] + rng.randi_range(2, 7)
	return col


# A few platforms at varied heights spread across a stretch — hopping across.
func _section_hops(pl: Array, rng: RandomNumberGenerator, col: int) -> int:
	for _i in range(rng.randi_range(3, 4)):
		var m: String = ["A", "B", "C"][rng.randi_range(0, 2)]
		pl.append([m, col, rng.randi_range(28, 37)])
		col += SOURCES[m][1] + rng.randi_range(7, 15)
	return col


# One or two higher platforms to jump up to (good spot for jade later).
func _section_peak(pl: Array, rng: RandomNumberGenerator, col: int) -> int:
	var m := "B" if rng.randf() < 0.5 else "C"
	var row := rng.randi_range(21, 30)
	pl.append([m, col, row])
	col += SOURCES[m][1] + rng.randi_range(3, 9)
	if rng.randf() < 0.5:
		pl.append(["A", col, clampi(row - rng.randi_range(3, 6), 15, 34)])
		col += SOURCES["A"][1] + rng.randi_range(5, 11)
	return col


# A vertical tower reaching high, capped with the tall structure.
func _section_tower(pl: Array, rng: RandomNumberGenerator, col: int) -> int:
	var row := 34
	for _i in range(rng.randi_range(2, 3)):
		pl.append(["A", col, row])
		row = clampi(row - rng.randi_range(5, 7), 13, 33)
		col += rng.randi_range(3, 8)
	pl.append(["H", col, clampi(row - 2, 8, 27)])
	return col + SOURCES["H"][1] + rng.randi_range(5, 12)
