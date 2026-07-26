extends Node
## Rides the TREE ROOT so it survives change_scene_to_file, and reports what the
## screen actually looks like N seconds after a realm entry (a stuck fade shows up
## as a black frame). Used by tools/DoorEnterProbe.tscn.

var shot_at: float = 6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(shot_at).timeout
	var path: String = OS.get_environment("PROBE_SHOT")
	if path != "":
		get_viewport().get_texture().get_image().save_png(path)
	print("PROBE: shot at ", shot_at, "s  paused=", get_tree().paused,
			"  scene=", get_tree().current_scene)
	get_tree().quit()
