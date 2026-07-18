extends SceneTree

# Headless proof of the void moth's burn->death chain (run:
#   godot --headless --script tools/check_moth_burn.gd
# ). A stub target reports an always-lit light; 4s of ticks must burn the
# moth out. Guards the "holding L never dissolves it" class of bug on the
# moth's side of the contract.


func _init() -> void:
	var stub_src := GDScript.new()
	stub_src.source_code = """extends Node2D
func light_state() -> Array:
	return [global_position, 999999.0]
func take_damage(_a: int, _k: Vector2 = Vector2.ZERO) -> void:
	pass
"""
	stub_src.reload()
	var her: Node2D = stub_src.new()
	root.add_child(her)
	var anchor := Node2D.new()
	root.add_child(anchor)

	var moth: VoidMoth = load("res://scenes/VoidMoth.tscn").instantiate()
	root.add_child(moth)
	if moth._visual == null:
		moth._ready()   # _init-time add_child predates tree processing
	moth._target = her
	moth._anchor = anchor
	moth.state = VoidMoth.State.STALK

	var burned := [false]
	moth.died_to_light.connect(func() -> void: burned[0] = true)
	for i in 45:
		moth._tick_burn(0.1)   # 4.5s of always-lit
	print("burn check: state=%s lit=%s light_t=%.2f died_signal=%s" %
			[VoidMoth.State.keys()[moth.state], moth._lit, moth._light_t, burned[0]])
	# died_to_light rides the flash tween, which needs render frames this
	# harness never pumps — BURNED state is the chain's proof
	if moth.state == VoidMoth.State.BURNED:
		print("MOTH BURN CHAIN: PASS")
	else:
		print("MOTH BURN CHAIN: FAIL")
	quit()
