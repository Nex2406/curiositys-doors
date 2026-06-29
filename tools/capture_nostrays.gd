extends Node2D

# TEST: does removing the 2 stray below-floor tiles (col 395/396, row 57) pull
# the camera's bottom limit up to the floor, dropping the floor to the bottom of
# the view (killing the "floating shelf over water" look)? Removes them at
# runtime BEFORE Realm1._ready runs its camera setup, then screenshots.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	# Strip the strays before the realm's _ready() reads get_used_rect().
	var tiles: TileMapLayer = realm.get_node("TileMapLayer")
	tiles.set_cell(Vector2i(395, 57))   # erase
	tiles.set_cell(Vector2i(396, 57))   # erase
	add_child(realm)
	await get_tree().create_timer(2.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/shots/nostrays.png")
	print("NOSTRAYS_DONE  used_rect=", tiles.get_used_rect())
	get_tree().quit()
