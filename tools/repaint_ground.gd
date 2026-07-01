extends Node

# Make Advika's new ground texture UNIFORM. She repainted the ground band (world rows
# 41..47) in cols 0..87 with a 2x2 checker of {(39,53),(40,53),(39,54),(40,54)}. This
# applies the exact same per-(col,row) pattern to the whole band across every column,
# touching only ground cells (atlas.y >= 43) so floor crates and structure bases
# (atlas.y < 43) are left untouched. Rewrites ONLY the tile_map_data property in the
# .tscn (surgical, no re-pack), so instanced children stay intact.

const PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const BAND_TOP := 41
const BAND_BOTTOM := 47
const GROUND_ATLAS_MIN_Y := 43   # atlas.y below this = crate/structure → leave alone


# Exact pattern taken from her clean region (cols 0..16), keyed by world row + column parity.
func _new_tile(col: int, row: int) -> Vector2i:
	var odd := (col % 2) != 0
	match row:
		41: return Vector2i(40, 53) if odd else Vector2i(39, 53)
		42: return Vector2i(40, 54) if odd else Vector2i(39, 54)
		43: return Vector2i(39, 53) if odd else Vector2i(40, 53)
		44: return Vector2i(39, 54) if odd else Vector2i(40, 54)
		45: return Vector2i(39, 53) if odd else Vector2i(40, 53)
		46: return Vector2i(39, 54) if odd else Vector2i(40, 54)
		47: return Vector2i(39, 53) if odd else Vector2i(40, 53)
	return Vector2i(-1, -1)


func _ready() -> void:
	var inst: Node = load(PATH).instantiate()
	var ct: TileMapLayer = inst.get_node("TileMapLayer")
	var ur := ct.get_used_rect()
	var changed := 0
	var skipped_struct := 0
	for col in range(ur.position.x, ur.position.x + ur.size.x):
		for row in range(BAND_TOP, BAND_BOTTOM + 1):
			var c := Vector2i(col, row)
			if ct.get_cell_source_id(c) == -1:
				continue
			if ct.get_cell_atlas_coords(c).y < GROUND_ATLAS_MIN_Y:
				skipped_struct += 1
				continue
			var nt := _new_tile(col, row)
			if nt.x == -1:
				continue
			if ct.get_cell_atlas_coords(c) != nt or ct.get_cell_alternative_tile(c) != 0:
				ct.set_cell(c, 0, nt, 0)
				changed += 1
	print("REPAINTED=", changed, "  skipped_struct/crate=", skipped_struct)

	var b64 := Marshalls.raw_to_base64(ct.tile_map_data)
	var fr := FileAccess.open(PATH, FileAccess.READ)
	var text := fr.get_as_text()
	fr.close()
	var re := RegEx.new()
	re.compile("tile_map_data = PackedByteArray\\(\"[^\"]*\"\\)")
	var repl := "tile_map_data = PackedByteArray(\"" + b64 + "\")"
	var out := re.sub(text, repl)
	if out == text:
		print("ERROR: tile_map_data pattern not found / unchanged!")
	else:
		var fw := FileAccess.open(PATH, FileAccess.WRITE)
		fw.store_string(out)
		fw.close()
		print("WROTE_SCENE ok  b64_len=", b64.length())
	print("REPAINT_DONE")
	get_tree().quit()
