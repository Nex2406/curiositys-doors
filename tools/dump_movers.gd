extends Node

# List moving platforms: index (from MovingPiece name), motion type, whether it carries a
# jade, painted top-center world pos, size. Also lists the golem placements (G# by x).
const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"

func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	await get_tree().process_frame
	await get_tree().process_frame
	var tiles: TileMapLayer = realm.get_node("TileMapLayer")
	var tsize := Vector2(tiles.tile_set.tile_size)
	var movers: Array = []
	for child in tiles.get_children():
		if child is AnimatableBody2D and String(child.name).begins_with("MovingPiece"):
			var idx := int(String(child.name).replace("MovingPiece", ""))
			var art: TileMapLayer = child.get_node_or_null("Art")
			if art == null:
				continue
			var ur := art.get_used_rect()
			var tc: Vector2 = art.to_global(Vector2(
				(float(ur.position.x) + float(ur.size.x) * 0.5) * tsize.x, float(ur.position.y) * tsize.y))
			var motion: String = realm.PIECE_MOTION.get(idx, "")
			if motion == "":
				motion = realm._default_plank_motion(idx)
			var jade: bool = realm.PIECE_JADE.has(idx)
			movers.append({"idx": idx, "x": tc.x, "y": tc.y, "w": ur.size.x, "motion": motion, "jade": jade})
	movers.sort_custom(func(a, b): return a["x"] < b["x"])
	print("=== MOVING PLATFORMS ===")
	for m in movers:
		print("  MP%-2d  motion=%-9s jade=%s  top_center=(%d,%d)  w=%d" % [
			m["idx"], m["motion"], str(m["jade"]), int(m["x"]), int(m["y"]), m["w"]])
	# Golems, sorted by x → matches the in-game G# labels.
	var gs: Array = get_tree().get_nodes_in_group("enemies")
	gs.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	print("=== GOLEMS (G# by x) ===")
	for i in range(gs.size()):
		print("  G%-2d  x=%d y=%d" % [i, int(gs[i].global_position.x), int(gs[i].global_position.y)])
	print("DONE")
	get_tree().quit()
