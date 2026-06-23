extends SceneTree

# Audit Realm 1's tile grid for disruptions: floor holes, surface-height steps,
# orphan/floating tiles, and mismatches between the tiled segments. Read-only —
# prints a report; fixes are decided from it.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const SEG_W := 192  # base segment width


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	var cols := {}        # x -> sorted-ish info: count, top, bottom, set of y
	var col_cells := {}   # x -> Dictionary{y: "src:ax:ay:alt"} for segment compare
	var max_x := 0
	var min_y := 1 << 30
	var max_y := -(1 << 30)
	for i in range(n):
		var off := 2 + i * CELL
		var x := data.decode_s16(off)
		var y := data.decode_s16(off + 2)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)
		if not cols.has(x):
			cols[x] = {"count": 0, "top": 1 << 30, "bot": -(1 << 30), "ys": {}}
			col_cells[x] = {}
		cols[x].count += 1
		cols[x].top = mini(cols[x].top, y)
		cols[x].bot = maxi(cols[x].bot, y)
		cols[x].ys[y] = true
		var key := "%d:%d:%d:%d" % [data.decode_u16(off + 4), data.decode_u16(off + 6), data.decode_u16(off + 8), data.decode_u16(off + 10)]
		col_cells[x][y] = key

	print("=== EXTENT ===")
	print("cells=%d  cols 0..%d  y %d..%d" % [n, max_x, min_y, max_y])

	# 1) HOLES — columns in 0..max_x with no tiles at all.
	print("\n=== HOLES (empty columns) ===")
	var holes := []
	for x in range(max_x + 1):
		if not cols.has(x):
			holes.append(x)
	print(_ranges(holes) if holes.size() > 0 else "  none")

	# 2) SURFACE STEPS — where the top tile jumps vs the previous column.
	print("\n=== SURFACE STEPS (top-y change >= 1) ===")
	var prev_top := -9999
	var steps := []
	for x in range(max_x + 1):
		if not cols.has(x):
			prev_top = -9999
			continue
		var t = cols[x].top
		if prev_top != -9999 and t != prev_top:
			steps.append("x=%d: %d -> %d (%+d)" % [x, prev_top, t, t - prev_top])
		prev_top = t
	if steps.size() == 0:
		print("  none — surface is perfectly flat")
	else:
		for s in steps:
			print("  " + s)

	# 3) INTERNAL GAPS — columns whose tiles aren't a solid run top..bot.
	print("\n=== COLUMNS WITH INTERNAL GAPS (non-solid stack) ===")
	var gappy := []
	for x in cols.keys():
		var c = cols[x]
		var span: int = int(c.bot) - int(c.top) + 1
		if int(c.count) != span:
			gappy.append(x)
	gappy.sort()
	print(_ranges(gappy) if gappy.size() > 0 else "  none")

	# 4) SEGMENT EQUALITY — compare each segment to segment 0 cell-for-cell.
	print("\n=== SEGMENT MISMATCHES (vs segment 0) ===")
	var n_segs := (max_x + 1 + SEG_W - 1) / SEG_W
	for seg in range(1, n_segs):
		var diff := 0
		var sample := []
		for lx in range(SEG_W):
			var x0 := lx
			var xs := seg * SEG_W + lx
			var a = col_cells.get(x0, {})
			var b = col_cells.get(xs, {})
			if not _same_col(a, b):
				diff += 1
				if sample.size() < 6:
					sample.append(xs)
		print("  seg %d (cols %d..%d): %d/%d columns differ %s" % [
			seg, seg * SEG_W, seg * SEG_W + SEG_W - 1, diff, SEG_W,
			("e.g. " + str(sample)) if diff > 0 else ""])
	quit()


func _same_col(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for y in a.keys():
		if not b.has(y) or b[y] != a[y]:
			return false
	return true


func _ranges(xs: Array) -> String:
	if xs.size() == 0:
		return "  none"
	xs.sort()
	var out := ""
	var s = xs[0]
	var p = xs[0]
	for i in range(1, xs.size()):
		if xs[i] == p + 1:
			p = xs[i]
		else:
			out += ("  %d" % s) if s == p else ("  %d-%d" % [s, p])
			s = xs[i]
			p = xs[i]
	out += ("  %d" % s) if s == p else ("  %d-%d" % [s, p])
	return out
