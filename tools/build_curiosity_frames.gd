extends SceneTree

# One-shot builder: assembles Curiosity's new SpriteFrames from the per-animation folders
# and saves it as a .tres the scene references. Run:
#   godot --headless --script res://tools/build_curiosity_frames.gd

func _initialize() -> void:
	var anims := [
		{"name": "idle",      "n": 12, "loop": true,  "speed": 6.0},
		{"name": "walk",      "n": 12, "loop": true,  "speed": 12.0},
		{"name": "run",       "n": 12, "loop": true,  "speed": 14.0},
		{"name": "jump",      "n": 10, "loop": false, "speed": 12.0},
		{"name": "attack",    "n": 12, "loop": false, "speed": 14.0},
		{"name": "hurt",      "n": 12, "loop": false, "speed": 12.0},
		{"name": "celebrate", "n": 6,  "loop": true,  "speed": 9.0},
	]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for a in anims:
		var nm: String = a["name"]
		sf.add_animation(nm)
		sf.set_animation_loop(nm, a["loop"])
		sf.set_animation_speed(nm, a["speed"])
		for i in range(1, int(a["n"]) + 1):
			var path := "res://assets/player/curiosity/%s/%s%d.png" % [nm, nm, i]
			var tex: Texture2D = load(path)
			if tex == null:
				push_error("MISSING " + path)
				printerr("MISSING ", path)
			else:
				sf.add_frame(nm, tex)
		print("%s: %d frames, loop=%s" % [nm, sf.get_frame_count(nm), str(a["loop"])])
	var err := ResourceSaver.save(sf, "res://assets/player/curiosity/curiosity_frames.tres")
	print("SAVE err=", err)
	quit()
