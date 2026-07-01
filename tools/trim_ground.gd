extends Node

# Trim the ground to a slim band: keep KEEP rows from the ground surface down, remove the
# thick lower cobble beneath it (so the floor reads as a strip with backdrop below).
# Structures above the surface (towers) are kept. Surgical tile_map_data rewrite.

const PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const KEEP := 3                  # ground rows to keep below the surface row
const FLOOR_MIN_CELLS := 150
const FLOOR_MIN_W := 45


func _ready() -> void:
	var ct: TileMapLayer = load(PATH).instantiate().get_node("TileMapLayer")

	# Floor = the big connected component(s).
	var cells := {}
	for c in ct.get_used_cells():
		cells[c] = true
	var seen := {}
	var floor := {}
	for start in cells.keys():
		if seen.has(start):
			continue
		var stack: Array = [start]
		var group: Array = []
		var mnx: int = 1 << 30
		var mxx: int = -(1 << 30)
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			if seen.has(c) or not cells.has(c):
				continue
			seen[c] = true
			group.append(c)
			mnx = mini(mnx, c.x); mxx = maxi(mxx, c.x)
			stack.append(c + Vector2i(1, 0)); stack.append(c + Vector2i(-1, 0))
			stack.append(c + Vector2i(0, 1)); stack.append(c + Vector2i(0, -1))
		if group.size() >= FLOOR_MIN_CELLS or (mxx - mnx + 1) >= FLOOR_MIN_W:
			for c in group:
				floor[c] = true

	# Ground surface row = the most common topmost floor row across columns.
	var top := {}
	for c in floor.keys():
		if not top.has(c.x) or c.y < top[c.x]:
			top[c.x] = c.y
	var freq := {}
	for x in top.keys():
		freq[top[x]] = freq.get(top[x], 0) + 1
	var surface := 0
	var best := -1
	for y in freq.keys():
		if freq[y] > best:
			best = freq[y]; surface = y
	var cutoff := surface + KEEP    # remove floor cells at this row or deeper

	var removed := 0
	for c in floor.keys():
		if c.y >= cutoff:
			ct.erase_cell(c)
			removed += 1
	print("surface_row=", surface, " cutoff=", cutoff, " removed=", removed)

	var b64 := Marshalls.raw_to_base64(ct.tile_map_data)
	var fr := FileAccess.open(PATH, FileAccess.READ)
	var text := fr.get_as_text()
	fr.close()
	var re := RegEx.new()
	re.compile("tile_map_data = PackedByteArray\\(\"[^\"]*\"\\)")
	var out := re.sub(text, "tile_map_data = PackedByteArray(\"" + b64 + "\")")
	if out == text:
		print("ERROR: tile_map_data not found")
	else:
		var fw := FileAccess.open(PATH, FileAccess.WRITE)
		fw.store_string(out)
		fw.close()
		print("TRIM ok b64_len=", b64.length())
	print("TRIM_DONE")
	get_tree().quit()
