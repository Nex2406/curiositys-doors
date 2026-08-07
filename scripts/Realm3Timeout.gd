extends CanvasLayer
class_name Realm3Timeout

## THE CLOCK RAN OUT. Black, four words typed onto it, and the realm starts over.
##
## Advika: *"if the user cannot finish in 7mins and the timer runs out, in the
## same font used for the prologue and the same type writing sound used for the
## prologue, type 'Curiosity never dies', and then put the player back to the
## area where r3 started, restarting the entire level — I'm talking audio track
## and everything."*
##
## Which is why this is the PROLOGUE's presentation and not a new one: the same
## EB Garamond at 30, the same cream-gold `#E8C88A`-ish default_color read off
## `scenes/prologue/Prologue.tscn`'s NarratorLine, the same `Typewriter` and the
## same `ui/type_tick.wav` under it. The game already has a voice for talking to
## the player on black; running out of time is that voice's line, not a new UI.
##
## Running out of time used to route through `_die()` — it spent an eye and let
## her keep going on the same clock. That is a punishment. This is a rule.

## exactly `NarratorLine`'s: EB Garamond 30, its warm cream, its line spacing
const FONT := "res://assets/fonts/eb_garamond.ttf"
const FONT_SIZE := 64   # bigger than the prologue: this line is the whole screen
const INK := Color(0.910, 0.784, 0.541, 1.0)
const TICK := "res://assets/audio/ui/type_tick.wav"
const LINE := "Curiosity never dies"

## the prologue's own pacing constants, so the line lands at the same speed the
## opening does
const CPS := 26.0
const TICK_DB := -12.0
const TICK_MIN_GAP := 0.055

const FADE_IN := 1.4          # the black arrives before the words do
const HOLD_AFTER := 2.6       # the line sits, finished, before anything moves
const FADE_OUT := 1.6

const TypewriterScript := preload("res://scripts/Typewriter.gd")

var _black: ColorRect
var _label: RichTextLabel
var _type = TypewriterScript.new()
var _tick_stream: AudioStream
var _since_tick := 0.0
var _running := false


func _ready() -> void:
	# the level behind is frozen; this is not
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 210

	_black = ColorRect.new()
	_black.color = Color(0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	add_child(_black)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", load(FONT))
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_color_override("default_color", INK)
	_label.add_theme_constant_override("line_separation", 4)
	# A `fit_content` RichTextLabel has NO minimum width, and a CenterContainer
	# hands a child exactly its minimum — the first attempt shrank the line to
	# one character per row and drew it as a vertical thread down the middle of
	# the screen. The block is given a width; `[center]` then centres inside it.
	_label.custom_minimum_size = Vector2(1500.0, 0.0)
	_label.modulate.a = 0.0
	# DEAD CENTRE, via a CenterContainer rather than the prologue's fixed
	# offsets. That scene is authored at one size; this has to land in the
	# middle of whatever resolution the realm was being played at, and a
	# `fit_content` label grows DOWNWARD — anchored by hand it drifts off centre
	# the moment the text or the window changes.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.add_child(_label)

	_tick_stream = load(TICK)
	_type.cps = CPS
	_run()


func _run() -> void:
	get_tree().paused = true
	# the music goes with the realm. Advika asked for the whole level back,
	# audio included, and a track that kept playing across the reset would be
	# the one thing that did not restart.
	AudioManager.stop_ambient(FADE_IN)

	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_black, "modulate:a", 1.0, FADE_IN)
	await t.finished

	_label.text = "[center]%s[/center]" % _type.append_line(LINE, false)
	_label.visible_characters = 0
	_label.modulate.a = 1.0
	_running = true
	# R3_TIMEOUT_SHOT=<path> — the card carries its own capture. The level's
	# harness cannot take this one: `_run()` pauses the tree, and a
	# `create_timer` on a paused tree never fires, so the shot simply hangs.
	if OS.get_environment("R3_TIMEOUT_SHOT") != "":
		await get_tree().create_timer(1.6).timeout
		get_viewport().get_texture().get_image().save_png(
				OS.get_environment("R3_TIMEOUT_SHOT"))
		get_tree().quit()


func _process(delta: float) -> void:
	if not _running:
		return
	var landed: Vector2i = _type.tick(delta)
	_since_tick += delta
	if landed.y > _label.visible_characters:
		_label.visible_characters = landed.y
		# ONE tick per keystroke, floored to a gap. At 26cps the characters land
		# every 38ms, which fuses into a buzz — the prologue thins it the same
		# way and the result is what makes the typing read as physical.
		if _since_tick >= TICK_MIN_GAP:
			_since_tick = 0.0
			AudioManager.play_sfx(_tick_stream, TICK_DB)
	if not _type.is_typing():
		_running = false
		_restart()


## Back to the top of Realm 3, whole. `reload_current_scene` rebuilds the realm
## from `_ready` — spawn, clock, the six mushrooms, the opening card and the
## ambient bed — so there is no partial state to reset by hand and nothing that
## can be forgotten here later.
func _restart() -> void:
	await get_tree().create_timer(HOLD_AFTER).timeout
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_label, "modulate:a", 0.0, FADE_OUT)
	await t.finished
	get_tree().paused = false
	get_tree().reload_current_scene()
	# the black lifts on the rebuilt realm, so the restart is a blink rather
	# than a cut
	await get_tree().process_frame
	var lift := create_tween()
	lift.tween_property(_black, "modulate:a", 0.0, 1.8)
	await lift.finished
	queue_free()
