extends Node

# Shift ONLY the ground terrain (the big connected floor mass + its fused structures/crates)
# down SHIFT tiles, leaving the floating planks where they are — so more of the painted
# backdrop is exposed above the floor. Surgically rewrites tile_map_data (no re-pack).

const PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const SHIFT := 5                 # tiles down
const FLOOR_MIN_CELLS := 150
const FLOOR_MIN_W := 45


func _ready() -> void:
	var inst: Node = load(PATH).instantiate()
	var ct: TileMapLayer = inst.get_node("TileMapLayer")

	# Connected components of the painted cells; the big/wide ones are the ground.
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

	# Snapshot each ground cell, erase them all, then re-stamp SHIFT rows lower.
	var data := {}
	for c in floor.keys():
		data[c] = [ct.get_cell_source_id(c), ct.get_cell_atlas_coords(c), ct.get_cell_alternative_tile(c)]
	for c in floor.keys():
		ct.erase_cell(c)
	for c in floor.keys():
		var d = data[c]
		ct.set_cell(c + Vector2i(0, SHIFT), d[0], d[1], d[2])

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
		print("SHIFTED ground cells=", floor.size(), " down ", SHIFT, " tiles  b64_len=", b64.length())
	print("SHIFT_DONE")
	get_tree().quit()
