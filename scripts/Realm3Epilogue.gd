extends CanvasLayer

## THE END OF THE GAME: an eye closes, the voice from the prologue finishes what
## it started, and the eye opens on the main menu.
##
## THE VOICE IS NOT REIMPLEMENTED. `scenes/prologue/Prologue.tscn` and its
## `scripts/Prologue.gd` are instantiated and handed a different `stanzas_override`
## — so the pause tokens `{n}`, the punctuation pauses, the accumulating stanza
## reveal, the font, the colour, the per-line delays and the type tick are all
## literally the prologue's, not a copy that will drift from it. Prologue.gd
## gained exactly three things for this: `stanzas_override`, `suppress_exit`, and
## the `stanza_started` / `stanzas_done` signals.
##
## The prologue OPENS the game by putting out the light. This closes it by
## putting out the eye, and every delay runs the other way: the prologue
## accelerates into the game, this decelerates out of it.

const PROLOGUE := preload("res://scenes/prologue/Prologue.tscn")
const MENU_SCENE := "res://scenes/UI/MainMenu.tscn"
const MENU_TRACK := preload("res://assets/audio/menu_starfall_dreams.ogg")

const CLOSE_TIME := 2.5       # the lids coming down
const BLACK_BEAT := 0.6       # held shut before the first word
const STILL_AFTER := 2.0      # the beat after "?" — the longest silence in the game
const OPEN_TIME := 0.7
const MENU_HOLD := 0.5

## Stanza VII is slower than everything before it, and its two pauses are the
## whole ending: "The End", a held breath, and then the question mark that takes
## it back.
const STANZAS: Array = [
	{   # I — it is still talking, and it was watching the fight
		"lines": ["Oh{0.5}—look.", "Still standing.", "", "(Barely.", "I counted.)"],
		"cps": 26.0, "line_delay": 0.34, "final_hold": 1.10,
	},
	{   # II — the jade was never treasure
		"lines": ["Those seventeen stones", "you pulled out of the dark—",
				"did you wonder why they glowed?", "", "They were pieces of you.",
				"You broke when you fell.", "", "You spent that whole cave",
				"picking yourself back up."],
		"cps": 26.0, "line_delay": 0.34, "final_hold": 1.20,
	},
	{   # III — the moths, and what the lantern actually did to them
		"lines": ["And the moths.", "The poor moths.", "",
				"They live where nothing is seen.", "And you—", "you walked in",
				"carrying light,", "asking to see everything.", "",
				"They never stood a chance."],
		"cps": 26.0, "line_delay": 0.40, "final_hold": 1.25,
	},
	{   # IV — it admits authorship of the boss
		"lines": ["Then the forest went grey,", "and something wore your face.", "",
				"You noticed, didn’t you?", "It jumped when you would jump.",
				"It swung when you would swing.", "", "It should have.",
				"I built it from watching you."],
		"cps": 26.0, "line_delay": 0.40, "final_hold": 1.30,
	},
	{   # V — and concedes the one thing it could not predict
		"lines": ["Every step you took in here,", "I kept.", "And I made your habits",
				"fight you back.", "", "You couldn’t beat", "what already knew you.", "",
				"So you did the one thing", "I don’t have written down.", "You changed."],
		"cps": 26.0, "line_delay": 0.45, "final_hold": 1.50,
	},
	{   # VI — it asks for the eye, and does not believe the answer
		"lines": ["So.", "Put down the lantern.", "Close the eye.", "", "(Go on.",
				"We’ll both pretend", "it will stay shut.)"],
		"cps": 26.0, "line_delay": 0.50, "final_hold": 3.00,
	},
	{   # VII — "The End", a breath, and the mark that reopens it
		"lines": ["The End{1.4}…{0.9}?"],
		"cps": 14.0, "line_delay": 0.50, "final_hold": 0.0,
	},
]

## THE LIDS. Two full-screen quads whose covered edge BULGES in the middle, so
## what closes reads as an eyelid rather than a letterbox bar, and whose edge is
## feathered so it never draws a line across the frame.
const LID_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;   // 0 open, 1 shut
uniform float flip = 0.0;     // 0 top lid, 1 bottom lid
uniform float curve = 0.26;   // how far the middle of the lid hangs past its edges
uniform float feather = 0.055;
void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = mix(UV.y, 1.0 - UV.y, flip);
	float edge = amount * (1.0 + curve) - curve * (1.0 - x * x);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(edge + feather, edge - feather, y));
}
"""

var _lids: Array[ColorRect] = []
var _pro: Node = null
var _text_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 250
	for i in 2:
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		var sh := Shader.new()
		sh.code = LID_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("amount", 0.0)
		m.set_shader_parameter("flip", float(i))
		r.material = m
		add_child(r)
		_lids.append(r)
	# R3_EPI_SHOT=<dir> — three frames of the ending: the eye half shut, a
	# stanza mid-type, and the menu behind the opening lids. A video cannot be
	# taken from here, so these are what proves the beats land.
	if OS.get_environment("R3_EPI_SHOT") != "":
		_shots(OS.get_environment("R3_EPI_SHOT"))
	_run()


## ONE frame, at `R3_EPI_AT` seconds. A three-shot loop was tried and only ever
## produced its first frame — the ending is long, and a coroutine sitting on a
## timer through a scene change is not a reliable thing to hang a check on.
func _shots(path: String) -> void:
	var at: float = float(OS.get_environment("R3_EPI_AT"))
	await _wait(at if at > 0.1 else 1.4)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _run() -> void:
	# the boss track goes with the boss
	AudioManager.stop_ambient(CLOSE_TIME)
	await _lids_to(1.0, CLOSE_TIME, Tween.EASE_IN)
	# THE TREE IS NOT PAUSED. Pausing it was the obvious move and it deadlocked
	# the ending: `Prologue.gd` drives its stanzas on plain `create_tween()`,
	# which halts with the tree, so the voice never said a word. Nothing behind
	# the lids is visible anyway — and the realm is over, so there is nothing
	# left back there that pausing would protect.
	await _wait(BLACK_BEAT)

	_pro = PROLOGUE.instantiate()
	# there is no menu painting to eat here — the eye already did that job, so
	# the prologue's own dissolve is skipped rather than played against black
	_pro.dissolve_seconds = 0.05
	_pro.black_beat = 0.0
	_pro.blank_line_delay = 0.9
	_pro.stanzas_override = STANZAS
	_pro.suppress_exit = true
	_pro.process_mode = Node.PROCESS_MODE_ALWAYS
	# AND IF THE PROLOGUE IS ITSELF A CanvasLayer, the wrapper below does nothing
	# for it: a CanvasLayer nested in a CanvasLayer does NOT inherit, its `layer`
	# is a global sort key. Same trap `QuoteTransition` documents, and it is what
	# made the ending play as a black screen with typing audible on it.
	if _pro is CanvasLayer:
		(_pro as CanvasLayer).layer = layer + 10
	_pro.stanza_started.connect(_on_stanza)
	_pro.stanzas_done.connect(_finish)
	# ABOVE THE LIDS. Parented to the root it drew at layer 0, underneath two
	# opaque black quads at 250 — so the ending played correctly and invisibly:
	# black screen, typing audible, not one word on it. The voice gets its own
	# CanvasLayer over the eye, and the eye is freed of it before it opens.
	_text_layer = CanvasLayer.new()
	_text_layer.layer = layer + 10
	_text_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_text_layer)
	_text_layer.add_child(_pro)
	# ...and if the prologue is ITSELF a CanvasLayer, the wrapper does nothing:
	# a CanvasLayer nested in a CanvasLayer does not inherit, its `layer` is a
	# global sort key. This is the same trap `QuoteTransition` documents, and it
	# is why the ending played as a black screen with typing on it.
	if _pro is CanvasLayer:
		(_pro as CanvasLayer).layer = layer + 10


## The menu's track comes up under stanza VII, so the last line is already being
## spoken over where the player is about to be put back.
func _on_stanza(index: int) -> void:
	if index == STANZAS.size() - 1:
		AudioManager.play_ambient(MENU_TRACK, "menu", 6.0)


func _finish() -> void:
	# THE LONGEST SILENCE IN THE GAME, and it is doing the work: "?" has landed,
	# nothing moves, and the player is left holding it.
	await _wait(STILL_AFTER)
	# the menu is built BEHIND the shut eye, so opening reveals it already there
	# — there is no fade on stanza VII, the eye opening is its only exit
	get_tree().change_scene_to_file(MENU_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_text_layer):
		_text_layer.queue_free()
	await _lids_to(0.0, OPEN_TIME, Tween.EASE_OUT)
	await _wait(MENU_HOLD)
	queue_free()


func _lids_to(amount: float, secs: float, ease_: int) -> void:
	var t := create_tween().set_parallel(true)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for r in _lids:
		var m: ShaderMaterial = r.material
		t.tween_method(func(v: float) -> void: m.set_shader_parameter("amount", v),
				m.get_shader_parameter("amount"), amount, secs) \
				.set_trans(Tween.TRANS_SINE).set_ease(ease_)
	await t.finished


## timers stop with the tree; this one must not
func _wait(secs: float) -> void:
	var t := get_tree().create_timer(secs, true, false, true)
	await t.timeout
