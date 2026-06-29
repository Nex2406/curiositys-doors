extends Node2D

# Two settled shots: the spawn area (via Curiosity's real camera — judges platform
# height + spacing) and the exit door (override camera at the right edge — judges
# whether the door now rests on the floor). Dumps door/floor geometry too.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
const TILES := 16.0


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	await get_tree().create_timer(2.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/play.png")

	var door: Node2D = realm.get_node("ExitDoor")
	var tiles: TileMapLayer = realm.get_node("TileMapLayer")
	var ur: Rect2i = tiles.get_used_rect()
	var floor_surface_y := tiles.to_global(Vector2(0, 40) * Vector2(tiles.tile_set.tile_size)).y
	print("door.global_position=", door.global_position, "  floor_surface_y=", floor_surface_y)
	print("door base y=", door.global_position.y + 90.0, " (should ~= floor_surface_y)")

	# Override camera framed on the door.
	var cam := Camera2D.new()
	add_child(cam)
	cam.global_position = Vector2(door.global_position.x - 120.0, floor_surface_y - 180.0)
	cam.zoom = Vector2(2.4, 2.4)
	cam.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/door.png")
	print("PLAY_DONE")
	get_tree().quit()
