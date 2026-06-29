extends SceneTree

# Compare the original LEFT-half design against the duplicated RIGHT half
# (offset +472). Reports above-floor cells that differ, so we can see exactly
# what was hand-edited in one half and propagate it to the other. Read-only.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const FLOOR_TOP := 40
const OFFSET := 472
const SPLIT := 465   # cols < SPLIT = left/original, >= SPLIT = right/copy


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	var left := {}   # Vector2i(col,row) -> "atlasx,atlasy,alt"
	var right := {}  # keyed in LEFT coords (col-OFFSET)
	for i in range(n):
		var off := 2 + i * CELL
		var x := data.decode_s16(off)
		var y := data.decode_s16(off + 2)
		if y >= FLOOR_TOP:
			continue
		var sig := "%d,%d,%d" % [data.decode_u16(off + 6), data.decode_u16(off + 8), data.decode_u16(off + 10)]
		if x < SPLIT:
			left[Vector2i(x, y)] = sig
		else:
			right[Vector2i(x - OFFSET, y)] = sig

	# Compare.
	var only_left := []    # in original, missing/changed in copy
	var only_right := []   # in copy, missing in original
	var changed := []
	for k in left:
		if not right.has(k):
			only_left.append(k)
		elif right[k] != left[k]:
			changed.append(k)
	for k in right:
		if not left.has(k):
			only_right.append(k)

	print("left(orig) above-floor cells: %d   right(copy): %d" % [left.size(), right.size()])
	print("--- in ORIGINAL but not matching COPY: %d cells ---" % only_left.size())
	_summarise(only_left)
	print("--- in COPY but not in ORIGINAL: %d cells ---" % only_right.size())
	_summarise(only_right)
	print("--- present in both but DIFFERENT tile: %d cells ---" % changed.size())
	_summarise(changed)
	quit()


# Print bounding columns/rows of a cell list so the divergent region is obvious.
func _summarise(cells: Array) -> void:
	if cells.is_empty():
		return
	var mnx := 1 << 30; var mxx := -(1 << 30); var mny := 1 << 30; var mxy := -(1 << 30)
	var cols := {}
	for c in cells:
		mnx = mini(mnx, c.x); mxx = maxi(mxx, c.x)
		mny = mini(mny, c.y); mxy = maxi(mxy, c.y)
		cols[c.x] = true
	var collist := cols.keys()
	collist.sort()
	print("    cols %d..%d  rows %d..%d   (distinct cols: %s)" % [mnx, mxx, mny, mxy, str(collist)])
