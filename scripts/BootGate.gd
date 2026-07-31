extends Node2D

## The black screen the game opens on, before the menu: it asks for fullscreen and waits.
##
## This exists because of a browser rule, not a design whim. Fullscreen is only granted
## inside a user gesture, so a web build CANNOT open fullscreen — something has to ask. Once
## there is a gate for the web, the desktop may as well use the same one: one flow, and the
## player is told the hotkey exists rather than discovering it never.
##
##   F / F11        fullscreen, then in
##   any other key  straight in, windowed — undocumented on purpose (Advika cut the second
##                  line), but kept so nobody can be stuck on this screen
##
## One line, Cinzel caps in the quote card's gold, centred on black: the tarot's voice.

const CINZEL := "res://assets/fonts/cinzel.ttf"
const CREAM := Color(0.910, 0.784, 0.541)     # #E8C88A — the quote card's gold
const MENU_SCENE := "res://scenes/UI/MainMenu.tscn"

## Long enough that the words are not already gone when the player looks up from the loading
## bar, short enough that nobody thinks the build has hung.
const FADE_IN := 1.4
const FADE_OUT := 0.7

var _block: Control
var _ready_for_input := false
var _leaving := false


func _ready() -> void:
	var black := ColorRect.new()
	black.color = Color(0.02, 0.019, 0.026)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = -10
	layer.add_child(black)
	add_child(layer)

	var ui := CanvasLayer.new()
	add_child(ui)
	_block = CenterContainer.new()
	_block.set_anchors_preset(Control.PRESET_FULL_RECT)
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.modulate.a = 0.0
	ui.add_child(_block)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	_block.add_child(col)
	# single spaces: the 10px tracking already opens the words up, and doubling them as well
	# pulls the line into three separate things
	col.add_child(_line("PRESS F FOR FULLSCREEN", CINZEL, 30, Color(CREAM, 0.92), 10))

	var t := create_tween()
	t.tween_property(_block, "modulate:a", 1.0, FADE_IN)
	# input opens with the words, not before — a keypress landing on an invisible screen
	# feels like the game ate it
	t.tween_callback(func() -> void: _ready_for_input = true)

	# GATE_SHOT=<path>: capture the gate and quit, so its type can be judged like everything
	# else here rather than described.
	if OS.get_environment("GATE_SHOT") != "":
		_shot(OS.get_environment("GATE_SHOT"))
	# GATE_AUTO=<seconds>: walk through unattended, to prove the hand-off into the menu
	elif OS.get_environment("GATE_AUTO") != "":
		await get_tree().create_timer(float(OS.get_environment("GATE_AUTO"))).timeout
		_leave()


func _shot(path: String) -> void:
	await get_tree().create_timer(FADE_IN + 0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _line(text: String, font_path: String, size: int, colour: Color, tracking: int) -> Label:
	var l := Label.new()
	l.text = text
	var f := FontVariation.new()
	f.base_font = load(font_path)
	f.spacing_glyph = tracking
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## F is never SEEN here. ScreenMode is an autoload, so its `_input` runs first and marks the
## event handled — nothing downstream receives it. So the gate watches the RESULT instead:
## the moment the window is fullscreen, the ask has been answered and it leaves.
func _process(_delta: float) -> void:
	if not _leaving and _ready_for_input and ScreenMode.is_fullscreen():
		_leave()


## Any other key, or a click: straight through, window untouched. Only F asks for fullscreen,
## so "any key to continue" cannot force a window change nobody asked for.
func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not _ready_for_input:
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if (key != null and key.pressed and not key.echo) \
			or (click != null and click.pressed):
		_leave()


func _leave() -> void:
	_leaving = true
	var t := create_tween()
	t.tween_property(_block, "modulate:a", 0.0, FADE_OUT)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
