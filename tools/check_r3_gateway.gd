extends SceneTree
## HEADLESS build check for the Realm 2 -> Realm 3 gateway.
##
## No window, no waiting (Advika: "avoid opening blank test windows"). It
## instantiates the doorway, builds every piece, runs the assembly, and reports
## the child count — which is the only thing a parse check cannot tell you: that
## the builders actually produced geometry rather than silently no-opping on a
## missing texture.
##
## Run: godot --headless --path . --script res://tools/check_r3_gateway.gd
func _init() -> void:
	var gate: Node2D = load("res://scripts/Realm3Gateway.gd").new() as Node2D
	get_root().add_child(gate)
	gate.call("build")
	var n: int = gate.get_child_count()
	print("R3GATE children=", n)
	var has_view := false
	for c in gate.get_children():
		if String(c.name) == "PortalWindow":
			has_view = true
	print("R3GATE portal window present=", has_view)
	gate.call("assemble")
	print("R3GATE assemble ok")
	var lift: Resource = load("res://scripts/Realm2LiftTest.gd")
	print("R2 script loaded=", lift != null)
	quit()
