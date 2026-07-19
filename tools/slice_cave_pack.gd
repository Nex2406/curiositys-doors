extends SceneTree
# Importer for the Maaot "Cave Assets" pack (Downloads/CaveAssetsMaaot.zip).
# Successor to slice_mossy_pack.gd for DENSE sheets: that tool crops plain
# rectangles, so on tightly-packed sheets a crop drags slivers of its
# neighbours along (and bbox-overlap merging chains separate rocks into one
# piece). This one:
#   - merges components only when their cell-masks actually TOUCH (1-cell
#     dilation), never by bounding-box proximity
#   - masks every pixel that belongs to a DIFFERENT component out of the
#     crop (2-cell dilation keeps each piece's own soft edges intact)
# No hue shift: the pack's neutral dark brown is used as-is — Realm 1's
# Crimson Hollow ambient does the warming in-scene.
#
# Usage:
#   godot --headless --script tools/slice_cave_pack.gd -- \
#       <sheet.png> <out_dir> <prefix>
#
# Output: <out_dir>/<prefix>_NN.png (numbered by top-to-bottom, left-to-right
# position in the sheet).

const ALPHA_MIN := 40        # a pixel counts as "occupied" above this alpha
const CELL := 4              # mask downsample factor for component labeling
const MIN_CELLS := 24        # components smaller than this are stray specks
const PAD := 6               # cells of padding around each crop
const KEEP_DILATE := 3       # cells — own-component halo kept when masking


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <sheet.png> <out_dir> <prefix>")
		quit(1)
		return
	var sheet := Image.load_from_file(args[0])
	if sheet == null:
		push_error("cannot load sheet: " + args[0])
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)

	var w := sheet.get_width()
	var h := sheet.get_height()
	var mw := (w + CELL - 1) / CELL
	var mh := (h + CELL - 1) / CELL
	var labels := _label_components(sheet, mw, mh)
	var group := _merge_touching(labels, mw, mh)
	var rects := _group_rects(labels, group, mw, mh, w, h)
	print("[slice] %d pieces after touch-merge" % rects.size())

	DirAccess.make_dir_recursive_absolute(args[1])
	var order := rects.keys()
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra: int = rects[a].position.y / 400
		var rb: int = rects[b].position.y / 400
		return ra < rb if ra != rb else rects[a].position.x < rects[b].position.x)
	var idx := 0
	for gid: int in order:
		var r: Rect2i = rects[gid]
		var crop := sheet.get_region(r)
		_mask_foreign(crop, r, labels, group, gid, mw, mh)
		var path := "%s/%s_%02d.png" % [args[1], args[2], idx]
		crop.save_png(path)
		print("[slice] %s  <- rect %s" % [path, r])
		idx += 1
	print("[slice] DONE")
	quit(0)


# Occupancy mask at 1/CELL resolution -> 4-neighbour connected components.
# Returns the label grid (0 = empty; components below MIN_CELLS are erased).
func _label_components(sheet: Image, mw: int, mh: int) -> PackedInt32Array:
	var w := sheet.get_width()
	var h := sheet.get_height()
	var data := sheet.get_data()
	var mask := PackedByteArray()
	mask.resize(mw * mh)
	for y in range(0, h, 2):
		var row := y * w
		var my := (y / CELL) * mw
		for x in range(0, w, 2):
			if data[(row + x) * 4 + 3] > ALPHA_MIN:
				mask[my + x / CELL] = 1
	var labels := PackedInt32Array()
	labels.resize(mw * mh)
	var next := 0
	var queue := PackedInt32Array()
	for start in mw * mh:
		if mask[start] == 0 or labels[start] != 0:
			continue
		next += 1
		var cells := PackedInt32Array()
		queue.clear()
		queue.append(start)
		labels[start] = next
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			cells.append(cur)
			var cx := cur % mw
			var cy := cur / mw
			for off in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var nx: int = cx + off[0]
				var ny: int = cy + off[1]
				if nx < 0 or ny < 0 or nx >= mw or ny >= mh:
					continue
				var ni := ny * mw + nx
				if mask[ni] == 1 and labels[ni] == 0:
					labels[ni] = next
					queue.append(ni)
		if cells.size() < MIN_CELLS:
			for c in cells:
				labels[c] = 0
	return labels


# Two components join one piece only if their masks share a cell EDGE —
# nearby-but-separate elements (the pack's thin ledge slats sit ~8px under
# the platform blocks) stay their own pieces.
# Returns group id per label (union-find, path-compressed into a flat map).
func _merge_touching(labels: PackedInt32Array, mw: int, mh: int) -> Dictionary:
	var parent: Dictionary = {}
	for i in mw * mh:
		var l := labels[i]
		if l != 0 and not parent.has(l):
			parent[l] = l
	for y in mh:
		for x in mw:
			var l := labels[y * mw + x]
			if l == 0:
				continue
			for off in [[1, 0], [0, 1]]:
				var nx: int = x + off[0]
				var ny: int = y + off[1]
				if nx >= mw or ny >= mh:
					continue
				var nl := labels[ny * mw + nx]
				if nl != 0 and nl != l:
					_union(parent, l, nl)
	var group: Dictionary = {}
	for l: int in parent.keys():
		group[l] = _find(parent, l)
	return group


func _find(parent: Dictionary, a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a


func _union(parent: Dictionary, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[rb] = ra


# Padded pixel bbox per group, clamped to the sheet.
func _group_rects(labels: PackedInt32Array, group: Dictionary,
		mw: int, mh: int, w: int, h: int) -> Dictionary:
	var boxes: Dictionary = {}
	for y in mh:
		for x in mw:
			var l := labels[y * mw + x]
			if l == 0:
				continue
			var g: int = group[l]
			var r := Rect2i(x, y, 1, 1)
			boxes[g] = r if not boxes.has(g) else (boxes[g] as Rect2i).merge(r)
	var rects: Dictionary = {}
	for g: int in boxes.keys():
		var b: Rect2i = boxes[g]
		var px := Rect2i(b.position.x * CELL, b.position.y * CELL,
				b.size.x * CELL, b.size.y * CELL)
		rects[g] = px.grow(PAD * CELL).intersection(Rect2i(0, 0, w, h))
	return rects


# Zero out crop pixels whose cell belongs to another group. Own-group cells
# are honoured with a KEEP_DILATE halo so soft painted edges survive.
func _mask_foreign(crop: Image, r: Rect2i, labels: PackedInt32Array,
		group: Dictionary, gid: int, mw: int, mh: int) -> void:
	var d := crop.get_data()
	var cw := crop.get_width()
	var ch := crop.get_height()
	for y in ch:
		for x in cw:
			var i := (y * cw + x) * 4
			if d[i + 3] == 0:
				continue
			var cx := (r.position.x + x) / CELL
			var cy := (r.position.y + y) / CELL
			var keep := false
			for dy in range(-KEEP_DILATE, KEEP_DILATE + 1):
				for dx in range(-KEEP_DILATE, KEEP_DILATE + 1):
					var nx := cx + dx
					var ny := cy + dy
					if nx < 0 or ny < 0 or nx >= mw or ny >= mh:
						continue
					var l := labels[ny * mw + nx]
					if l != 0 and group[l] == gid:
						keep = true
						break
				if keep:
					break
			if not keep:
				d[i + 3] = 0
	crop.set_data(cw, ch, false, Image.FORMAT_RGBA8, d)
