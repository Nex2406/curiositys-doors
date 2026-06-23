extends Node2D

# Headless-ish visual capture: load Realm 1, override the camera, and save a row
# of horizontal slices (plus a whole-level overview) to tools/shots/ so we can
# eyeball the tiling for visual disruptions. Run as the main scene:
#   godot --path . --resolution 1600x600 res://tools/Screenshotter.tscn

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
const SHOT_DIR := "res://tools/shots/"
const SLICES := 6


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	await get_tree().process_frame
	await get_tree().process_frame

	# Kill Curiosity's follow-camera so ours wins.
	var cur: Node = realm.get_node_or_null("Curiosity")
	if cur:
		var cc: Camera2D = cur.get_node_or_null("Camera") as Camera2D
		if cc:
			cc.enabled = false

	var tml: TileMapLayer = realm.get_node("TileMapLayer") as TileMapLayer
	var ur: Rect2i = tml.get_used_rect()
	var ts: Vector2 = Vector2(tml.tile_set.tile_size)
	var tl: Vector2 = tml.to_global(Vector2(ur.position) * ts)
	var br: Vector2 = tml.to_global(Vector2(ur.position + ur.size) * ts)
	var world_w: float = br.x - tl.x
	var cy: float = (tl.y + br.y) * 0.5

	var cam: Camera2D = Camera2D.new()
	add_child(cam)
	cam.make_current()
	var vp: Vector2 = get_viewport().get_visible_rect().size

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))

	# Whole-level overview.
	cam.global_position = Vector2((tl.x + br.x) * 0.5, cy)
	cam.zoom = Vector2(vp.x / world_w, vp.x / world_w)
	await _settle()
	_save(cam, "overview")

	# Slices, each framing ~world_w/SLICES wide.
	var slice_w: float = world_w / SLICES
	var z: float = vp.x / slice_w
	cam.zoom = Vector2(z, z)
	for i in range(SLICES):
		cam.global_position = Vector2(tl.x + slice_w * (i + 0.5), cy)
		await _settle()
		_save(cam, "slice_%d" % i)

	print("SHOTS_DONE world_w=%.0f slice_w=%.0f" % [world_w, slice_w])
	get_tree().quit()


func _settle() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


func _save(_cam: Camera2D, name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + name + ".png")
