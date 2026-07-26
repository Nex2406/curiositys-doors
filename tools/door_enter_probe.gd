extends Node2D
## Reproduces entering a realm THROUGH the fade, the way a Hub door does it:
## Transition.transition_to(<realm>). The shot is taken by a node parented to the
## TREE ROOT, because change_scene_to_file frees this scene (and anything awaiting
## inside it) the moment the realm loads.
##
## PROBE_TARGET=<scene path>  PROBE_SHOT=<png>  PROBE_AT=<seconds>


func _ready() -> void:
	var target: String = OS.get_environment("PROBE_TARGET")
	if target == "":
		target = "res://scenes/realms/realm1/Realm1PlatformTest.tscn"
	var at: float = 6.0
	if OS.get_environment("PROBE_AT") != "":
		at = float(OS.get_environment("PROBE_AT"))
	var watcher := Node.new()
	watcher.set_script(load("res://tools/door_enter_watch.gd"))
	watcher.set("shot_at", at)
	get_tree().root.add_child.call_deferred(watcher)
	await get_tree().create_timer(0.5).timeout
	print("PROBE: transition_to ", target)
	Transition.transition_to(target)
