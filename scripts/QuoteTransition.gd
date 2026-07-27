extends CanvasLayer
class_name QuoteTransition

## The bridge between realms: black, a quote held in it, and the next realm loaded
## underneath so we arrive already inside. Realm 1's door hands over to this.
##
## Advika's spec (2026-07-26): 8 seconds of black — fade in 0.8s, quote up over
## 1.2s, hold, quote out over 0.8s, then the realm fades up over 1s. Input is dead
## from the moment [Y] is pressed; after the first 2 seconds any key skips the hold
## (first read is protected, retries are not punished). The two realms' tracks
## CROSS: Realm 1 fades out over the first ~4s while Realm 2's comes up beneath it
## from ~2s, so for a couple of seconds both are sounding.

signal finished()

## Advika 2026-07-26, in order: 8s -> "at least 15, it needs to be CINEMATIC" ->
## "a good 20 seconds... the animations need to be slow and drawn out". So every
## movement here is long: nothing snaps, the black arrives and leaves like breath.
const FADE_IN := 1.8
const QUOTE_IN := 3.0
const QUOTE_OUT := 2.0
const HOLD_BEFORE_PROMPT := 10.0   # read time before "Press any key" appears
const REALM_FADE := 2.2
const SKIP_AFTER := 2.0       # no skipping before this

## warm parchment gold on black — her pick
const CREAM := Color("E8C88A")
## "Classy and thin and italic, cinematic, Netflixy" (Advika 2026-07-27, after
## rejecting fifteen candidates). The families were never the problem: they are
## VARIABLE fonts and every sample drew at regular weight, which is why they all
## read heavy. Cormorant Garamond Italic pulled down to Light (300) is the high-
## contrast hairline italic that look is made of — see _thin().
const QUOTE_FONT := "res://assets/fonts/cormorant_garamond_italic.ttf"
const GARAMOND_IT := "res://assets/fonts/eb_garamond_italic.ttf"
const GARAMOND := "res://assets/fonts/eb_garamond.ttf"
const QUOTE_WEIGHT := 300

## the realm to arrive in, and its ambient
@export var next_scene: String = "res://scenes/realms/Realm2LiftTest.tscn"
@export var next_track: AudioStream = preload("res://assets/audio/realm2_moonlight.ogg")
@export var next_track_name: String = "realm2"

var _black: ColorRect
var _block: VBoxContainer
var _prompt: Label
var _t := 0.0
var _skipped := false
var _holding := false
var _waiting := false         # the prompt is up; any key now continues


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200

	_black = ColorRect.new()
	_black.color = Color(0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP    # eats clicks too
	_black.modulate.a = 0.0
	add_child(_black)

	# the quote block, composed as one unit and centred on both axes
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_block = VBoxContainer.new()
	_block.add_theme_constant_override("separation", 2)
	_block.modulate.a = 0.0
	centre.add_child(_block)

	# em dash, parentheses and en dash exactly as written; the quote marks are the
	# typographic pair (the ASCII " draws as a closing mark at both ends).
	var quote := _line("\u201cYou will not fall, nor rise.\u201d", QUOTE_FONT, 64, CREAM, true)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block.add_child(quote)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	_block.add_child(gap)

	# attribution: right-aligned inside the block's width, reading as one unit
	var fear := _line("\u2014 Fear", QUOTE_FONT, 36, CREAM, true)
	fear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_block.add_child(fear)

	var book := _line("(Written by Silence \u2013 Advika Kohli)", GARAMOND_IT, 20,
			Color(CREAM.r, CREAM.g, CREAM.b, 0.55))
	book.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_block.add_child(book)

	# "Press any key to continue" — the tarot card's prompt voice exactly: plain EB
	# Garamond, small, dimmed cream, sitting low and centred under the quote. It only
	# appears once the card has been up long enough to read (Advika 2026-07-27).
	_prompt = _line("Press any key to continue", GARAMOND, 22,
			Color(CREAM.r, CREAM.g, CREAM.b, 0.55))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.modulate.a = 0.0
	var prompt_wrap := CenterContainer.new()
	prompt_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(prompt_wrap)
	var prompt_col := VBoxContainer.new()
	prompt_col.alignment = BoxContainer.ALIGNMENT_END
	prompt_col.custom_minimum_size = Vector2(0, 620)
	prompt_wrap.add_child(prompt_col)
	prompt_col.add_child(_prompt)

	_run()


func _line(text: String, font_path: String, size: int, colour: Color,
		thin: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	var f: Font = load(font_path)
	if f != null:
		l.add_theme_font_override("font", _thin(f) if thin else f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	# NO glow, no hue — cream on black. The words carry it.
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Variable fonts default to Regular, which is why every italic candidate read
## heavy. This pulls the weight axis down to Light — the hairline, high-contrast
## italic that makes a title card feel cinematic instead of bookish.
func _thin(base: Font) -> Font:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": QUOTE_WEIGHT}
	return v


## Every tween on this card must run THROUGH the pause — the gameplay behind is
## frozen, the card is not. Without this the sequence stalled on its first fade and
## the screen simply sat black (caught in test, 2026-07-26).
func _tw() -> Tween:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t


## The whole beat, start to finish.
func _run() -> void:
	print("QUOTE: card up")
	get_tree().paused = true                 # gameplay is frozen behind the black

	var t := _tw()
	t.tween_property(_black, "modulate:a", 1.0, FADE_IN)
	await t.finished

	# The two realms' music MIXES under the card, both sitting lower than normal
	# (Advika: "both tracks mixing together in a slightly lower volume in the
	# background"). Realm 1 bleeds out across ~8s; Moonlight comes up beneath it from
	# ~6s, so they sound together for several seconds. The bus is ducked for the whole
	# card and only opens back up as we arrive.
	# NOT ducked any more: ducking the bus made the merge a background murmur, and
	# the merge is the point (Advika 2026-07-26: "the track merging needs to be
	# audible during the transition"). Realm 1 bleeds out across 11s and Moonlight
	# rises from 4s over 8s, both at full bus volume — they sound together, loudly,
	# for most of the card.
	AudioManager.stop_ambient(11.0)
	_cross_in_next_track()

	var q := _tw()
	q.tween_property(_block, "modulate:a", 1.0, QUOTE_IN)

	# QUOTE_SHOT=<path>: capture the card mid-hold (the level's own shot harness dies
	# with the scene change, so the card carries its own)
	if OS.get_environment("QUOTE_SHOT") != "":
		_card_shot()

	# Hold the line long enough to be read, THEN hand the pace to the player: the
	# prompt fades in and the card waits for a key, however long that takes (Advika
	# 2026-07-27 — a fixed 20s meant waiting on a card you had already finished).
	_holding = true
	var elapsed: float = FADE_IN
	while elapsed < HOLD_BEFORE_PROMPT and not _skipped:
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
		_t = elapsed
	if _prompt != null:
		var pt := _tw()
		pt.tween_property(_prompt, "modulate:a", 1.0, 1.0)
	_waiting = true
	while not _skipped:
		await get_tree().create_timer(0.05).timeout
	_waiting = false
	_holding = false

	var out := _tw()
	out.tween_property(_block, "modulate:a", 0.0, QUOTE_OUT)
	out.parallel().tween_property(_prompt, "modulate:a", 0.0, QUOTE_OUT * 0.6)
	await out.finished

	# load the next realm UNDER the black, then open our eyes on it — the black
	# lifts as a BLINK (Advika): a first look, a shut, then all the way open.
	get_tree().paused = false
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
		await get_tree().process_frame
		await get_tree().process_frame       # let the realm build before it shows
		print("QUOTE: arrived in ", next_scene)
	AudioManager.unduck_music(REALM_FADE)     # in case the realm behind us left it ducked
	var lift := _tw()
	lift.tween_property(_black, "modulate:a", 0.18, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lift.tween_property(_black, "modulate:a", 0.75, 0.45) \
			.set_trans(Tween.TRANS_SINE)
	lift.tween_property(_black, "modulate:a", 0.0, REALM_FADE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await lift.finished
	finished.emit()
	queue_free()


## QUOTE_SHOT=<path>: capture the card mid-hold (the level's own shot harness dies
## with the scene change, so the card carries its own).
func _card_shot() -> void:
	await get_tree().create_timer(QUOTE_IN + 1.5).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("QUOTE_SHOT"))
	print("QUOTE: card shot saved")


## Realm 2's track comes up beneath Realm 1's — a true overlap, not a handover.
## The Trial re-requests the same track by name on arrival, which AudioManager
## no-ops, so what starts here simply keeps playing into the realm.
func _cross_in_next_track() -> void:
	await get_tree().create_timer(4.0).timeout
	if next_track != null:
		AudioManager.play_ambient(next_track, next_track_name, 8.0)


## Every input is swallowed while the card is up; after the grace it also skips.
func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		if _holding and _t >= SKIP_AFTER:
			_skipped = true
	elif event is InputEventKey or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
