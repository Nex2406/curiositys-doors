extends SceneTree

# One-shot tool: lengthen Realm 1 by tiling its hand-painted geometry rightward.
#
# Works directly on the serialized TileMapLayer.tile_map_data blob in the .tscn
# (base64). It never instantiates the scene, so it doesn't drag in autoloads /
# scripts. Format (Godot 4 TileMapLayer): 2-byte uint16 header, then 12 bytes
# per cell: coord_x i16, coord_y i16, source_id u16, atlas_x u16, atlas_y u16,
# alternative u16 (all little-endian).
#
# Run (inspect):  godot --headless --script res://tools/extend_realm1.gd -- inspect
# Run (extend):   godot --headless --script res://tools/extend_realm1.gd -- 3

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "inspect"
	var copies := 3
	if args.size() > 0:
		if args[0] == "inspect":
			mode = "inspect"
		elif args[0].is_valid_int():
			mode = "extend"
			copies = maxi(2, args[0].to_int())

	var text := _read(SCENE_PATH)
	var b64 := _extract_blob(text)
	if b64 == "":
		push_error("tile_map_data not found")
		quit(1)
		return
	var data := Marshalls.base64_to_raw(b64)

	var n := (data.size() - 2) / CELL
	print("blob bytes=%d  header=%d  cells=%d  (len-2)%%12=%d" % [
		data.size(), data.decode_u16(0), n, (data.size() - 2) % CELL])

	# Min/max x over all cells (for width + sanity).
	var min_x := 1 << 30
	var max_x := -(1 << 30)
	for i in range(n):
		var off := 2 + i * CELL
		var x := data.decode_s16(off)
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
	print("x range: %d .. %d  (width=%d tiles)" % [min_x, max_x, max_x - min_x + 1])

	# Dump first 4 cells so we can eyeball the field layout.
	for i in range(mini(4, n)):
		var off := 2 + i * CELL
		print("  cell[%d] x=%d y=%d src=%d atlas=(%d,%d) alt=%d" % [
			i,
			data.decode_s16(off),
			data.decode_s16(off + 2),
			data.decode_u16(off + 4),
			data.decode_u16(off + 6),
			data.decode_u16(off + 8),
			data.decode_u16(off + 10),
		])

	if mode == "inspect":
		quit()
		return

	# ── extend ──────────────────────────────────────────────────────────────
	var width := max_x - min_x + 1
	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, data.decode_u16(0))  # keep original header
	# original cells first
	out.append_array(data.slice(2))
	# duplicated cells, each shifted right by width * copy
	for copy in range(1, copies):
		var dx := width * copy
		for i in range(n):
			var off := 2 + i * CELL
			var cell := data.slice(off, off + CELL)
			cell.encode_s16(0, data.decode_s16(off) + dx)
			out.append_array(cell)

	var new_b64 := Marshalls.raw_to_base64(out)
	var start := text.find(MARKER)
	var cs := start + MARKER.length()
	var ce := text.find("\"", cs)
	var new_text := text.substr(0, cs) + new_b64 + text.substr(ce)
	_write(SCENE_PATH, new_text)
	print("extend: width=%d  %dx  cells %d -> %d  bytes %d -> %d" % [
		width, copies, n, n * copies, data.size(), out.size()])
	quit()


func _read(p: String) -> String:
	var f := FileAccess.open(p, FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	return t


func _write(p: String, s: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(s)
	f.close()


func _extract_blob(text: String) -> String:
	var start := text.find(MARKER)
	if start == -1:
		return ""
	var cs := start + MARKER.length()
	var ce := text.find("\"", cs)
	return text.substr(cs, ce - cs)
