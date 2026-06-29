extends SceneTree

# Raise ONE specific plank (the col-484 ledge in the middle, group the hero stood
# on) by RAISE rows. Surgical: only cells inside SRC move; everything else is
# untouched. Idempotent — moves rows SRC->DEST, so a re-run finds SRC empty.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
# Source plank bounding box [col0, row0, col1, row1] inclusive (group 20).
const SRC := [484, 33, 493, 34]
const RAISE := 4   # rows up


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

	var moved := 0
	var to_move := []
	for key in cells:
		if key.x >= SRC[0] and key.x <= SRC[2] and key.y >= SRC[1] and key.y <= SRC[3]:
			to_move.append(key)
	for key in to_move:
		var dst := Vector2i(key.x, key.y - RAISE)
		var c: PackedByteArray = (cells[key] as PackedByteArray).duplicate()
		c.encode_s16(2, dst.y)
		cells.erase(key)
		cells[dst] = c
		moved += 1

	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, 0)
	for key in cells:
		out.append_array(cells[key])
	var new_text := text.substr(0, start) + Marshalls.raw_to_base64(out) + text.substr(ce)
	var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w.store_string(new_text)
	w.close()
	print("raised %d cells of plank %s by %d rows" % [moved, str(SRC), RAISE])
	quit()
