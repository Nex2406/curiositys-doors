extends SceneTree

# Place Advika's 6 elements as ONE coherent, evenly-spaced path: consistent gaps,
# all platforms in a sensible reachable height band (gentle wave, no random highs),
# mostly ledges with the structures as occasional grounded anchors. Preserves her
# painted section (cols < 195). Stamps verbatim copies of her tiles.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const FLOOR_TOP := 40
const CLEAR_FROM_COL := 195

const SOURCES := {
	"sh": [12, 33, 21, 34],    # short ledge
	"md": [25, 29, 35, 30],    # medium ledge
	"br": [49, 33, 60, 39],    # brazier pillar
	"bg": [73, 25, 91, 30],    # bridge
	"lg": [104, 34, 123, 35],  # long ledge
	"st": [168, 32, 188, 39],  # stepped structure
}
# Structures sit just above the floor (so they read as grounded supports, tops in
# the same band as the ledges).
const STRUCT_BASE := {"br": 33, "bg": 34, "st": 32}
const LEDGES := ["sh", "md", "lg"]
const GAP := 24          # consistent empty space between platforms (cols)
const START := 212
const END := 905


func _init() -> void:
	# Build a REACHABLE jump-chain: each platform within Curiosity's jump of the
	# previous one. Ledges vary in height but stay in a band that's off the floor
	# (row <= 35) and not too high (row >= 25); climbs are done as little step
	# formations (a couple of tight upward hops), and the horizontal gap tightens
	# as the climb gets taller so the jump is always makeable. Boxes stay grounded.
	# Jump clears ~8 tiles up and ~16 across (less when also going up).
	const MIN_ROW := 25     # highest a ledge goes (15 above floor)
	const MAX_ROW := 35     # lowest a ledge goes (5 above floor — never on it)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var placements := []
	var col := START
	var i := 0
	var row := 33           # first ledge: reachable from the floor
	while false:            # DISABLED — Advika builds the layout, not me
		var e: String
		var place_row: int
		if i % 6 == 5:
			e = ["br", "bg", "st"][int(i / 6) % 3]   # grounded box anchor
			place_row = STRUCT_BASE[e]
		else:
			e = LEDGES[i % LEDGES.size()]
			place_row = row
		placements.append([e, col, place_row])

		# Pick the NEXT height, reachable from the one just placed (<= 8 up).
		var roll := rng.randf()
		var delta: int
		if roll < 0.32:
			delta = -rng.randi_range(5, 8)           # climb (a step up)
		elif roll < 0.62:
			delta = rng.randi_range(4, 8)            # drop down
		else:
			delta = rng.randi_range(-3, 3)           # gentle wander
		var next_row := clampi(place_row + delta, MIN_ROW, MAX_ROW)
		# Tighten the gap when climbing so the up-jump is makeable; looser on drops.
		var gap: int
		if next_row < place_row:
			gap = rng.randi_range(4, maxi(5, 12 - (place_row - next_row)))
		else:
			gap = rng.randi_range(11, 16)
		row = next_row
		col += _width(e) + gap
		i += 1

	# Stamp.
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	var cells := {}
	for j in range(n):
		var off := 2 + j * CELL
		cells[Vector2i(data.decode_s16(off), data.decode_s16(off + 2))] = data.slice(off, off + CELL)
	for key in cells.keys():
		if key.y < FLOOR_TOP and key.x >= CLEAR_FROM_COL:
			cells.erase(key)

	for pl in placements:
		var b = SOURCES[pl[0]]
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
	print("placed %d evenly-spaced elements (cols 195+) — your section kept" % placements.size())
	quit()


func _width(e: String) -> int:
	var b = SOURCES[e]
	return b[2] - b[0] + 1
