extends Node2D

# Single focused screenshot of a column range, for judging detail (combos, tiles).
# Frames cols START_COL..END_COL of Realm 1. Saves tools/shots/strip.png.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
const START_COL := 0
const END_COL := 200


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	await get_tree().process_frame
	await get_tree().process_frame
	var cur: Node = realm.get_node_or_null("Curiosity")
	if cur:
		var cc: Camera2D = cur.get_node_or_null("Camera") as Camera2D
		if cc:
			cc.enabled = false
	var tml: TileMapLayer = realm.get_node("TileMapLayer") as TileMapLayer
	var ts := Vector2(tml.tile_set.tile_size)
	var left := tml.to_global(Vector2(START_COL, 0) * ts).x
	var right := tml.to_global(Vector2(END_COL, 0) * ts).x
	var floor_y := tml.to_global(Vector2(0, 40) * ts).y

	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	var vp := get_viewport().get_visible_rect().size
	var world_w := right - left
	var z: float = vp.x / world_w
	cam.zoom = Vector2(z, z)
	# Centre horizontally on the strip; vertically a bit above the floor so the
	# floating platforms are framed.
	cam.global_position = Vector2((left + right) * 0.5, floor_y - 110.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/shots/strip.png")
	print("STRIP_DONE cols %d..%d" % [START_COL, END_COL])
	get_tree().quit()
