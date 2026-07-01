extends Node

# Bring the floating planks (every painted component that ISN'T the big ground mass) DOWN
# SHIFT tiles, so after the ground was lowered the jump distances are reachable again.
# Surgical tile_map_data rewrite.

const PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const SHIFT := -1   # nudge the planks back UP one tile (they ended up a touch low)
const FLOOR_MIN_CELLS := 150
const FLOOR_MIN_W := 45


func _ready() -> void:
	var ct: TileMapLayer = load(PATH).instantiate().get_node("TileMapLayer")

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

	# Everything that isn't ground = a floating plank. Shift those down.
	var movers := []
	for c in cells.keys():
		if not floor.has(c):
			movers.append(c)
	var data := {}
	for c in movers:
		data[c] = [ct.get_cell_source_id(c), ct.get_cell_atlas_coords(c), ct.get_cell_alternative_tile(c)]
	for c in movers:
		ct.erase_cell(c)
	for c in movers:
		var d = data[c]
		ct.set_cell(c + Vector2i(0, SHIFT), d[0], d[1], d[2])
	print("shifted planks cells=", movers.size(), " down ", SHIFT)

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
		print("PLANK_SHIFT ok b64_len=", b64.length())
	print("PLANK_SHIFT_DONE")
	get_tree().quit()
