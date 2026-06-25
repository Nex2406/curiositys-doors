extends Node2D

const JADE := preload("res://scenes/Jade.tscn")

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.08, 0.09))
	var cam := Camera2D.new()
	add_child(cam)
	cam.zoom = Vector2(3, 3)
	cam.make_current()
	add_child(JADE.instantiate())
	await get_tree().create_timer(0.7).timeout   # let the bob lift + spin advance
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shots/jade.png")
	print("JADE_DONE")
	get_tree().quit()
