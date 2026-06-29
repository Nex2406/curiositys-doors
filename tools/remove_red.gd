extends SceneTree

# Remove the red glowing ember (atlas 40-41 x 49-50) everywhere by replacing each
# red-core cell with the rubble tile directly above it, so the cage/crate stays
# solid with no hole — just no glow. Surgical: only red-core cells change.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const RED := {Vector2i(40, 49): true, Vector2i(41, 49): true, Vector2i(40, 50): true, Vector2i(41, 50): true}


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	# pos -> bytes; and quick atlas lookup.
	var cells := {}
	for i in range(n):
		var off := 2 + i * CELL
		cells[Vector2i(data.decode_s16(off), data.decode_s16(off + 2))] = data.slice(off, off + CELL)

	var reds := []
	for pos in cells:
		var c: PackedByteArray = cells[pos]
		if RED.has(Vector2i(c.decode_u16(6), c.decode_u16(8))):
			reds.append(pos)

	var fixed := 0
	var deleted := 0
	for pos in reds:
		# Walk upward to the first non-red rubble tile and copy its atlas.
		var src := Vector2i(pos.x, pos.y - 1)
		var fill: PackedByteArray = PackedByteArray()
		while cells.has(src):
			var sc: PackedByteArray = cells[src]
			if not RED.has(Vector2i(sc.decode_u16(6), sc.decode_u16(8))):
				fill = sc
				break
			src.y -= 1
		if fill.is_empty():
			cells.erase(pos)   # nothing above to borrow → just drop it
			deleted += 1
			continue
		var c: PackedByteArray = (cells[pos] as PackedByteArray).duplicate()
		c.encode_u16(6, fill.decode_u16(6))   # atlas x
		c.encode_u16(8, fill.decode_u16(8))   # atlas y
		c.encode_u16(10, fill.decode_u16(10)) # alt flags
		cells[pos] = c
		fixed += 1

	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, 0)
	for key in cells:
		out.append_array(cells[key])
	var new_text := text.substr(0, start) + Marshalls.raw_to_base64(out) + text.substr(ce)
	var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w.store_string(new_text)
	w.close()
	print("red-core cells: %d  -> rubble-filled: %d  deleted: %d" % [reds.size(), fixed, deleted])
	quit()
