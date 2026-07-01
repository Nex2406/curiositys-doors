extends Node2D

# Self-check for the first-pass golem placement: boot Realm1, let the golems fall
# and settle on the floor for a moment, then capture a few strips across the level
# so I can confirm each guard is standing on the ground (not sunk / floating / on a
# tower). Saves tools/shots/golems_<n>.png. Run WINDOWED (needs a renderer).

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
const VIEW_W := 1920.0
const STRIP_W := 2600.0   # world px per strip

# Strip centres (world x) covering the four map sections' golem clusters.
const CENTRES := [1500.0, 4500.0, 8200.0, 12800.0]


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	# Let physics run so every golem drops onto the floor and settles.
	for i in range(90):
		await get_tree().physics_frame
	var cam := Camera2D.new()
	add_child(cam)
	cam.zoom = Vector2(VIEW_W / STRIP_W, VIEW_W / STRIP_W)
	cam.make_current()
	for i in range(CENTRES.size()):
		cam.global_position = Vector2(CENTRES[i], 430.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://tools/shots/golems_%d.png" % i)
	print("GOLEMS_CAPTURE_DONE")
	get_tree().quit()
