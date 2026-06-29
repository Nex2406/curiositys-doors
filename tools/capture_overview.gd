extends Node2D

# Whole-level overview: instantiate Realm1, then override with a wide camera that
# frames the entire painted level (all 960 columns) in one frame, so we can judge
# the left/right layout balance at a glance. Saves tools/shots/overview.png.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
const TILES := 16.0
const LEVEL_COLS := 960.0


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	await get_tree().process_frame
	await get_tree().process_frame
	# Our own camera, framing the full width.
	var cam := Camera2D.new()
	add_child(cam)
	var level_w := LEVEL_COLS * TILES
	cam.global_position = Vector2(level_w * 0.5, 430.0)
	cam.zoom = Vector2(1920.0 / level_w, 1920.0 / level_w)  # fit width
	cam.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/overview.png")
	print("OVERVIEW_DONE")
	get_tree().quit()
