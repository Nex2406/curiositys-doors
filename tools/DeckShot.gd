extends Node
## Capture rig for the deck (docs/presentation). Boots a realm scene, taps a key
## every so often so the tarot cards dismiss themselves, then saves one frame.
##   DECK_SCENE=res://...tscn  DECK_OUT=<abs png>  DECK_AT=<seconds>
##   DECK_TAP_UNTIL=<seconds>  (stop tapping this long before the shot)

func _ready() -> void:
	var scene_path: String = OS.get_environment("DECK_SCENE")
	var out: String = OS.get_environment("DECK_OUT")
	var at: float = float(OS.get_environment("DECK_AT"))
	if at <= 0.0:
		at = 6.0
	var tap_until: float = float(OS.get_environment("DECK_TAP_UNTIL"))
	if tap_until <= 0.0:
		tap_until = maxf(at - 2.0, 0.0)
	var lvl: Node = load(scene_path).instantiate()
	add_child(lvl)
	# DECK_CALL=<method>[@seconds] — poke the level once, so a beat that normally
	# needs the whole realm played to reach can be photographed.
	var call_spec: String = OS.get_environment("DECK_CALL")
	if call_spec != "":
		var parts: PackedStringArray = call_spec.split("@")
		var when: float = float(parts[1]) if parts.size() > 1 else 2.0
		get_tree().create_timer(when).timeout.connect(func() -> void:
			if is_instance_valid(lvl) and lvl.has_method(parts[0]):
				lvl.call(parts[0])
				print("DECK CALL ", parts[0]))
	var t: float = 0.0
	while t < at:
		await get_tree().create_timer(0.35).timeout
		t += 0.35
		if t < tap_until:
			var ev := InputEventKey.new()
			ev.keycode = KEY_ENTER
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := InputEventKey.new()
			up.keycode = KEY_ENTER
			up.pressed = false
			Input.parse_input_event(up)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("DECK SHOT saved ", out)
	get_tree().quit()
