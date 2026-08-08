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
##
## THE WORDS ARE NO LONGER DRAWN HERE (2026-07-31). Realm 1 needed an opening card of its
## own, and rather than write a second card the presentation moved into `QuoteCard` —
## quote, optional speaker, attribution, continue affordance, and the typewriter it shares
## with the prologue. What stayed is what only a BRIDGE does: freezing the tree, crossing
## the two soundtracks, changing scene, and lifting the black as a blink. See `_build_card`.

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
## contrast hairline italic that look is made of.
const QUOTE_FONT := "res://assets/fonts/cormorant_garamond_italic.ttf"
const GARAMOND_IT := "res://assets/fonts/eb_garamond_italic.ttf"
const GARAMOND := "res://assets/fonts/eb_garamond.ttf"
const QUOTE_WEIGHT := 300

## the realm to arrive in, and its ambient
@export var next_scene: String = "res://scenes/realms/Realm2LiftTest.tscn"
@export var next_track: AudioStream = preload("res://assets/audio/realm2_moonlight.ogg")
@export var next_track_name: String = "realm2"

## THE WORDS. Exported (2026-07-31) so this same bridge can carry a different quote — the
## prologue uses one to reach Realm 1. Defaults are Fear's line, which is what the Realm 1
## → Realm 2 handover has always shown.
##
## One entry per line. `speaker` empty means no speaker line is drawn at all and the block
## closes up — the Realm 1 opening quote has no speaker.
## (bare, no quote marks — `QuoteCard` puts those on now, for every card in the game)
@export var quote_lines: PackedStringArray = PackedStringArray([
	"You will not fall, nor rise.",
])
@export var speaker: String = "— Fear"
@export var attribution: String = "(Written by Silence – Advika Kohli)"

var _black: ColorRect
var _card: QuoteCard
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

	_build_card()
	_run()


## The card, dressed exactly as this one has always been dressed. Every value is passed in
## explicitly rather than inherited from QuoteCard's defaults — 64/36/20pt, Cormorant
## pulled to Light, right-aligned credits, cream on black, no typing, and the prompt as a
## WORD rather than a caret. Nothing about how it looks is meant to have changed.
func _build_card() -> void:
	_card = QuoteCard.new()
	_card.name = "Card"
	# A CanvasLayer nested inside a CanvasLayer does NOT inherit it — the child's `layer`
	# is a global sort key, so leaving it at 0 buried the whole card under this file's own
	# black at 200 and the card shot came back as an empty frame. One above ours.
	_card.layer = layer + 1

	# em dash, parentheses and en dash exactly as written; the quote marks are the
	# typographic pair (the ASCII " draws as a closing mark at both ends).
	_card.quote_lines = quote_lines
	_card.speaker = speaker
	_card.attribution = attribution

	_card.block_fade_in = QUOTE_IN
	_card.quote_font = load(QUOTE_FONT)
	_card.quote_size = 64
	_card.quote_weight = QUOTE_WEIGHT     # Light (300) — the hairline cinematic italic
	_card.attribution_font = load(GARAMOND_IT)
	_card.attribution_size = 20
	_card.text_colour = CREAM
	_card.attribution_alpha = 0.55
	_card.quote_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.credit_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.speaker_gap = 16

	# "Press any key to continue" — the tarot card's prompt voice: plain EB Garamond,
	# small, dimmed cream, centred under the quote. It appears only once the card has been
	# up long enough to read (Advika 2026-07-27), which is why the delay is ours, below.
	_card.indicator_text = "Press any key to continue"
	_card.indicator_alpha = 0.55
	_card.indicator_gap = 120
	add_child(_card)


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
	# background"). NOT ducked: ducking the bus made the merge a background murmur, and
	# the merge is the point (Advika 2026-07-26: "the track merging needs to be
	# audible during the transition"). Realm 1 bleeds out across 11s and Moonlight
	# rises from 4s over 8s, both at full bus volume — they sound together, loudly,
	# for most of the card.
	AudioManager.stop_ambient(11.0)
	_cross_in_next_track()

	# The quote block breathes in over QUOTE_IN. Not awaited: the hold below is measured
	# from the top of the card, exactly as it was when the fade lived in this file.
	_card.present()

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
	_card.reveal_indicator()
	_waiting = true
	while not _skipped:
		await get_tree().create_timer(0.05).timeout
	_waiting = false
	_holding = false

	await _card.fade_out(QUOTE_OUT)

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
## This runs at `_input`, ahead of QuoteCard's own `_unhandled_input`, and marks every
## press handled — so the card's built-in skip/dismiss never fires here and the pacing
## stays entirely in this file.
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
