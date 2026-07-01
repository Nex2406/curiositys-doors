extends Node2D
const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	for i in range(30):
		await get_tree().process_frame
	var door: Node2D = realm.get_node_or_null("ExitDoor")
	var cx: float = door.global_position.x if door != null else 15200.0
	var cam := Camera2D.new()
	add_child(cam)
	cam.global_position = Vector2(cx - 120.0, 380.0)
	cam.zoom = Vector2(1.3, 1.3)
	cam.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/door_spirit.png")
	print("DOOR_CAP_DONE door_x=", cx)
	get_tree().quit()
