extends CanvasLayer

# A controls card shown over the level at start. It pauses the game until the player
# presses a key / clicks, then dismisses itself. Kept deliberately spare and gold-on-
# dark to match the vibe. Built in code so it's one self-contained node.

const GOLD := Color(1.0, 0.82, 0.42)
const INK := Color(0.88, 0.86, 0.80)
const DIM := Color(0.62, 0.60, 0.56)

const CONTROLS := [
	["Move", "A / D   ·   ← / →"],
	["Run", "hold  Shift"],
	["Jump", "Space  ·  W  ·  ↑"],
	["Attack", "J   ·   Z"],
	["Dash", "K   ·   X"],
	["Dash-Attack", "Dash, then Attack"],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.93)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 22)
	center.add_child(vb)

	var title := Label.new()
	title.text = "CURIOSITY'S DOORS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", GOLD)
	vb.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	for pair in CONTROLS:
		var a := Label.new()
		a.text = pair[0]
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.add_theme_font_size_override("font_size", 28)
		a.add_theme_color_override("font_color", GOLD)
		a.custom_minimum_size = Vector2(280, 0)
		grid.add_child(a)
		var k := Label.new()
		k.text = pair[1]
		k.add_theme_font_size_override("font_size", 28)
		k.add_theme_color_override("font_color", INK)
		grid.add_child(k)

	var hint := Label.new()
	hint.text = "press any key to begin"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", DIM)
	vb.add_child(hint)

	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	var go := (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if go:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		queue_free()
