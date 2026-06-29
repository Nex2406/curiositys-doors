extends SceneTree

# ASCII occupancy map of the painted tiles (downsampled), to eyeball the layout.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL
	var cells := {}
	var minx := 1 << 30; var maxx := -(1 << 30); var miny := 1 << 30; var maxy := -(1 << 30)
	for i in range(n):
		var off := 2 + i * CELL
		var x := data.decode_s16(off); var y := data.decode_s16(off + 2)
		cells[Vector2i(x, y)] = true
		minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
	var w := maxx - minx + 1
	var step := maxi(1, int(ceil(w / 200.0)))
	print("cells=%d  cols %d..%d  rows %d..%d  (1 char=%d cols)" % [cells.size(), minx, maxx, miny, maxy, step])
	for ry in range(miny, maxy + 1):
		var line := ""
		var cx := minx
		while cx <= maxx:
			var any := false
			for sx in range(step):
				if cells.has(Vector2i(cx + sx, ry)):
					any = true; break
			line += "#" if any else "."
			cx += step
		print("%4d %s" % [ry, line])
	quit()
