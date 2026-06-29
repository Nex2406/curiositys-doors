extends Node2D

# Prove the left->right copy: frame a left-half spot and its right-half twin
# (offset +472 cols) at identical zoom. They should look the same.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
const TILES := 16.0
const ZOOM := 1.31


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	await get_tree().create_timer(1.5).timeout
	var cam := Camera2D.new()
	add_child(cam)
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.make_current()
	# Left spot ~col 230, right twin ~col 702 (230 + 472).
	for pair in [["left", 230], ["right", 702]]:
		cam.global_position = Vector2(float(pair[1]) * TILES, 360.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tools/shots/cmp_%s.png" % pair[0])
	print("COMPARE_DONE")
	get_tree().quit()
