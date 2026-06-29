extends SceneTree

# Copy Advika's hand-painted LEFT-half above-floor design (platforms + rock
# scenery) into the bare RIGHT half — same orientation, exact tiles, just shifted
# right. The floor (rows 40-47) already spans the full width, so this only adds
# optional platforming / scenery above it; it cannot break traversal.
#
# Idempotent: clears any prior copy (above-floor cells at col >= GUARD) before
# re-stamping, so re-runs don't accumulate. Advika's originals end at col 446, so
# GUARD=460 keeps everything she painted and only clears my stamps.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const FLOOR_TOP := 40     # rows < this are above-floor (platforms/rocks)
const OFFSET := 472       # columns to shift the copy right
const GUARD := 460        # clear/stamp boundary (keeps originals <= 446)


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	# Index every cell by position.
	var cells := {}  # Vector2i -> PackedByteArray(12)
	for i in range(n):
		var off := 2 + i * CELL
		cells[Vector2i(data.decode_s16(off), data.decode_s16(off + 2))] = data.slice(off, off + CELL)

	# Clear prior right-half stamps so re-runs are clean.
	for key in cells.keys():
		if key.y < FLOOR_TOP and key.x >= GUARD:
			cells.erase(key)

	# Collect the source = all above-floor originals (col < GUARD).
	var sources := []
	for key in cells.keys():
		if key.y < FLOOR_TOP and key.x < GUARD:
			sources.append(key)

	# Stamp a translated copy.
	var added := 0
	for key in sources:
		var dst := Vector2i(key.x + OFFSET, key.y)
		var c: PackedByteArray = (cells[key] as PackedByteArray).duplicate()
		c.encode_s16(0, dst.x)
		c.encode_s16(2, dst.y)
		cells[dst] = c
		added += 1

	# Rebuild blob (2-byte format header + cells).
	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, 0)
	for key in cells:
		out.append_array(cells[key])

	var new_text := text.substr(0, start) + Marshalls.raw_to_base64(out) + text.substr(ce)
	var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w.store_string(new_text)
	w.close()
	print("copied %d above-floor cells +%d cols -> %d total cells" % [added, OFFSET, cells.size()])
	quit()
