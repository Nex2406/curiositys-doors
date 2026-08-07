extends Node2D
## Capture the Realm 2 -> Realm 3 doorway on its own and quit.
##
## It exists so the doorway can be JUDGED without playing Realm 2 to the end of
## the wizard's trial, and without leaving a window open (Advika: "avoid opening
## blank test windows"). It shoots at R3GATE_AT seconds so the assembly sweep and
## the aperture can both be caught mid-beat.
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.055, 0.045, 0.085))
	var gate: Node2D = load("res://scripts/Realm3Gateway.gd").new() as Node2D
	gate.position = Vector2(960, 760)
	gate.scale = Vector2(1.15, 1.15)
	add_child(gate)
	gate.call("build")
	gate.call("assemble")
	var at: float = float(OS.get_environment("R3GATE_AT"))
	await get_tree().create_timer(at if at > 0.05 else 6.5).timeout
	var p: String = OS.get_environment("R3GATE_SHOT")
	if p == "":
		# no shot asked for: this is a LIVE look, so leave the window up
		return
	get_viewport().get_texture().get_image().save_png(p)
	print("R3GATE SHOT ", p)
	get_tree().quit()
