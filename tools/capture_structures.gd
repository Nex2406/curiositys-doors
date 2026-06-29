extends Node2D

# Frame each distinct tall structure (the plank/pillar groups) so we can match
# the one in Advika's photo. Saves tools/shots/struct_<col>.png.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
const TILES := 16.0
const ZOOM := 2.0
const COLS := [73, 545, 225, 697]   # divergent spots: left/right twins


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	await get_tree().create_timer(1.5).timeout
	var cam := Camera2D.new()
	add_child(cam)
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.make_current()
	for c in COLS:
		cam.global_position = Vector2((float(c) + 7.0) * TILES, 400.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tools/shots/struct_%d.png" % c)
	print("STRUCTS_DONE")
	get_tree().quit()
