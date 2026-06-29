extends Node2D

# Verify the moving-plank extraction: count the spawned AnimatableBody2D planks,
# confirm the floor structures stayed static, and shoot the spawn area at two
# moments (t≈0 home positions, then mid-motion) so we can see the planks move.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	# Let _ready() run (extraction happens there).
	await get_tree().process_frame
	await get_tree().process_frame
	var tiles: TileMapLayer = realm.get_node("TileMapLayer")
	var planks: Array = []
	for child in tiles.get_children():
		if child is AnimatableBody2D:
			planks.append(child)
	print("MOVING_PLANKS=", planks.size())
	print("STATIC_BODIES=", _count(tiles, "StaticBody2D"))

	# Settle one frame, shoot home positions.
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/planks_t0.png")

	# Let the tweens displace the planks, shoot again.
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/planks_t1.png")
	print("PLANKS_DONE")
	get_tree().quit()


func _count(node: Node, type_name: String) -> int:
	var n := 0
	for c in node.get_children():
		if c.get_class() == type_name:
			n += 1
	return n
