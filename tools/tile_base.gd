extends SceneTree

# Tile the hand-built base (cols 0..BASE_W-1) across the whole level, discarding
# everything past it (the old auto-duplicate placeholder). Writes the new blob
# back into the .tscn surgically. Flat-topped base => seamless by construction.
#
# Run: godot --headless --script res://tools/tile_base.gd -- <copies>

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const BASE_W := 192


func _init() -> void:
	var copies := 5
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		copies = maxi(1, args[0].to_int())

	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	# Snapshot only the base columns (0 .. BASE_W-1).
	var base: Array = []
	for i in range(n):
		var off := 2 + i * CELL
		if data.decode_s16(off) < BASE_W:
			base.append(data.slice(off, off + CELL))
	print("base cells (cols 0..%d): %d" % [BASE_W - 1, base.size()])

	# Rebuild: header + base tiled `copies` times, shifted right by BASE_W each.
	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, 0)
	for copy in range(copies):
		var dx := BASE_W * copy
		for cell in base:
			var c: PackedByteArray = (cell as PackedByteArray).duplicate()
			c.encode_s16(0, c.decode_s16(0) + dx)
			out.append_array(c)

	var new_b64 := Marshalls.raw_to_base64(out)
	var new_text := text.substr(0, start) + new_b64 + text.substr(ce)
	var w := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w.store_string(new_text)
	w.close()
	print("tiled: %d copies -> %d cols, %d cells (was %d)" % [
		copies, BASE_W * copies, base.size() * copies, n])
	quit()
