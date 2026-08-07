extends CanvasLayer

## THE PROLOGUE — six stanzas typed onto black, between the menu and the first door.
##
## The voice is the one that has been watching. It does not introduce the world; it
## interrupts the player. Everything here is timing, so everything here is a dial.
##
## COLOUR is not chosen in this file. It is #E8C88A — the gold the boot gate's
## "PRESS F FOR FULLSCREEN" is drawn in (`scripts/BootGate.gd` CREAM, a direct
## `font_color` override on that Label, which is itself the quote card's gold). The
## screens before the game all speak in one colour. The value lives in Prologue.tscn as
## a theme override on NarratorLine so there is exactly one copy of it.
##
## The sequence is ONE async function, `_run()`, read top to bottom. Not a state machine:
## a state machine would scatter six stanzas of timing across a dozen branches, and the
## only thing this file has to get right is timing.

# ------------------------------------------------------------------------- content ----

## Each stanza is authored, not derived. `lines` may contain "" for a blank line, and any
## line may carry inline pause tokens of the form {0.6} — a literal brace, a float, a
## closing brace. Tokens never reach the screen; see `_parse`.
##
## Em-dash is U+2014, ellipsis is the single character U+2026, apostrophes are U+2019.
## The pause table keys off those exact code points, so an ASCII substitution here would
## silently cost the line its longest hesitation.
##
## FORTY SECONDS, AND NO BOOK (Advika 2026-07-31). The first draft was six stanzas, ran past
## a minute, and leaned on things only a reader of `Written by Silence` would catch — a rule
## that was broken, a body that was given, a door shutting behind. A player who has read
## nothing has to leave this screen knowing four things:
##
##   1. someone is talking to you, and they were already here waiting
##   2. you came because of a pull you never chose — and it was PUT in you, deliberately,
##      by someone the game has not named yet
##   3. three doors, and behind each one a feeling you were never meant to have
##   4. you are going to open them anyway, and the voice knows it
##
## The 20s cut of this said (2) as "Made to want to know", and Advika's verdict was that it
## was weird — which it was: it is a passive construction doing three jobs, and the player
## has to unpack "made" as "manufactured" with no help. At forty seconds the voice can just
## SAY it, in order, the way a person would: you don't remember choosing this → you felt a
## pull → they put that there → it was never a kindness. Same fact, no unpacking.
##
## Speed came back down with the ceiling: 26cps, not the 32 the short cut needed. Thirty-two
## is legible but it reads as text appearing; twenty-six reads as someone speaking.
##
## `PRO_TIME=1` prints the measured duration on exit, so the ceiling is a fact and not an
## estimate — see `_exit`.
## Advika asked for forty and then said slightly over is fine, so this is a TRIPWIRE, not
## the target: it exists to catch a rewrite that quietly doubles the length, not to police
## the last two seconds. The holds that were shaved to squeeze under a hard 40 were put
## back the moment the ceiling softened — they were the breathing, and 40.4s of a prologue
## that breathes beats 39.1s of one that hurries.
const CEILING := 44.0

const STANZAS: Array = [
	{   # I — the interruption: it was already here, and it was expecting you
		"lines": ["Oh{0.45}—look.", "It’s you.", "Right on time."],
		"cps": 26.0, "line_delay": 0.40, "final_hold": 1.10,
	},
	{   # II — why you came, in the player's own terms: you don't know why you came
		"lines": ["You don’t remember choosing this.", "You felt a pull,",
				"and you followed it down."],
		"cps": 26.0, "line_delay": 0.40, "final_hold": 1.10,
	},
	{   # III — and the pull was installed. "They" stay unnamed on purpose: it plants a
		#       question the realms can answer, instead of assuming an answer already known.
		"lines": ["They put that in you.", "On purpose.", "It was never a kindness."],
		"cps": 26.0, "line_delay": 0.40, "final_hold": 1.25,
	},
	{   # IV — what the game is, and its SHAPE. Advika 2026-07-31 is scrapping the hub and
		#      dropping the player straight into realm 1, so the doors are no longer three
		#      things standing in a room to be chosen between — they are a queue. "Three
		#      doors down here" was written for a hub and quietly promised one; these lines
		#      promise a sequence instead, and say plainly that a door is earned by
		#      finishing the one before it.
		"lines": ["Three doors ahead of you.", "Behind each one, a feeling",
				"you were never meant to have.", "", "One at a time.",
				"Each one opens the next."],
		"cps": 26.0, "line_delay": 0.36, "final_hold": 1.10,
	},
	{   # V — the push
		"lines": ["You’ll open all of them.", "Not because you’re brave.",
				"Because you can’t help it.", "Go on."],
		"cps": 26.0, "line_delay": 0.34, "final_hold": 1.70,
	},
]

## The typing itself — cursor, punctuation pauses and `{0.5}` tokens — lives in
## `scripts/Typewriter.gd`, shared with the Realm 1 quote card. This file only decides
## WHAT is said and WHEN; it no longer knows how a character reaches the screen.

# --------------------------------------------------------------------------- dials ----

## WHERE THE PROLOGUE LETS GO. There is no hub any more (Advika 2026-07-31 is scrapping it),
## so the voice hands straight to Realm 1 — and Realm 1 owns its own opening quote card, so
## nothing about that arrival is this file's business beyond naming the scene.
##
## A PackedScene rather than a path string: an export like this is picked in the inspector
## from scenes that actually exist, and a renamed or deleted target fails loudly at import
## instead of silently at runtime the way a stale string would.
##
## The DEFAULT is set in Prologue.tscn, not by a `preload` here. Preloading it in the script
## made every context that merely reads this file drag Realm 1's whole script in with it —
## `tests/test_prologue_parse.gd` runs under `--headless --script`, where autoloads like
## `Haptics` do not exist, so Realm 1 failed to compile and printed two errors into a passing
## test run. As scene data the dependency is declared exactly where it is used.
## Stanzas to speak instead of `STANZAS`. Empty = the prologue's own.
@export var stanzas_override: Array = []
## Leave the ending to whoever hosted this instead of loading `next_scene`.
@export var suppress_exit := false

signal stanza_started(index: int)
signal stanzas_done

@export var next_scene: PackedScene

## THE QUOTE BETWEEN. When the voice stops, one card is held on the black before the game
## begins — and it is the SAME card the Realm 1 → Realm 2 handover shows, because it is
## literally the same object (`QuoteTransition`, drawing through `QuoteCard`): black,
## Cormorant Garamond Italic at Light in the quote card's gold, "Press any key to continue",
## then the realm loads underneath and the black lifts as a blink. Nothing here is typed —
## the typing belongs to the prologue, and the card is a held breath after it.
##
## Advika 2026-07-31, from `Written by Silence`. No speaker line: this is the narrator the
## prologue has just been, not a named voice like Fear.
@export var quote_lines: PackedStringArray = PackedStringArray([
	"And before I could argue,",
	"the floor gave way.",
])
@export var quote_attribution := "(Written by Silence – Advika Kohli)"

## Straight to `next_scene`, no words. For level testing — nobody should have to sit through
## the voice to reach the thing they are debugging. (Realm 1's card still plays: it belongs
## to the realm, not to the prologue.)
@export var skip_prologue := false

## The menu's painting dissolving to black, and NOTHING is typed while it does. The voice
## waits for the dark (Advika 2026-07-31: "i need the oh look thing to be there once screen
## is comepletely black") — the painting leaving and the voice arriving were two events
## sharing one moment, and neither got to land. Now they take turns.
##
## It also has to buy its own place in the budget, so it dropped from the original 3.0: with
## no text over it there is nothing to read, and a picture the player has been staring at
## through the whole menu does not need three seconds to say goodbye.
@export_range(0.3, 8.0, 0.1) var dissolve_seconds := 1.6

## Full black, held, before the first character. Without it the fade lands and the text
## starts in the same frame, which reads as the dissolve having caused the text.
@export_range(0.0, 2.0, 0.05) var black_beat := 0.40

## The label's box is this fraction of the viewport wide. Nothing wraps into it — every
## break in the script is authored — but it fixes the centre line and clamps the margins.
@export_range(0.3, 0.95, 0.01) var width_frac := 0.62

## OFF: the block stays vertically centred, so appending a line glides everything already
## on screen upward (see `_reflow` — the glide is tweened, so it settles rather than jumps).
## ON: the block is pinned near the top and stanzas grow downward, dead still.
@export var top_anchored := false
@export_range(0.0, 0.6, 0.01) var top_frac := 0.22

## How long the block takes to slide to its new centre after a line is appended. 0 makes
## it a cut.
@export_range(0.0, 1.0, 0.01) var settle_seconds := 0.28

@export_range(0.1, 3.0, 0.05) var stanza_fade_out := 0.70
@export_range(0.0, 3.0, 0.05) var stanza_gap := 0.45
## After a blank line the pause is longer than the stanza's own line delay — the blank
## line IS the beat, and it costs no typing time to sell it with. (No stanza uses one at
## twenty seconds; the machinery stays because it is tested and costs nothing.)
@export_range(0.0, 3.0, 0.05) var blank_line_delay := 0.9

# --------------------------------------------------------------------------- typing ----

## The keystroke. Seeded noise, no fundamental, 55ms — see tools/make_typing_sfx.py for why
## every one of those choices matters at twenty ticks a second.
const SFX_TYPE := "res://assets/audio/ui/type_tick.wav"

## Under the words, not over them. The tick's job is to make the typing feel PHYSICAL; the
## moment it becomes a thing you notice on its own it has failed.
@export_range(-60.0, 0.0, 0.5) var type_db := -21.0

## Multiplied per keystroke, so no two ticks are the same tick. Kept narrow — wide jitter
## starts sounding like different objects being struck rather than one hand typing.
@export_range(0.0, 0.4, 0.01) var type_pitch_jitter := 0.09

## The floor on the gap between ticks. At 26cps the characters land every 38ms, which is
## fast enough to fuse into a buzz; 55ms thins that to roughly two ticks in three and the
## ear hears typing again. Silence is not skipped work — the character still appears.
@export_range(0.0, 0.3, 0.005) var type_min_gap := 0.055

# --------------------------------------------------------------------------- state ----

@onready var _backdrop: ColorRect = $Backdrop
@onready var _label: RichTextLabel = $NarratorLine

var _menu: Node = null          # the still-rendering menu we are dissolving over
var _started := false
var _aborted := false
var _exited := false

## The cursor — see scripts/Typewriter.gd. Preloaded by PATH and left untyped on purpose:
## `tests/test_prologue_parse.gd` preloads THIS file under `godot --headless --script`, which
## runs without the editor's global class registry, so a bare `Typewriter` identifier here
## would fail to parse and take the test down with it.
const TypewriterScript := preload("res://scripts/Typewriter.gd")
var _type = TypewriterScript.new()

var _voices: Array[AudioStreamPlayer] = []
var _voice := 0                 # round-robin, so a tick never cuts the one before it off
var _tick_cooldown := 0.0
var _elapsed := 0.0             # depicted seconds, for PRO_TIME
var _max_jump := 0              # most characters ever landed in one frame, for PRO_TIME


func _ready() -> void:
	_label.visible_characters = 0
	_label.text = ""
	get_viewport().size_changed.connect(_reflow.bind(0.0))
	_reflow(0.0)
	_build_voices()

	if OS.get_environment("PRO_SHOT") != "":
		_shoot(OS.get_environment("PRO_SHOT"))

	# One frame of grace so MainMenu can hand us itself via attach_over() before the
	# first character lands — the dissolve has to start with that character, not before it.
	await get_tree().process_frame
	if not _started:
		_start()


## Called by MainMenu the moment it adds us. We are its SIBLING, not its child, so it can
## be freed out from under the text once the backdrop has finished eating it.
func attach_over(menu: Node) -> void:
	_menu = menu
	if not _started:
		_start()


func _start() -> void:
	_started = true
	# PRO_SKIP=1: straight to the quote card, for looking at the card without sitting
	# through the voice first.
	if skip_prologue or OS.get_environment("PRO_SKIP") != "":
		_exit()
		return
	_run()


# ------------------------------------------------------------------------ sequence ----

func _run() -> void:
	# The dark comes first and completely. The menu dissolves with nothing written over it,
	# the painting is freed the instant it is fully covered, and only then — after a held
	# beat of pure black — does the voice say the first thing.
	var dissolve := create_tween()
	dissolve.tween_property(_backdrop, "color:a", 1.0, dissolve_seconds)
	await dissolve.finished
	_free_menu()
	await _wait(black_beat)

	# THE VOICE IS REUSABLE, THE WORDS ARE NOT. The endgame speaks in exactly this
	# system — same pause tokens, same punctuation pauses, same accumulating
	# stanza reveal, same font, same tick — so `Realm3Epilogue` hands its own
	# stanzas in here rather than growing a second copy of all of it.
	var script_: Array = stanzas_override if not stanzas_override.is_empty() else STANZAS
	for i in script_.size():
		if _aborted:
			break
		stanza_started.emit(i)
		await _play_stanza(script_[i], i == script_.size() - 1)

	stanzas_done.emit()
	# the epilogue's exit is an eye OPENING, not a fade to a scene — it takes
	# over from here
	if suppress_exit:
		return
	_exit()


func _play_stanza(stanza: Dictionary, is_last: bool) -> void:
	_type.cps = float(stanza.cps)
	_type.reset()
	_label.text = ""
	_label.visible_characters = 0
	_label.modulate.a = 1.0
	_reflow(0.0)

	var lines: Array = stanza.lines
	for i in lines.size():
		if _aborted:
			return
		var blank: bool = String(lines[i]).is_empty()
		await _append_line(String(lines[i]), i > 0)
		if _aborted:
			return
		var last: bool = i == lines.size() - 1
		if last:
			await _wait(float(stanza.final_hold))
		elif blank:
			await _wait(blank_line_delay)
		else:
			await _wait(float(stanza.line_delay))

	# Out, not away: the text leaves, the black stays, and the next stanza's first
	# character is its own entrance. Nothing fades IN in this whole sequence.
	var out := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	out.tween_property(_label, "modulate:a", 0.0, stanza_fade_out)
	await out.finished
	_label.text = ""
	_type.reset()
	_label.visible_characters = 0
	_reflow(0.0)
	# The last stanza's gap would be black holding on nothing while the transition is
	# already fading — the exit IS the gap.
	if not is_last:
		await _wait(stanza_gap)


## Append one authored line to the accumulated block and type it. Everything already on
## screen stays exactly where it is and does not re-animate — `visible_characters` just
## keeps counting up through the whole block.
func _append_line(raw: String, needs_newline: bool) -> void:
	_label.text = "[center]%s[/center]" % _type.append_line(raw, needs_newline)
	_label.visible_characters = _type.visible_count()

	# The box just grew. Let it re-measure, then glide to the new centre.
	await get_tree().process_frame
	_reflow(settle_seconds)

	# A blank line types nothing and only costs its delay; the typewriter says so by
	# never entering the typing state for it.
	while _type.is_typing() and not _aborted:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		if _aborted:
			return
		await get_tree().process_frame
		left -= get_process_delta_time()


# -------------------------------------------------------------------------- typing ----

## NOTHING here can put a line on screen in one go. There used to be a skip that snapped the
## current line to full on a keypress, and it was the reason lines sometimes "just spawned"
## (Advika 2026-07-31) — an input pressed during an un-skippable wait stayed latched in
## `_advance` and was spent by the NEXT line the instant it began typing, so a line the
## player never touched appeared whole. The skip is gone rather than patched: at forty
## seconds there is nothing worth skipping, and the guarantee is now structural — the only
## way a character reaches the screen is one at a time through `Typewriter.tick`. The
## prologue never calls `Typewriter.finish()`, which is the only thing that could break it.
## ESC still abandons the whole prologue.
func _process(delta: float) -> void:
	_elapsed += delta
	_tick_cooldown = maxf(0.0, _tick_cooldown - delta)
	var landed: Vector2i = _type.tick(delta)
	if landed.y == landed.x:
		return
	_label.visible_characters = landed.y
	_max_jump = maxi(_max_jump, landed.y - landed.x)
	var text: String = _type.display()
	for i in range(landed.x, landed.y):
		_keystroke(text[i])


## One keystroke's worth of sound. Whitespace is silent — a space is the absence of a key,
## and ticking on it makes the gaps between words the loudest part of the line.
func _keystroke(c: String) -> void:
	if c == " " or c == "\n" or c == "\t":
		return
	if _tick_cooldown > 0.0 or _voices.is_empty():
		return
	_tick_cooldown = type_min_gap
	var p: AudioStreamPlayer = _voices[_voice]
	_voice = (_voice + 1) % _voices.size()
	p.pitch_scale = 1.0 + randf_range(-type_pitch_jitter, type_pitch_jitter)
	p.volume_db = type_db
	p.play()


## Four players, round-robin. The tick is 55ms and they land every 55ms at worst, so a
## single player would clip its own tail on the busiest lines.
##
## Built here rather than routed through AudioManager.play_sfx, which allocates a node per
## call — fine for a menu chime, several hundred nodes for a prologue. Bus is chosen the
## same way AudioManager chooses it, so the Settings panel's Sound slider still governs it
## everywhere the SFX bus exists.
func _build_voices() -> void:
	var stream: AudioStream = load(SFX_TYPE)
	if stream == null:
		return
	var bus := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = bus
		p.volume_db = type_db
		add_child(p)
		_voices.append(p)


# -------------------------------------------------------------------------- layout ----

## Width and centre line are recomputed from the live viewport, not from 1920x1080 — the
## project stretches with aspect=expand, so a non-16:9 window really is wider than the
## design canvas.
func _reflow(duration: float) -> void:
	if not is_instance_valid(_label):
		return
	var vp := get_viewport().get_visible_rect().size
	var w: float = vp.x * width_frac
	_label.size.x = w
	_label.position.x = (vp.x - w) * 0.5
	var target: float
	if top_anchored:
		target = vp.y * top_frac
	else:
		target = (vp.y - _label.get_content_height()) * 0.5
	if duration <= 0.0 or absf(target - _label.position.y) < 0.5:
		_label.position.y = target
		return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_label, "position:y", target, duration)


# --------------------------------------------------------------------------- input ----

## ESC and nothing else. Twenty seconds is short enough that a per-line skip is not worth
## the cost of having one — see the note on `_process`. Accept/click are deliberately inert
## so that mashing through the menu cannot eat the opening line.
func _unhandled_input(event: InputEvent) -> void:
	if _exited or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		_aborted = true
		get_viewport().set_input_as_handled()


# ----------------------------------------------------------------------- hand-offs ----

## The menu keeps painting until the backdrop has completely covered it. Freeing it any
## earlier would show a hole; freeing it any later would leave the mist and the dust
## running behind an opaque rectangle for the rest of the prologue.
func _free_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


## The screen is already black by the time we get here, so the fade Transition performs on
## the way OUT is a no-op. We do not want the fade back IN either — Realm 1 runs its own
## 1.6s rise from black under its opening quote card, and two fades stacked on one arrival
## fight each other. So this hands over black and lets the realm do the opening.
##
## Looked up through the tree rather than by the `Transition` identifier so this file
## compiles under `godot --headless --script`, which does not register autoloads — that is
## what lets tests/test_prologue_parse.gd exist at all.
func _exit() -> void:
	if _exited:
		return
	_exited = true
	_free_menu()
	# PRO_TIME=1: the measured wall-clock length of the whole thing, dissolve included. The
	# 20s ceiling is Advika's, and an estimate is not a ceiling.
	if OS.get_environment("PRO_TIME") != "":
		# Two numbers, two of Advika's constraints. The jump is the proof that no line ever
		# appears whole: at 26cps and 60fps a frame is worth under half a character, so the
		# honest answer is 1. A line spawning would read 20-plus and nothing in between.
		print("[Prologue] %.2fs total (ceiling %.2fs) | max chars in one frame: %d"
				% [_elapsed, CEILING, _max_jump])
		# Measure and stop. Loading Realm 1 afterwards would only add its cost to a number
		# that is supposed to be about this scene. Run it with --fixed-fps 60 so every
		# delta is exactly 1/60 and the figure is the DEPICTED length, not the wall clock.
		get_tree().quit(0 if _elapsed <= CEILING and _max_jump <= 2 else 1)
		return
	if next_scene == null:
		push_warning("[Prologue] next_scene is unset — staying put")
		return
	_hand_to_quote_card()


## The bridge card, added as our SIBLING. Our own backdrop is still black underneath it, so
## its 1.8s fade-in has nothing to reveal and simply arrives; then it holds the quote, waits
## for a key, loads Realm 1 and blinks the black away. It frees this scene itself when it
## changes scene, which is why nothing here queue_frees.
##
## Loaded at RUNTIME, not by `class_name` and not by `preload`. QuoteTransition talks to the
## `AudioManager` autoload, and naming it here would make this file compile-depend on it —
## which `tests/test_prologue_parse.gd` cannot satisfy under `--headless --script`, where no
## autoload is registered. A runtime `load` is resolved only on the branch that runs it, and
## that branch never runs in a test.
func _hand_to_quote_card() -> void:
	var card = load("res://scripts/QuoteTransition.gd").new()
	card.quote_lines = quote_lines
	card.speaker = ""                     # no named voice on this one
	card.attribution = quote_attribution
	card.next_scene = next_scene.resource_path
	# Realm 1 starts its own track on entry, so the card must not cross a different one in
	# underneath it — it only needs to bleed the menu's music out.
	card.next_track = null
	card.next_track_name = ""
	get_tree().root.add_child(card)


## PRO_SHOT=<abs path>, PRO_SHOT_AT=<seconds>: capture one frame at a chosen moment and
## quit, so the timing can be looked at instead of described.
func _shoot(path: String) -> void:
	var at := 2.0
	if OS.get_environment("PRO_SHOT_AT") != "":
		at = float(OS.get_environment("PRO_SHOT_AT"))
	await get_tree().create_timer(at).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
