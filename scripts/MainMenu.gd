@tool
extends Node2D
## Main menu — STEP 0: background in, graded, static.
##
## No mist, no parallax, no animation, no idle drift, no breathing zoom. The frame
## holds still on purpose so the grade and the title can be judged on their own.
##
## Harness: MENU_SHOT=<path> saves a screenshot and quits.
## MENU_SHOT_DELAY=<seconds> if the default settle time isn't enough.

## STEP 0b — title sizing. The full 1199x900 art carries a top flourish and an eye
## divider above the lettering, which crowded the frame's crown ornament; this region
## drops them and keeps the lettering plus the bottom flourish.
## `@tool` so these three re-apply live in the editor, not only at runtime.
## y=232 not 218: the top flourish's central drop ornament tapers down to y=230, so a
## crop at 218 sliced it mid-taper and left a white sliver above the lettering (which
## itself starts at y=233).
## AMENDED for the glow: the art is now `title_plate.png`, which has those ornaments erased
## rather than cropped away, so the region can open up (232 -> 202 at the top, 875 -> 900 at
## the bottom) and give the light somewhere to fall. A crop line 1px above the C's crown cut
## the glow flat across the top of the title. `title_top` moved with it to keep the
## lettering on exactly the same pixel.
@export var title_region := Rect2(0.0, 202.0, 1199.0, 698.0):
	set(v):
		title_region = v
		_apply_title()
@export_range(0.05, 2.0, 0.01) var title_scale := 0.55:
	set(v):
		title_scale = v
		_apply_title()
## With no ornament left between the crown and the cap line, a tighter gap reads
## deliberate rather than cramped. y=230 is the floor — below that the "U" stem starts
## crowding the crown arch's feet.
@export var title_top := 223.5:
	set(v):
		title_top = v
		_apply_title()

## The frame is the same cream as the title, at the same value, so the two competed.
## Pulled slightly warm/down so the title's pure #EAE6DA stays the brightest cream on
## screen. 0.62 -> 0.44 on Advika's call ("the border looks too much"): the filigree is
## dense, and at full weight a busy ornament competes with the lettering it is framing.
## 0.62 -> 0.44 -> 0.34 -> 0.26, dimmed three times. This is now BELOW the point where the
## thinnest corner strokes hold up on their own, so the cream is also pulled toward the
## painting's own warmth — a dim NEUTRAL cream reads as a grey smudge, a dim warm one reads
## as faded ink. That is what buys the extra headroom.
@export var frame_modulate := Color(0.93, 0.88, 0.79, 0.26):
	set(v):
		frame_modulate = v
		_apply_frame()

## How far past the screen edge the frame is drawn, in px per side. The art carries ~30px
## of transparent margin outside its outermost rule, so fitted exactly to the viewport the
## border floats ~34px inside the edge and reads as a picture sitting on the screen rather
## than as the screen's own edging. Bleeding it out drops that margin off-frame.
## Past ~40 the corner eyes start losing their outer filigree.
@export_range(0.0, 60.0, 1.0) var frame_bleed := 26.0:
	set(v):
		frame_bleed = v
		_fit_layers()

## The opener starts with the BORDER INSCRIBING ITSELF over the bare painting, and only once
## it has closed does the title's pen begin. It uses the title's own write-on shader with
## its own order map (tools/make_frame_draw_order.py): the draw starts at the crown eye and
## runs down BOTH sides at once, meeting at the moon ornament on the bottom rule — so the
## border closes on a feature instead of in the middle of a blank line, and the whole plate
## reads as one hand making it. A plain fade was the first pass; this says the same thing
## the title does.
## The eyes ride the same clock — a glow with no ornament under it yet reads as a bloom
## artifact.
@export var frame_fade_time := 3.5
## A beat between the border settling and the first stroke. Without it the two run into
## each other and the sequencing is lost.
@export var frame_fade_gap := 0.35

## STEP 2 — breathing zoom, on BGBase ONLY. The mist layers, the frame and the title
## must never scale with it: if the frame breathes too, the whole screen reads as a
## wobbling sticker instead of the room drifting toward you.
## Past ~20s the period stops reading as a rhythm and starts reading as a bug.
@export var breath_period := 16.0
## Oscillates between 1.000 and 1.000 + this, never below — so the cover scale is the
## floor and no overscan is needed. Drop to 0.020 before touching the period.
@export var breath_amplitude := 0.035
## The VANISHING POINT, not the geometric centre. Scaling about the centre reads as
## flat zoom; scaling about where the corridor recedes reads as forward travel.
@export var breath_pivot := Vector2(0.50, 0.42)

## Softness of the painting behind everything, in screen pixels of reach (BlurH + BlurV).
## The plate is a title screen, not a location — the corridor is a mood, and the lettering
## is the only thing that should be in focus. 0 turns it off.
@export_range(0.0, 40.0, 0.5) var background_blur := 9.0:
	set(v):
		background_blur = v
		_apply_blur()

## STEP 3 — the entries. Cinzel (the tarot's font) in caps with real tracking: the
## painted title is an engraved roman serif, so anything with lowercase or tight
## spacing under it reads as UI pasted onto art instead of part of the plate.
## The title hangs off a Node2D, and the FLOAT MOVES THAT NODE, not the TextureRect.
## Godot rounds Control positions to whole pixels (gui/common/snap_controls_to_pixels is on
## by default), so animating the rect directly made the title hold still and then jump a
## whole pixel — measured: the computed offset swept 6.00 -> 4.99px while the rendered
## position sat flat and then stepped. That stepping is what read as "glitchy". Node2D
## transforms are not snapped, so the same sine drawn through this parent is smooth.
const TITLE_PATH := "TitleAnchor/Title"
const TITLE_ANCHOR := "TitleAnchor"

## The menu bed — "Starfall Dreams (Loop)" from the JRPG pack, Advika's pick. The LOOP cut,
## not the full one, so it cycles under a screen the player may sit on for a while.
const MENU_TRACK := "res://assets/audio/menu_starfall_dreams.ogg"
## Synthesised in tools/make_menu_sfx.py. The move tick is quiet on purpose — it fires on
## every keypress, and anything with presence becomes a nuisance by the third press.
const SFX_MOVE := "res://assets/audio/ui/menu_move.wav"
const SFX_SELECT := "res://assets/audio/ui/menu_select.wav"
@export_range(-40.0, 6.0, 0.5) var sfx_move_db := -23.0
@export_range(-40.0, 6.0, 0.5) var sfx_select_db := -15.0
## From the top, with the border. Waiting for the first stroke of the title was tried and
## reverted — starting the plate in silence made the border draw feel like it was happening
## before the scene had begun.
@export var music_fade := 4.5

## The entries' face. Exported so it can be swapped without touching code — the candidates
## live in assets/fonts/candidates/.
## Cormorant Infant Italic. Cinzel's engraved roman caps read as a system menu bolted onto
## somebody's artwork; Petit Formal Script went too far the other way — a true script under
## a painted title makes two competing hands on one plate. This is the middle: an italic
## with the title's delicacy and its hairline contrast, still a serif, still legible small.
## Judged against Petit Formal, Junge, Amiri, Playfair, Cardo, Bodoni Moda, Spectral,
## Italiana, IM Fell and EB Garamond.
@export_file("*.ttf") var menu_font_path := "res://assets/fonts/candidates/cormorant_infant_italic.ttf":
	set(v):
		menu_font_path = v
		_build_menu()
## Roman caps want uppercase; italics and scripts want their own case, since capitalising a
## script face throws away the letterforms that make it one.
@export var menu_uppercase := false:
	set(v):
		menu_uppercase = v
		_build_menu()
const CREAM := Color(0.918, 0.902, 0.855)  # #EAE6DA — the title's own cream
const HUB_SCENE := "res://scenes/Hub.tscn"

## Vertical CENTRES, one per entry, not a top + spacing: the runway between the title
## flourish (bottom y=556) and the frame ornament (top y=914) is only 358px, and these
## three sit inside the dark band of the painting (luminance 0.14-0.17) with 94px of air
## above and 88px below. Anything lower than ~840 lands on the lit floor (luminance 0.30)
## where cream stops separating from the background.
## Per-entry rather than derived so hiding one (QUIT on web) never reflows the others —
## a menu that changes shape between launches reads as a bug.
## Four entries, 78px apart. Dropped 30px as a block on Advika's call — the block sat high
## in its runway and crowded the title's flourish. QUIT now sits at 882, into the top of the
## lit floor, and stays legible only because the grade's `floor_scrim` already darkens the
## bottom-centre. Much lower than this and cream stops separating from that ground.
@export var begin_y := 648.0:
	set(v):
		begin_y = v
		_layout_menu()
@export var continue_y := 726.0:
	set(v):
		continue_y = v
		_layout_menu()
@export var settings_y := 804.0:
	set(v):
		settings_y = v
		_layout_menu()
@export var quit_y := 882.0:
	set(v):
		quit_y = v
		_layout_menu()
## 36 for Cormorant: it is drawn on a small x-height, so it needs more nominal size than a
## caps face to read at the same visual weight.
@export_range(16, 96, 1) var menu_font_size := 36:
	set(v):
		menu_font_size = v
		_build_menu()
## 4: an italic wants a little air but not caps-tracking — that pulls the slant apart and
## the word stops flowing.
@export_range(0, 20, 1) var menu_tracking := 4:
	set(v):
		menu_tracking = v
		_build_menu()
## Resting weight of an unselected entry. The selected one always sits at full cream, so
## this is really "how far the others recede" — under 0.40 they stop reading as choices.
@export_range(0.2, 1.0, 0.01) var menu_dim := 0.55:
	set(v):
		menu_dim = v
		_paint_menu()
## CONTINUE is always ON THE PLATE, greyed out until a save exists — that tells a first-time
## player the game remembers them, and the menu keeps its shape on the second launch.
@export_range(0.1, 1.0, 0.01) var disabled_dim := 0.4:
	set(v):
		disabled_dim = v
		_paint_menu()
## Force the enabled look without a save file, for judging the lit state.
@export var preview_continue_enabled := false:
	set(v):
		preview_continue_enabled = v
		_build_menu()

## Dust hanging in the corridor light. The plate had nothing in it that MOVED at a human
## scale — the breath is too slow to notice and the mist is a field, not an object — so the
## room read as a painting rather than a place. A few motes drifting up through the shaft
## is what the art bible asks for everywhere else in the game.
@export_range(0.0, 2.0, 0.05) var motes_strength := 1.0:
	set(v):
		motes_strength = v
		_apply_motes()
## The eyes on the frame — the crown and all four corners — breathing. They are the game's
## signature mark and they sat inert while everything else came alive. They do NOT breathe
## together: each wakes a fifth of a cycle after the last, so attention travels around the
## frame instead of the whole border pulsing like one lamp.
@export_range(0.0, 0.6, 0.01) var eye_glow := 0.16:
	set(v):
		eye_glow = v
		_build_eyes()
## Deliberately NOT the title's 6.5s: two glows on the same period read as one mechanism
## blinking, and the point is separate living things sharing a room.
@export var eye_glow_period := 9.0
## Fractions of the viewport, so they stay on the ornament at any window size. Crown first,
## then the corners in a ring — the order the light travels.
const EYE_SPOTS := [
	{"uv": Vector2(0.500, 0.132), "scale": 7.0},
	{"uv": Vector2(0.944, 0.106), "scale": 4.6},
	{"uv": Vector2(0.944, 0.894), "scale": 4.6},
	{"uv": Vector2(0.056, 0.894), "scale": 4.6},
	{"uv": Vector2(0.056, 0.106), "scale": 4.6},
]

## The far light in the corridor, breathing. Two out-of-phase sines rather than one — the
## same trick the lantern uses in-game, and the reason it reads as a flame at a distance
## instead of a fader being ridden up and down.
@export_range(0.0, 0.3, 0.005) var light_breath := 0.06

## How lit the letters are at rest. The nib that writes them is separate (it lives on the
## material); this is the light they hold afterwards. Past ~0.6 the letterforms stop having
## edges and the title reads as a light source rather than as lettering.
@export_range(0.0, 1.5, 0.01) var title_glow := 0.35:
	set(v):
		title_glow = v
		_apply_glow()

## STEP 4 — the write-on. 2.6s -> 3.8s -> 5.0s, slowed twice on Advika's call. At the quick
## pace the hand read as hurried; the whole point is that something is being inscribed, and
## a title screen is the one place a player is happy to wait. Now 6.5s (2.6 -> 3.8 -> 5.0 ->
## 6.5, slowed three times) — at this pace you can watch individual letters being formed.
@export var write_on_duration := 6.5
## The entries wait for the writing to FINISH, then arrive — Advika's call. They used to
## start 0.2s early, which put the first label on screen while the flourish was still being
## drawn and split your attention at the one moment the title has it. `_entry_delay()`
## enforces the floor, so this can never accidentally overlap the writing again.
@export var labels_fade_start := 0.35
@export var labels_fade_time := 0.4
## Entries arrive one after another rather than as a block, each rising the last few px into
## place. Past ~0.25s of stagger they stop reading as one group.
@export var entries_stagger := 0.14
@export var entries_rise := 10.0

## Once the writing is finished the title comes UNMOORED and floats — Advika's call. It
## only starts once the last stroke lands, and eases in over `title_float_ramp` so nothing
## jumps at the handover.
##
## The whole title, slightly up and down. One sine, one axis, nothing else.
@export_range(0.0, 20.0, 0.5) var title_float := 6.0
@export var title_float_period := 8.0
@export var title_float_ramp := 1.6

var _bg: Sprite2D
var _bg_rest_pos := Vector2.ZERO
var _bg_rest_scale := Vector2.ONE
var _breath_t := 0.0

var _entries: Array[Dictionary] = []   # {id, label: Label, hit: Control}
var _selected := 0
var _rule: ColorRect                   # the hairline under the selected entry
var _rule_tween: Tween
var _committed := false                # one choice only; ignore input after
var _title_base := Vector2.ZERO        # where the title sits before it starts drifting
var _float_since := -1.0               # seconds-clock when the writing finished; -1 = still writing
var _float_at := -1.0                  # MENU_FLOAT_AT override: pin the float clock here
var _eyes_gate := 1.0                  # 0 while the border is still fading in


func _ready() -> void:
	_apply_title()
	_apply_frame()
	_apply_blur()
	_apply_glow()
	_apply_motes()
	_build_light()
	_build_eyes()
	_layout_living()   # the dust needs placing even if both glows are dialled to zero
	_build_menu()
	_bg = get_node_or_null("BGBase") as Sprite2D
	_fit_background()
	# aspect=expand means the viewport really does change size under us; the title and the
	# entries are both centred by hand, so they have to be told.
	get_viewport().size_changed.connect(_on_viewport_resized)
	if Engine.is_editor_hint():
		return
	# MENU_BREATH_FREEZE=<k>: pin the zoom at a given factor (1.0 = the cover scale) so
	# the edge-reveal case can be shot deliberately instead of waited for.
	if OS.get_environment("MENU_BREATH_CHECK") != "":
		_print_cover_check()
	# MENU_HIDE=MistFar,Motes,...: drop named layers for forensics. When an artifact is
	# visible in the composite, the only reliable way to find its owner is to switch layers
	# off one at a time and diff — theorising about which shader "should" be responsible
	# has been wrong more often than right on this project.
	if OS.get_environment("MENU_HIDE") != "":
		for n in OS.get_environment("MENU_HIDE").split(","):
			var node := get_node_or_null(NodePath(n.strip_edges())) as CanvasItem
			if node != null:
				node.visible = false
	# MENU_FACE=<res path>[,caps|mixed]: try a different face for the entries in a still.
	if OS.get_environment("MENU_FACE") != "":
		var parts := OS.get_environment("MENU_FACE").split(",")
		menu_uppercase = parts.size() < 2 or parts[1].strip_edges() == "caps"
		menu_font_path = parts[0].strip_edges()
	# MENU_GLOW / MENU_BLUR: override the two look dials for A/B stills.
	if OS.get_environment("MENU_GLOW") != "":
		title_glow = float(OS.get_environment("MENU_GLOW"))
	if OS.get_environment("MENU_BLUR") != "":
		background_blur = float(OS.get_environment("MENU_BLUR"))
	# A STILL wants the finished plate; a sequence capture is here precisely to watch the
	# motion, so only MENU_SHOT suppresses the openers.
	var still := OS.get_environment("MENU_SHOT") != ""
	# MENU_WRITE=<0..1>: pin the write-on at one moment so any point of it can be shot
	# deliberately. Otherwise stills are of the finished title, never a half-written one.
	# MENU_FRAME_AT=<0..1>: pin the border's draw partway, to judge where the line has got to
	if OS.get_environment("MENU_FRAME_AT") != "":
		_set_frame_progress(float(OS.get_environment("MENU_FRAME_AT")))
	if OS.get_environment("MENU_WRITE") != "":
		_set_write_progress(float(OS.get_environment("MENU_WRITE")))
	elif not still:
		_play_frame_in()
		_play_write_on()
	if not still:
		_play_music()
	# MENU_SEL=<i>: shoot with entry i highlighted, so the selected state of every entry
	# can be checked without driving the keyboard.
	if OS.get_environment("MENU_SEL") != "":
		_selected = clampi(int(OS.get_environment("MENU_SEL")), 0, maxi(0, _entries.size() - 1))
		_paint_menu()
		_snap_rule()
	# The entries arrive after the writing, not with it — the eye should be on the title
	# while it is being made. Skipped for captures so a still isn't of a half-faded menu.
	if not still:
		_play_entries_in()
	# MENU_FLOAT_AT=<seconds>: pin the float at one moment of its cycle so stills can be
	# taken across it. Used to measure whether the title actually moves in fractions of a
	# pixel or snaps to whole ones.
	if OS.get_environment("MENU_FLOAT_AT") != "":
		_float_since = 0.0
		_float_at = float(OS.get_environment("MENU_FLOAT_AT"))
	# MENU_PROBE=<t0,t1,...>: print the opener's actual state at those moments and quit.
	# A screenshot cannot answer "is the menu up yet" for a still capture (stills skip the
	# openers on purpose), so timing bugs need their own instrument.
	if OS.get_environment("MENU_PROBE") != "":
		_probe(OS.get_environment("MENU_PROBE"))
	# MENU_AUTOCOMMIT=<seconds>: take the selected entry unattended, so the hand-off into
	# the Hub can be proven from a script instead of by hand.
	if OS.get_environment("MENU_AUTOCOMMIT") != "":
		await get_tree().create_timer(float(OS.get_environment("MENU_AUTOCOMMIT"))).timeout
		_commit()
	if OS.get_environment("MENU_SEQ") != "":
		_shoot_sequence(OS.get_environment("MENU_SEQ"))
	elif OS.get_environment("MENU_SHOT") != "":
		_shot(OS.get_environment("MENU_SHOT"))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var t: float = float(Time.get_ticks_msec()) * 0.001
	_breathe_living(t)
	_breathe_selected(t)
	_float_title(t)
	if _bg == null:
		return
	var frozen := OS.get_environment("MENU_BREATH_FREEZE")
	if frozen != "":
		_apply_breath(float(frozen))
		return
	_breath_t += delta
	# (1 - cos)/2 runs 0 -> 1 -> 0, so k spans exactly 1.000 .. 1.000+amplitude and
	# STARTS at 1.000. A plain sine would have sat mid-travel at t=0.
	var phase: float = TAU * _breath_t / maxf(0.001, breath_period)
	_apply_breath(1.0 + breath_amplitude * 0.5 * (1.0 - cos(phase)))


## The eyes swell and settle a fifth of a cycle apart, so the light travels around the frame
## rather than the whole border pulsing as one lamp. ±40% of resting weight — enough that
## the border is never quite still, not enough to pull the eye off the title.
## The corridor light breathes here too, on two out-of-phase sines: one period alone reads
## as a fader being ridden, two beating against each other read as a flame far away.
func _breathe_living(t: float) -> void:
	var eyes := get_node_or_null("Eyes")
	if eyes != null and eye_glow > 0.0:
		var n: int = eyes.get_child_count()
		for i in n:
			var phase: float = TAU * (t / maxf(0.001, eye_glow_period) + float(i) / float(n))
			(eyes.get_child(i) as Sprite2D).modulate.a = \
					_eyes_gate * eye_glow * (1.0 + 0.4 * sin(phase))
	var light := get_node_or_null("LightBreath") as Sprite2D
	if light != null and light_breath > 0.0:
		var k: float = 1.0 + 0.22 * sin(t * 0.53) + 0.13 * sin(t * 1.31 + 1.7)
		light.modulate.a = light_breath * k


## Scale about `breath_pivot` rather than the sprite's own centre: a Sprite2D scales
## about its origin, so the position has to travel with the scale to keep the pivot
## fixed on screen.
func _apply_breath(k: float) -> void:
	var p: Vector2 = get_viewport_rect().size * breath_pivot
	_bg.position = p + (_bg_rest_pos - p) * k
	_bg.scale = _bg_rest_scale * k


## Proof there is no edge reveal at k = 1.000 — the one scale where a gap could open.
func _print_cover_check() -> void:
	_apply_breath(1.0)
	var vp: Vector2 = get_viewport_rect().size
	var half: Vector2 = _bg.texture.get_size() * _bg.scale * 0.5
	var tl: Vector2 = _bg.position - half
	var br: Vector2 = _bg.position + half
	print("COVER CHECK k=1.000  bg rect (%.2f, %.2f)-(%.2f, %.2f)  viewport (0,0)-(%.0f, %.0f)"
			% [tl.x, tl.y, br.x, br.y, vp.x, vp.y])
	print("COVER CHECK covered=%s  (left %.2f top %.2f right %.2f bottom %.2f slack)"
			% [tl.x <= 0.0 and tl.y <= 0.0 and br.x >= vp.x and br.y >= vp.y,
			-tl.x, -tl.y, br.x - vp.x, br.y - vp.y])


## Crop the title to `title_region`, scale it, and centre it horizontally with its top
## edge at `title_top`. Driven from code as well as the scene so the exported values
## stay the single source of truth.
func _apply_title() -> void:
	if not is_inside_tree():
		return
	var title := get_node_or_null(TITLE_PATH) as TextureRect
	if title == null:
		return
	var atlas := title.texture as AtlasTexture
	if atlas != null:
		atlas.region = title_region
	var w: float = title_region.size.x * title_scale
	var h: float = title_region.size.y * title_scale
	title.size = Vector2(w, h)
	_title_base = Vector2((get_viewport_rect().size.x - w) * 0.5, title_top * _vscale())
	title.position = _title_base


func _apply_motes() -> void:
	if not is_inside_tree():
		return
	for name in ["Motes", "MotesNear"]:
		var m := get_node_or_null(NodePath(name)) as CPUParticles2D
		if m != null:
			m.modulate.a = clampf(motes_strength, 0.0, 1.0)
			m.emitting = motes_strength > 0.0


## A soft radial dot, built in code so the living elements need no art.
func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	# 128, not 64: the corridor light stretches this to ~1600px, and at 64 each texel spans
	# 26 screen px, which is wide enough for the steps between them to contour.
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## Built rather than placed: the spots are viewport fractions, so they have to be laid out
## against the live viewport, and there are five of them wanting one shared texture.
func _build_eyes() -> void:
	if not is_inside_tree():
		return
	var old := get_node_or_null("Eyes")
	if old != null:
		old.free()
	if eye_glow <= 0.0:
		return
	var root := Node2D.new()
	root.name = "Eyes"
	add_child(root)
	# under the frame art, never over the title
	var frame := get_node_or_null("Frame")
	if frame != null:
		move_child(root, frame.get_index())
	var tex := _dot_texture()
	for spot in EYE_SPOTS:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * float(spot.scale)
		s.modulate = Color(1.0, 0.9, 0.72, eye_glow)
		root.add_child(s)
	_layout_living()


func _build_light() -> void:
	if not is_inside_tree():
		return
	var old := get_node_or_null("LightBreath")
	if old != null:
		old.free()
	if light_breath <= 0.0:
		return
	var s := Sprite2D.new()
	s.name = "LightBreath"
	s.texture = _dot_texture()
	s.scale = Vector2.ONE * 26.0
	s.modulate = Color(1.0, 0.88, 0.66, light_breath)
	add_child(s)
	# behind the mist, so the mist drifts THROUGH the light rather than under it
	var mist := get_node_or_null("MistFar")
	if mist != null:
		move_child(s, mist.get_index())
	_layout_living()


func _layout_living() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var eyes := get_node_or_null("Eyes")
	if eyes != null:
		for i in mini(eyes.get_child_count(), EYE_SPOTS.size()):
			(eyes.get_child(i) as Sprite2D).position = vp * (EYE_SPOTS[i].uv as Vector2)
	var light := get_node_or_null("LightBreath") as Sprite2D
	if light != null:
		# the bloom in the painting measures at UV (0.49, 0.34)
		light.position = vp * Vector2(0.49, 0.34)
	# the dust volumes are fractions of the frame too, or a tall window leaves the near
	# layer emitting off the bottom of the screen
	# the mist's noise cells are kept square by an aspect uniform, which was baked at 16:9
	# and skews the moment the window is any other shape
	for n in ["MistFar", "MistNear"]:
		var rect := get_node_or_null(NodePath(n)) as ColorRect
		if rect != null and rect.material is ShaderMaterial:
			(rect.material as ShaderMaterial).set_shader_parameter("aspect", vp.x / maxf(1.0, vp.y))
	var far := get_node_or_null("Motes") as CPUParticles2D
	if far != null:
		far.position = vp * Vector2(0.5, 0.648)
		far.emission_rect_extents = vp * Vector2(0.224, 0.306)
	var near := get_node_or_null("MotesNear") as CPUParticles2D
	if near != null:
		near.position = vp * Vector2(0.5, 0.833)
		near.emission_rect_extents = vp * Vector2(0.469, 0.241)


func _apply_glow() -> void:
	if not is_inside_tree():
		return
	var title := get_node_or_null(TITLE_PATH) as TextureRect
	if title == null:
		return
	var mat := title.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("glow_strength", title_glow)


## Both blur passes share one dial — a horizontal reach that differs from the vertical one
## is a smear, not a defocus.
func _apply_blur() -> void:
	if not is_inside_tree():
		return
	for name in ["BlurH", "BlurV"]:
		var rect := get_node_or_null(NodePath(name)) as ColorRect
		if rect == null:
			continue
		rect.visible = background_blur > 0.0
		var mat := rect.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("radius", background_blur)


## Frame weight — see `frame_modulate`.
func _apply_frame() -> void:
	if not is_inside_tree():
		return
	var frame := get_node_or_null("Frame") as TextureRect
	if frame != null:
		frame.modulate = frame_modulate


# ------------------------------------------------------------------------ write-on ----

## Each entry rises the last few pixels into its place and fades up, one after another. A
## block of text appearing all at once reads as a UI panel switching on; arriving in order
## reads as the plate settling.
## `labels_fade_start` is now a PAUSE AFTER the writing, not an absolute time — so slowing
## the write-on can never leave the entries arriving on top of it.
func _entry_delay(i: int) -> float:
	return _write_start() + write_on_duration + maxf(0.0, labels_fade_start) \
			+ entries_stagger * float(i)


func _play_entries_in() -> void:
	for i in _entries.size():
		var slot: Control = _entries[i].slot
		var rest: Vector2 = slot.position
		slot.modulate.a = 0.0
		slot.position = rest + Vector2(0.0, entries_rise)
		var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_interval(_entry_delay(i))
		# NOT parallel() on the fade: parallel() binds a tweener to the PREVIOUS one, so
		# `interval` then `parallel().fade` ran the fade DURING the wait — the entries were
		# up before the title finished, which is the bug this delay exists to prevent. The
		# fade must be sequential; only the rise rides alongside it.
		t.tween_property(slot, "modulate:a", 1.0, labels_fade_time)
		t.parallel().tween_property(slot, "position", rest, labels_fade_time * 1.6)
	# The hairline hangs off the menu root, not off a slot, so fading the slots left it
	# sitting on the plate on its own all through the writing. It arrives with the entry it
	# belongs to.
	if _rule != null:
		_rule.modulate.a = 0.0
		var r := create_tween()
		r.tween_interval(_entry_delay(_selected))
		r.tween_property(_rule, "modulate:a", 1.0, labels_fade_time)


## Put the plate back to the moment before the writing starts and run it again.
func _replay_opener() -> void:
	_play_frame_in()
	_play_entries_in()
	_play_write_on()


## The selected entry is never quite still — it breathes about a tenth of its weight on a
## slow cycle, so the choice you are on looks lit rather than highlighted. Only the selected
## one: if they all breathed, the menu would shimmer.
func _breathe_selected(t: float) -> void:
	if _entries.is_empty() or _selected >= _entries.size():
		return
	if not _entries[_selected].enabled:
		return
	var label: Label = _entries[_selected].label
	label.modulate = Color(CREAM, 1.0 - 0.06 * (1.0 - cos(t * TAU / 2.8)))


## AudioManager owns the crossfade, so leaving the Hub later hands over cleanly instead of
## cutting. Silent-to-full over `music_fade`, starting with the border.
func _play_music() -> void:
	var stream: AudioStream = load(MENU_TRACK)
	if stream == null:
		push_warning("menu track missing: %s" % MENU_TRACK)
		return
	AudioManager.play_ambient(stream, "menu_starfall_dreams", music_fade)


## When the pen starts, measured from the top of the opener.
func _write_start() -> float:
	return frame_fade_time + frame_fade_gap


## The border draws itself in over the bare painting first. `_eyes_gate` scales the eye
## glows so they arrive with the ornament they belong to rather than hovering over nothing.
func _play_frame_in() -> void:
	_eyes_gate = 0.0
	_set_frame_progress(0.0)
	var t := create_tween()
	# linear: the draw runs at a constant hand-speed around the loop. Easing it made the
	# corners arrive in a rush and the bottom rule crawl.
	t.parallel().tween_method(_set_frame_progress, 0.0, 1.0, frame_fade_time)
	# the eyes come up over the back half, so they land as their own corners are drawn
	t.parallel().tween_property(self, "_eyes_gate", 1.0, frame_fade_time) \
			.set_delay(frame_fade_time * 0.5)


func _set_frame_progress(p: float) -> void:
	var frame := get_node_or_null("Frame") as TextureRect
	if frame == null:
		return
	var mat := frame.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("progress", p)


func _play_write_on() -> void:
	_set_write_progress(0.0)
	_float_since = -1.0
	var t := create_tween()
	t.tween_interval(_write_start())
	t.tween_method(_set_write_progress, 0.0, 1.0, write_on_duration)
	t.tween_callback(func() -> void: _float_since = float(Time.get_ticks_msec()) * 0.001)


## The title comes loose once it is finished and drifts. Amplitude eases up from nothing so
## the first pixel of movement doesn't land the instant the pen lifts.
func _float_title(t: float) -> void:
	var title := get_node_or_null(TITLE_PATH) as TextureRect
	if title == null:
		return
	title.scale = Vector2.ONE
	title.position = _title_base
	var anchor := get_node_or_null(TITLE_ANCHOR) as Node2D
	if anchor == null:
		return
	if title_float <= 0.0 or _float_since < 0.0:
		anchor.position = Vector2.ZERO
		return
	if _float_at >= 0.0:
		t = _float_at
	var age: float = t - _float_since
	var ramp: float = clampf(age / maxf(0.001, title_float_ramp), 0.0, 1.0)
	ramp = ramp * ramp * (3.0 - 2.0 * ramp)
	anchor.position = Vector2(0.0,
			ramp * title_float * sin(t * TAU / maxf(0.5, title_float_period)))


## The tween runs dead linear and the shaping happens here: a nib that accelerates through
## the middle of a word looks mechanical, and one that eases hard at both ends looks like
## it is hesitating. 35% of a smoothstep is enough to soften the start and the stop without
## the stroke ever visibly speeding up.
func _set_write_progress(p: float) -> void:
	var title := get_node_or_null(TITLE_PATH) as TextureRect
	if title == null:
		return
	var mat := title.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("progress", lerpf(p, smoothstep(0.0, 1.0, p), 0.35))


## THE FULLSCREEN BUG. The project stretches `canvas_items` with aspect `expand`, so a
## window that is not 16:9 shows MORE canvas than 1920x1080 — and every layer here was
## pinned to exactly 1920x1080, so the extra strip was bare black. The full-screen layers
## are anchored to the viewport now, and the painting is scaled to COVER whatever is
## visible rather than to a fixed 1920 wide.
## Anchors are not an option here: these Controls hang off a Node2D, which has no rect for
## anchors to resolve against — setting them collapsed every layer to zero size. Explicit
## sizing it is.
const FULL_SCREEN_LAYERS := ["BlurH", "BlurV", "BGGrade", "MistFar", "MistNear", "Frame"]


func _fit_layers() -> void:
	if not is_inside_tree():
		return
	var vp: Vector2 = get_viewport_rect().size
	for n in FULL_SCREEN_LAYERS:
		var c := get_node_or_null(NodePath(n)) as Control
		if c == null:
			continue
		# the frame alone is drawn oversized, so its outer margin falls off-screen
		var bleed: float = frame_bleed if n == "Frame" else 0.0
		c.position = Vector2(-bleed, -bleed)
		c.size = vp + Vector2(bleed, bleed) * 2.0


func _fit_background() -> void:
	_fit_layers()
	if _bg == null or _bg.texture == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var ts: Vector2 = _bg.texture.get_size()
	var k: float = maxf(vp.x / ts.x, vp.y / ts.y)
	_bg_rest_scale = Vector2(k, k)
	_bg_rest_pos = vp * 0.5
	_bg.scale = _bg_rest_scale
	_bg.position = _bg_rest_pos


## Vertical positions were measured against the art at 1080 tall. The frame now stretches
## with the window, so the things placed against it have to travel with it too, or the
## title drifts toward the crown on a tall window.
func _vscale() -> float:
	return get_viewport_rect().size.y / 1080.0


func _on_viewport_resized() -> void:
	_fit_background()
	_apply_title()
	_layout_menu()
	_layout_living()


# ---------------------------------------------------------------------------- menu ----

## Rebuild the entry list from scratch. Everything lives under one throwaway `Menu` node
## with no `owner`, so it never serialises into MainMenu.tscn even though this is a @tool
## script — the scene file stays the art plate, the entries stay code.
func _build_menu() -> void:
	if not is_inside_tree():
		return
	var old := get_node_or_null("Menu")
	if old != null:
		old.free()
	_entries.clear()
	_rule = null

	var root := Control.new()
	root.name = "Menu"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var font := FontVariation.new()
	font.base_font = load(menu_font_path)
	font.spacing_glyph = menu_tracking

	for spec in _entry_specs():
		# Each label rides in its own slot. The slot owns the ARRIVAL (a rise and a fade,
		# staggered per entry); the label owns its STATE colour. Two animations on one node
		# would fight over modulate every frame.
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(slot)
		var label := Label.new()
		label.text = String(spec.text) if menu_uppercase else String(spec.text).capitalize()
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", menu_font_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
		# A separate hitbox rather than making the Label itself clickable: the label is
		# only as wide as its glyphs, and a 40px-tall strip of exact letterforms is a
		# miserable mouse target.
		var hit := Control.new()
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(hit)
		var idx := _entries.size()
		hit.mouse_entered.connect(_select.bind(idx))
		hit.gui_input.connect(_on_entry_input.bind(idx))
		_entries.append({"id": spec.id, "label": label, "hit": hit, "slot": slot,
				"y": spec.y, "enabled": spec.enabled})

	# The hairline is the frame's own vocabulary — the plate is drawn in 1px rules, so the
	# selection marker is one too, rather than a highlight box or an arrow.
	_rule = ColorRect.new()
	_rule.color = Color(CREAM, 0.45)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_rule)

	_selected = _first_enabled()
	_layout_menu()
	_paint_menu()
	_snap_rule()


## QUIT is dropped on web, where the browser tab IS the quit button and the entry would do
## nothing. CONTINUE always appears; it is merely disabled when there is no save.
func _entry_specs() -> Array:
	var has_save: bool = preview_continue_enabled
	if not has_save and not Engine.is_editor_hint() and SaveManager != null:
		has_save = SaveManager.has_save()
	var specs := [
		{"id": "begin", "text": "BEGIN", "y": begin_y, "enabled": true},
		{"id": "continue", "text": "CONTINUE", "y": continue_y, "enabled": has_save},
		{"id": "settings", "text": "SETTINGS", "y": settings_y, "enabled": true},
	]
	# QUIT is on web too now (Advika's call) — the two builds show the same four entries.
	# `_commit` drops the browser out of fullscreen before quitting there, so nobody is left
	# staring at a dead canvas filling their screen.
	specs.append({"id": "quit", "text": "QUIT", "y": quit_y, "enabled": true})
	return specs


func _first_enabled() -> int:
	for i in _entries.size():
		if _entries[i].enabled:
			return i
	return 0


func _layout_menu() -> void:
	if _entries.is_empty():
		return
	var vw: float = get_viewport_rect().size.x
	var ys := [begin_y, continue_y, settings_y, quit_y]
	for i in _entries.size():
		# the export setters fire before _build_menu has re-read them into the entry dicts
		_entries[i]["y"] = ys[i] if i < ys.size() else _entries[i].y
		var label: Label = _entries[i].label
		var h: float = label.get_minimum_size().y
		var w: float = label.get_minimum_size().x
		label.size = Vector2(w, h)
		label.position = Vector2.ZERO
		var slot: Control = _entries[i].slot
		slot.size = Vector2(w, h)
		# `y` is the entry's CENTRE, so the labels stay put when the font size changes
		slot.position = Vector2((vw - w) * 0.5, float(_entries[i].y) * _vscale() - h * 0.5)
		var hit: Control = _entries[i].hit
		# generous horizontally, snug vertically — neighbouring entries must not overlap
		hit.size = Vector2(w + 160.0, minf(h, 76.0))
		hit.position = Vector2((vw - hit.size.x) * 0.5, slot.position.y + (h - hit.size.y) * 0.5)
	_snap_rule()


func _paint_menu() -> void:
	for i in _entries.size():
		var label: Label = _entries[i].label
		var a: float = menu_dim
		if not _entries[i].enabled:
			a = disabled_dim
		elif i == _selected:
			a = 1.0
		label.modulate = Color(CREAM, a)
	if _rule != null:
		# a disabled entry can only be reached in the editor; never mark it as a choice
		_rule.visible = not _entries.is_empty() and _entries[_selected].enabled


## Width and position the rule would have if it were finished animating.
func _rule_rect() -> Rect2:
	var slot: Control = _entries[_selected].slot
	var w: float = slot.size.x * 0.78
	return Rect2(slot.position.x + (slot.size.x - w) * 0.5,
			slot.position.y + slot.size.y + 6.0, w, 1.0)


func _snap_rule() -> void:
	if _rule == null or _entries.is_empty():
		return
	var r := _rule_rect()
	_rule.position = r.position
	_rule.size = r.size


func _select(idx: int) -> void:
	if _committed or idx == _selected or idx < 0 or idx >= _entries.size():
		return
	if not _entries[idx].enabled:
		return
	_selected = idx
	_paint_menu()
	if Engine.is_editor_hint():
		_snap_rule()
		return
	AudioManager.play_sfx(load(SFX_MOVE), sfx_move_db)
	# The rule slides between entries instead of cutting — at 0.16s it reads as the same
	# ink being drawn again, not as two different rules.
	var r := _rule_rect()
	if _rule_tween != null and _rule_tween.is_valid():
		_rule_tween.kill()
	_rule_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rule_tween.parallel().tween_property(_rule, "position", r.position, 0.16)
	_rule_tween.parallel().tween_property(_rule, "size", r.size, 0.16)


func _on_entry_input(event: InputEvent, idx: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_select(idx)
		_commit()


func _unhandled_input(event: InputEvent) -> void:
	if _committed or _entries.is_empty() or not event.is_pressed() or event.is_echo():
		return
	# ui_up/ui_down are arrows + gamepad only, and this game is played on WASD as often as
	# not, so W/S are read straight off the key.
	var key := event as InputEventKey
	var k: int = key.keycode if key != null else 0
	# R replays the opener in a debug build — the write-on is 2.6s of timing that can only
	# be judged by watching it, and relaunching the game to see it again is a bad loop.
	if k == KEY_R and OS.is_debug_build():
		_replay_opener()
		return
	if event.is_action("ui_down") or k == KEY_S:
		_step(1)
	elif event.is_action("ui_up") or k == KEY_W:
		_step(-1)
	elif event.is_action("ui_accept") or event.is_action("interact"):
		_commit()


## Walk to the next entry that can actually be chosen — a disabled CONTINUE is a sign, not
## a stop on the way down.
func _step(dir: int) -> void:
	var idx := _selected
	for _i in _entries.size():
		idx = posmod(idx + dir, _entries.size())
		if _entries[idx].enabled:
			_select(idx)
			return


## SETTINGS opens over the plate and hands input back when it closes. The menu keeps
## running underneath — the mist, the dust and the title's drift do not stop for a dialog.
func _open_settings() -> void:
	if get_node_or_null("Settings") != null:
		return
	var panel: SettingsPanel = load("res://scenes/UI/SettingsPanel.tscn").instantiate()
	panel.name = "Settings"
	panel.closed.connect(func() -> void: set_process_unhandled_input(true))
	add_child(panel)
	set_process_unhandled_input(false)   # the panel owns the keyboard while it is up


func _commit() -> void:
	if _committed or _entries.is_empty() or not _entries[_selected].enabled:
		return
	Haptics.buzz(45, 0.35)
	AudioManager.play_sfx(load(SFX_SELECT), sfx_select_db)
	match String(_entries[_selected].id):
		"settings":
			# not a commit — the menu is still live underneath and waiting
			_open_settings()
			return
		"quit":
			_committed = true
			if OS.has_feature("web"):
				ScreenMode.set_fullscreen(false)
			get_tree().quit()
		_:
			# Both Begin and Continue land in the Hub today; Continue diverges when M6
			# teaches the boot flow where the player actually was.
			Transition.transition_to(HUB_SCENE)


## MENU_SEQ=<abs dir>: capture a frame sequence so the motion can actually be watched.
## MENU_SEQ_N / MENU_SEQ_DT tune length and interval.
##
## save_png blocks, so the capture runs slower than real time — but the breath and the
## mist are driven by real delta/TIME, so the WALL-CLOCK span is the true depicted
## duration. It prints frames/elapsed at the end; encode at that fps for real-time
## playback rather than assuming 1/dt.
func _shoot_sequence(dir: String) -> void:
	var n := 480
	var dt := 1.0 / 30.0
	if OS.get_environment("MENU_SEQ_N") != "":
		n = int(OS.get_environment("MENU_SEQ_N"))
	if OS.get_environment("MENU_SEQ_DT") != "":
		dt = float(OS.get_environment("MENU_SEQ_DT"))
	DirAccess.make_dir_recursive_absolute(dir)
	var t0 := Time.get_ticks_msec()
	for i in n:
		await get_tree().create_timer(dt).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [dir, i])
	var elapsed: float = float(Time.get_ticks_msec() - t0) / 1000.0
	print("SEQ frames=%d elapsed=%.2fs realtime_fps=%.3f" % [n, elapsed, float(n) / elapsed])
	get_tree().quit()


func _probe(spec: String) -> void:
	var t0 := float(Time.get_ticks_msec()) * 0.001
	for part in spec.split(","):
		var at := float(part.strip_edges())
		var wait: float = at - (float(Time.get_ticks_msec()) * 0.001 - t0)
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		var mat := (get_node_or_null(TITLE_PATH) as TextureRect).material as ShaderMaterial
		var frame := get_node_or_null("Frame") as TextureRect
		var line := "PROBE t=%.2f  frame=%.2f  write=%.3f  entries=[" % [at,
				frame.modulate.a if frame != null else NAN,
				mat.get_shader_parameter("progress")]
		for e in _entries:
			line += " %s:%.2f" % [String(e.id).substr(0, 3), (e.slot as Control).modulate.a]
		print(line + " ]")
	get_tree().quit()


func _shot(path: String) -> void:
	var delay := 0.8
	if OS.get_environment("MENU_SHOT_DELAY") != "":
		delay = float(OS.get_environment("MENU_SHOT_DELAY"))
	await get_tree().create_timer(delay).timeout
	# two frames after the timer so the backbuffer the grade samples is populated
	await RenderingServer.frame_post_draw
	# report the title's actual offset AT CAPTURE TIME. Reading it from a process_frame
	# signal is useless — that fires before _process, so it always reads the rest pose.
	var anchor := get_node_or_null(TITLE_ANCHOR) as Node2D
	if anchor != null:
		print("SHOT anchor.y=%.4f" % anchor.position.y)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
