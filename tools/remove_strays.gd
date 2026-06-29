extends SceneTree

# Surgically remove the 2 stray below-floor tiles (col 395/396, row 57) from
# Realm1.tscn's painted tile_map_data — nothing else in the scene is touched.
# These junk cells dragged get_used_rect() 10 rows below the floor, which pushed
# the camera's bottom limit down and made the floor look like a floating shelf
# over water. Removing them pins the floor to the bottom of the view.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const STRAYS := [Vector2i(395, 57), Vector2i(396, 57)]


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var b64 := text.substr(start, ce - start)
	var data := Marshalls.base64_to_raw(b64)
	var n := (data.size() - 2) / CELL

	var out := PackedByteArray()
	out.append_array(data.slice(0, 2))  # preserve 2-byte format header
	var removed := 0
	for i in range(n):
		var off := 2 + i * CELL
		var cell := Vector2i(data.decode_s16(off), data.decode_s16(off + 2))
		if cell in STRAYS:
			removed += 1
			continue
		out.append_array(data.slice(off, off + CELL))

	var new_b64 := Marshalls.raw_to_base64(out)
	var new_text := text.substr(0, start) + new_b64 + text.substr(ce)
	var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w.store_string(new_text)
	w.close()
	print("removed %d stray cell(s); cells %d -> %d" % [removed, n, (out.size() - 2) / CELL])
	quit()
