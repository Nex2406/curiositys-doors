extends Node2D
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06,0.07,0.10))
	var cl := CanvasLayer.new()
	add_child(cl)
	var bar = load("res://ui/GolemHealthBar.gd").new()
	bar.max_health = 300.0
	bar.boss_name = "CRYSTAL GOLEM"
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.position = Vector2(-300, 24)
	cl.add_child(bar)
	await get_tree().process_frame
	bar.take_damage(60.0)
	await get_tree().create_timer(0.15).timeout
	bar.take_damage(45.0)
	await get_tree().create_timer(0.5).timeout
	for i in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/bosshp.png")
	print("BOSSHP_DONE")
	get_tree().quit()
