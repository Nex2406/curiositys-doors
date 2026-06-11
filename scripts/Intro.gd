extends Node2D

# Intro / prologue. Curiosity speaks directly to the player while the scene
# cross-fades through six painted backgrounds, then the last line drops us into
# the hub. Backgrounds advance WITH the dialogue: each is held across a couple
# of lines so visuals move with the story rather than snapping every line.
#
# Voice is grounded in Advika's novel "Written by Silence" (see docs/VOICE.md):
# dry, warm, fragmentary; doors never meant to be opened, the lantern, the
# Tower, Consciousness, the jade key, the Watcher. Curiosity as keeper of
# secrets, addressing the one who has arrived at the doors.

const HUB_PATH: String = "res://scenes/Hub.tscn"
const FADE_TIME: float = 1.2

# Special "dive into the flask" transition, used ONLY when leaving Shelves 6
# (the foggy bottles) for Shelves 2 — the camera flies into the central flask,
# blooms white through the glass, and surfaces inside the next scene.
const SHELVES6_BG: int = 2
const SHELVES2_BG: int = 3
const DIVE_FOCAL: Vector2 = Vector2(0.52, 0.45)   # normalised flask centre
const DIVE_TIME: float = 2.0         # zoom-in duration (ease-in, accelerating)
const DIVE_PEAK_SCALE: float = 5.5   # how far Shelves 6 flies into the glass
const DIVE_XFADE: float = 0.6        # cross-dissolve overlap at the peak (no white)
const DIVE_SETTLE: float = 0.7       # extra emerge time after the dissolve
const DIVE_DLG_FADE: float = 0.3     # hide the dialogue before diving

# The six backgrounds, in the order they appear (paths into the compressed set).
const BACKGROUNDS: Array[String] = [
	"res://assets/scenes/intro/cauldron_2.webp",
	"res://assets/scenes/intro/grimoire_1.webp",
	"res://assets/scenes/intro/shelves_6.webp",
	"res://assets/scenes/intro/shelves_2.webp",
	"res://assets/scenes/intro/shelves_1.webp",
	"res://assets/scenes/intro/tent_3.webp",
]

# Curiosity's prologue. Advika's exact wording — do not paraphrase or reorder.
# Each line is its own [Y]-advance box; lines are grouped by background below.
const LINES: Array[String] = [
	# --- Background 1: cauldron_2 ---
	"Ah.",
	"There you are.",
	"I've been waiting for someone willing to look a little closer.",
	"Most people see a mystery and walk away.",
	"You stopped.",
	# --- Background 2: grimoire_1 ---
	"Questions can be found in strange places.",
	"Between the pages of forgotten books.",
	"Beneath dust and silence.",
	"Most people stop searching after the first answer.",
	"I've never been very good at that.",
	# --- Background 3: shelves_6 ---
	"Curiosity is a peculiar thing.",
	"It begins with a single thought.",
	"A single question.",
	"And before long, you're surrounded by possibilities.",
	# --- Background 4: shelves_2 ---
	"Every discovery starts the same way.",
	"A strange object.",
	"An unusual sound.",
	"A detail no one else noticed.",
	"A question that refuses to leave.",
	# --- Background 5: shelves_1 ---
	"Questions have a habit of growing.",
	"The more you chase them...",
	"The more they seem to multiply.",
	"Until answers become all you can think about.",
	# --- Background 6: tent_3 ---
	"I know this because I followed mine.",
	"Through forgotten stories.",
	"Through relics and abandoned places.",
	"And eventually...",
	"I found a door.",
	"Then another.",
	"Then another.",
	"Come.",
	"I'd like to show you what's waiting beyond them.",
]

# Which background each line shows on (index into BACKGROUNDS). The background
# cross-fades to the next exactly when its labeled group begins.
const BG_FOR_LINE: Array[int] = [
	0, 0, 0, 0, 0,      # cauldron_2  (5 lines)
	1, 1, 1, 1, 1,      # grimoire_1  (5 lines)
	2, 2, 2, 2,         # shelves_6   (4 lines)
	3, 3, 3, 3, 3,      # shelves_2   (5 lines)
	4, 4, 4, 4,         # shelves_1   (4 lines)
	5, 5, 5, 5, 5, 5, 5, 5, 5,  # tent_3 (9 lines)
]

var _current_bg: int = 0
var _fade_tween: Tween

@onready var _bg_a: TextureRect = $Background/BgA
@onready var _bg_b: TextureRect = $Background/BgB
@onready var _dialogue: CanvasLayer = $DialogueBox
@onready var _lid: ColorRect = $Eyelids/Lid
@onready var _vignette: TextureRect = $Eyelids/Vignette
@onready var _effects: Node2D = $BgEffects
@onready var _dlg_panel: Control = $DialogueBox/Panel


func _ready() -> void:
	# Show the first background immediately; the second layer rides on top and
	# only fades in when we cross to a new image. Cauldron 2 sits visible under
	# the black "eyelid" overlay from frame one so the blink reveals it.
	_bg_a.texture = load(BACKGROUNDS[0])
	_bg_a.modulate.a = 1.0
	_bg_b.modulate.a = 0.0
	_current_bg = 0

	# Light up only the first background's tailored effects; the rest stay cold.
	_effects.set_active(0)

	_dialogue.line_changed.connect(_on_line_changed)
	_dialogue.finished.connect(_on_finished)

	# Hold the dialogue back — and freeze its input/process — until the player
	# has "opened their eyes". Otherwise a stray key/click during the blink
	# could advance an empty line straight into the hub.
	_dialogue.visible = false
	_dialogue.process_mode = Node.PROCESS_MODE_DISABLED

	_play_wakeup()


# WAKING UP. A black overlay plays the part of eyelids: a groggy hold on black,
# then real-feeling flutters — closings FAST, openings slightly slower — before
# settling fully open. A faint vignette lingers at the edges and lifts as the
# eyes clear. Dialogue only begins once this completes.
#
# Lid alpha timeline (TRANS_SINE, EASE_IN_OUT throughout; ~2.45s total):
#   hold 0.70  · eyes shut, groggy
#   1.0→0.40  0.30  · first crack, slow
#   0.40→0.85 0.15  · heavy blink shut, fast
#   0.85→0.15 0.35  · open wider, slow
#   0.15→0.40 0.10  · quick half-blink shut, fast
#   0.40→0.10 0.10  · re-open
#   0.10→0.0  0.50  · settle fully open
#   hold 0.25  · beat before Curiosity speaks
func _play_wakeup() -> void:
	_lid.color.a = 1.0
	_vignette.modulate.a = 1.0

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.70)
	tw.tween_property(_lid, "color:a", 0.40, 0.30)   # crack open (slow)
	tw.tween_property(_lid, "color:a", 0.85, 0.15)   # blink shut (fast)
	tw.tween_property(_lid, "color:a", 0.15, 0.35)   # open wider (slow)
	tw.tween_property(_lid, "color:a", 0.40, 0.10)   # half-blink (fast)
	tw.tween_property(_lid, "color:a", 0.10, 0.10)   # re-open
	tw.tween_property(_lid, "color:a", 0.0, 0.50)    # settle fully open
	tw.tween_interval(0.25)
	tw.tween_callback(_begin_dialogue)

	# Grogginess clears in parallel: the edge vignette lifts as the eyes wake.
	var vg: Tween = create_tween()
	vg.tween_interval(0.70)
	vg.tween_property(_vignette, "modulate:a", 0.0, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _begin_dialogue() -> void:
	_dialogue.process_mode = Node.PROCESS_MODE_INHERIT
	_dialogue.visible = true
	_dialogue.start(LINES)


func _on_line_changed(index: int) -> void:
	if index < 0 or index >= BG_FOR_LINE.size():
		return
	# Opening line on Cauldron 2: the smoke spirit quietly notices the player.
	if index == 0:
		_effects.spirit_react()
	var target: int = BG_FOR_LINE[index]
	if target != _current_bg:
		# Leaving Shelves 6 for Shelves 2 gets the flask dive; everything else
		# uses the normal cross-fade.
		if _current_bg == SHELVES6_BG and target == SHELVES2_BG:
			_dive_to(target)
		else:
			_crossfade_to(target)


# Cross-fade BgA -> next image over FADE_TIME by fading BgB in on top, then
# settling the result back onto BgA so the next fade starts clean.
func _crossfade_to(bg_index: int) -> void:
	_current_bg = bg_index
	# Hand the tailored effects over in lockstep with the image cross-fade so
	# only the incoming (and briefly outgoing) background's effects run.
	_effects.set_active(bg_index)
	_bg_b.texture = load(BACKGROUNDS[bg_index])
	_bg_b.modulate.a = 0.0

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_bg_b, "modulate:a", 1.0, FADE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_callback(func() -> void:
		_bg_a.texture = _bg_b.texture
		_bg_a.modulate.a = 1.0
		_bg_b.modulate.a = 0.0)


# DIVE INTO THE FLASK — the Shelves 6 -> Shelves 2 special transition. Fly the
# current background (Shelves 6, settled on BgA) into the central flask while
# Shelves 2 (on BgB) is revealed already zoomed-in and settles back to normal.
# The two zooming layers cross-dissolve at the peak — both in motion, so there's
# no white frame and no hard cut: it reads as passing through the glass.
func _dive_to(bg_index: int) -> void:
	_current_bg = bg_index
	# Pause Shelves 6's tailored mist the moment the dive starts.
	_effects.deactivate_current()
	# Freeze the typewriter so the next line doesn't type out behind the dive.
	_dialogue.process_mode = Node.PROCESS_MODE_DISABLED

	# Focal point in the background's local pixels, and the pan that carries it
	# to screen centre as it grows.
	var focal: Vector2 = Vector2(DIVE_FOCAL.x * 1920.0, DIVE_FOCAL.y * 1080.0)
	# Lock the orb and grow straight into it (pivot at the focal point, no pan)
	# so there's no lateral drift — a tight, dead-straight dive.
	_bg_a.pivot_offset = focal
	_bg_a.position = Vector2.ZERO

	# The exact scale BgA reaches the instant the dissolve begins (cubic ease-in,
	# so progress^3). BgB starts at that same scale, on the same focal centre, so
	# the cross-dissolve has zero size or position mismatch. Derived from the
	# constants above, so it stays matched if they're nudged.
	var p: float = (DIVE_TIME - DIVE_XFADE) / DIVE_TIME
	var emerge: float = 1.0 + (DIVE_PEAK_SCALE - 1.0) * p * p * p

	_bg_b.texture = load(BACKGROUNDS[bg_index])
	_bg_b.pivot_offset = focal
	_bg_b.position = Vector2.ZERO
	_bg_b.scale = Vector2(emerge, emerge)
	_bg_b.modulate.a = 0.0
	# Shelves 2's effects come alive as we surface inside the flask.
	_effects.set_active(bg_index)

	var xfade_begin: float = DIVE_DLG_FADE + DIVE_TIME - DIVE_XFADE
	var total: float = xfade_begin + DIVE_XFADE + DIVE_SETTLE

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	# Hide the dialogue first.
	_fade_tween.tween_property(_dlg_panel, "modulate:a", 0.0, DIVE_DLG_FADE)
	# Fly straight into the flask, accelerating inward (ease-in).
	_fade_tween.tween_property(_bg_a, "scale",
		Vector2(DIVE_PEAK_SCALE, DIVE_PEAK_SCALE), DIVE_TIME) \
		.set_delay(DIVE_DLG_FADE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Cross-dissolve at the peak: Shelves 6 out, Shelves 2 in — co-centred and
	# scale-matched at the hand-off.
	_fade_tween.tween_property(_bg_a, "modulate:a", 0.0, DIVE_XFADE) \
		.set_delay(xfade_begin).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(_bg_b, "modulate:a", 1.0, DIVE_XFADE) \
		.set_delay(xfade_begin).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Shelves 2 settles from the matched scale down to normal, decelerating.
	_fade_tween.tween_property(_bg_b, "scale", Vector2.ONE, DIVE_XFADE + DIVE_SETTLE) \
		.set_delay(xfade_begin).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_callback(_dive_finished).set_delay(total)


func _dive_finished() -> void:
	# Settle Shelves 2 back onto BgA so future cross-fades start from the usual
	# state (current image on BgA at scale 1, BgB hidden).
	_bg_a.texture = _bg_b.texture
	_bg_a.scale = Vector2.ONE
	_bg_a.position = Vector2.ZERO
	_bg_a.pivot_offset = Vector2.ZERO
	_bg_a.modulate.a = 1.0
	_bg_b.modulate.a = 0.0
	_bg_b.scale = Vector2.ONE
	_bg_b.pivot_offset = Vector2.ZERO
	# Bring the dialogue back; the frozen line resumes typing on the far side.
	_dialogue.process_mode = Node.PROCESS_MODE_INHERIT
	var tw := create_tween()
	tw.tween_property(_dlg_panel, "modulate:a", 1.0, 0.4)


func _on_finished() -> void:
	# Hand off to the hub with the shared fade-to-black transition.
	Transition.transition_to(HUB_PATH)
