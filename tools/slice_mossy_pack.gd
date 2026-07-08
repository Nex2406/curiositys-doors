extends SceneTree
# One-off importer for the "Mossy Assets" pack (Downloads/Mossy Assets.zip).
# Slices a sprite sheet into its separate elements (connected alpha regions),
# hue-shifts the pack's green into the realm's violet, and writes each element
# to its own PNG. The hue delta is MEASURED, not guessed: pass a reference
# pair — an already-shipped violet asset and its green pack sibling — and the
# tool rotates every sliced element by the same hue distance, so new pieces
# land in exactly the palette the shipped realm2_moss assets already use.
#
# Usage:
#   godot --headless --script tools/slice_mossy_pack.gd -- \
#       <sheet.png> <out_dir> <prefix> [<ref_violet.png> <ref_green.png>]
#
# Output: <out_dir>/<prefix>_NN.png (numbered by top-to-bottom, left-to-right
# position in the sheet). Rename to semantic names before wiring into scenes.

const ALPHA_MIN := 40        # a pixel counts as "occupied" above this alpha
const CELL := 8              # mask downsample factor for component labeling
const MIN_CELLS := 10        # components smaller than this are stray specks
const PAD := 3               # cells of padding around each crop (applied LAST)
const MERGE_GAP := 4         # px — merge rects closer than this (split elements)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <sheet.png> <out_dir> <prefix> [ref_violet ref_green]")
		quit(1)
		return
	var sheet := Image.load_from_file(args[0])
	if sheet == null:
		push_error("cannot load sheet: " + args[0])
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)

	var hue_delta := 0.0
	var sat_scale := 1.0
	if args.size() >= 5:
		var violet := Image.load_from_file(args[3])
		var green := Image.load_from_file(args[4])
		if violet == null or green == null:
			push_error("cannot load reference images")
			quit(1)
			return
		var hv := _mean_hue_sat(violet)
		var hg := _mean_hue_sat(green)
		hue_delta = wrapf(hv.x - hg.x, -0.5, 0.5)
		sat_scale = hv.y / maxf(hg.y, 0.01)
		print("[slice] measured hue_delta=%.3f (%.0f deg)  sat_scale=%.2f" %
				[hue_delta, hue_delta * 360.0, sat_scale])

	var rects := _find_elements(sheet)
	print("[slice] %d elements found" % rects.size())
	DirAccess.make_dir_recursive_absolute(args[1])
	var idx := 0
	for r in rects:
		var crop := sheet.get_region(r)
		if hue_delta != 0.0 or sat_scale != 1.0:
			_shift_hue(crop, hue_delta, sat_scale)
		var path := "%s/%s_%02d.png" % [args[1], args[2], idx]
		crop.save_png(path)
		print("[slice] %s  <- rect %s" % [path, r])
		idx += 1
	print("[slice] DONE")
	quit(0)


# Circular mean of hue (weighted by sat*alpha) + mean saturation of an image.
func _mean_hue_sat(img: Image) -> Vector2:
	img.convert(Image.FORMAT_RGBA8)
	var d := img.get_data()
	var sx := 0.0
	var sy := 0.0
	var sat_sum := 0.0
	var n := 0.0
	for i in range(0, d.size(), 16):  # every 4th pixel is plenty for a mean
		var a := d[i + 3]
		if a < 128:
			continue
		var c := Color8(d[i], d[i + 1], d[i + 2])
		if c.s < 0.15 or c.v < 0.10:
			continue  # near-black bases / grey pixels carry no hue signal
		var w := c.s * (a / 255.0)
		sx += cos(c.h * TAU) * w
		sy += sin(c.h * TAU) * w
		sat_sum += c.s
		n += 1.0
	if n == 0.0:
		return Vector2.ZERO
	var hue := atan2(sy, sx) / TAU
	if hue < 0.0:
		hue += 1.0
	return Vector2(hue, sat_sum / n)


func _find_elements(sheet: Image) -> Array[Rect2i]:
	var w := sheet.get_width()
	var h := sheet.get_height()
	var data := sheet.get_data()
	var mw := (w + CELL - 1) / CELL
	var mh := (h + CELL - 1) / CELL
	var mask := PackedByteArray()
	mask.resize(mw * mh)
	# occupancy mask at 1/CELL resolution (stride-2 scan inside each cell)
	for y in range(0, h, 2):
		var row := y * w
		var my := (y / CELL) * mw
		for x in range(0, w, 2):
			if data[(row + x) * 4 + 3] > ALPHA_MIN:
				mask[my + x / CELL] = 1
	# label connected components (4-neighbour BFS)
	var labels := PackedInt32Array()
	labels.resize(mw * mh)
	var boxes: Array[Rect2i] = []
	var counts: Array[int] = []
	var next := 0
	var queue := PackedInt32Array()
	for start in mw * mh:
		if mask[start] == 0 or labels[start] != 0:
			continue
		next += 1
		var minx := mw
		var miny := mh
		var maxx := 0
		var maxy := 0
		var cells := 0
		queue.clear()
		queue.append(start)
		labels[start] = next
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			cells += 1
			var cx := cur % mw
			var cy := cur / mw
			minx = mini(minx, cx)
			miny = mini(miny, cy)
			maxx = maxi(maxx, cx)
			maxy = maxi(maxy, cy)
			for off in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var nx: int = cx + off[0]
				var ny: int = cy + off[1]
				if nx < 0 or ny < 0 or nx >= mw or ny >= mh:
					continue
				var ni := ny * mw + nx
				if mask[ni] == 1 and labels[ni] == 0:
					labels[ni] = next
					queue.append(ni)
		if cells >= MIN_CELLS:
			boxes.append(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))
			counts.append(cells)
	# cells -> tight pixel rects (padding comes AFTER merging, or neighbouring
	# elements chain together through their pads and the whole sheet fuses)
	var rects: Array[Rect2i] = []
	for b in boxes:
		rects.append(Rect2i(b.position.x * CELL, b.position.y * CELL,
				b.size.x * CELL, b.size.y * CELL))
	print("[slice] %d components pre-merge" % rects.size())
	# merge rects whose gap is under MERGE_GAP (an element split by thin alpha)
	var merged := true
	while merged:
		merged = false
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if rects[i].grow(MERGE_GAP).intersects(rects[j]):
					rects[i] = rects[i].merge(rects[j])
					rects.remove_at(j)
					merged = true
					break
			if merged:
				break
	for i in rects.size():
		rects[i] = rects[i].grow(PAD * CELL).intersection(Rect2i(0, 0, w, h))
	# stable reading order: coarse rows first, then x
	rects.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		var ra := a.position.y / 400
		var rb := b.position.y / 400
		return ra < rb if ra != rb else a.position.x < b.position.x)
	return rects


func _shift_hue(img: Image, delta: float, sat_scale: float) -> void:
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		if d[i + 3] == 0:
			continue
		var c := Color8(d[i], d[i + 1], d[i + 2])
		if c.s < 0.05 or c.v < 0.03:
			continue  # keep blacks/greys untouched — outlines and shadow cores
		var out := Color.from_hsv(wrapf(c.h + delta, 0.0, 1.0),
				clampf(c.s * sat_scale, 0.0, 1.0), c.v)
		d[i] = int(out.r * 255.0)
		d[i + 1] = int(out.g * 255.0)
		d[i + 2] = int(out.b * 255.0)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
