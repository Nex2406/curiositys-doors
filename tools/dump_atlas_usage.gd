extends SceneTree

# List every distinct atlas tile used in the level with its usage count and the
# columns it appears at, so we can pin down "that red thing" and remove it
# everywhere. Read-only.

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

	var usage := {}  # "ax,ay" -> { count, mincol, maxcol, rows:{} }
	for i in range(n):
		var off := 2 + i * CELL
		var x := data.decode_s16(off)
		var y := data.decode_s16(off + 2)
		var ax := data.decode_u16(off + 6)
		var ay := data.decode_u16(off + 8)
		var key := "%d,%d" % [ax, ay]
		if not usage.has(key):
			usage[key] = {"count": 0, "mincol": 1 << 30, "maxcol": -(1 << 30), "rows": {}}
		var u = usage[key]
		u["count"] += 1
		u["mincol"] = mini(u["mincol"], x)
		u["maxcol"] = maxi(u["maxcol"], x)
		u["rows"][y] = true

	var keys := usage.keys()
	keys.sort_custom(func(a, b): return usage[a]["count"] < usage[b]["count"])
	print("distinct atlas tiles: %d" % keys.size())
	for k in keys:
		var u = usage[k]
		var rows: Array = u["rows"].keys(); rows.sort()
		print("atlas(%s)  count=%d  cols %d..%d  rows=%s" % [k, u["count"], u["mincol"], u["maxcol"], str(rows)])
	quit()
