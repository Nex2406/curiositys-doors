extends Node2D
## REALM 3 — FUNGAL ENVIRONMENT SHELL, rebuilt to Advika's reference images
## (assets/_reference/realm3_target_*_2026-07-14.png — made from THIS pack).
## The refs' construction grammar, followed exactly:
##   - terrain = near-black navy FILL BODIES rimmed with the pack's pebble
##     frames/strips (fungalground), never bare rock sprites
##   - every surface wears a dense frond FRINGE (blue coral tufts) — growing
##     up from floors/platform tops, hanging down from ceilings/undersides
##   - props live in grouped, grounded assemblies: pots + boulders + gold
##     spore stalks + curled sprouts (ref 1), white glow-mushrooms on the
##     platform stack (ref 2), big flat-caps on a stone shelf (ref 3)
##   - background = dark silhouette bands (value hierarchy: far darkest ->
##     mid dark -> gameplay lighter); foreground = near-black anchor layer
## MOOD (Advika, 2026-07-14): Realm 2's darkness recipe hue-shifted to deep
## teal-green (#122B28 -> #0A1614, teal grade). ALL glows warm amber.
## Purple is reserved for Curiosity + UI — none in the environment.
## Environment ONLY: no enemies, no puzzle. Zones, left to right:
##   A cavern mouth (ref 3) -> B pot-strewn floor + hanging chunk (ref 1)
##   -> C overgrown platform stack under a fringed ceiling (ref 2).
## Controls: Curiosity's own. R restarts. ESC returns to the Hub.
## R3_SHOT env: screenshot at 1s + quit. R3_SHOT_X: park the hero first.
## R3_SHOT_CAMY: freeze the camera at a fixed Y (inspect the jump/roof view).

const BASE := "res://assets/realms/realm3_fungal/"
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const HUB_SCENE := "res://scenes/Hub.tscn"
const STARTING_LIVES: int = 3

## HOW BIG SHE READS IN THIS FOREST — 0.33, up from the 0.24 every other realm
## uses (Advika, 2026-08-07: bigger, and only for level 3). Nothing about the
## platforming moves with it: her speed, gravity and 138px jump are world units
## and do not know what scale she is drawn at. What DOES move is her collider
## (88x432 local), so she stands taller against the mushrooms, and the mirror,
## which takes its size off her — the two are always the same height.
const HERO_SCALE := 0.33
## Everything that is supposed to be measured AGAINST HER BODY — how high the
## walk fringe comes up her legs, where the front moss row's tips land — was
## tuned when she was 0.24 and is written in those pixels. This carries all of
## it with her, so growing the hero never quietly lowers the grass.
const GROWTH_SCALE := HERO_SCALE / 0.24
## the front growth row takes just over half of that growth — see `_build_foreground`.
## R3_FRINGE=<n> overrides it live, so how deep she wades is a thing that can
## be SHOT at three depths and looked at rather than argued about.
const FRINGE_GROWTH := 1.0
var _fringe_growth := FRINGE_GROWTH
## where the front moss curtain's tips land, relative to the walk line
const MOSS_FRONT_TIP := 30.0

## The growth that draws IN FRONT of her — the front moss curtain and the walk
## fringe. Two z values, because during the boss fight everything has to climb
## over the drain (see `_drain_front_growth`): the world lives under z 90, and
## she is lifted above it so the grey does not take her.
## ---------- THE THREE TIERS (Advika's decoration spec, step 3) ----------
## One z per tier, no per-sprite exceptions. Before this the realm used NINE
## different z values with no rule behind them (measured: z0,1,2,3,4,7,8,9,10),
## which is why nothing had a consistent depth read.
##
##   Z_BG      background decor — darkest, most desaturated, behind terrain, sparse
##   Z_TERRAIN the ground itself and everything standing on it
##   Z_FORE    foreground accents — fullest colour, in front of her, RARE
##
## Curiosity draws at 5, between terrain and foreground, which is what lets the
## front growth cross her legs without anything else in the level doing so.
const Z_BG := -2
const Z_TERRAIN := 2
const Z_FORE := 8

const FRONT_Z := 7
const FORE_Z := 8
## how far the front growth jumps when the forest dies, so it still covers her
## legs while she and the mirror are riding above the drain
const DRAINED_LIFT := 89

## REALM 3'S TWO TRACKS. Divine Echo carries the living forest; Whispers Beyond
## takes over as it drains and holds through the boss. `AudioManager.play_ambient`
## already crossfades — asking for the second one IS the fade-out of the first.
const DIVINE_ECHO := "res://assets/audio/realm3_divine_echo.ogg"
const WHISPERS_BEYOND := "res://assets/audio/realm3_whispers_beyond.ogg"

const FLOOR_Y := 420.0
## FURTHER IN THAN THE EDGE (Advika, having watched the handover: *"spawn
## curiosity a little further into the forest post the qoute scene"*). At -40
## she landed a thousand pixels off the west wall, and the camera clamp
## (`WORLD_L + 600`) put that wall on screen — so the first frame of Realm 3,
## arrived at through a doorway and a card, was the end of the level.
##
## 385 IS THE FRAME SHE PICKED, not a guess at "a bit further". A first pass put
## her at 1400; she walked back west and sent a screenshot of where she actually
## wanted to stand, and this is that frame read off its landmarks — the rock
## pile and its cup mushrooms just off her right shoulder, the orange cap above
## them, the twin clubs standing at the right edge. Nothing about it is round,
## because it was measured rather than chosen.
const SPAWN := Vector2(385.0, FLOOR_Y - 140.0)
const WORLD_L := -1050.0
const WORLD_R := 26000.0
# anchor x of each generated climbing arc down the long walk
const ARC_XS: Array[float] = [7300.0, 9500.0, 11200.0, 13400.0, 15600.0,
		17800.0, 20000.0, 22200.0, 24400.0]

# REALM 2'S DARKNESS RECIPE, hue-shifted to deep teal-green (Advika's
# mood correction). R2 bakes its dark into the art; our slices are raw,
# so the teal CanvasModulate below plays that role. Value hierarchy is
# strict: far silhouettes darkest/flattest -> mid dark -> gameplay reads
# lighter. Glow hues stay inside the palette — amber gold, moss green, pale
# cyan (Advika 2026-07-15: varied hues). Purple belongs to Curiosity + UI only.
const FILL_DARK := Color(0.085, 0.145, 0.132)     # terrain body, dark teal
const SOIL := Color(0.028, 0.05, 0.045)           # near-black soil under the band
const BG_TOP := Color(0.071, 0.169, 0.157)        # #122B28
const BG_BOTTOM := Color(0.039, 0.086, 0.078)     # #0A1614
# SIL_FAR / SIL_MID / CAP_HUES are GONE. Three hand-picked silhouette colours
# and a loud three-hue cap palette are how the background ended up with its
# value order backwards; `_depth()` below is the only tint source now.
const GLOW_WARM := Color(1.0, 0.85, 0.62)         # amber caps / gold stalks
const GLOW_COOL := Color(0.68, 0.95, 0.90)        # pale cyan — white glowers
const GLOW_MOSS := Color(0.62, 0.95, 0.58)        # bioluminescent moss green
const FRINGE_LIT := Color(0.95, 1.0, 0.97)        # gameplay fringe (grade teals it)
const FRINGE_NEAR := Color(0.55, 0.68, 0.63)      # front row, darker
const FRINGE_HANG := Color(0.45, 0.58, 0.54)      # ceiling fringe, dimmer still
## THE LEVEL WAS DARK BECAUSE MOST OF IT HAD NO LIGHTS IN IT.
##
## Advika: *"i love it but i feel like its too dark in a way so like??"* — and
## the cause is not exposure, it is that the light budget was handed out
## FIRST-COME. There were 24 PointLight2Ds for a 27,000px level, `_glow_light`
## granted them in call order, and `_build_dressing` (zones A to D, all of it
## under x 6800) runs before the long walk does. So every single light in the
## realm was spent in the first quarter of it, and the entire walk from 6800 to
## the door — two thirds of the level — was lit by nothing at all: flat
## modulate and additive blooms, no actual light touching anything.
##
## The budget is spatial now. A glower gets a real light if no other light is
## within `MIN_LIGHT_GAP` of it, which spreads them evenly the whole way down
## whatever order the builders happen to run in, and self-limits to about
## 27000/560 of them. Off-screen lights cost nothing — Godot culls them.
const MAX_GLOW_LIGHTS := 96
const MIN_LIGHT_GAP := 560.0
const AMBIENT := Color(0.74, 0.92, 0.88)          # the teal grade (R2-dark)
const FOG_TINT := Color(0.20, 0.38, 0.34)         # haze bands: deep teal, faint
const MOSS_FOG := "res://assets/realms/realm2_moss/fog.png"
const MOSS_SPORE := "res://assets/realms/realm2_moss/spore.png"
const MOSS_FIREFLY := "res://assets/realms/realm2_moss/firefly.png"

# frond cluster slices used for fringe rows (clusters only — singles read thin)
const FRINGE_TEX: Array[int] = [2, 3, 4, 10, 11, 16, 3, 10, 11]

# ---------- THE VALUE LAW ----------
## Advika, both levels open side by side: "look at level2, its so maximalist
## flowy cohesive looks perfectly built, and then level 3 is so subpar."
##
## Realm 2 is not cohesive because of its palette. It is cohesive because
## DEPTH IS THE ONLY THING VALUE MEANS IN IT. One hue, and a strict ramp: the
## furthest thing on screen is a pale haze, the nearest is almost black, and
## nothing anywhere is allowed off that ramp. That is the entire trick.
##
## Realm 3 broke the ramp at BOTH ends at once. Its giant background caps wore
## saturated mint hues with additive auras, which made the most distant objects
## in the level the BRIGHTEST things on screen; its ceiling teeth were painted
## near-white and hung down as fangs; its boulders were pale grey. Meanwhile
## the near layer was flat soil-black with nothing in it. So the picture had a
## value order exactly backwards from the depth order, and no amount of adding
## assets was ever going to fix it — every new thing just landed at a random
## brightness and read as pasted on.
##
## `_depth(t)` is now the ONLY source of an environment tint in this realm.
## t is distance: 0 is the far haze, 1 is the near-black frame edge. The curve
## is deliberately not linear — the far half is compressed, because that is
## what atmosphere actually does (everything distant sits close to the haze
## value), and the near half falls away fast.
## NOTE both of these are read THROUGH the realm's `AMBIENT` CanvasModulate
## (0.55, 0.72, 0.68), so what lands on screen is about 60% of what is written
## here. The first pass of this ramp was tuned by eye on the numbers instead of
## on the frame and the whole cavern came back crushed to black.
const HAZE := Color(0.265, 0.445, 0.410)          # what infinite distance is
## NOT actually black. A foreground that reaches true black is a hole in the
## picture — Realm 2's nearest carpet still shows every leaf in it, it is just
## very dark. The first pass of this ramp bottomed out at 0.013 and the whole
## lower half of the frame went featureless.
const NEAR_BLACK := Color(0.058, 0.104, 0.094)    # what the frame edge is

## THE PLAY LAYER IS NOT ON THE DEPTH RAMP, and that is deliberate.
##
## The ramp answers "how far away is this", and the answer for everything she
## can touch is "here" — which on a pure ramp means black. But this is the
## layer the level is actually played on, so it has to read. Realm 2 solves it
## the same way: the play space is a LIT POCKET inside the dark, brighter than
## the near band behind it and far darker than the haze beyond that.
##
## These are the only two off-ramp environment values in the realm.
const PLAY_STONE := Color(0.33, 0.46, 0.42)   # mushroom caps, boulders, rock
const PLAY_GROWTH := Color(0.30, 0.42, 0.39)  # the fronds and pots around them

## the four depths the whole realm is built at. Naming them stops any builder
## from inventing its own brightness.
const D_FAR := 0.10      # far band — hazed, flat, no detail survives
const D_MID := 0.40      # mid band — reads as shape, not as material
const D_NEAR := 0.68     # near band — the big flowy masses behind the play
const D_PLAY := 0.86     # the gameplay layer she stands in
const D_FORE := 1.00     # the frame edge

## the one warm accent, and it is the ONLY thing allowed off the value ramp.
## In Realm 2 the gold firefly points at every depth are what stitch the bands
## into one picture — the eye reads them as the same light seen near and far.
## Realm 3 had none (fireflies were cut on Advika's word, 2026-07-15), so the
## bands had nothing in common but hue. These are not insects: they are this
## realm's own amber-capped glowers, standing in the background at every depth.
const EMBER := Color(1.0, 0.80, 0.50)

# ---------- the three parallax bands ----------
## Bands move at cam*0.82 (far), cam*0.60 (mid) and cam*0.32 (near), so an item
## at base x appears at base + factor*cam. For cam in [-450, 25650] the view
## only ever samples base positions inside the ranges below (plus a screen of
## margin), so populating them is full coverage with no band edge ever on view.
const FAR_L := -950.0
const FAR_R := 5600.0
const MID_L := -1050.0
const MID_R := 11300.0
const NEAR_L := -1350.0
const NEAR_R := 18500.0


## the realm's only tint function. `lift` brightens a piece WITHIN its depth
## (a lit face, a rim) without letting it escape the band it belongs to.
func _depth(t: float, lift := 0.0) -> Color:
	var k: float = pow(clampf(t, 0.0, 1.0), 0.62)
	var c: Color = HAZE.lerp(NEAR_BLACK, k)
	if lift > 0.0:
		c = c.lerp(HAZE, clampf(lift, 0.0, 1.0) * (1.0 - k * 0.55))
	return c

var _curi: CharacterBody2D
var _cam: Camera2D
var _lives: LivesHUD
var _lantern: LanternHUD
var _exit_door: Area2D
var _at_exit := false
var _freeze_cam := false
var _lbl: Label
var _ui_layer: CanvasLayer
var _dying := false
var _leaving := false
var _glow_lights := 0
var _light_xs: Array[float] = []
var _hills_far: Node2D
var _hills_mid: Node2D
var _hills_near: Node2D
## where she respawns — SPAWN, unless R3_START_X moved the test in
var _spawn: Vector2 = SPAWN
var _ghosts := 0
## [sprite, base alpha, phase, rate] — the giants breathe their own light
var _auras: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# see _process: this is only so the debug pause key survives a pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(Color(0.04, 0.09, 0.08))
	_rng.seed = 20260714
	_build_backdrop()
	_build_background()
	_build_terrain()
	_build_platforms()
	_build_ceiling()
	_build_setpieces()
	_build_dressing()
	_build_density()
	_moss_body()
	_meadow_masses()
	_build_foreground()
	_build_atmosphere()
	_build_fog_layers()
	_build_player()
	_build_exit_door()
	_build_camera()
	_build_sporelings()
	_build_echo()
	_build_drain()
	_build_ui()
	# Divine Echo, on loop, from the moment she arrives (the loop flag lives in
	# the .ogg's import settings, same as Realm 2's Moonlight).
	_play_track(DIVINE_ECHO, "realm3_divine", 3.0)
	# THE OPENING CARD, FIVE SECONDS IN (Advika). Not on arrival: she comes out
	# of a quote card into this realm, and stacking a second card straight onto
	# the first makes the doorway feel like a menu. Five seconds is long enough
	# to see the forest breathing before the game says anything about it.
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_inside_tree():
			add_child(Realm3Card.open()))
	# hazy blue-grey ambient — a soft cool dim over the world (the backdrop
	# CanvasLayer is unaffected, so the mist keeps glowing behind everything
	# and the lantern's ADDED light stays the one warm thing)
	# THE GRAVITY PASS. Runs after every builder has had its say, so no builder
	# has to know what any other builder did.
	_settle_floaters()
	var grade := CanvasModulate.new()
	grade.color = AMBIENT
	add_child(grade)
	# R3_ID=1 — ASSET FORENSICS. Flat-colours every sprite in the level by which
	# art family it came from, so "what IS that shape" is answered by looking
	# rather than by reasoning about scale maths: hill=RED, frond=GREEN,
	# stalagmite=BLUE, mushroom=YELLOW, stone/ground=CYAN, anything loaded from
	# Realm 2=MAGENTA. Magenta is the one that matters — it is the only way to
	# be sure no R2 art has crept back in outside the floor.
	if OS.get_environment("R3_ID") != "":
		_id_pass(self)
	if OS.get_environment("R3_SHOT") != "":
		_self_screenshot(OS.get_environment("R3_SHOT"))
	# R3_BOSS=1 — the last two minutes of the level, now. It parks her on a
	# clear stretch and runs the real handoff (drain, then it is standing
	# there), so the fight can be judged without killing six mushrooms across
	# a ten-minute walk first. R3_BOSS=<x> picks the stretch.
	# R3_END=1 — THE WHOLE ENDING, in about a minute. Same as R3_BOSS, but the
	# mirror comes in on two swings' worth of health, so the fight is over fast
	# and what gets looked at is everything after it: the blink, the colour
	# coming home, the door arriving, the last line. [M] kills it outright.
	if OS.get_environment("R3_BOSS") != "" or OS.get_environment("R3_END") != "":
		var bx: float = float(OS.get_environment("R3_BOSS"))
		_curi.position.x = bx if bx > 100.0 else 12000.0
		_spawn = _curi.position
		# it has nothing to copy in a boot-straight-in test, so it is given a
		# few seconds of her actually playing before the colour goes
		await get_tree().create_timer(4.0).timeout
		if not _shifted:
			_begin_shift()
	# R3_BOOT=1 — boot the whole realm, hold a few seconds, quit. This is the
	# gate that actually proves the scripts COMPILE and the scene assembles;
	# `--headless --import` does neither, which is how a dead widget once got
	# reported as shipped. It owns its own timer so it cannot be orphaned by
	# whichever harness happens to be switched off.
	# R3_AUDIT=1 — WHAT IS IN THE AIR. Walks the finished world and reports
	# every sprite whose bottom edge floats clear of the meadow with nothing
	# under it. Guessing which builder owns a floating mushroom cost most of
	# 2026-08-06; this answers it with coordinates instead.
	# R3_ALPHA=1 — WHAT IS SEE-THROUGH. Walks the finished world and counts every
	# sprite not at full opacity. Fog, motes and the drain are meant to be
	# translucent; anything else is the `Color * float` alpha bug (see `_dim`),
	# and this is how it is proved dead rather than assumed dead.
	if OS.get_environment("R3_ALPHA") != "":
		await get_tree().process_frame
		_audit_alpha()
		get_tree().quit()
	# R3_DECOR=1 — HOW CROWDED IS IT, ACTUALLY. Counts what lands inside one
	# screen at several points down the walk, split by z tier and by art family,
	# and measures how much neighbouring decor of the SAME family overlaps.
	# Step 2 of the decoration spec is "audit the placement logic"; this is the
	# audit, so the density rules get set from measurements instead of taste.
	if OS.get_environment("R3_DECOR") != "":
		await get_tree().process_frame
		_audit_decor()
		get_tree().quit()
	if OS.get_environment("R3_AUDIT") != "":
		await get_tree().process_frame
		_audit_floaters()
		get_tree().quit()
	if OS.get_environment("R3_BOOT") != "":
		# R3_BOOT=<seconds> holds that long before quitting (default 2.5) —
		# long enough to sit through the drain and watch the boss arrive when
		# it is paired with R3_BOSS
		var hold: float = float(OS.get_environment("R3_BOOT"))
		await get_tree().create_timer(hold if hold > 0.5 else 2.5).timeout
		var lo: float = 999999.0
		var hi: float = -999999.0
		for lx in _light_xs:
			lo = minf(lo, lx)
			hi = maxf(hi, lx)
		print("R3 LIGHTS — %d placed, x %.0f..%.0f" % [_light_xs.size(), lo, hi])
		print("R3 BOOT OK — scene assembled, no parse errors")
		get_tree().quit()


# ---------- shared little builders ----------

# ---------- THE MUSHROOMS HAVE HUES ----------
## Advika, on the rebuilt look: *"add a hue to all of the mushrooms in this
## level, im loving this new look."*
##
## The danger here is not hypothetical — the level has already been here once
## and it is what this whole pass tore out. The old `CAP_HUES` painted the
## background giants in saturated mint, and because a hue was applied as a
## plain multiply it also changed their VALUE, which made the most distant
## objects the brightest things on screen and destroyed the depth read.
##
## So hue is added WITHOUT TOUCHING VALUE. `_hue()` normalises every hue to
## luminance 1 before it multiplies, so a mushroom changes colour and keeps
## exactly the brightness the depth ramp handed it. A hued far mushroom is
## still a far mushroom.
##
## And hue is locked PER SPECIES, never random: every `mushroomcap9` in the
## cavern is the same colour whether it is under her feet or on the horizon.
## That reads as a forest with several kinds of mushroom growing in it.
## Per-sprite random hue reads as confetti.
##
## Everything stays inside the realm's own family — teals, moss, cold blue, and
## the amber the glowers already carry. NO PURPLE: that belongs to Curiosity.

## how far toward the full hue a mushroom is pushed. The cap species are the
## big painted domes she stands on and they take it best; dialled here so the
## whole forest can be warmed or cooled with one number.
## Advika, on the rainbow version: *"the hues look so random and it destroys
## the look of the level."* She is right, and the mistake was mine on the
## definition of "hue". I read it as VARIETY and gave every species its own
## colour — cold blue, cyan, moss, sea green, amber — which is a rainbow, and a
## rainbow is the exact opposite of the cohesion this whole rebuild was for.
##
## Hue in a cohesive level is not variety, it is ONE FAMILY AND ONE ACCENT.
## That is what Realm 2 does: everything violet, gold points, nothing else. So
## every mushroom here is now somewhere on a narrow TEAL-TO-MOSS arc — the
## realm's own green — and the only thing allowed off it is the lit species,
## which carry the amber that was already this level's single warm accent.
## Species still pick their own spot on the arc, so a `mushroomcap9` is always
## the same green and the forest still has kinds in it; they just all belong to
## each other now.
##
## The mechanism is unchanged and it is the important part: `_hue()` normalises
## to luminance 1 before multiplying, so colour never touches the depth ramp.
## dialled back from 0.85: the giant platform caps are the biggest surfaces in
## the level, so they carry the most colour, and at full strength they came out
## candy-green against an art direction that says muted throughout.
const HUE_STRENGTH := 0.66
const MUSH_LIFT := 1.12

## THE ARC. Every value here is a green — the spread is teal at one end and
## moss at the other, and nothing in between leaves the family.
const FUNGAL_TEAL := Color(0.52, 1.18, 1.06)
const FUNGAL_MOSS := Color(0.74, 1.26, 0.62)
## the one accent, and only the lit species get it
const FUNGAL_GOLD := Color(1.46, 0.96, 0.34)


## somewhere on the teal-to-moss arc, picked by species so it never changes
func _fungal(species: int, warm := false) -> Color:
	if warm:
		return FUNGAL_GOLD
	# an irregular walk along the arc, so neighbouring ids are not neighbouring
	# colours and the forest does not band into stripes of one green
	var f: float = fmod(float(species) * 0.618, 1.0)
	return FUNGAL_TEAL.lerp(FUNGAL_MOSS, f)


## the caps. 1/2/5/7/8 are the thin stalks the pack paints gold — they are the
## realm's lit species and keep the accent; 3/4/6/9/10 are the flat domes she
## stands on and they are green.
const CAP_WARM: Array[int] = [1, 2, 5, 7, 8]
## the glowers. 1-12 are the amber-capped lights; everything else is growth.
const GLOW_WARM_MAX := 12


## rotate `c` toward a hue while holding its luminance. This is the whole
## safety rail: multiply by a colour normalised to luminance 1 and the value
## ramp survives intact.
func _hue(c: Color, hue: Color) -> Color:
	var l: float = hue.r * 0.299 + hue.g * 0.587 + hue.b * 0.114
	if l <= 0.001:
		return c
	var n := Color(hue.r / l, hue.g / l, hue.b / l)
	return Color(c.r * lerpf(1.0, n.r, HUE_STRENGTH),
			c.g * lerpf(1.0, n.g, HUE_STRENGTH),
			c.b * lerpf(1.0, n.b, HUE_STRENGTH), c.a)


## every mushroom in the level passes through here, whoever placed it —
## the species is read off the filename so no builder has to know about hues
func _mush_tint(tex_name: String, tint: Color) -> Color:
	if not tex_name.begins_with("mushroom"):
		return tint
	var digits := ""
	for ch in tex_name:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits.is_empty():
		return tint
	var id: int = int(digits)
	var lit := Color(tint.r * MUSH_LIFT, tint.g * MUSH_LIFT,
			tint.b * MUSH_LIFT, tint.a)
	if tex_name.begins_with("mushroomcap"):
		return _hue(lit, _fungal(id, CAP_WARM.has(id)))
	return _hue(lit, _fungal(id + 7, id <= GLOW_WARM_MAX))



## SCALE A COLOUR'S BRIGHTNESS WITHOUT TOUCHING ITS ALPHA.
##
## THE BUG THIS EXISTS TO KILL: in Godot, `Color * float` multiplies ALL FOUR
## components, alpha included. So `R2_TEAL * 0.40` — written to mean "this moss
## is 40% as bright" — actually produced `(0.208, 0.448, 0.376, a=0.40)`, and
## every sprite tinted that way rendered at FORTY PERCENT OPACITY.
##
## Advika saw the symptom before I did: "the decorated terrain renders as an
## unreadable semi-transparent mass, you can see overlapping sprite rectangles
## ghosting through each other." That is exactly what a level full of
## 30-70%-alpha decoration looks like — every clump showing every clump behind
## it, and the soft PNG edges compounding into a haze instead of a silhouette.
##
## It was in nineteen places across the realm and the gateway, including the
## floor's own moss courses, which is why the ground never looked solid no
## matter how much of it there was.
func _dim(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

func _sprite(tex_name: String, pos: Vector2, sc: float, z: int,
		tint := PLAY_STONE, fh := false, fv := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(BASE + tex_name)
	s.scale = Vector2(sc, sc)
	s.position = pos
	s.z_index = z
	s.modulate = _mush_tint(tex_name, tint)
	s.flip_h = fh
	s.flip_v = fv
	add_child(s)
	return s


## bottom-anchored prop: base sits ON base_y (sunk a touch so nothing floats)
func _prop(tex_name: String, x: float, base_y: float, sc: float, z: int,
		tint := PLAY_STONE, fh := false) -> Sprite2D:
	var tex: Texture2D = load(BASE + tex_name)
	var h := tex.get_height() * sc
	return _sprite(tex_name, Vector2(x, base_y - h * 0.5 + h * 0.04 + 5.0),
			sc, z, tint, fh)


func _fill_rect(x0: float, x1: float, y0: float, y1: float, z: int,
		col := FILL_DARK) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0),
			Vector2(x1, y1), Vector2(x0, y1)])
	p.color = col
	p.z_index = z
	add_child(p)


func _collider_rect(x0: float, x1: float, y0: float, y1: float,
		one_way := false) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, y1 - y0)
	cs.shape = rect
	cs.position = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
	cs.one_way_collision = one_way
	body.add_child(cs)
	add_child(body)
	# every walkable surface in the level, remembered — `_settle_floaters`
	# needs to know what is under a thing before it drops it
	_solid_rects.append([x0, x1, y0])


## pebble strip riding an edge line (the refs' platform/ground rims).
## The span is split into n tiles at ONE uniform scale near the target —
## whole-tiles-only leaves the end naked; a shrunken last tile overshoots.
## (Both row textures are 590px wide; both col textures 588px tall.)
func _pebble_row(x0: float, x1: float, y: float, sc: float, z: int,
		tint := PLAY_STONE) -> void:
	var names := ["fungalground22.png", "fungalground26.png"]
	var span := x1 - x0
	var tw := 590.0
	var n := maxi(1, roundi(span / (tw * sc * 0.88)))
	var s := span / (tw * (0.88 * float(n - 1) + 1.0))
	var x := x0
	for i in n:
		_sprite(names[i % 2], Vector2(x + tw * s * 0.5, y), s, z, tint,
				_rng.randf() < 0.5)
		x += tw * s * 0.88


## vertical pebble strip (the refs' wall/side rims), tiled downward —
## same uniform-fit tiling so the rim always reaches the corner exactly
func _pebble_col(x: float, y0: float, y1: float, sc: float, z: int,
		tint := PLAY_STONE) -> void:
	var names := ["fungalground20.png", "fungalground21.png"]
	var span := y1 - y0
	var th := 588.0
	var n := maxi(1, roundi(span / (th * sc * 0.88)))
	var s := span / (th * (0.88 * float(n - 1) + 1.0))
	var y := y0
	for i in n:
		_sprite(names[i % 2], Vector2(x, y + th * s * 0.5), s, z, tint,
				_rng.randf() < 0.5)
		y += th * s * 0.88


## the signature move: a dense frond fringe along an edge.
## hang=false grows UP from base_y; hang=true drips DOWN from base_y.
func _fringe(x0: float, x1: float, base_y: float, hang: bool, sc_min: float,
		sc_max: float, z: int, tint: Color, step_mul := 0.55) -> void:
	var x := x0
	while x < x1:
		var idx: int = FRINGE_TEX[_rng.randi() % FRINGE_TEX.size()]
		var tex: Texture2D = load(BASE + "fungalfrond%d.png" % idx)
		var sc := _rng.randf_range(sc_min, sc_max)
		var h := tex.get_height() * sc
		var sink := h * 0.14 + 6.0 + _rng.randf_range(0.0, 7.0)   # y jitter
		var y := base_y + (h * 0.5 - sink) * (1.0 if hang else -1.0)
		_sprite("fungalfrond%d.png" % idx, Vector2(x, y), sc, z, tint,
				_rng.randf() < 0.5, hang)
		x += tex.get_width() * sc * step_mul
	# a few curled sprouts poking out of the row
	var cx := x0 + _rng.randf_range(60.0, 220.0)
	while cx < x1 - 60.0:
		var ci := 17 + _rng.randi() % 5
		var ctex: Texture2D = load(BASE + "fungalfrond%d.png" % ci)
		var csc := _rng.randf_range(0.16, 0.24)
		var ch := ctex.get_height() * csc
		_sprite("fungalfrond%d.png" % ci,
				Vector2(cx, base_y + (ch * 0.5 - 8.0) * (1.0 if hang else -1.0)),
				csc, z, tint, _rng.randf() < 0.5, hang)
		cx += _rng.randf_range(380.0, 720.0)


func _glow_light(host: Node2D, col: Color, energy: float, tsc: float) -> void:
	# fake bloom first (web renderer has no 2D glow): an ADDITIVE soft radial
	# behind the cap, 2.5x its width — this is what makes glowers read as
	# light sources instead of flat sprites. Every glower gets one.
	if host is Sprite2D:
		_bloom(host as Sprite2D, col, 0.26)
	if _glow_lights >= MAX_GLOW_LIGHTS:
		return
	# spatial budget: one real light per stretch of cavern, wherever the
	# builders happen to ask in what order
	var hx: float = host.global_position.x
	for lx in _light_xs:
		if absf(hx - lx) < MIN_LIGHT_GAP:
			return
	_light_xs.append(hx)
	_glow_lights += 1
	# softened: bigger pool, lower energy — light pools, not spotlights
	var l := PointLight2D.new()
	l.texture = _soft_glow_texture()
	l.color = col
	l.energy = energy * 1.15
	l.texture_scale = tsc * 2.6
	host.add_child(l)


func _bloom(host: Sprite2D, tint: Color, alpha: float) -> void:
	var g := Sprite2D.new()
	g.texture = _soft_glow_texture()
	g.show_behind_parent = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	g.modulate = Color(tint.r, tint.g, tint.b, alpha)
	# child inherits the host's scale — normalize so the halo lands at
	# ~2.5x the cap width regardless of the mushroom's own scale
	var target_px := host.texture.get_width() * 2.5
	g.scale = Vector2.ONE * (target_px / 256.0)
	g.position = Vector2(0.0, -host.texture.get_height() * 0.22)   # on the cap
	host.add_child(g)


# ---------- backdrop / background ----------

func _build_backdrop() -> void:
	# screen-anchored vertical gradient, R2-dark in teal: #122B28 (top)
	# sinking to #0A1614 (bottom). No bright band — the glows carry the light.
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	# Advika's painted olive mist replaces the code-drawn gradient. Same node,
	# same CanvasLayer (-10), same full-rect anchors — only the texture and
	# the fitting changed. COVERED, not stretched: the art is 1920x1080 and a
	# non-16:9 window must crop it rather than squash it.
	var tr := TextureRect.new()
	tr.texture = load(BASE + "olivemistbg.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# NO runtime tint. The teal is BAKED into the asset by
	# tools/grade_olivemist.py — a multiply drags olive toward teal by
	# crushing the red channel, which muddies the midtones instead of moving
	# the hue. The original is kept beside it as olivemistbg_src.png, so the
	# grade can be re-run with different targets at any time.
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)
	_build_bg_mist(cl)


## MIST, MOVING, BEHIND EVERYTHING.
##
## The painted backdrop is one still image, so the deepest layer of the realm
## was the only part of it not alive. These are broad soft sheets drifting
## across it at three speeds — slow enough to read as distance rather than
## weather — each wrapping within its own span so the drift never runs out.
##
## They sit on the backdrop's own CanvasLayer (-10): behind every parallax
## band, and under the drain, so the shift kills them with the rest of it.
var _bg_mist: Array = []      # [sprite, speed, span, base_alpha, phase]


func _build_bg_mist(host: CanvasLayer) -> void:
	var tex: Texture2D = load(MOSS_FOG)
	if tex == null:
		return
	var vp := Vector2(1920.0, 1080.0)
	# three depths: the far sheet barely moves, the near one leads
	var lanes: Array = [
		{"y": 0.30, "sc": 3.4, "a": 0.10, "sp": 5.0},
		{"y": 0.52, "sc": 2.6, "a": 0.13, "sp": 9.0},
		{"y": 0.74, "sc": 2.0, "a": 0.16, "sp": 14.0},
	]
	for li in lanes.size():
		var lane: Dictionary = lanes[li]
		var span: float = tex.get_width() * float(lane["sc"])
		# two copies per lane, so one is always sliding in as the other leaves
		for c in 2:
			var s := Sprite2D.new()
			s.texture = tex
			s.scale = Vector2(float(lane["sc"]), float(lane["sc"]))
			s.modulate = Color(FOG_TINT.r, FOG_TINT.g, FOG_TINT.b,
					float(lane["a"]))
			s.position = Vector2(float(c) * span, vp.y * float(lane["y"]))
			s.z_index = -8 + li
			host.add_child(s)
			_bg_mist.append([s, float(lane["sp"]), span,
					float(lane["a"]), float(li) * 1.9 + float(c) * 3.1])


## THE BACKGROUND, REBUILT ON REALM 2'S GRAMMAR (Advika, 2026-08-07:
## "look at level2, its so maximalist flowy cohesive looks perfectly built,
## and then level 3 is so subpar. redo the entire level 3 look").
##
## What Realm 2 actually does, and what this now does too:
##
##   1. THREE bands, not two, and the nearest one is the loudest. R2's power
##      comes from big near-black masses sitting just behind the play space,
##      with the hazed distance showing between them. R3 had its two bands
##      both far away, so there was nothing between the hero and the horizon
##      and the picture was flat.
##   2. EVERY SHAPE CROSSES THE FRAME VERTICALLY. R2's silhouette language is
##      leaning, bending trunks that run from under the floor to over the top
##      edge. R3's was horizontal ellipses stacked on horizontal ellipses —
##      every shape agreed with the frame's own direction, which is exactly
##      what makes a background read as wallpaper. See `_column`.
##   3. Value is depth and nothing else — `_depth()`, applied without
##      exception. The old giant caps wore saturated mint and additive auras
##      and were the brightest objects in the level; they are now the dimmest.
##   4. One warm accent scattered through ALL of it, so the bands share
##      something besides hue — `_ember`.
##
## Built from this realm's own pack only (Advika: the purple structures do not
## come into this level). The floor is the one exception and it is Realm 2's.
func _build_background() -> void:
	_hills_far = Node2D.new()
	_hills_far.z_index = -8
	add_child(_hills_far)
	_hills_mid = Node2D.new()
	_hills_mid.z_index = -6
	add_child(_hills_mid)
	_hills_near = Node2D.new()
	_hills_near.z_index = -4
	add_child(_hills_near)

	_far_band()
	_mid_band()
	_near_band()

	# UPPER AIR — distant teeth hanging in the two deep bands, so every window
	# between the roof's fingers shows dark depth rather than bare gradient.
	# They used to be painted at 0.66-0.76 grey, which made them white fangs
	# and the highest-value thing in the picture after the lantern.
	_teeth_row(_hills_far, FAR_L, FAR_R, ROOF_Y - 40.0, 0.55, 0.75,
			_depth(D_FAR + 0.06))
	_teeth_row(_hills_mid, MID_L, MID_R, ROOF_Y - 20.0, 0.6, 0.85,
			_depth(D_MID + 0.04))


## THE FAR BAND — the haze. Almost no value spread inside it on purpose: at
## this distance atmosphere has eaten the detail, and anything that still reads
## as a distinct object is a thing standing too close to be there.
func _far_band() -> void:
	# a continuous cap-and-spire skyline, so the horizon is never bare
	var x := FAR_L
	var i := 0
	while x < FAR_R:
		var t: float = D_FAR + _rng.randf_range(-0.02, 0.05)
		match i % 3:
			0:
				var ct: Texture2D = load(BASE + "mushroomcap%d.png" % [3, 6, 9, 4, 10][i % 5])
				var cs := _rng.randf_range(1.0, 1.45)
				_band_at(_hills_far, "mushroomcap%d.png" % [3, 6, 9, 4, 10][i % 5],
						x, FLOOR_Y + 60.0, cs, _depth(t), i % 2 == 0)
			1:
				_spire_cluster(_hills_far, x, [[1, 3], [2, 4, 5], [3, 1], [5, 2]][i % 4],
						_rng.randf_range(0.62, 0.86), _depth(t))
			2:
				# a far column: the flowy shape, sunk in the haze
				_column(_hills_far, x, D_FAR + 0.04, _rng.randf_range(0.55, 0.8),
						FLOOR_Y + 70.0)
		x += _rng.randf_range(180.0, 290.0)
		i += 1
	# thin species threading the gaps, one step out of the haze
	var tx := FAR_L + 90.0
	var ti := 0
	while tx < FAR_R:
		_band_at(_hills_far, "mushroomglow%d.png" % [1, 7, 11, 2, 8, 5][ti % 6],
				tx, FLOOR_Y + 30.0, _rng.randf_range(0.55, 0.78),
				_depth(D_FAR + 0.08), ti % 2 == 0)
		tx += _rng.randf_range(150.0, 235.0)
		ti += 1
	# the far embers — small, sparse, and the reason the horizon is not dead
	var ex := FAR_L + 200.0
	while ex < FAR_R:
		_ember(_hills_far, ex, FLOOR_Y - _rng.randf_range(30.0, 190.0), 0.5, 0.09)
		ex += _rng.randf_range(340.0, 580.0)


## THE MID BAND — the crowd. Shapes read here, material does not. This is
## where the composition gets its rhythm: groves and clearings, never an even
## spread. The old code built four rotating "vignettes" of giant hued caps and
## it was the single loudest thing on screen; the giants stay, but they are
## dark now, and the band is led by columns instead of by domes.
func _mid_band() -> void:
	var x := MID_L
	var i := 0
	while x < MID_R:
		var t: float = D_MID + _rng.randf_range(-0.05, 0.07)
		# a GROVE: three to five columns leaning together, tallest in the
		# middle, with the small stuff gathered at their feet. Realm 2 never
		# places a single trunk — it places a stand of them.
		var n: int = 4 + _rng.randi() % 4
		for k in n:
			var kx: float = x + (float(k) - float(n) * 0.5) * _rng.randf_range(120.0, 210.0)
			var mid_k: float = 1.0 - absf(float(k) - float(n - 1) * 0.5) / maxf(1.0, float(n) * 0.5)
			_column(_hills_mid, kx, t + _rng.randf_range(-0.03, 0.03),
					_rng.randf_range(0.85, 1.05) * (0.72 + mid_k * 0.5),
					FLOOR_Y + 60.0)
		# one giant cap looming behind the grove every third clearing —
		# the largest shape in the picture, and now also one of the darkest
		if i % 3 == 0:
			_band_at(_hills_mid, "mushroomcap%d.png" % [9, 6, 4, 3, 10][i % 5],
					x + _rng.randf_range(-120.0, 120.0), FLOOR_Y + 70.0,
					_rng.randf_range(1.05, 1.4), _depth(t - 0.06), i % 2 == 0)
		# and the floor life of the band, so no grove stands on bare ground
		for k in 3:
			_band_at(_hills_mid, "fungalhill%d.png" % [1, 3, 4, 2, 5][(i + k) % 5],
					x + _rng.randf_range(-260.0, 260.0), FLOOR_Y + 46.0,
					_rng.randf_range(0.42, 0.78), _depth(t + 0.06),
					_rng.randf() < 0.5)
		if _rng.randf() < 0.5:
			_band_at(_hills_mid, "fungalstoneb%d.png" % (1 + _rng.randi() % 11),
					x + _rng.randf_range(-300.0, 300.0), FLOOR_Y + 40.0,
					_rng.randf_range(0.30, 0.52), _depth(t + 0.10),
					_rng.randf() < 0.5)
		# embers threaded through the grove at grove depth
		for k in 2:
			_ember(_hills_mid, x + _rng.randf_range(-280.0, 280.0),
					FLOOR_Y - _rng.randf_range(40.0, 260.0), 0.62, 0.13)
		x += _rng.randf_range(215.0, 340.0)
		i += 1


## THE NEAR BAND — the one Realm 3 never had, and the reason it looked flat.
##
## In Realm 2 the biggest, blackest shapes in the frame are NOT the far ones:
## they are enormous trunks and crowns standing a few metres behind the hero,
## moving fast against the camera, with the hazed distance glimpsed in the gaps
## between them. That band is what turns a flat backdrop into a place you are
## standing inside. Realm 3's nearest background was six hundred pixels away
## and the same brightness as the sky, so there was nothing for the eye to pass
## behind and the whole cavern read as a painted wall at arm's length.
##
## Kept deliberately sparse — a stand every 900-1400px, so most screens have
## one or two and the distance still shows. A continuous row here would be a
## wall, which is the failure mode every previous foreground in this realm hit.
func _near_band() -> void:
	var x := NEAR_L
	var i := 0
	while x < NEAR_R:
		var n: int = 3 + _rng.randi() % 3
		for k in n:
			_column(_hills_near, x + (float(k) - float(n) * 0.5) * _rng.randf_range(150.0, 260.0),
					D_NEAR + _rng.randf_range(-0.05, 0.06),
					_rng.randf_range(1.15, 1.65), FLOOR_Y + 120.0)
		# the stand's own undergrowth, so it is rooted rather than pasted
		for k in 4:
			_band_at(_hills_near, "fungalhill%d.png" % [2, 5, 1, 3, 4][(i + k) % 5],
					x + _rng.randf_range(-380.0, 380.0), FLOOR_Y + 96.0,
					_rng.randf_range(0.62, 1.15), _depth(D_NEAR + 0.08),
					_rng.randf() < 0.5)
		# one big stone mass every other stand — not all of it is growth
		if i % 2 == 0:
			_band_at(_hills_near, "fungalstoneb%d.png" % (1 + _rng.randi() % 11),
					x + _rng.randf_range(-420.0, 420.0), FLOOR_Y + 90.0,
					_rng.randf_range(0.55, 0.85), _depth(D_NEAR + 0.05),
					_rng.randf() < 0.5)
		# the near embers are the biggest and the warmest — they read as
		# lights hanging between the camera and the forest
		_ember(_hills_near, x + _rng.randf_range(-300.0, 300.0),
				FLOOR_Y - _rng.randf_range(60.0, 300.0), 0.85, 0.18)
		x += _rng.randf_range(600.0, 950.0)
		i += 1


## THE FLOWY VERTICAL — the shape Realm 2 has everywhere and Realm 3 had none
## of. A trunk that leans, bends and tapers out of the ground, crowned with a
## fuzzy radial burst, drawn at whatever depth it is standing at.
##
## Built from this realm's own pack: `fungalfrond` 5-15 are single curving
## tendrils, and at six to twelve times their painted size they are exactly
## Realm 2's leaning trunks; `fungalhill` 2 and 5 are radial bursts, which on
## top of one is the crown. The rest of the pack only ever offered horizontal
## domes, which is why the old background could not stop looking like a stack
## of plates.
##
## `t` is depth (feeds `_depth`), `power` scales the whole stand, `base_y` is
## how far under the floor line the foot is buried.
func _column(band: Node2D, cx: float, t: float, power: float,
		base_y: float) -> void:
	var tint: Color = _depth(t)
	var lean: float = _rng.randf_range(-9.0, 9.0)
	var trunk_id: int = [5, 6, 7, 8, 13, 14, 15, 1, 9, 12][_rng.randi() % 10]
	var tex: Texture2D = load(BASE + "fungalfrond%d.png" % trunk_id)
	# height is the thing that matters: a trunk that stops inside the frame is
	# a stick, a trunk that leaves through the top is architecture
	var want_h: float = _rng.randf_range(620.0, 1150.0) * power
	var sc: float = want_h / float(tex.get_height())
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(sc, sc)
	s.flip_h = _rng.randf() < 0.5
	s.rotation_degrees = lean
	s.position = Vector2(cx, base_y - want_h * 0.5)
	s.modulate = tint
	band.add_child(s)
	# a second, shorter tendril leaning off the same foot — a bare single
	# curve reads as a wire; two crossing curves read as a plant
	if _rng.randf() < 0.75:
		var t2: Texture2D = load(BASE + "fungalfrond%d.png" % [6, 7, 8, 14, 15][_rng.randi() % 5])
		var h2: float = want_h * _rng.randf_range(0.42, 0.72)
		var s2 := Sprite2D.new()
		s2.texture = t2
		s2.scale = Vector2(h2 / float(t2.get_height()), h2 / float(t2.get_height()))
		s2.flip_h = not s.flip_h
		s2.rotation_degrees = lean + _rng.randf_range(-14.0, 14.0)
		s2.position = Vector2(cx + _rng.randf_range(-40.0, 40.0) * power,
				base_y - h2 * 0.5)
		s2.modulate = tint
		band.add_child(s2)
	# THE CROWN — the fuzzy radial head. This is the silhouette Realm 2 reads
	# by: a soft spiky mass, never a clean edge.
	var chid: int = 2 if _rng.randf() < 0.6 else 5
	var ctex: Texture2D = load(BASE + "fungalhill%d.png" % chid)
	var cw: float = want_h * _rng.randf_range(0.42, 0.66)
	var csc: float = cw / float(ctex.get_width())
	var c := Sprite2D.new()
	c.texture = ctex
	c.scale = Vector2(csc, csc)
	c.flip_h = _rng.randf() < 0.5
	c.rotation_degrees = lean * 0.6
	# seat the crown ON the trunk's head, following its lean
	var head := Vector2(cx, base_y - want_h) 			+ Vector2(sin(deg_to_rad(lean)), 0.0) * want_h * 0.5
	c.position = head + Vector2(0.0, ctex.get_height() * csc * 0.22)
	c.modulate = tint
	band.add_child(c)
	# a smaller second head, offset — crowns in R2 are never one blob
	if _rng.randf() < 0.55:
		var c2 := Sprite2D.new()
		c2.texture = load(BASE + "fungalhill%d.png" % (5 if chid == 2 else 2))
		var c2w: float = cw * _rng.randf_range(0.45, 0.7)
		var c2sc: float = c2w / float(c2.texture.get_width())
		c2.scale = Vector2(c2sc, c2sc)
		c2.flip_h = _rng.randf() < 0.5
		c2.position = head + Vector2(_rng.randf_range(-cw * 0.5, cw * 0.5),
				_rng.randf_range(cw * 0.15, cw * 0.5))
		c2.modulate = tint
		band.add_child(c2)


## a bottom-anchored sprite in an arbitrary band, buried to `base_y`
func _band_at(band: Node2D, tex_name: String, x: float, base_y: float,
		sc: float, tint: Color, fh := false) -> Sprite2D:
	var tex: Texture2D = load(BASE + tex_name)
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(sc, sc)
	s.flip_h = fh
	s.position = Vector2(x, base_y - tex.get_height() * sc * 0.5)
	s.modulate = _mush_tint(tex_name, tint)
	band.add_child(s)
	return s


## THE WARM ACCENT, at every depth. One of this realm's own amber-capped
## glowers plus an additive halo — small and far, big and warm up close.
##
## Realm 2 stitches its bands together with gold firefly points seen at every
## distance: the eye reads them as one light source repeated through space, and
## that is most of why its layers feel like one forest instead of three
## paintings. Realm 3 cut its fireflies (Advika, 2026-07-15) and never replaced
## the function they were serving, so the bands had nothing in common but hue.
## These are not insects — they are mushrooms standing in the background, which
## is the same accent without the thing she rejected.
func _ember(band: Node2D, x: float, y: float, power: float,
		halo: float) -> void:
	var mid: int = [1, 2, 3, 4, 5, 6, 10, 11, 12][_rng.randi() % 9]
	var tex: Texture2D = load(BASE + "mushroomglow%d.png" % mid)
	var sc: float = _rng.randf_range(0.16, 0.30) * power
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(sc, sc)
	s.flip_h = _rng.randf() < 0.5
	s.position = Vector2(x, y)
	# the cap itself never goes fully warm — it is a dark mushroom with a lit
	# head, so it still belongs to the silhouette layer it is standing in
	s.modulate = _mush_tint("mushroomglow%d.png" % mid,
			EMBER.lerp(_depth(D_MID), 0.35))
	band.add_child(s)
	var g := Sprite2D.new()
	g.texture = _soft_glow_texture()
	g.show_behind_parent = true
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = gm
	g.modulate = Color(EMBER.r, EMBER.g, EMBER.b, halo)
	g.scale = Vector2.ONE * (tex.get_width() * 3.6 / 256.0)
	g.position = Vector2(0.0, -tex.get_height() * 0.30)
	s.add_child(g)
	# they breathe, each on its own clock — nothing in this cavern sits at a
	# constant brightness
	_auras.append([g, halo, _rng.randf_range(0.0, TAU), _rng.randf_range(0.4, 0.8)])


## distant ceiling teeth for a parallax band: even rhythm, varied length,
## heads anchored above top_y so they always connect upward into the dark
func _teeth_row(band: Node2D, x0: float, x1: float, top_y: float,
		sc_lo: float, sc_hi: float, tint: Color) -> void:
	var x := x0 + _rng.randf_range(0.0, 120.0)
	var i := 0
	while x < x1:
		var t_id: int = [13, 15, 12, 16, 14][i % 5]
		var tex: Texture2D = load(BASE + "stalagmite%d.png" % t_id)
		var sc := _rng.randf_range(sc_lo, sc_hi)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.flip_v = true
		s.position = Vector2(x, top_y + tex.get_height() * sc * 0.5)
		s.modulate = tint
		band.add_child(s)
		x += _rng.randf_range(240.0, 380.0)
		i += 1


## 2-3 background stalagmites grown together: varied scale (0.6-1.4x of
## base), random x-flip, 2-6 degree lean, staggered depth via x-offsets
func _spire_cluster(band: Node2D, cx: float, ids: Array, base_sc: float,
		tint: Color) -> void:
	for i in ids.size():
		var tex: Texture2D = load(BASE + "stalagmiteb%d.png" % ids[i])
		var sc: float = base_sc * _rng.randf_range(0.6, 1.4)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.rotation_degrees = (1.0 if _rng.randf() < 0.5 else -1.0) \
				* _rng.randf_range(2.0, 6.0)
		s.position = Vector2(cx + (i - ids.size() * 0.5) * _rng.randf_range(90.0, 150.0),
				FLOOR_Y + 50.0 - tex.get_height() * sc * 0.5)
		s.modulate = tint
		band.add_child(s)


# ---------- terrain: ground + ceiling + platforms ----------

func _build_terrain() -> void:
	# THE SOIL: one near-black body under the whole walk — the only
	# geometric fill, and the band rows bury it (R2's earth polygon).
	# Art overshoots the camera clamps; colliders stop at the world edge.
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, FLOOR_Y, FLOOR_Y + 900.0, 0, SOIL)
	_collider_rect(WORLD_L, WORLD_R, FLOOR_Y, FLOOR_Y + 120.0)
	# CAVERN END WALLS (ref 2's left edge): dark column + vertical pebble rim.
	# Walls run 900px past the world edge — the camera's widest framing at
	# the clamps still lands inside solid dark, nothing leaks through.
	# no pebble rims on the walls — the cave just fades into its own dark
	# (the rim column read as a floating rock chain against the black)
	_fill_rect(WORLD_L - 900.0, WORLD_L + 40.0, -1400.0, FLOOR_Y, 0)
	_collider_rect(WORLD_L - 60.0, WORLD_L + 40.0, FLOOR_Y - 900.0, FLOOR_Y)
	_fill_rect(WORLD_R - 40.0, WORLD_R + 900.0, -1400.0, FLOOR_Y, 0)
	_collider_rect(WORLD_R - 40.0, WORLD_R + 60.0, FLOOR_Y - 900.0, FLOOR_Y)
	# the walls end in GROWTH, not in a cut line: dark spire columns leaning
	# on each face (feet in the soil, heads tucked behind the roof band) +
	# a seat boulder, so no straight vertical seam ever shows
	for wp in [[WORLD_L - 30.0, 5, 0.9, false], [WORLD_L + 120.0, 1, 0.72, true],
			[WORLD_R + 30.0, 3, 0.7, true], [WORLD_R - 130.0, 5, 0.88, false]]:
		var wtex: Texture2D = load(BASE + "stalagmiteb%d.png" % wp[1])
		var wsc: float = wp[2]
		_sprite("stalagmiteb%d.png" % wp[1],
				Vector2(wp[0], FLOOR_Y + 40.0 - wtex.get_height() * wsc * 0.5),
				wsc, 1, _depth(D_NEAR), wp[3])
	_prop("fungalstoneb4.png", WORLD_L + 100.0, FLOOR_Y + 30.0, 0.5, 2,
			PLAY_STONE)
	_prop("fungalstoneb7.png", WORLD_R - 100.0, FLOOR_Y + 30.0, 0.5, 2,
			PLAY_STONE, true)
	# THE GROUND BAND — Realm 2's depth-stack recipe with the fungal hills:
	# the same big fringed strips in staggered rows, each lower and darker,
	# one seamless grown body fading into the soil. No pebble rims, no
	# small-fringe carpet — big fingers all the way down (R2's law).
	_ground_band()


## one staggered row of fungal hills: overlapping big fringed strips,
## random flips + scale/y jitter — the R2 moss-row move
func _hill_row(base_y: float, sc_base: float, z: int, tint: Color,
		hang := false, x0 := WORLD_L - 250.0, x1 := WORLD_R + 250.0,
		step_lo := 0.52, step_hi := 0.66) -> void:
	var ids := [1, 3, 4]   # the wide mound strips (2/5 are radial bursts)
	var x := x0
	while x < x1:
		var hi: int = ids[_rng.randi() % ids.size()]
		var tex: Texture2D = load(BASE + "fungalhill%d.png" % hi)
		# strong per-sprite variation (scale, height, VALUE) — rows must
		# undulate and shift, never settle into a constant-height band
		var sc := sc_base * _rng.randf_range(0.78, 1.25)
		var h := tex.get_height() * sc
		var y := base_y + _rng.randf_range(-28.0, 28.0)
		var tj := _rng.randf_range(0.84, 1.12)
		var vt := Color(tint.r * tj, tint.g * tj, tint.b * tj)
		# bottom-anchored growing up; top-anchored dripping down when hanging
		var cy := (y - h * 0.5) if not hang else (y + h * 0.5)
		_sprite("fungalhill%d.png" % hi, Vector2(x, cy), sc, z, vt,
				_rng.randf() < 0.5, hang)
		x += tex.get_width() * sc * _rng.randf_range(step_lo, step_hi)


func _ground_band() -> void:
	# THE SIX FINGER-ROWS ARE GONE. This was the floor: `fungalhill` strips laid
	# end to end in six overlapping rows at six heights. That is the LAWN —
	# thousands of identical fingers filling the bottom half of every screen —
	# and it is what Advika kept circling, what she meant by "look at how good
	# level2 looks and how shit level 3 looks", and why moving the hero's draw
	# order around never fixed anything. It was never a depth bug. It was the
	# ground being a texture instead of a place.
	#
	# `_moss_body()` is now Realm 2's actual floor, loaded from Realm 2's own
	# files (see there), and this only adds the woven accents on top of it.
	_floor_mat()


## the meadow builder — ONE gradient field, not stacked flat layers
## (Advika: the dark front band read as a strip). Every clump draws its
## own depth t: tint slides continuously from the lit back value to the
## dark front value, z follows t, height rides TWO overlapped waves plus
## jitter. The walk line becomes a zigzag of value and height — there is
## no boundary anywhere for the eye to follow.
func _floor_mat() -> void:
	# The scattered-clump meadow that used to live here is GONE. It was the
	# source of every ruled line Advika kept circling: thousands of sprites
	# that each shared a base, a height or a top, and whatever they shared read
	# as a line drawn across the level. The floor is now `_moss_body()` — one
	# pre-composed strip repeated at six depths, Realm 2's construction.
	# What survives here is only the woven accents: single mushrooms and curled
	# sprouts at random depths, sparse enough that they never form a row.
	# woven accents at random depths: tiny mushrooms and curled sprouts
	var ax := WORLD_L + _rng.randf_range(150.0, 400.0)
	while ax < WORLD_R:
		# NEVER above her. She draws at z5, and these accents were picking z6
		# half the time — so a lit cap could land on her exact x and sit over her
		# head like a hat. Caught in a screenshot, not by reasoning: the whole
		# hero was behind a glowing mushroom.
		var az: int = 1 if _rng.randf() < 0.5 else 4
		if _rng.randf() < 0.55:
			var mid: int = [16, 18, 20, 21, 22, 25][_rng.randi() % 6]
			var mt: Texture2D = load(BASE + "mushroomglow%d.png" % mid)
			var msc := _rng.randf_range(0.10, 0.16)
			_sprite("mushroomglow%d.png" % mid,
					Vector2(ax, FLOOR_Y + 20.0 - mt.get_height() * msc * 0.5 + 10.0),
					msc, az, Color(FRINGE_NEAR.r * 0.9, FRINGE_NEAR.g * 0.9,
					FRINGE_NEAR.b * 0.9), _rng.randf() < 0.5)
		else:
			var ci := 17 + _rng.randi() % 5
			var ct: Texture2D = load(BASE + "fungalfrond%d.png" % ci)
			var csc := _rng.randf_range(0.14, 0.20)
			_sprite("fungalfrond%d.png" % ci,
					Vector2(ax, FLOOR_Y + 18.0 - ct.get_height() * csc * 0.5 + 8.0),
					csc, az, PLAY_GROWTH, _rng.randf() < 0.5)
		ax += _rng.randf_range(380.0, 700.0)
	# (the old seam-belt tuft strip is gone — Advika: it read as a
	# continuous moss band above the ground. The undulating rows + meadow
	# interlock on their own now.)


## the same recipe upside down for a cave-roof edge: a near-solid deep
## CURTAIN first (big strips, tight step — heads buried in the fill, no
## background window survives between fingers), then two shaped rows in
## front. The ceiling reads as one grown underside, end to end.
func _roof_band(x0: float, x1: float, edge_y: float) -> void:
	_hill_row(edge_y - 10.0, 0.55, 1, _depth(D_MID + 0.08), true, x0, x1,
			0.38, 0.48)
	_hill_row(edge_y - 25.0, 0.44, 1, _depth(D_NEAR), true, x0, x1,
			0.46, 0.58)
	_hill_row(edge_y - 35.0, 0.32, 2, _depth(D_NEAR + 0.16), true, x0, x1)


func _build_platforms() -> void:
	# Platforms are MUSHROOMS ONLY (Advika: rocks are decor, never steps).
	# Each arc climbs low -> mid -> high. The LOW step is a giant cap
	# half-buried in the meadow — a dome swelling out of the growth; the
	# higher steps are full mushrooms with visible stems.
	# ZONE B
	_shroom_platform(950.0, FLOOR_Y - 62.0, 9, false, 210.0, false)
	_shroom_platform(1500.0, FLOOR_Y - 128.0, 9)
	# ZONE C: the overgrown stack
	_shroom_platform(2950.0, FLOOR_Y - 58.0, 6, true, 210.0, false)
	_shroom_platform(3350.0, FLOOR_Y - 128.0, 6)
	_shroom_platform(3750.0, FLOOR_Y - 252.0, 4, true)
	# ZONE D
	_shroom_platform(4750.0, FLOOR_Y - 60.0, 4, false, 210.0, false)
	_shroom_platform(5250.0, FLOOR_Y - 128.0, 10)
	_shroom_platform(5750.0, FLOOR_Y - 252.0, 9, true)
	# THE LONG WALK — climbing arcs repeat down the cavern, each with its
	# own cap species mix; clean boulder piles sit at the arc feet as DECOR
	var arc_caps: Array = [[9, 6, 9], [6, 4, 10], [10, 10, 6], [4, 9, 4]]
	for ai in ARC_XS.size():
		var amx: float = ARC_XS[ai]
		var caps: Array = arc_caps[ai % arc_caps.size()]
		_shroom_platform(amx, FLOOR_Y - 66.0, caps[0], ai % 2 == 0, 210.0, false)
		_shroom_platform(amx + 500.0, FLOOR_Y - 128.0, caps[1], ai % 2 == 1)
		_shroom_platform(amx + 1000.0, FLOOR_Y - 252.0, caps[2], ai % 2 == 0)
		_boulder_decor(amx - 320.0, ai % 2 == 1)
		_shroom_cluster(amx + 490.0, FLOOR_Y + 12.0, (ai + 1) % 3)
	# LONE HOP CAPS (Advika: mushrooms to jump on) — playful single domes
	# swelling from the meadow down every stretch between the arcs
	# the echo gate's plate / cap / wall are hand-placed — keep the procedural
	# hop domes off them or a stray cap grows through the puzzle
	var used: Array[float] = [950.0, 1500.0, 2950.0, 3350.0, 3750.0,
			4750.0, 5250.0, 5750.0]
	for amx in ARC_XS:
		used.append(amx)
		used.append(amx + 500.0)
		used.append(amx + 1000.0)
	var hx := 700.0
	var hpi := 0
	while hx < WORLD_R - 700.0:
		var clear := true
		for ux in used:
			if absf(hx - ux) < 430.0:
				clear = false
				break
		if clear:
			# DECOR, not steps. These are the low domes swelling out of the
			# meadow between the climbs; standing on them turned the whole
			# walk into a hop over scenery. The arcs are where she climbs.
			# Advika: *"why are we ontop of structures???"* — these are the
			# scenery domes swelling out of the meadow, and they were topping
			# out 108-140px over the walk line. She is 143px tall, so they came
			# up to her CHEST; and because she draws in front of them, standing
			# beside one reads exactly like standing on top of one. They are
			# ankle-to-knee now, which is what "swelling out of the meadow"
			# actually looks like, and the front growth still crosses them.
			_shroom_platform(hx, FLOOR_Y - _rng.randf_range(34.0, 78.0),
					[9, 6, 4, 10][hpi % 4], hpi % 2 == 1, 210.0, false)
			hpi += 1
		hx += _rng.randf_range(680.0, 980.0)


## rocks are DECOR (Advika): a clean half-sunk pile in the meadow —
## no growth on the stone, no collider, nothing to stand on
func _boulder_decor(cx: float, fh := false) -> void:
	_prop("fungalstoneb%d.png" % [6, 4, 1][int(absf(cx)) % 3], cx,
			FLOOR_Y + 60.0, _rng.randf_range(0.36, 0.44), 3,
			_dim(PLAY_STONE, 0.86), fh)
	_prop("fungalstoneb%d.png" % [1, 6, 4][int(absf(cx)) % 3], cx + 130.0,
			FLOOR_Y + 50.0, _rng.randf_range(0.24, 0.30), 4,
			_dim(PLAY_STONE, 0.70), not fh)


## a giant mushroom rooted in the floor — the cap is the platform.
## bury = how deep the base sits under the floor line: 40 keeps the stem
## visible; ~210 sinks it so only the dome swells out of the meadow.
## `walk` = false builds the mushroom as pure scenery: same dome, same perched
## little caps, NO collider. Advika: the low domes scattered through the meadow
## are not steps — down here she walks on the ground.
func _shroom_platform(cx: float, top_y: float, cap_id: int, fh := false,
		bury := 40.0, walk := true) -> void:
	var tex: Texture2D = load(BASE + "mushroomcap%d.png" % cap_id)
	# scale so the cap's walkable dome (~8% below the texture top) is top_y
	var sc := (FLOOR_Y + bury - top_y) / (tex.get_height() * 0.92)
	var h := tex.get_height() * sc
	var w := tex.get_width() * sc
	# the caps used to draw at full WHITE modulate, which made the pale blue-grey
	# painted domes the brightest objects in the level after the lantern — a row
	# of them across the meadow read as headlights. They are the play layer's
	# own value now: still the lightest thing she stands on, nowhere near white.
	_sprite("mushroomcap%d.png" % cap_id,
			Vector2(cx, FLOOR_Y + bury - h * 0.5), sc, 1, PLAY_STONE, fh)
	# one-way slab across the cap — she can hop up through it, walk off it
	if walk:
		_collider_rect(cx - w * 0.26, cx + w * 0.26, top_y, top_y + 24.0, true)
	# a couple of tiny caps perched on the dome — overgrown, lived-on
	_prop("mushroomglow%d.png" % ([16, 20, 25][_rng.randi() % 3]),
			cx - w * 0.14, top_y + 10.0, 0.16, 2, PLAY_STONE, _rng.randf() < 0.5)
	_prop("mushroomglow%d.png" % ([18, 21, 22][_rng.randi() % 3]),
			cx + w * 0.17, top_y + 12.0, 0.13, 2, PLAY_STONE, _rng.randf() < 0.5)


const ROOF_Y := -380.0   # ONE ceiling line, end to end (Advika: uniform, higher)

func _build_ceiling() -> void:
	# ONE continuous roof: a single fill + a single hanging hill band the
	# whole way — no chunks, no steps, no gaps. Stalactites and half-sunk
	# boulders vary the silhouette; the LINE never moves.
	# ABOVE the dressed edge the rock is DARK stone the whole way — a jump
	# must read as looking up into black rock. The gradient stays dark end
	# to end: SOIL at the fringe line fading to near-black above. (Advika
	# 2026-07-15: the old bottom stop was FILL_DARK — the bright terrain
	# teal — and it glowed as a rectangular band right above the fringe.)
	var roof_deep := Color(0.016, 0.03, 0.027)   # near-black cave rock
	var grad_p := Polygon2D.new()
	grad_p.polygon = PackedVector2Array([
			Vector2(WORLD_L - 900.0, -820.0), Vector2(WORLD_R + 900.0, -820.0),
			Vector2(WORLD_R + 900.0, ROOF_Y), Vector2(WORLD_L - 900.0, ROOF_Y)])
	grad_p.vertex_colors = PackedColorArray([roof_deep, roof_deep, SOIL, SOIL])
	grad_p.z_index = 0
	add_child(grad_p)
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, -1400.0, -820.0, 0, roof_deep)
	_roof_band(WORLD_L - 250.0, WORLD_R + 250.0, ROOF_Y)
	# THE WHITE FANGS ARE GONE. These were painted at 0.66-0.76 grey, which
	# made a row of near-white teeth the highest-value thing in the picture
	# after the lantern — and they hung at the TOP of the frame, so the eye was
	# pulled up and out of the level every single screen. The art is worse than
	# it looks, too: the pack paints stalagmites pale at the tip and black at
	# the base, so flipping one for a ceiling puts its brightest end pointing
	# straight down. They are on the value ramp now, at the depth they actually
	# occupy, and there are fewer of them.
	var stx := WORLD_L - 350.0
	var sti := 0
	while stx < WORLD_R + 350.0:
		var st_id: int = [12, 14, 13, 15, 16][sti % 5]
		var st_sc := _rng.randf_range(0.62, 0.95)
		var tex: Texture2D = load(BASE + "stalagmite%d.png" % st_id)
		_sprite("stalagmite%d.png" % st_id,
				Vector2(stx, ROOF_Y + 8.0 + tex.get_height() * st_sc * 0.5),
				st_sc, 3, _depth(D_NEAR + 0.10), _rng.randf() < 0.5, true)
		stx += _rng.randf_range(520.0, 760.0)
		sti += 1
	# hanging curls on a long rhythm
	var phx := 1440.0
	while phx < WORLD_R:
		_prop_hang("fungalfrond%d.png" % (18 + (int(phx) % 2)), phx,
				ROOF_Y + 6.0, _rng.randf_range(0.26, 0.32), 2, FRINGE_HANG)
		phx += _rng.randf_range(2900.0, 3900.0)
	# (no boulders poking above the edge — they read as floating lumps in
	# the dark when a jump lifts the camera. The roof's mass is the
	# gradient dark + the hanging band, nothing else.)


## top-anchored hanging prop (curls off the chunk's underside)
func _prop_hang(tex_name: String, x: float, top_y: float, sc: float, z: int,
		tint := PLAY_STONE) -> void:
	var tex: Texture2D = load(BASE + tex_name)
	var h := tex.get_height() * sc
	_sprite(tex_name, Vector2(x, top_y + h * 0.5 - 8.0), sc, z, tint,
			_rng.randf() < 0.5, true)


# ---------- set-pieces ----------
## THE ROCK MASSES ARE GONE, ALL OF THEM.
##
## Advika, at the last one still standing: *"why on earth do we hv a lump of
## rock."* It is the right question and the answer is that they should never
## have been here. Two hanging ceiling chunks and three floating rock ledges
## came out of the 2026-07 reference images, and they broke HER OWN LAW for
## this realm, written down in July: **platforms are mushrooms only; rock is
## decor, nothing grows on it and nothing stands on it.** A rock slab in the
## air is that law inverted twice over — stone, hanging, walkable.
##
## They also cost two rebuilds on their own. First they read as untextured
## black rectangles; rimmed properly they read as picture frames; rebuilt as
## boulder piles they read as a lump of rock hanging over the forest with no
## reason to be there. Three passes is the level telling you the object is
## wrong, not the execution.
##
## The high path they carried survives — the three ledges are GIANT MUSHROOMS
## now, at the same x and the same heights, so the route through zones B to D
## is unchanged and every surface in the cavern is fungus again.

## first showcase pass — zones B..D only (Advika judges, then we extend
## the grammar down the long walk). Slabs live in the CLEAR AIR band
## (>=250px over the floor — lower drowns in the meadow) and continue the
## existing mushroom climbs, the refs' high-path idiom: B's P2 cap
## (1500, -245) -> two slabs bridge to C's first dome (2950, -120); C's
## stack top (3750, -350) steps off onto a slab before the drop.
func _build_setpieces() -> void:
	# the high path, in mushroom: same x, same tops, same jumps
	_shroom_platform(1900.0, FLOOR_Y - 310.0, 3)   # off P2's cap...
	_shroom_platform(2600.0, FLOOR_Y - 340.0, 10, true)  # ...to C's first dome
	_shroom_platform(4250.0, FLOOR_Y - 330.0, 4)   # step off the C stack top
	_build_oddities()


# ---------- THE ODDITIES ----------
## Advika: *"add some more whacky structures to it — like moss and vines with
## rocks and mushrooms, yk."*
##
## NOTE this revises a standing law. The July rule for this realm was "rocks are
## decor, no growth on stone" — written when stone kept turning up as walkable
## floor it had no business being. What she is asking for now is the opposite
## and it is a different thing: not rock as terrain, but rock CAUGHT IN the
## fungus. It stays scenery, it just stops being scenery on its own.
##
## Five kinds, and the rule that makes them read as structures rather than as
## piles: every one is a load path. Something holds something else up, and you
## can see what. A stone is wedged in a crook, or cradled in a ring of stems, or
## the thing above it is visibly resting on the thing below.
##
## RARE, by her older standing note — variety, not wallpaper. One every
## ~3400px, never within 700px of a climbing arc (the platforming stays clean),
## and always rooted in the meadow. Nothing here floats.
const ODDITY_STEP := 3400.0


func _build_oddities() -> void:
	if OS.get_environment("R3_ODD") == "0":
		return
	var x := 1150.0
	var k := 0
	while x < WORLD_R - 900.0:
		var clear := true
		for ax in ARC_XS:
			if absf(x - ax) < 700.0 or absf(x - (ax + 500.0)) < 700.0 					or absf(x - (ax + 1000.0)) < 700.0:
				clear = false
				break
		if clear:
			_oddity(x, k % 5)
			k += 1
		x += ODDITY_STEP * _rng.randf_range(0.82, 1.20)


## ODDITIES LIVE IN THE PLAY SPACE, NOT IN THE BACKGROUND.
##
## The first pass tinted them at near-band depth, and the result was that the
## thin stems holding a cradled boulder up were both too dark to see AND partly
## swallowed by the foreground bank — so the structure lost its load path and
## all that read was a rock apparently floating in the air, which is the exact
## note Advika has now raised twice. They are lit at the play layer's own value:
## `k` is how far each piece recedes from it, 0 = right here, 1 = the near band.
func _odd_tint(k: float) -> Color:
	return PLAY_STONE.lerp(_depth(D_NEAR), clampf(k, 0.0, 1.0))


func _oddity(cx: float, kind: int) -> void:
	var t: float = 0.0
	match kind:
		0: _odd_arch(cx, t)
		1: _odd_fallen(cx, t)
		2: _odd_cradle(cx, t)
		3: _odd_curtain(cx, t)
		4: _odd_cairn(cx, t)


## PLANTING A LEANING STALK, PROPERLY.
##
## Godot rotates a Sprite2D about its CENTRE, so leaning one swings its foot
## off the ground and lifts its head somewhere you did not ask for. The first
## arch was built by setting a base position and then adding rotation, which
## meant neither end landed where the maths said — its two stalks never
## actually met, and the boulder that was supposed to be wedged in the crook
## ended up hanging in clear air above two stalks that were merely leaning.
## Which is the third time now that a rock has appeared to float, and all three
## were the same class of mistake: placing growth against a number instead of
## against the geometry it is actually resting on.
##
## This plants the FOOT at `fx, fy` and returns where the head ends up, so the
## caller can put things on top of it and be right.
func _lean_stalk(tex_name: String, fx: float, fy: float, h: float,
		rot_deg: float, z: int, tint: Color, fh := false) -> Vector2:
	var tex: Texture2D = load(BASE + tex_name)
	var r: float = deg_to_rad(rot_deg)
	var s := Sprite2D.new()
	s.texture = tex
	var sc: float = h / float(tex.get_height())
	s.scale = Vector2(sc, sc)
	s.flip_h = fh
	s.rotation = r
	# local bottom (0, h/2) rotates to (-h/2 sin r, h/2 cos r); solve for the
	# centre that puts it exactly on the foot we were given
	s.position = Vector2(fx + h * 0.5 * sin(r), fy - h * 0.5 * cos(r))
	s.modulate = _mush_tint(tex_name, tint)
	s.z_index = z
	add_child(s)
	return Vector2(fx + h * sin(r), fy - h * cos(r))


## THE ARCH — two giant stems planted apart and leaning until they MEET, with a
## boulder wedged in the crook they make and growth spilling out of the join.
## The lean is solved from the span, not guessed: sin(theta) = span / height, so
## the two heads land on the centre line whatever size the arch comes out.
func _odd_arch(cx: float, t: float) -> void:
	var span := _rng.randf_range(150.0, 230.0)
	var h := _rng.randf_range(430.0, 620.0)
	var theta: float = rad_to_deg(asin(clampf(span / h, 0.0, 0.70)))
	var head := Vector2(cx, FLOOR_Y)
	for side in [-1.0, 1.0]:
		var sid: int = [1, 5, 7, 8, 2][_rng.randi() % 5]
		head = _lean_stalk("mushroomcap%d.png" % sid, cx + side * span,
				FLOOR_Y + 40.0, h * _rng.randf_range(0.96, 1.04),
				-side * theta, 3, _odd_tint(0.30), side > 0.0)
	# NOTHING SITS IN THE CROOK. The arch carried a boulder wedged where the two
	# stalks meet, with growth packed round the join — Advika circled it twice
	# and then said to take the rock and the moss out. She is right: the two
	# stalks crossing ARE the structure, and everything balanced on top of them
	# only ever muddied that silhouette. First it read as a table, then as a
	# dark lump snagged in a fork. The join is bare now and the shape is legible
	# from across the cavern.
	for i in 3:
		var f := _prop("fungalfrond%d.png" % (17 + _rng.randi() % 5),
				cx + _rng.randf_range(-span, span), FLOOR_Y + 26.0,
				_rng.randf_range(0.20, 0.30), 4, PLAY_GROWTH, _rng.randf() < 0.5)
		f.rotation_degrees = _rng.randf_range(-12.0, 12.0)


## THE FALLEN GIANT — a huge cap toppled on its side, half sunk in the meadow,
## a new generation growing straight out of its back.
func _odd_fallen(cx: float, t: float) -> void:
	var cid: int = [9, 6, 3, 10, 4][_rng.randi() % 5]
	var tex: Texture2D = load(BASE + "mushroomcap%d.png" % cid)
	var w := _rng.randf_range(520.0, 760.0)
	var sc: float = w / float(tex.get_width())
	var body := _sprite("mushroomcap%d.png" % cid,
			Vector2(cx, FLOOR_Y + 74.0 - tex.get_height() * sc * 0.42), sc, 2,
			_odd_tint(0.45), _rng.randf() < 0.5)
	body.rotation_degrees = _rng.randf_range(64.0, 96.0) 			* (1.0 if _rng.randf() < 0.5 else -1.0)
	# the stone it came down on, half under it
	_prop("fungalstoneb%d.png" % [4, 6, 5][_rng.randi() % 3],
			cx + _rng.randf_range(-w * 0.4, w * 0.4), FLOOR_Y + 56.0,
			_rng.randf_range(0.22, 0.34), 1, _odd_tint(0.45), _rng.randf() < 0.5)
	# what grew out of the corpse — a row of young caps along its length
	for i in 5:
		var f: float = (float(i) / 4.0 - 0.5) * w * 0.8
		var gid: int = [16, 19, 20, 25, 22][i % 5]
		_prop("mushroomglow%d.png" % gid, cx + f, FLOOR_Y - _rng.randf_range(20.0, 90.0),
				_rng.randf_range(0.14, 0.24), 4, PLAY_STONE, _rng.randf() < 0.5)
	_fringe(cx - w * 0.42, cx + w * 0.42, FLOOR_Y + 30.0, false,
			0.14, 0.24, 3, PLAY_GROWTH)


## THE CRADLE — a boulder held clear of the ground in a ring of mushroom stems,
## with moss skirting the join. The load path is the whole point: you can see
## the stems taking the weight.
func _odd_cradle(cx: float, t: float) -> void:
	# the bank in front of her tops out at y 356, so a cradle lower than this
	# hides its own legs and the stone looks like it is hovering
	var lift := _rng.randf_range(250.0, 340.0)
	var ring := _rng.randf_range(90.0, 140.0)
	# the stems lean IN toward the stone they are carrying, feet planted, so
	# the load path is visible: four legs, one boulder, no mystery
	var top: float = FLOOR_Y
	for i in 4:
		var f: float = float(i) / 3.0 - 0.5
		var sid: int = [5, 1, 7, 8][i]
		var sh: float = lift * _rng.randf_range(1.05, 1.25)
		var hd: Vector2 = _lean_stalk("mushroomcap%d.png" % sid,
				cx + f * ring * 2.0, FLOOR_Y + 36.0, sh,
				-f * _rng.randf_range(16.0, 26.0), 3, _odd_tint(0.45), i % 2 == 0)
		top = hd.y if i == 0 else minf(top, hd.y)
	var rid: int = [10, 11, 6][_rng.randi() % 3]
	var rt: Texture2D = load(BASE + "fungalstoneb%d.png" % rid)
	var rh := _rng.randf_range(170.0, 250.0)
	var rock := _sprite("fungalstoneb%d.png" % rid,
			Vector2(cx, top + rh * 0.30), rh / float(rt.get_height()),
			4, _odd_tint(0.12), _rng.randf() < 0.5)
	rock.set_meta("air", true)
	# moss packed into the cradle where stone meets stem
	_fringe(cx - ring, cx + ring, top + rh * 0.42, false,
			0.12, 0.20, 5, PLAY_GROWTH)
	_fringe(cx - ring * 0.8, cx + ring * 0.8, top + rh * 0.54, true,
			0.10, 0.16, 5, _odd_tint(0.12), 0.7)


## THE CURTAIN — a stand of the tall curled fronds, the pack's vines, hung off
## a leaning stone with small caps riding them.
func _odd_curtain(cx: float, t: float) -> void:
	var rid: int = [2, 3, 8, 9][_rng.randi() % 4]
	var rt: Texture2D = load(BASE + "fungalstoneb%d.png" % rid)
	var rh := _rng.randf_range(300.0, 430.0)
	var lean := _sprite("fungalstoneb%d.png" % rid,
			Vector2(cx, FLOOR_Y + 50.0 - rh * 0.5), rh / float(rt.get_height()),
			2, _odd_tint(0.45), _rng.randf() < 0.5)
	lean.rotation_degrees = _rng.randf_range(-16.0, 16.0)
	# the vines: fungalfrond 22/23 are the tall curled ones
	for i in 5:
		var vid: int = 22 + (i % 2)
		var vt: Texture2D = load(BASE + "fungalfrond%d.png" % vid)
		var vh := _rng.randf_range(200.0, 380.0)
		var v := _sprite("fungalfrond%d.png" % vid,
				Vector2(cx + _rng.randf_range(-150.0, 150.0),
				FLOOR_Y + 34.0 - vh * 0.5), vh / float(vt.get_height()),
				4, PLAY_GROWTH, _rng.randf() < 0.5)
		v.rotation_degrees = _rng.randf_range(-10.0, 10.0)
	for i in 3:
		_prop("mushroomglow%d.png" % [18, 21, 25][i], cx + _rng.randf_range(-140.0, 140.0),
				FLOOR_Y + 22.0, _rng.randf_range(0.13, 0.20), 5, PLAY_STONE,
				_rng.randf() < 0.5)


## THE CAIRN — stones stacked with fungus wedged between every course, each one
## visibly bedded on the one under it.
func _odd_cairn(cx: float, t: float) -> void:
	var y := FLOOR_Y + 40.0
	var wide := _rng.randf_range(150.0, 210.0)
	for i in 4:
		var rid: int = [10, 6, 11, 4, 1, 7][(i * 2 + _rng.randi()) % 6]
		var rt: Texture2D = load(BASE + "fungalstoneb%d.png" % rid)
		var rh: float = wide * (1.0 - float(i) * 0.17)
		var sc: float = rh / float(rt.get_height())
		var r := _sprite("fungalstoneb%d.png" % rid,
				Vector2(cx + _rng.randf_range(-26.0, 26.0), y - rh * 0.5),
				sc, 3 + i, _odd_tint(0.45 - float(i) * 0.10), i % 2 == 0)
		r.rotation_degrees = _rng.randf_range(-9.0, 9.0)
		r.set_meta("air", true)
		# fungus packed into the joint, which is what stops it being a stack
		_fringe(cx - rh * 0.42, cx + rh * 0.42, y - rh * 0.06, false,
				0.09, 0.15, 4 + i, PLAY_GROWTH)
		y -= rh * _rng.randf_range(0.62, 0.76)
	# a cap crowning it, and curls off the base
	_prop("mushroomglow%d.png" % [1, 5, 12][_rng.randi() % 3], cx, y + 30.0,
			_rng.randf_range(0.18, 0.26), 8, PLAY_STONE, _rng.randf() < 0.5)
	for i in 2:
		_prop("fungalfrond%d.png" % (17 + _rng.randi() % 5),
				cx + _rng.randf_range(-140.0, 140.0), FLOOR_Y + 26.0,
				_rng.randf_range(0.18, 0.26), 3, PLAY_GROWTH, _rng.randf() < 0.5)


# ---------- dressing: the grouped assemblies ----------

func _build_dressing() -> void:
	# ZONE A — the mushroom shelf (ref 3 left): boulder mound carrying a
	# family of big blue flat-caps, amber stalks leaning on its shoulder
	_prop("fungalstone20.png", -620.0, FLOOR_Y + 10.0, 0.6, 3)
	_prop("mushroomcap9.png", -700.0, FLOOR_Y - 130.0, 0.5, 4)
	_prop("mushroomcap6.png", -540.0, FLOOR_Y - 138.0, 0.38, 4, PLAY_STONE, true)
	_prop("mushroomcap4.png", -620.0, FLOOR_Y - 60.0, 0.26, 5)
	var amber_a := _prop("mushroomglow5.png", -430.0, FLOOR_Y + 6.0, 0.34, 3)
	_glow_light(amber_a, GLOW_WARM, 0.3, 1.2)
	_prop("mushroomglow7.png", -380.0, FLOOR_Y + 8.0, 0.26, 3, PLAY_STONE, true)
	# spawn-side boulder pair so the start reads placed, not empty
	_prop("fungalstone22.png", -120.0, FLOOR_Y + 10.0, 0.55, 3)
	_prop("fungalstone2.png", -20.0, FLOOR_Y + 12.0, 0.4, 3, PLAY_STONE, true)

	# ZONE B — ref 1's floor life. Assembly 1: pot cluster + boulder + curl
	_prop("fungalstone18.png", 640.0, FLOOR_Y + 14.0, 0.5, 3)
	_prop("fungalfrond29.png", 700.0, FLOOR_Y + 10.0, 0.28, 4)
	_prop("fungalfrond27.png", 560.0, FLOOR_Y + 8.0, 0.22, 4, PLAY_STONE, true)
	var stalk_b1 := _prop("mushroomcap1.png", 760.0, FLOOR_Y + 6.0, 0.26, 3)
	_glow_light(stalk_b1, GLOW_WARM, 0.28, 1.4)
	# assembly 2: gold stalks + amber toadstools + pots against the pedestal
	var stalk_b2 := _prop("mushroomcap5.png", 1190.0, FLOOR_Y + 6.0, 0.3, 4)
	_glow_light(stalk_b2, GLOW_WARM, 0.3, 1.5)
	_prop("mushroomglow1.png", 1260.0, FLOOR_Y + 8.0, 0.3, 3)
	_prop("fungalfrond25.png", 1120.0, FLOOR_Y + 10.0, 0.2, 4)
	# assembly 3: the mound + pot + tall curl (mid-walk breather)
	_prop("fungalstone19.png", 1850.0, FLOOR_Y + 14.0, 0.55, 3)
	_prop("fungalfrond30.png", 1960.0, FLOOR_Y + 10.0, 0.26, 4)
	_prop("fungalfrond22.png", 1770.0, FLOOR_Y + 6.0, 0.24, 3)
	var amber_b := _prop("mushroomglow4.png", 2060.0, FLOOR_Y + 8.0, 0.34, 3, PLAY_STONE, true)
	_glow_light(amber_b, GLOW_WARM, 0.3, 1.3)
	# assembly 4: foreground stalagmites + boulders (ref 3's right edge)
	_prop("stalagmite7.png", 2250.0, FLOOR_Y + 16.0, 0.5, 3, _dim(PLAY_STONE, 0.82))
	_prop("fungalstone1.png", 2360.0, FLOOR_Y + 12.0, 0.45, 4)
	_prop("mushroomglow11.png", 2300.0, FLOOR_Y + 6.0, 0.28, 4)

	# ZONE C — ref 2's glowers on the stack and at its feet, hues cycling
	# cyan -> moss -> cyan so the stack reads bioluminescent, not floodlit
	var wgi := 0
	for wg in [[2950.0, FLOOR_Y - 120.0, 23, 0.32], [2870.0, FLOOR_Y - 120.0, 24, 0.24],
			[3350.0, FLOOR_Y - 235.0, 17, 0.5], [3420.0, FLOOR_Y - 235.0, 24, 0.26],
			[3750.0, FLOOR_Y - 350.0, 23, 0.3], [2680.0, FLOOR_Y + 8.0, 17, 0.55],
			[3150.0, FLOOR_Y + 10.0, 24, 0.38]]:
		var m := _prop("mushroomglow%d.png" % wg[2], wg[0], wg[1], wg[3], 3,
				PLAY_STONE, _rng.randf() < 0.5)
		_glow_light(m, GLOW_COOL if wgi % 2 == 0 else GLOW_MOSS, 0.38, 1.1)
		wgi += 1
	_prop("mushroomglow16.png", 3050.0, FLOOR_Y + 8.0, 0.3, 4)
	_prop("mushroomglow19.png", 3550.0, FLOOR_Y + 10.0, 0.32, 4)
	_prop("fungalfrond23.png", 4020.0, FLOOR_Y + 8.0, 0.3, 3)
	_prop("fungalstone5.png", 3900.0, FLOOR_Y + 26.0, 0.45, 3, PLAY_STONE)

	# ZONE D — the long dark garden (the new stretch): pot fields, stalk
	# pairs, a moss-lit grove climbing to the second stack, wall-base seal
	_prop("fungalstone18.png", 4350.0, FLOOR_Y + 14.0, 0.55, 3)
	_prop("fungalfrond27.png", 4460.0, FLOOR_Y + 8.0, 0.24, 4, PLAY_STONE, true)
	var stalk_d1 := _prop("mushroomcap5.png", 4560.0, FLOOR_Y + 6.0, 0.32, 4)
	_glow_light(stalk_d1, GLOW_WARM, 0.3, 1.5)
	var moss_d1 := _prop("mushroomglow12.png", 5000.0, FLOOR_Y + 8.0, 0.34, 3)
	_glow_light(moss_d1, GLOW_MOSS, 0.32, 1.3)
	_prop("mushroomglow21.png", 5090.0, FLOOR_Y + 10.0, 0.22, 4)
	_prop("fungalstone19.png", 5450.0, FLOOR_Y + 14.0, 0.5, 3, PLAY_STONE, true)
	var cool_d1 := _prop("mushroomglow23.png", 5560.0, FLOOR_Y + 8.0, 0.4, 3)
	_glow_light(cool_d1, GLOW_COOL, 0.36, 1.2)
	# the terminal grove — the level ends in a garden of mixed glows
	var moss_d2 := _prop("mushroomglow17.png", 6050.0, FLOOR_Y + 8.0, 0.5, 3,
			PLAY_STONE, true)
	_glow_light(moss_d2, GLOW_MOSS, 0.34, 1.4)
	var amber_d := _prop("mushroomglow5.png", 6220.0, FLOOR_Y + 6.0, 0.34, 4)
	_glow_light(amber_d, GLOW_WARM, 0.3, 1.3)
	_prop("mushroomglow24.png", 6320.0, FLOOR_Y + 10.0, 0.3, 3)
	_prop("fungalfrond29.png", 6150.0, FLOOR_Y + 10.0, 0.26, 4)
	_prop("fungalstone22.png", 6420.0, FLOOR_Y + 12.0, 0.5, 3)
	_prop("fungalfrond23.png", 6500.0, FLOOR_Y + 8.0, 0.28, 4, PLAY_STONE, true)

	# THE LONG WALK (Advika: a 5-minute level) — past x 6800 rotating floor
	# motifs stamp the same grouped-assembly grammar down the whole cavern:
	# pot fields, glower pairs, stalagmite groves, moss gardens
	var dmx := 6800.0
	var dmi := 0
	while dmx < WORLD_R - 500.0:
		match dmi % 4:
			0:  # pot field + gold stalk
				_prop("fungalstone18.png", dmx, FLOOR_Y + 14.0, 0.5, 3,
						PLAY_STONE, dmi % 8 < 4)
				_prop("fungalfrond27.png", dmx + 110.0, FLOOR_Y + 8.0, 0.22, 4)
				var stalk := _prop("mushroomcap%d.png" % ([5, 1][dmi % 2]),
						dmx + 210.0, FLOOR_Y + 6.0, 0.3, 4)
				_glow_light(stalk, GLOW_WARM, 0.3, 1.4)
			1:  # white/cyan glower pair
				var wgm := _prop("mushroomglow%d.png" % ([17, 23, 24][dmi % 3]),
						dmx, FLOOR_Y + 8.0, 0.42, 3, PLAY_STONE, dmi % 2 == 0)
				_glow_light(wgm, GLOW_COOL, 0.34, 1.2)
				_prop("mushroomglow%d.png" % ([16, 19][dmi % 2]),
						dmx + 95.0, FLOOR_Y + 10.0, 0.24, 4)
			2:  # stalagmite pair + boulder
				_prop("stalagmite%d.png" % ([7, 9, 2][dmi % 3]), dmx,
						FLOOR_Y + 16.0, 0.5, 3, _dim(PLAY_STONE, 0.82))
				_prop("fungalstone%d.png" % ([1, 5, 2][dmi % 3]), dmx + 120.0,
						FLOOR_Y + 12.0, 0.45, 4, PLAY_STONE, dmi % 2 == 1)
			3:  # moss-green garden
				var mgm := _prop("mushroomglow%d.png" % ([12, 4][dmi % 2]),
						dmx, FLOOR_Y + 8.0, 0.34, 3)
				_glow_light(mgm, GLOW_MOSS, 0.32, 1.3)
				_prop("mushroomglow21.png", dmx + 90.0, FLOOR_Y + 10.0, 0.22, 4)
		dmx += _rng.randf_range(650.0, 950.0)
		dmi += 1


## the density pass: growth CLUSTERS, not scatter. Clumps of 3-6 glowers at
## platform edges and rock bases (small overlapping big), cup fungi tucked
## into floor corners, lone ferns breaking the long fringe runs. z varies —
## some behind the pebble rims (1), most amongst/in front of the fringe.
func _build_density() -> void:
	for cl in [
			[-640.0, FLOOR_Y + 14.0, 2],      # under the flat-cap shelf
			[-150.0, FLOOR_Y + 12.0, 2],      # spawn boulders
			[615.0, FLOOR_Y + 12.0, 0],       # pot assembly's shoulder
			[950.0, FLOOR_Y + 12.0, 2],      # zone B dome crown
			[1495.0, FLOOR_Y + 12.0, 2],     # P2 cap top
			[1890.0, FLOOR_Y + 12.0, 0],      # the mound's feet
			[2290.0, FLOOR_Y + 14.0, 2],      # fore stalagmite base
			[2940.0, FLOOR_Y + 12.0, 1],     # zone C pedestal top
			[2740.0, FLOOR_Y + 12.0, 1],      # stack feet
			[3340.0, FLOOR_Y + 12.0, 1],     # P4 top (follows the lowered step)
			[3590.0, FLOOR_Y + 12.0, 2],      # zone C floor run
			[3960.0, FLOOR_Y + 14.0, 2],      # zone C/D border
			[4740.0, FLOOR_Y + 10.0, 2],      # D mound top — the mound is decor now
			[4480.0, FLOOR_Y + 12.0, 0],      # D pot field
			[5240.0, FLOOR_Y + 12.0, 1],     # D cap top (follows the lowered step)
			[5620.0, FLOOR_Y + 12.0, 2],      # D grove floor
			[6080.0, FLOOR_Y + 12.0, 1],      # terminal grove
			[6460.0, FLOOR_Y + 14.0, 0]]:     # zone D floor
		_shroom_cluster(cl[0] as float, cl[1] as float, int(cl[2]))
	# the long walk: clusters keep coming on their own rhythm
	var lcx := 6900.0
	var lci := 0
	while lcx < WORLD_R - 300.0:
		_shroom_cluster(lcx, FLOOR_Y + 12.0, lci % 3)
		lcx += _rng.randf_range(560.0, 820.0)
		lci += 1
	# cup fungi in the floor corners, the whole way down
	var cups: Array = []
	var cupx := WORLD_L + 50.0
	while cupx < WORLD_R - 150.0:
		cups.append([cupx, _rng.randf_range(0.13, 0.16)])
		cupx += _rng.randf_range(420.0, 1050.0)
	for cup in cups:
		_prop("fungalfrond%d.png" % (24 + _rng.randi() % 5), cup[0] as float,
				FLOOR_Y + 16.0, cup[1] as float,
				1 if _rng.randf() < 0.5 else 4, PLAY_STONE, _rng.randf() < 0.5)
	# lone ferns breaking the fringe line
	var ferns: Array = []
	var fernx := WORLD_L + 180.0
	while fernx < WORLD_R - 150.0:
		ferns.append([fernx, _rng.randf_range(0.22, 0.26)])
		fernx += _rng.randf_range(400.0, 720.0)
	for fern in ferns:
		var fi: int = [1, 5, 6, 7, 8, 9, 12, 13, 14, 15][_rng.randi() % 10]
		_prop("fungalfrond%d.png" % fi, fern[0] as float, FLOOR_Y + 10.0,
				fern[1] as float, 3 if _rng.randf() < 0.5 else 4, FRINGE_NEAR,
				_rng.randf() < 0.5)


## one clump. style: 0 = amber-led, 1 = white-glower-led, 2 = thin mixed
func _shroom_cluster(cx: float, base_y: float, style: int) -> void:
	var tall_amber := [1, 4, 5, 6, 10, 12]
	var small := [16, 18, 19, 20, 21, 22, 25]
	var white_caps := [17, 23, 24]
	var n := 3 + _rng.randi() % 4
	for i in n:
		var idx: int
		var sc: float
		if i == 0 and style == 0:
			idx = tall_amber[_rng.randi() % tall_amber.size()]
			sc = _rng.randf_range(0.24, 0.32)
		elif i == 0 and style == 1:
			idx = white_caps[_rng.randi() % white_caps.size()]
			sc = _rng.randf_range(0.30, 0.42)
		else:
			idx = small[_rng.randi() % small.size()]
			sc = _rng.randf_range(0.15, 0.24)
		var z := 1 if _rng.randf() < 0.3 else (3 if _rng.randf() < 0.65 else 4)
		var m := _prop("mushroomglow%d.png" % idx,
				cx + _rng.randf_range(-75.0, 75.0),
				base_y + _rng.randf_range(0.0, 8.0), sc, z, PLAY_STONE,
				_rng.randf() < 0.5)
		var hue: Color = [GLOW_WARM, GLOW_COOL, GLOW_MOSS][style]
		if i == 0:
			_glow_light(m, hue, 0.25, 1.2)
		elif _rng.randf() < 0.4:
			_bloom(m, hue, 0.15)


## THE MOSS BODY — Realm 2's construction, ported.
##
## Advika: "theres a fucking moss line thats visible... rebuild this entire
## level exactly like how u did lvl2." She is right about the cause. Realm 3
## scattered individual frond sprites at the floor, and scattered sprites ALWAYS
## share something — a base, a height, a top — and whatever they share the eye
## reads as a ruled line straight across the level. I fixed the bottom edge,
## then built a new line at the top. There is no tuning number that fixes it.
##
## Realm 2 never had the problem because it does not scatter anything: it
## repeats ONE WIDE PRE-COMPOSED STRIP (3840px, wrap-seamless) at six depths,
## each row lower and darker, plus a front row drawn OVER the hero. A painted
## strip has no per-sprite boundaries, so there is no edge to see.
##
## `moss_strip.png` is that strip for the fungal art, built by
## tools/compose_moss_strip.py: real frond art scattered along an undulating
## line whose every wave is an integer number of cycles across the width (so it
## tiles), then union-solidified downward into one mass so no hole or internal
## boundary survives. Its only edge is the organic top.
const MOSS_STRIP := "moss_strip.png"
const MOSS_SCALE := 0.7
## where the strip's tip line falls inside the texture, in texture pixels
const MOSS_TIP_Y := 230.0

## every sprite that draws in FRONT of her — the front moss curtain, the walk
## fringe and the near-black frame bands. Held so the drained fight can lift
## the whole set over her head-height z and hand it back afterwards.
var _front_growth: Array[Sprite2D] = []
var _front_base_tint: Array[Color] = []

var _moss_dissolve: ShaderMaterial
var _moss_dissolve_soft: ShaderMaterial


## THE FLOOR IS REALM 2'S FLOOR (Advika: "use the same flooring as lvl2").
##
## Not an imitation of it — the same four objects, loaded from the same files,
## built in the same order, at the same 0.7 scale. `band_ground` for the deep
## mass, `moss_mat` for the continuous carpet the feet are always on,
## `moss_front` for the crest that keeps the mat's top edge from being a line,
## and clustered mounds on the crest. The only difference is the tint: R2's art
## is violet-shifted and this realm is teal, so every piece is multiplied into
## the teal family on the way in.
##
## The `moss_strip` lawn that used to be here is gone. Six rows of one blade
## texture repeated the length of the level is the thing that looked cheap next
## to Realm 2, and no amount of tinting or re-heighting was going to fix a
## construction problem.
const R2 := "res://assets/realms/realm2_moss/"
const R2_SCALE := 0.7
## R2's violet floor art, multiplied into this realm's teal. Measured against
## the realm's own AMBIENT rather than picked: green up, red down, blue held.
const R2_TEAL := Color(0.52, 1.12, 0.94)

## THE GROUND UNDER THE GROWTH.
##
## It was a flat `Polygon2D` in one colour, and that is what every "patch"
## Advika circled actually was: not a missing clump, but the moment you could
## see the fill itself. A flat plane has no grain, so the eye reads it as a hole
## punched in the picture rather than as earth behind the growth.
##
## Value noise at two octaves, very low contrast, entirely inside the depth
## ramp's near end — plus a slow darkening downward so the bottom of the frame
## still falls away. It is never bright enough to compete with anything, and it
## never needs covering again.
func _earth_material() -> ShaderMaterial:
	var sh := Shader.new()
	# IT SAMPLES WORLD POSITION, NOT UV.
	#
	# The first version of this used `UV`, and a scan of the finished level came
	# back with tiles whose luminance standard deviation was EXACTLY zero — a
	# pure, mathematically flat fill. `Polygon2D` has no texture here, so its UV
	# is degenerate and every fragment sampled the noise at the same point. The
	# shader was running and doing nothing, which is why the patches survived
	# being "fixed". A varying carries the world position across instead, so the
	# grain is real and it is also continuous between the soil and the ground
	# mass — they are two objects wearing one texture.
	sh.code = "shader_type canvas_item;
uniform vec3 soil : source_color = vec3(0.052, 0.094, 0.085);
uniform vec3 grain : source_color = vec3(0.022, 0.044, 0.040);
uniform float scale = 0.0075;
varying vec2 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }

void fragment() {
	vec2 p = wpos * scale;
	float n = noise(p) * 0.52 + noise(p * 3.7) * 0.31 + noise(p * 11.3) * 0.17;
	// and it falls away downward, so the frame edge is still the darkest place
	float fade = clamp((wpos.y - 430.0) / 900.0, 0.0, 1.0);
	vec3 c = mix(grain, soil, n) * (1.0 - fade * 0.5);
	COLOR = vec4(c, 1.0);
}"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _moss_body() -> void:
	# the razor-straight bottom edge of a fully opaque texture is a line across
	# the level — R2 dissolves its last 5% into the dark and so do we
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;
void fragment() {
	COLOR.a *= 1.0 - smoothstep(0.95, 0.995, UV.y);
}"
	_moss_dissolve = ShaderMaterial.new()
	_moss_dissolve.shader = sh

	# near-black soil under everything, so no gap can ever show sky
	var earth := Polygon2D.new()
	earth.polygon = PackedVector2Array([
			Vector2(WORLD_L - 2000.0, FLOOR_Y + 6.0),
			Vector2(WORLD_R + 2000.0, FLOOR_Y + 6.0),
			Vector2(WORLD_R + 2000.0, FLOOR_Y + 1400.0),
			Vector2(WORLD_L - 2000.0, FLOOR_Y + 1400.0)])
	earth.color = Color.WHITE
	earth.material = _earth_material()
	earth.z_index = 1
	add_child(earth)

	var mat: Texture2D = load(R2 + "moss_mat.png")
	var front: Texture2D = load(R2 + "moss_front.png")
	var span: float = 3840.0 * R2_SCALE
	var n: int = int((WORLD_R - WORLD_L + 4000.0) / span) + 2

	# 1) THE DEEP MASS — and `band_ground.png` is GONE from this realm.
	#
	# Advika circled two tall dark fuzzy columns and said get rid of them; the
	# forensic pass (`R3_ID=1`) came back MAGENTA on both, which is the flag for
	# Realm 2 art. They were not placed by anything — they are PAINTED INTO
	# `band_ground.png`, Realm 2's 3840x1080 deep-mass strip, which carries that
	# realm's trunk silhouettes standing up out of its ground. Laid at 0.7 scale
	# with its base on the floor line, those trunks reach the top of the frame,
	# which is exactly where she circled them. "Only the R3 pack, the floor may
	# use R2 moss" is satisfied by the pieces that are ACTUALLY floor —
	# `moss_mat`, `moss_front`, the tufts and the mossy rocks — and this one is
	# not floor, it is Realm 2's skyline.
	#
	# Its job (a dark body under the carpet, so the meadow has depth behind it
	# rather than soil) now belongs to a dense row of this realm's own mounds.
	var dx := WORLD_L - 2000.0
	var di := 0
	while dx < WORLD_R + 2000.0:
		var hid: int = [1, 3, 4, 1, 4, 3][di % 6]
		var htex: Texture2D = load(BASE + "fungalhill%d.png" % hid)
		var want_h: float = _rng.randf_range(150.0, 290.0)
		var hsc: float = want_h / float(htex.get_height())
		var h := Sprite2D.new()
		h.texture = htex
		h.scale = Vector2(hsc, hsc)
		h.flip_h = _rng.randf() < 0.5
		h.position = Vector2(dx, FLOOR_Y + 26.0 - want_h * 0.5
				+ _rng.randf_range(-18.0, 18.0))
		h.modulate = _depth(0.74 + _rng.randf_range(-0.06, 0.06))
		h.z_index = 2
		add_child(h)
		dx += htex.get_width() * hsc * _rng.randf_range(0.34, 0.52)
		di += 1

	# 2) the carpet her feet are always on — no visual dip she can float over
	for i in n:
		var m := Sprite2D.new()
		m.texture = mat
		m.centered = false
		m.scale = Vector2(R2_SCALE, R2_SCALE)
		m.position = Vector2(WORLD_L - 2000.0 + i * span, FLOOR_Y - 90.0)
		m.modulate = _dim(R2_TEAL, 0.78)
		m.z_index = 3
		add_child(m)

	# 3) the crest — a darker row of tips so the carpet's top is not a rule
	for i in n + 1:
		var c := Sprite2D.new()
		c.texture = front
		c.centered = false
		c.scale = Vector2(R2_SCALE, R2_SCALE)
		c.position = Vector2(WORLD_L - 2000.0 - span * 0.25 + i * span,
				FLOOR_Y - 150.0)
		c.modulate = _dim(R2_TEAL, 0.5)
		c.z_index = 2
		add_child(c)

	# 4) mound clusters ON the crest, exactly R2's move: the skyline gets its
	# shape from grouped masses, never from the tile
	var rocks := ["rock_moss_0.png", "rock_moss_1.png", "rock_moss_2.png"]
	var x := WORLD_L - 1200.0
	while x < WORLD_R + 1200.0:
		var rn: String = rocks[_rng.randi() % rocks.size()]
		var rt: Texture2D = load(R2 + rn)
		var rsc: float = _rng.randf_range(0.22, 0.44)
		var r := Sprite2D.new()
		r.texture = rt
		r.scale = Vector2(rsc, rsc)
		r.flip_h = _rng.randf() < 0.5
		r.position = Vector2(x, FLOOR_Y - 40.0 + rt.get_height() * rsc * 0.18)
		r.modulate = _dim(R2_TEAL, _rng.randf_range(0.34, 0.58))
		r.z_index = 3
		add_child(r)
		# a tuft or two hugging it, so no mound is a bare shape
		for k in 2:
			var tn: String = "tuft_%d.png" % (_rng.randi() % 3)
			var tt: Texture2D = load(R2 + tn)
			var tsc: float = _rng.randf_range(0.16, 0.30)
			var t := Sprite2D.new()
			t.texture = tt
			t.scale = Vector2(tsc, tsc)
			t.flip_h = _rng.randf() < 0.5
			t.position = Vector2(x + _rng.randf_range(-220.0, 220.0),
					FLOOR_Y + 4.0 - tt.get_height() * tsc * 0.34)
			t.modulate = _dim(R2_TEAL, _rng.randf_range(0.42, 0.70))
			t.z_index = 4
			add_child(t)
		x += _rng.randf_range(420.0, 820.0)


func _moss_row(tex: Texture2D, tw: float, tip_y: float, tint: Color, z: int,
		phase: float, soft: bool) -> void:
	var x: float = WORLD_L - 1400.0 + fmod(phase, tw)
	var i := 0
	while x < WORLD_R + 1400.0:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(MOSS_SCALE, MOSS_SCALE)
		# per-tile height wobble so the repeats never sit on one flat line
		s.position = Vector2(x, tip_y - MOSS_TIP_Y * MOSS_SCALE
				+ sin(float(i) * 2.6 + tip_y * 0.03) * 11.0)
		s.modulate = tint
		s.z_index = z
		s.material = _moss_dissolve_soft if soft else _moss_dissolve
		add_child(s)
		if soft:
			# the front curtain is the growth she walks INSIDE, so it has to
			# be able to climb over the drain with her when the forest dies
			_front_growth.append(s)
		x += tw
		i += 1


## THE GROUND HAS SHAPE — Realm 2's construction, in this realm's art.
##
## Advika, with both levels open side by side: "look at how good level2 looks
## and look at how shit level 3 looks... you need to fully fix it just like
## lvl2." She is right, and the difference is not a tint or a height. Realm 2's
## floor is not a TEXTURE, it is a COMPOSITION: a dark mass whose skyline is
## broken by mounds, boulder piles and clumps at four or five different sizes,
## with the hero walking behind some of them and in front of others. Realm 3's
## floor was a LAWN — one blade strip repeated the length of the level at one
## height, with nothing to cast a silhouette against it. A lawn cannot read as
## depth no matter what colour it is.
##
## So the meadow gets the same treatment the ascent corridor got: grounded
## ASSEMBLIES, never single sprites. Two passes —
##
##   BEHIND  mounds she walks in front of, breaking the flat horizon, each one
##           with its own skirt of fronds so nothing is a bare shape
##   FRONT   fewer, bigger, near-black masses she walks BEHIND. This is the
##           thing that actually reads as travelling THROUGH the growth rather
##           than across it: she is periodically eaten by the foreground and
##           comes out the other side.
##
## `fungalhill*` is the mound art. It was only ever used in the far background
## bands; at this scale, tinted down, it is the same rounded mass R2's moss
## mounds are.
func _meadow_masses() -> void:
	var fronds := FRINGE_TEX
	# --- BEHIND HER: the skyline stops being a ruled line ---
	var x := WORLD_L - 300.0
	while x < WORLD_R + 300.0:
		var hi: int = 1 + _rng.randi() % 5
		var tex: Texture2D = load(BASE + "fungalhill%d.png" % hi)
		# a target height, so the five hill shapes agree with each other
		var want_h: float = _rng.randf_range(70.0, 190.0) * GROWTH_SCALE
		var sc: float = want_h / float(tex.get_height())
		# its base is BURIED — a mound sitting on the line is a lump on a lawn
		var base: float = FLOOR_Y + _rng.randf_range(30.0, 78.0)
		var z: int = 3 if _rng.randf() < 0.5 else 4
		var dark: float = _rng.randf_range(0.30, 0.62)
		var tint := Color(FILL_DARK.r + dark * 0.20, FILL_DARK.g + dark * 0.26,
				FILL_DARK.b + dark * 0.24)
		_sprite("fungalhill%d.png" % hi,
				Vector2(x, base - want_h * 0.5), sc, z, tint, _rng.randf() < 0.5)
		# NOTHING IS A BARE SHAPE — every mound wears a skirt of growth, which
		# is the scene-dressing law and also what stops it reading as a decal
		var skirt: int = 1 + _rng.randi() % 2
		for k in skirt:
			var fi: int = fronds[_rng.randi() % fronds.size()]
			var ft: Texture2D = load(BASE + "fungalfrond%d.png" % fi)
			var fh: float = _rng.randf_range(34.0, 70.0) * GROWTH_SCALE
			var fsc: float = fh / float(ft.get_height())
			_sprite("fungalfrond%d.png" % fi,
					Vector2(x + _rng.randf_range(-want_h * 0.9, want_h * 0.9),
					base - fh * 0.5 + fh * 0.10), fsc, z, tint.lerp(FRINGE_NEAR, 0.45),
					_rng.randf() < 0.5)
		# and every third mound keeps a stone group, so the masses are not all
		# the same material
		if _rng.randf() < 0.34:
			var si: int = 1 + _rng.randi() % 20
			var st: Texture2D = load(BASE + "fungalstone%d.png" % si)
			var ssc: float = (_rng.randf_range(26.0, 58.0) * GROWTH_SCALE) 					/ float(st.get_height())
			_sprite("fungalstone%d.png" % si,
					Vector2(x + _rng.randf_range(-260.0, 260.0),
					FLOOR_Y + 26.0 - st.get_height() * ssc * 0.3), ssc, z,
					tint.lerp(Color(0.42, 0.46, 0.45), 0.5), _rng.randf() < 0.5)
		x += _rng.randf_range(340.0, 700.0)

	# THE FRONT PASS IS GONE. Near-black mounds at her own height put a solid
	# black hole in the middle of the picture with her legs inside it — Advika
	# circled it. Anything in front of her from now on is SMALL and readable:
	# tufts, not masses (this is how Realm 2 does it too).


## `_walk_fringe()` USED TO LIVE HERE AND WAS NEVER CALLED.
##
## It was the builder whose whole job was to draw growth across her shins, it
## carried three paragraphs of notes about getting exactly that right — and
## `_ready()` did not invoke it. That is why Advika kept seeing her stand ON the
## moss no matter what was tuned: the code that would have fixed it had been
## orphaned at some point and nobody noticed, because dead code that reads as
## live is invisible. Its job now belongs to `_build_foreground`'s front row,
## which IS called, and the R3_FRINGE knob with it.
## THE BOTTOM OF THE FRAME IS GROWTH, NOT A HOLE.
##
## Advika, 2026-08-07: "the character needs to walk THROUGH the moss, not ON
## the moss, throughout the level." Same sentence, two problems, and they turn
## out to be one problem seen from two sides.
##
## The floor line is at y 420 and the camera's bottom edge is at 770, so there
## were three hundred and fifty pixels of screen under her feet with nothing in
## them but flat soil — a black rectangle across the bottom third of every
## single frame. Realm 2 never has that: its carpet keeps going and is CUT BY
## THE FRAME, so the picture is full corner to corner and the hero is standing
## inside a mass rather than on top of a line.
##
## And that is also why she read as standing ON the growth. Nothing in front of
## her reached higher than a tuft, so the meadow's top edge was always visibly
## below her boots. The fix is not to raise a band — that was tried twice and
## it buried her to the chin (see `_walk_fringe`'s history). The fix is that
## the growth in front of her is a BANK with real depth: its top edge rides
## across her shins and knees, jittered so it never draws a line, and its body
## runs down past the bottom of the screen.
##
## Three rows, near to far, each darker than the last, all of it this realm's
## own fungal pack (Advika: only the R3 pack — the floor is the one exception
## and that is Realm 2's moss).
## IT IS A FIELD, NOT ROWS (Advika, circling three of them at once: *"why on
## earth is there so many just lines of moss and a fucking gap"*).
##
## The bank was four ROWS, each with its own base and its own top range. That
## is a banding machine and it was always going to end here: every clump in a
## row tops out inside the same 45px window, so the row reads as a ruled
## horizontal stripe — four of them, stacked — and wherever one row's bodies
## ended above the next row's tops began, there was a horizontal band with
## nothing drawn in it at all. That is the gap. Neither is a tuning problem;
## you cannot space four stripes so that they stop being stripes.
##
## This is the same correction the meadow itself needed back in July, and the
## note is still in `_floor_mat`: ONE GRADIENT FIELD, NOT STACKED FLAT LAYERS.
## Every clump now draws its own depth `t` from a continuous range, and its top,
## its base, its z and its value all slide with that one number. No two
## neighbours agree on anything, so there is no line to see — and because each
## clump's body extends 150-330px BELOW its own top, the spans overlap
## everywhere and there is no height at which nothing is drawn.
##
## `t` is nearness: 0 is the growth she wades through, 1 is the frame edge.
## MEASURED, NOT GUESSED. `R3_DECOR=1` reported `fungalhill` at 97% mean
## overlap with its own neighbour across 2,340 sprites — that is the blob. The
## carpet underneath (Realm 2's moss strips) is what guarantees the ground is
## covered; these clumps are ACCENTS ON it, and accents at 97% overlap are not
## accents, they are a hedge. Two passes, and the step below spaces them.
const FIELD_PASSES := 2
## where the tops land at t=0 and t=1. The near end is measured against her:
## her feet are on 420, her knee is near 372, her hood near 277.
const FIELD_TOP_NEAR := 338.0
const FIELD_TOP_FAR := 900.0
## how far each clump's body runs below its own top — this is what closes the
## gaps, so it is generous on purpose
const FIELD_BODY_MIN := 150.0
const FIELD_BODY_MAX := 520.0


func _build_foreground() -> void:
	if OS.get_environment("R3_FRINGE") != "":
		_fringe_growth = float(OS.get_environment("R3_FRINGE"))
	for p in FIELD_PASSES:
		# each pass sweeps x on its own offset and picks its own depths, so the
		# passes never line up with each other either
		var x: float = WORLD_L - 600.0 + _rng.randf_range(0.0, 420.0)
		var i := 0
		while x < WORLD_R + 600.0:
			# UNIFORM AGAIN, and the near end is somebody else's job now.
			#
			# This was biased hard toward the near end so that something always
			# covered her legs — and that starved the far end, which is why bald
			# patches kept reappearing along the bottom of the frame no matter
			# what I did to the soil under them. There simply were not many
			# clumps down there. Her legs are guaranteed by the wade band in
			# `_understory` instead, which is the right place for a guarantee,
			# and the field is free to spread evenly again.
			var t: float = _rng.randf()
			# the nearest clumps are the ones measured against her legs, and
			# they are the only ones R3_FRINGE moves
			var top: float = lerpf(FIELD_TOP_NEAR, FIELD_TOP_FAR, t)
			if t < 0.22:
				top = FLOOR_Y - (FLOOR_Y - top) * _fringe_growth
			top += _rng.randf_range(-20.0, 20.0)
			var body: float = lerpf(FIELD_BODY_MIN, FIELD_BODY_MAX, t) 					* _rng.randf_range(0.85, 1.25)
			# fungalhill 2 and 5 are the radial bursts and 1/3/4 the wide
			# mounds — mixing them is what stops the field being a hedge
			var hid: int = [1, 2, 3, 4, 5, 1, 3, 2][(i + p) % 8]
			var tex: Texture2D = load(BASE + "fungalhill%d.png" % hid)
			var sc: float = body / float(tex.get_height())
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.scale = Vector2(sc, sc)
			sp.flip_h = _rng.randf() < 0.5
			sp.rotation_degrees = _rng.randf_range(-4.0, 4.0)
			sp.position = Vector2(x, top + body * 0.5)
			# value and draw order both ride the same depth, so a clump can
			# never be lighter than something in front of it
			sp.modulate = _depth(lerpf(0.60, 0.97, t) + _rng.randf_range(-0.04, 0.04))
			sp.z_index = FRONT_Z + int(t * 3.99)
			sp.set_meta("air", true)   # it hangs below the floor on purpose
			sp.material = _growth_sway()
			add_child(sp)
			_front_growth.append(sp)
			# fronds bursting out of the mass — a mound alone is a lump, the
			# spikes breaking its silhouette are what make it read as growth
			if _rng.randf() < 0.34:
				var fi: int = FRINGE_TEX[_rng.randi() % FRINGE_TEX.size()]
				var ft: Texture2D = load(BASE + "fungalfrond%d.png" % fi)
				var fh: float = body * _rng.randf_range(0.40, 0.80)
				var f := Sprite2D.new()
				f.texture = ft
				f.scale = Vector2(fh / float(ft.get_height()),
						fh / float(ft.get_height()))
				f.flip_h = _rng.randf() < 0.5
				f.rotation_degrees = _rng.randf_range(-12.0, 12.0)
				f.position = Vector2(x + _rng.randf_range(-body * 0.4, body * 0.4),
						top + fh * 0.5 + _rng.randf_range(-16.0, 26.0))
				f.modulate = _depth(lerpf(0.56, 0.92, t))
				f.z_index = sp.z_index
				f.set_meta("air", true)
				f.material = _growth_sway()
				add_child(f)
				_front_growth.append(f)
			# the step rides depth too: near clumps are big and sparse, far
			# ones small and tight, which is one more thing that cannot band
			# ~20% overlap at most (the spec's number), instead of 70%
			x += tex.get_width() * sc * _rng.randf_range(0.82, 1.18)
			i += 1

	_understory()

## THE UNDERSTORY — GAPLESS BY CONSTRUCTION.
##
## Advika kept circling flat dark patches in the lower half, and each time I
## closed the one she found by adding another sweep somewhere. That is the wrong
## shape of fix, because the cause is structural: a SCATTER cannot guarantee
## coverage of a 2D region. However many clumps you throw at it, the
## distribution will leave some rectangle empty somewhere down a 27,000px level,
## and what shows through is the bare soil polygon — perfectly smooth, perfectly
## flat, and instantly readable as a hole.
##
## So the region below the walk line is no longer scattered. It is a stack of
## sweeps, each CONTINUOUS in x, whose top ranges deliberately OVERLAP their
## neighbours. Coverage is guaranteed in both axes by construction: in x by the
## tight step, in y because every sweep's tops begin inside the sweep above it.
## No hole can open.
##
## And it does not stripe — the trap the earlier four-row version fell into —
## because a stripe needs its tops to share a narrow band. These ranges are
## 120-170px tall AND overlap each other, so at any height you are looking at
## clumps from two different sweeps at two different depths.
##
## [top_lo, top_hi, body_lo, body_hi, z, depth, step_lo, step_hi]
## Advika, on the six-sweep version: *"i dont want u to just put like a whole
## strip of moss to cover patches, thats just incorrect and wrong."* She is
## right, and it is worth writing down why, because I did it three times.
##
## The patches were the bare SOIL POLYGON showing between clumps. Every fix I
## reached for added more growth on top of it — a sweep here, a deeper sweep
## there — which is treating the symptom, costs thousands of sprites, and puts
## the level right back into the banded look it just escaped. The actual defect
## was one object: a flat, uniform, untextured `Polygon2D` under everything. In
## a painterly game ANY flat fill reads as a hole the moment it is visible, and
## it was always going to be visible somewhere down 27,000px.
##
## So the soil is textured now (see `_earth_material`) and it is allowed to
## show. What is left here is ONE band, and it is not a patch: it is the growth
## she wades through, which is a readability requirement she has raised four
## times and cannot be left to a random distribution.
##
## [top_lo, top_hi, body_lo, body_hi, z, depth, step_lo, step_hi]
const UNDERSTORY: Array = [
	[328.0, 400.0, 150.0, 250.0, FRONT_Z, 0.60, 0.78, 1.06],
]


## THE GROUND MASS — why the patches kept coming back.
##
## Advika, after circling the fourth one: *"i dont wanna hand point these
## patches to u, u should know and remove all of them at once."* Fair, and the
## reason I could not was that I kept treating it as a density problem. It is
## not. Scattered sprites CANNOT tile a 2D region — whatever the count, some
## rectangle is always empty, and any flat thing behind it reads as bald.
##
## Realm 2 never has this because its floor is not scattered at all: it is a
## painted MASS with an organic top edge, and its clumps only break that edge.
## This is the same construction, built rather than painted — one continuous
## body per span whose top is an undulating line (three sines on incommensurate
## periods, so it never repeats), textured by the same grain the soil uses, and
## everything else in the understory sits on top of it and roughens it.
##
## Below that line there is no hole to find, because there are no seams down
## there to begin with.
const MASS_TOP := 545.0        # mean height of the ground mass's edge
const MASS_WAVE := 78.0        # how far that edge wanders
const MASS_STEP := 52.0        # x resolution of the edge


func _understory_mass() -> void:
	# Advika: *"please do not cover patches with bloody rocks — u should use the
	# moss from lvl2 and 3 combined, or some mushrooms with moss and vines, make
	# it BLEND IN with the rest of the floor."*
	#
	# That is the answer, and it also explains why the shaded polygon failed. A
	# code-drawn noise field is not the floor; it is a different material sitting
	# where the floor should be, and even with real grain it read as a hole
	# because it did not match anything around it. `moss_mat.png` IS the floor —
	# `_moss_body` lays the very same strip at the walk line — so repeating it
	# lower down cannot fail to blend: it is the same paint.
	#
	# And it cannot gap. The strip is 3840px and wrap-seamless, so laying it end
	# to end is continuous BY CONSTRUCTION, which is the guarantee no scatter
	# could ever give. Three courses, each lower and darker, the R3 clumps and
	# the fungal field breaking their edges on top.
	var mat: Texture2D = load(R2 + "moss_mat.png")
	var front: Texture2D = load(R2 + "moss_front.png")
	var span: float = 3840.0 * R2_SCALE
	var n: int = int((WORLD_R - WORLD_L + 4000.0) / span) + 2
	# [texture, y, z, tint multiplier, x offset]
	var courses: Array = [
		[front, 470.0, FORE_Z, 0.46, span * 0.31],
		[mat, 555.0, FORE_Z, 0.40, 0.0],
		[mat, 760.0, FORE_Z + 1, 0.30, span * 0.17],
		# the scan's leftovers sat in a band at world y ~880-1020, so these are
		# placed FROM the measurement rather than by eye
		[mat, 990.0, FORE_Z + 2, 0.22, span * 0.48],
	]
	# EVERY COURSE IS LAID CROOKED, ON PURPOSE.
	#
	# Laid flat they band — Advika circled a long dark trough running the width
	# of the screen. Two causes, both structural: each course sat at a CONSTANT
	# y, so its top edge was a ruled line across 27,000px; and each carried ONE
	# flat tint, so the steps between courses were visible as horizontal value
	# jumps. Together they read as a ditch cut through the floor.
	#
	# So each tile takes its own height off a long wave (period ~2.6 tiles, so
	# it never lines up with the tiling) plus jitter, and its own tint from a
	# range that OVERLAPS its neighbours' — a course can be darker than the one
	# below it in places, which is what kills the step.
	for ci in courses.size():
		var c: Array = courses[ci]
		var tex: Texture2D = c[0]
		for i in n:
			var m := Sprite2D.new()
			m.texture = tex
			m.centered = false
			m.scale = Vector2(R2_SCALE, R2_SCALE)
			var wob: float = sin(float(i) * 2.37 + float(ci) * 1.9) * 26.0 					+ sin(float(i) * 0.71 + float(ci) * 4.1) * 17.0 					+ _rng.randf_range(-11.0, 11.0)
			m.position = Vector2(WORLD_L - 2000.0 - float(c[4]) + i * span,
					float(c[1]) + wob)
			m.modulate = _dim(R2_TEAL, float(c[3]) * _rng.randf_range(0.82, 1.24))
			m.z_index = int(c[2])
			add_child(m)
			_front_growth.append(m)


func _understory() -> void:
	_understory_mass()
	for si in UNDERSTORY.size():
		var row: Array = UNDERSTORY[si]
		var x: float = WORLD_L - 500.0 + _rng.randf_range(0.0, 260.0)
		var i := 0
		while x < WORLD_R + 500.0:
			var hid: int = [2, 5, 1, 3, 4, 2, 3][(i + si) % 7]
			var tex: Texture2D = load(BASE + "fungalhill%d.png" % hid)
			var top: float = _rng.randf_range(float(row[0]), float(row[1]))
			if si == 0:
				top = FLOOR_Y - (FLOOR_Y - top) * _fringe_growth
			var body: float = _rng.randf_range(float(row[2]), float(row[3]))
			var sc: float = body / float(tex.get_height())
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.scale = Vector2(sc, sc)
			sp.flip_h = _rng.randf() < 0.5
			sp.rotation_degrees = _rng.randf_range(-5.0, 5.0)
			sp.position = Vector2(x, top + body * 0.5)
			sp.modulate = _depth(float(row[5]) + _rng.randf_range(-0.05, 0.04))
			sp.z_index = int(row[4])
			sp.set_meta("air", true)
			add_child(sp)
			_front_growth.append(sp)
			x += tex.get_width() * sc * _rng.randf_range(float(row[6]), float(row[7]))
			i += 1


	# THE NEAREST THING IN THE LEVEL — a handful of near-black masses the
	# camera passes, bases well below the frame, so occasionally the whole
	# bottom corner of the screen is solid and she walks out from behind it.
	# Sparse on purpose (one every ~1600px): this is punctuation, not a wall,
	# and a continuous row here is the "blade wall" that was cut before.
	var bx := WORLD_L + 400.0
	var bi := 0
	while bx < WORLD_R:
		var bt: Texture2D = load(BASE + "fungalhill%d.png" % [2, 5][bi % 2])
		var bh: float = _rng.randf_range(250.0, 370.0) * GROWTH_SCALE
		var bs: float = bh / float(bt.get_height())
		var b := Sprite2D.new()
		b.texture = bt
		b.scale = Vector2(bs, bs)
		b.flip_h = _rng.randf() < 0.5
		b.position = Vector2(bx, FLOOR_Y + 440.0 - bh * 0.5)
		b.modulate = _depth(1.0)
		b.z_index = FORE_Z + 2
		b.set_meta("air", true)
		add_child(b)
		_front_growth.append(b)
		# a stone shoulder against it, so the near frame is not all one
		# material either
		if bi % 2 == 0:
			var st: Texture2D = load(BASE + "fungalstoneb%d.png" % (1 + _rng.randi() % 11))
			var sh: float = _rng.randf_range(180.0, 280.0) * GROWTH_SCALE
			var ss: float = sh / float(st.get_height())
			var so := Sprite2D.new()
			so.texture = st
			so.scale = Vector2(ss, ss)
			so.flip_h = _rng.randf() < 0.5
			so.position = Vector2(bx + _rng.randf_range(-380.0, 380.0),
					FLOOR_Y + 470.0 - sh * 0.5)
			so.modulate = _depth(1.0)
			so.z_index = FORE_Z + 2
			so.set_meta("air", true)
			add_child(so)
			_front_growth.append(so)
		bx += _rng.randf_range(1300.0, 2100.0)


# ---------- atmosphere ----------

## three wide haze bands at different depths, drifting slowly and wrapping.
## Each layer = evenly spaced soft radial sprites; the layer node slides and
## wraps within one spacing, so coverage never gaps. [node, speed_px_s, spacing]
var _fog_bands: Array = []
func _build_fog_layers() -> void:
	# alphas <=0.04, deep teal tint — haze structure kept, brightness killed
	for cfg in [[-7, 0.04, 1.4, 5.0], [-3, 0.035, 1.0, 7.5], [7, 0.03, 1.7, 4.0]]:
		var band := Node2D.new()
		band.z_index = int(cfg[0])
		add_child(band)
		var spacing := 900.0 * (cfg[2] as float)
		var x := WORLD_L - 1400.0
		while x < WORLD_R + 1400.0:
			var f := Sprite2D.new()
			f.texture = _soft_glow_texture()
			f.position = Vector2(x, FLOOR_Y - _rng.randf_range(120.0, 320.0))
			f.scale = Vector2(7.0, 2.6) * (cfg[2] as float)
			f.modulate = Color(FOG_TINT.r, FOG_TINT.g, FOG_TINT.b, cfg[1] as float)
			band.add_child(f)
			x += spacing
		_fog_bands.append([band, cfg[3] as float, spacing])


var _fogs: Array[Sprite2D] = []
## THE DUST IN THE AIR (Advika: "add those tiny tiny atmospherical dots things
## for the vibes as well into the r3 map").
##
## There was already one mote layer — amber, sparse, all at one depth, one size,
## one speed. One layer of anything reads as an effect playing over a picture.
## Four layers at four depths read as AIR, because the eye gets parallax out of
## them: the far dots barely move and are almost invisible, the near ones cross
## the screen and are big enough to catch. That difference is the whole trick.
##
## They are deliberately TINY. The realm already has big glowing things in it —
## the caps, the lantern, the embers — and dots that compete with those become
## snow. These sit at the threshold of being noticed, which is where atmosphere
## lives.
##
## Two hues only, both already in the realm: the amber the glowers carry, and
## the teal everything else is made of. No third colour.
const MOTE_LAYERS: Array = [
	# [z, count_div, size_min, size_max, alpha, speed_min, speed_max, warm]
	[-7, 190.0, 0.16, 0.30, 0.34, 3.0, 9.0, false],   # far haze grit
	[-3, 240.0, 0.24, 0.42, 0.42, 6.0, 15.0, true],   # between the bands
	[4, 300.0, 0.34, 0.60, 0.46, 10.0, 24.0, false],  # the play space
	[9, 520.0, 0.50, 0.92, 0.30, 18.0, 40.0, true],   # right in front of her
]


func _build_motes() -> void:
	var span: float = WORLD_R - WORLD_L
	for cfg in MOTE_LAYERS:
		var p := CPUParticles2D.new()
		p.texture = load(MOSS_SPORE)
		p.amount = maxi(24, int(span / float(cfg[1])))
		p.lifetime = 26.0
		p.preprocess = 26.0        # the air is already full when she walks in
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(span * 0.5 + 400.0, 560.0)
		# they DRIFT and they RISE a little — dust that only ever falls reads as
		# weather, and this cavern has no weather
		p.direction = Vector2(1.0, -0.18)
		p.spread = 26.0
		p.gravity = Vector2(0.0, -3.0)
		p.initial_velocity_min = float(cfg[5])
		p.initial_velocity_max = float(cfg[6])
		p.scale_amount_min = float(cfg[2])
		p.scale_amount_max = float(cfg[3])
		# each one fades in and out over its own life, so nothing ever pops
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.22, 0.78, 1.0])
		var hue: Color = EMBER if bool(cfg[7]) else Color(0.62, 1.0, 0.94)
		var a: float = float(cfg[4])
		ramp.colors = PackedColorArray([
			Color(hue.r, hue.g, hue.b, 0.0), Color(hue.r, hue.g, hue.b, a),
			Color(hue.r, hue.g, hue.b, a), Color(hue.r, hue.g, hue.b, 0.0)])
		# NOTE `CPUParticles2D.color_ramp` takes a Gradient directly — it is
		# `GPUParticles2D` whose material wants a GradientTexture1D.
		p.color_ramp = ramp
		p.position = Vector2((WORLD_L + WORLD_R) * 0.5, FLOOR_Y - 300.0)
		p.z_index = int(cfg[0])
		add_child(p)


## THE GROWTH BREATHES, and it has to be done on the GPU.
##
## Advika asked whether the R3 pack has animation frames to bring the level to
## life. It does not — checked file by file: every asset in it is a single still
## PNG, no subfolders, no sequences. (Realm 2's pack has three 30-frame plants;
## this one has none.) So the life has to come from somewhere else.
##
## This is one ShaderMaterial SHARED by every piece of growth in the level. It
## displaces vertices only — it never writes COLOR — which matters twice over:
## a canvas shader that writes COLOR discards the node's modulate, and the drain
## tweens exactly that modulate on every one of these sprites when the forest
## dies. Phase comes from each sprite's own world position, so thousands of
## sprites on one material still move independently, at zero CPU cost.
const SWAY_SHADER := "shader_type canvas_item;
uniform float amp = 3.2;
uniform float speed = 0.55;
void vertex() {
	// world position of this sprite drives its phase, so neighbours differ
	float ph = MODEL_MATRIX[3][0] * 0.013 + MODEL_MATRIX[3][1] * 0.021;
	// only the TOP of a clump moves; its feet are in the ground
	float w = 1.0 - UV.y;
	VERTEX.x += sin(TIME * speed + ph) * amp * w * w;
}"

var _sway_mat: ShaderMaterial


func _growth_sway() -> ShaderMaterial:
	if _sway_mat == null:
		var sh := Shader.new()
		sh.code = SWAY_SHADER
		_sway_mat = ShaderMaterial.new()
		_sway_mat.shader = sh
	return _sway_mat


func _build_atmosphere() -> void:
	# local fog banks: deep teal, faint — no bright haze anywhere
	var nfog := int((WORLD_R - WORLD_L + 1800.0) / 950.0) + 1
	for i in nfog:
		var f := Sprite2D.new()
		f.texture = load(MOSS_FOG)
		f.position = Vector2(WORLD_L - 900.0 + i * 950.0, FLOOR_Y - _rng.randf_range(60.0, 280.0))
		f.scale = Vector2(_rng.randf_range(2.8, 4.2), _rng.randf_range(2.0, 2.9))
		f.modulate = Color(0.25, 0.42, 0.38, _rng.randf_range(0.10, 0.15))
		f.z_index = -4 if i % 2 == 0 else 6
		add_child(f)
		_fogs.append(f)
	# drifting spores — Realm 2's spore config (same motion feel), warm
	# amber and sparse
	var motes := CPUParticles2D.new()
	motes.texture = load(MOSS_SPORE)
	motes.amount = int((WORLD_R - WORLD_L) / 320.0)
	motes.lifetime = 16.0
	motes.preprocess = 16.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2((WORLD_R - WORLD_L) * 0.5 + 300.0, 520.0)
	motes.direction = Vector2(1, 0.22)
	motes.spread = 12.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 14.0
	motes.initial_velocity_max = 34.0
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.2
	motes.color = Color(1.0, 0.85, 0.6, 0.55)
	motes.position = Vector2((WORLD_L + WORLD_R) * 0.5, FLOOR_Y - 260.0)
	motes.z_index = 6
	add_child(motes)
	# (fireflies removed — Advika 2026-07-15: not in this level. The spore
	# motes + mushroom glows carry the living-air feel here.)
	_build_motes()
	# corner vignette — dark teal-black (purple is Curiosity's, not the cave's)
	var cl := CanvasLayer.new()
	cl.layer = 15
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0),
			Color(0.01, 0.04, 0.035, 0.30)])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 512
	gt.height = 512
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)


var _glow_tex: GradientTexture2D = null
func _soft_glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
		_glow_tex.width = 256
		_glow_tex.height = 256
	return _glow_tex


# ---------- player / camera / ui ----------

func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = SPAWN
	# R3_START_X drops her straight at whatever is being tested — the gate is
	# 6km down the walk and nobody should have to stroll there to see it
	if OS.get_environment("R3_START_X") != "":
		_curi.position.x = float(OS.get_environment("R3_START_X"))
		_spawn = _curi.position
	_curi.scale = Vector2(HERO_SCALE, HERO_SCALE)
	# she walks IN FRONT of props + fringe (<=4), behind fore silhouettes (8)
	_curi.z_index = 5
	add_child(_curi)
	_lives = LIVES_HUD.instantiate() as LivesHUD
	_lives.eye_scale = 0.22
	_lives.eye_spacing = 112.0
	# realm-tinted eyes: crush red, feed green — the violet art reads as
	# luminous teal, this cavern's own color (set before add_child/_ready)
	_lives.eye_tint = Color(0.42, 1.8, 0.6)
	add_child(_lives)
	_lives.reset(STARTING_LIVES)
	# HER HEALTH IS HER LANTERN, HERE TOO (Advika). Realm 2 has carried this
	# since the red strip was cut; Realm 3 was still running with the lifeline
	# eyes alone and no read on the health inside a life, which matters far more
	# here — the mirror takes 22 a blow and the fight is the whole last act.
	# Same object, same wiring, tinted to this cavern rather than re-authored.
	_lantern = LanternHUD.new()
	_lantern.hud_position = Vector2(40, 104)
	_lantern.hue = Color(1.0, 0.78, 0.42)
	# lit from the first step: unlike Realm 2's trial there is no "before the
	# fight" here — the clock is running and the forest is already dangerous
	_lantern.start_hidden = false
	_ui_layer_for_lantern().add_child(_lantern)
	if _curi.has_signal("health_changed"):
		_curi.health_changed.connect(func(h: int, m: int) -> void:
			if _lantern != null and is_instance_valid(_lantern):
				_lantern.set_health(h, m))
	# AND PUSH THE CURRENT VALUE IN. Curiosity emits `health_changed` from her
	# own `_ready`, and `add_child(_curi)` runs that immediately — before this
	# connection exists. So the one emit that says "full" was always missed and
	# the lantern sat at its default fill for the whole level (Advika: it needs
	# to be fully full, not 75%, at the start).
	if "health" in _curi and "max_health" in _curi:
		_lantern.set_health(_curi.health, _curi.max_health)
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


## the lantern draws on a CanvasLayer so it never rides the camera. `_ui_layer`
## is built later than `_build_player`, so this makes one on demand rather than
## reordering the build (which is how the drain's z-order got broken once).
func _ui_layer_for_lantern() -> CanvasLayer:
	if _ui_layer == null:
		_ui_layer = CanvasLayer.new()
		_ui_layer.layer = 20
		add_child(_ui_layer)
	return _ui_layer


## the way home: the standard arch door (Realm 1's exact recipe — Visual
## with sprite + warm glow, Door.gd Area2D that trigger() sends to the Hub)
## standing at the end of the long walk
func _build_exit_door() -> void:
	var arch: Texture2D = load("res://assets/scenes/hub/door_arch.png")
	var root := Node2D.new()
	root.name = "ExitDoor"
	root.position = Vector2(WORLD_R - 420.0,
			FLOOR_Y + 8.0 - arch.get_height() * 0.5)
	root.z_index = 3
	add_child(root)
	_exit_root = root
	# how far the arch's own base sits under its origin, so the ending can put
	# this thing down on the meadow somewhere else without it hovering
	_exit_lift = arch.get_height() * 0.5 - 8.0
	var vis := Node2D.new()
	vis.name = "Visual"
	root.add_child(vis)
	var spr := Sprite2D.new()
	spr.texture = arch
	vis.add_child(spr)
	var glow := PointLight2D.new()
	glow.name = "Glow"
	glow.color = Color(0.95, 0.78, 0.45)
	glow.energy = 1.1
	glow.texture = load("res://assets/effects/lantern_halo.png")
	glow.texture_scale = 1.6
	vis.add_child(glow)
	var area := Area2D.new()
	area.name = "DoorArea"
	area.set_script(load("res://scripts/Door.gd"))
	area.target_realm = "hub"
	area.door_id = "Realm3Exit"
	area.prompt_offset = Vector2(0, -110)
	area.prompt_text = "[Y] Return"
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200.0, 280.0)
	cs.shape = rect
	area.add_child(cs)
	root.add_child(area)
	area.near_door.connect(func(_d: Node) -> void: _at_exit = true)
	area.left_door.connect(func(_d: Node) -> void: _at_exit = false)
	_exit_door = area


func _build_camera() -> void:
	_cam = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := 1.0 * vp.y / 1080.0   # she's the subject, with room to breathe
	_cam.zoom = Vector2(z, z)
	_cam.position = _spawn + Vector2(0, -80)
	add_child(_cam)
	_cam.make_current()
	var hcam: Camera2D = _curi.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false


## the hopping species: one look, one rhythm, evenly spaced end to end
## SIX MUSHROOMS, and the level turns on the sixth.
##
## There were thirty-two of them every 760px, which made them weather. Six
## makes each one an EVENT — four lone encounters, then a pair at the end so
## the last fight is the hardest thing the forest has asked for. Spread across
## the whole walk so the count paces the level instead of front-loading it.
## Tightened (Advika: "wayyyy too apart"). They were ~4600px apart, which is
## roughly 23 seconds of walking between encounters — long enough that the
## level forgot it had enemies. ~2700px is about 13s: still room to breathe,
## but the forest stays dangerous. The last two stay a pair.
## The first one is set BACK from the rest of the run's spacing on purpose
## (Advika: *"curiosity spawns too close to the mushroom at the start — move it
## a lil later so it doesnt come charging through when the player walks into the
## realm"*). These break ground when she nears them, and moving SPAWN in to 385
## left the first barely a screen away: she arrived out of a quote card and was
## immediately being charged, before the opening card had even shown. 2400 puts
## it outside its own wake radius at spawn, so the realm gets its quiet beat.
const SPORE_XS: Array[float] = [2400.0, 4300.0, 7000.0, 9700.0,
		12300.0, 12900.0]
## how many must die before the forest gives up its colour
const MUSHROOMS_TO_KILL := 6

const SPORE_FIRST := 1250.0
const SPORE_SPACING := 760.0
## Advika circled these three on the contact sheet: glow17, glow23, glow24 —
## the fat round domes on stubby stems. Far better creatures than the first
## pick: one dome per body means one face, and the pale cap makes red eyes pop.
## Each entry is [texture, eye height up from the feet, eye spacing, x offset].
## The eyes sit BELOW the dome's centre — level with the middle of a face, not
## on top of a skull.
const SPORE_KINDS: Array = [
	["mushroomglow17.png", 0.60, 0.17, 0.0],
	["mushroomglow23.png", 0.63, 0.16, 0.0],
	["mushroomglow24.png", 0.63, 0.16, 0.0],
]
var _sporelings: Array[Sporeling] = []


## ONE species, one silhouette, one rhythm, one even spacing the whole way down
## (Advika: uniform and nice). Only the hop PHASE differs — evenly stepped, so
## a stretch of them ripples like a wave instead of pulsing in lockstep.
## They are underground until she nears them; then they break ground and come.
## R3_SPORE=0 turns them off.
func _build_sporelings() -> void:
	if OS.get_environment("R3_SPORE") == "0":
		return
	var trig: Array[Node2D] = []
	trig.append(_curi)
	var i := 0
	for sx in SPORE_XS:
		var kind: Array = SPORE_KINDS[i % SPORE_KINDS.size()]
		var s := Sporeling.new()
		s.tex_name = kind[0]
		s.eye_y_frac = kind[1]
		s.eye_dx_frac = kind[2]
		s.eye_x_off_frac = kind[3]
		s.base_dir = BASE
		# they grow with her. Her own law is that these come up to about
		# two-thirds of Curiosity; 86px was two-thirds of her at 0.24, so at
		# 0.33 it has to follow or the species quietly becomes ankle-high.
		s.target_height = 86.0 * (HERO_SCALE / 0.24)
		s.position = Vector2(sx, FLOOR_Y + 4.0)
		# the ripple: five evenly-stepped phases, then it wraps
		s.phase = float(i % 5) * (s.hop_period / 5.0)
		add_child(s)
		s.triggers = trig
		_sporelings.append(s)
		# every death counts toward the six that end the forest
		s.popped.connect(_on_mushroom_killed)
		i += 1


# ---------- THE FOREST JOINS THE FIGHT ----------
## Advika: *"to make the fight more interesting, mushrooms spawn upside down
## from the ceiling, fall to the ground and then attack Curiosity"* — during
## the boss fight.
##
## Why it works as a fight beat: the mirror is a duel, and a duel with nothing
## else in it becomes a spacing puzzle you solve once. These break that. They
## do not fight her — they arrive, and they make the ground she was using to
## keep her distance stop being hers. She cannot stand anywhere for long, which
## is exactly the pressure a boss that reads her standing habits should have.
##
## They are the SAME species she has been killing all level, arriving upside
## down instead of from underneath (`Sporeling.drop_from`). A brand-new creature
## in the last two minutes would read as a different game.
##
## THE DROP IS TELEGRAPHED. Each one grips the roof, fades in, shivers, and
## only then lets go — roughly a second of warning. A mushroom that simply
## appeared overhead and landed on her would be an unfair hit, and this fight
## is meant to be hard, not cheap.
##
## They do NOT count toward the six that ended the forest — that door is shut
## by the time they start.
## IT IS WAVES, NOT A TRICKLE (Advika: *"keep it to max 4 shrooms until they
## all die and we respawn more"*).
##
## A steady stream on a timer is unanswerable — kill one, another is already
## falling, and there is never a moment where clearing them accomplished
## something. A WAVE has a shape: four come down, she has a real choice about
## whether to fight the boss or the mushrooms, and clearing them BUYS her a
## clean stretch of duel. That stretch is the reward, and it is what makes the
## next wave land as a beat rather than as noise.
const DROP_FIRST := 5.0        # a beat of clean duel before the roof opens
## the pause between clearing a wave and the roof opening again
const DROP_GAP_MIN := 2.6
const DROP_GAP_MAX := 4.4
## HOW MANY COME DOWN, ROLLED FRESH EVERY WAVE (Advika: *"spawn 4 sometimes
## then maybe 3 one round or 4 again — you need to be random w it just like the
## void moth"*). A fixed four made the roof a metronome: after two waves she
## knew exactly how much work was coming and could pre-commit to fighting or
## running before any of them landed. Three or four takes that certainty away
## without ever changing what a wave IS.
const DROP_WAVE_MIN := 3
const DROP_WAVE_MAX := 4       # and never more than this on the floor at once
## never dead on top of her, never off screen — it has to be a place she can
## see it land and choose to leave
const DROP_NEAR_MIN := 190.0
const DROP_NEAR_MAX := 620.0
## how many are allowed to be alive at once. The boss is the fight; these are
## weather.
## past this from her, a dropper is not pressure any more — it is a leak, and
## a leak that never dies would hold the wave open forever
const DROP_CULL := 1750.0

var _drop_t := DROP_FIRST
var _droppers: Array[Sporeling] = []


func _tick_droppers(delta: float) -> void:
	if _mirror == null or not is_instance_valid(_mirror) or not _mirror.live:
		return
	if OS.get_environment("R3_DROP") == "0":
		return
	# CULL THE ONES SHE HAS LEFT BEHIND. Advika: they should only stop coming
	# once evil C is dead. They already did — except for one thing: a dropper
	# she walks away from instead of killing stays alive forever, and six of
	# those fill `DROP_MAX_ALIVE` and silently shut the stream off for the rest
	# of the fight. The cap has to mean "how many are ON HER", not "how many
	# exist", so anything left more than a screen and a half behind burrows away
	# and gives its slot back.
	# NOTE this rebuilds the list by hand rather than with `.filter()`, which
	# returns an untyped Array and cannot be assigned back to an
	# `Array[Sporeling]` — Godot throws on every single frame if you try.
	var here: float = _curi.global_position.x
	var alive: Array[Sporeling] = []
	for d in _droppers:
		if d == null or not is_instance_valid(d):
			continue
		if absf(d.global_position.x - here) > DROP_CULL:
			d.queue_free()
			continue
		alive.append(d)
	_droppers = alive
	# THE WAVE HOLDS THE DOOR. Nothing new comes down while any of the last lot
	# is still standing — clearing them is the thing that opens the roof again.
	if not _droppers.is_empty():
		return
	_drop_t -= delta
	if _drop_t > 0.0:
		return
	_drop_t = _rng.randf_range(DROP_GAP_MIN, DROP_GAP_MAX)
	for k in _rng.randi_range(DROP_WAVE_MIN, DROP_WAVE_MAX):
		# alternate sides so a wave always brackets her rather than piling up on
		# one flank, which she could simply walk away from
		_spawn_dropper(1.0 if k % 2 == 0 else -1.0)


func _spawn_dropper(side: float = 0.0) -> void:
	if side == 0.0:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
	var dx: float = side * _rng.randf_range(DROP_NEAR_MIN, DROP_NEAR_MAX)
	var x: float = clampf(_curi.global_position.x + dx,
			WORLD_L + 400.0, WORLD_R - 400.0)
	var kind: Array = SPORE_KINDS[_rng.randi() % SPORE_KINDS.size()]
	var d := Sporeling.new()
	d.tex_name = kind[0]
	d.eye_y_frac = kind[1]
	d.eye_dx_frac = kind[2]
	d.eye_x_off_frac = kind[3]
	d.base_dir = BASE
	d.target_height = 86.0 * (HERO_SCALE / 0.24)
	d.position = Vector2(x, FLOOR_Y + 4.0)
	d.phase = _rng.randf_range(0.0, d.hop_period)
	add_child(d)
	var trig: Array[Node2D] = []
	trig.append(_curi)
	d.triggers = trig
	_droppers.append(d)
	# it grips the roof line, hangs for a beat, then falls to the meadow
	d.drop_from(ROOF_Y + 120.0, FLOOR_Y + 4.0, _rng.randf_range(0.7, 1.6))


# ---------- the shift ----------
#
# THE FOREST GIVES UP ON THE SIXTH KILL.
#
# She spends the whole level saving this place from what is sprouting out of
# it, and the reward for finishing is that the colour goes out of the world.
# Then she meets herself in the grey. That irony is the level, so the drain is
# deliberately SLOW — four seconds, no flash, no sting: long enough that the
# player watches it happen to something they liked.
#
# It runs on the screen, under the HUD, so no texture is touched and the same
# material can later be run backwards over the boss's body as it dies.

var _kills := 0
var _drain: ColorRect
var _drain_mat: ShaderMaterial
var _shifted := false
## each fog bank's living alpha, kept so the boss's death can hand it back
var _fog_alpha: Array[float] = []
signal forest_drained


## What the death is allowed to touch.
##
## The drain lives IN THE WORLD, not on a CanvasLayer. Two things fall out of
## that for free: everything on a CanvasLayer — the lifeline eyes, the
## hourglass — draws above it and keeps its colour, and plain z_index decides
## who else survives. Curiosity is lifted above it when the front arrives, so
## she walks through the dead forest as the only living thing in it.
const DRAIN_Z := 90
const CURI_ALIVE_Z := 95
## What her lantern settles to once the forest is dead, as a fraction of its
## living brightness. 1.0 = untouched, which is Advika's call: the lantern
## keeps exactly the brightness it has always had, and the forest dying around
## it is what changes — not the flame. Lower this if it ever reads as blown
## out against the grey.
const LANTERN_DEAD_SCALE := 1.0
## the softer hue her lantern settles into once the forest is grey — a milky,
## desaturated warm rather than the living forest's hard gold. Easy on the eye
## against a world with no colour left to argue with it.
const LANTERN_DEAD_HUE := Color(1.0, 0.93, 0.82)


func _build_drain() -> void:
	_drain = ColorRect.new()
	_drain_mat = ShaderMaterial.new()
	_drain_mat.shader = load("res://shaders/realm_drain.gdshader")
	_drain_mat.set_shader_parameter("sweep", -1.0)
	_drain_mat.set_shader_parameter("amount", 1.0)
	_drain.material = _drain_mat
	_drain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drain.z_index = DRAIN_Z
	_drain.top_level = true      # world coords, not the level's transform
	# HIDDEN UNTIL THE FOREST ACTUALLY DIES. Even at zero effect this rect
	# re-copies the whole screen every frame, and that copy clamps the
	# additive auras and glow caps the forest's colour depends on — the
	# living forest came out visibly duller with it merely present.
	_drain.visible = false
	add_child(_drain)
	_fit_drain()


## it only ever covers what the camera can see, so it costs one screen of fill
func _fit_drain() -> void:
	if _drain == null or _cam == null:
		return
	var vs: Vector2 = get_viewport_rect().size / _cam.zoom
	_drain.size = vs
	_drain.global_position = _cam.global_position - vs * 0.5


func _on_mushroom_killed() -> void:
	_kills += 1
	if _kills >= MUSHROOMS_TO_KILL and not _shifted:
		_begin_shift()


func _begin_shift() -> void:
	_shifted = true
	# THE SAND KEEPS FALLING (Advika: "keep it running, i need the player to
	# feel the pressure"). This used to stop here, on the argument that a player
	# who spent ten honest minutes finding six mushrooms should not then be
	# killed by the timer during the fight they earned. Her call overrides it,
	# and it makes the whole level one decision instead of two: every second
	# spent exploring the forest is a second you will not have when it turns
	# around and fights you. Rushing the walk buys you a safer duel.
	_clock_stopped = false
	if _drain != null:
		_drain.visible = true
	# AND THE GROWTH GOES WITH HER. Lifting her over the drain used to lift her
	# out of the WORLD — the moss curtain and the walk fringe stayed at z7 and
	# she and the mirror fought the entire last act standing on top of the
	# meadow like two stickers (Advika: "curiosity and shii sit ONTOP of the
	# moss, we've been over this"). The front growth climbs with her.
	_drain_front_growth(true)
	# SHE STAYS LIT. Lifted above the drain the moment it starts, so the front
	# washes past her and she is the last coloured thing in the forest.
	if _curi != null:
		_curi.z_index = CURI_ALIVE_Z
		# ...but her LANTERN came up with her, and it is a child of hers, so
		# it kept every bit of its brightness while the forest lost half of
		# its own. Against a drained world an untouched 3.6-energy light
		# reads as blown out. It settles as the world dies — the flame is
		# still the only warm thing, it just stops shouting.
		var lamp: PointLight2D = _curi.get_node_or_null("Lantern")
		if lamp != null:
			lamp.create_tween().tween_property(lamp, "energy",
					lamp.energy * LANTERN_DEAD_SCALE, 3.4)
			# and it SOFTENS. Against a grey world her hard gold was the one
			# harsh thing left on screen; this walks it to a gentler, milkier
			# warm that carries the same light without the glare.
			lamp.create_tween().tween_property(lamp, "color",
					LANTERN_DEAD_HUE, 3.8)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var fl: Sprite2D = _curi.get_node_or_null("LanternFlame")
		if fl != null:
			fl.create_tween().tween_property(fl, "modulate:a",
					fl.modulate.a * LANTERN_DEAD_SCALE, 3.4)
	# the front crosses the screen left to right — it starts off-frame on the
	# left and finishes off-frame on the right, so no edge of it is ever seen
	# parked in view
	# SLOWER, and much softer at the front (Advika: it felt abrupt). The dying
	# band is now half a screen wide instead of a quarter, so there is no line
	# to see — the colour just stops being there — and it takes 9 seconds to
	# cross rather than 4. This is the level's biggest moment; it should not
	# be over before she has looked up.
	var e: float = 0.55
	_drain_mat.set_shader_parameter("edge", e)
	_drain_mat.set_shader_parameter("ambient", Vector3(AMBIENT.r, AMBIENT.g, AMBIENT.b))
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float) -> void:
			_drain_mat.set_shader_parameter("sweep", v), -e, 1.0 + e, 9.0)
	# the air stops living with it — the spores and glow motes let go. Each
	# bank's own alpha is remembered first: they are seeded random (0.10-0.15)
	# and killing the boss puts the air back, which it cannot do from zero.
	# THE TRACK TURNS WITH THE FOREST. Divine Echo has been looping since she
	# arrived; it leaves as the colour does, and Whispers Beyond is all the way
	# up before the thing in the mirror is standing there. The crossfade is
	# deliberately shorter than the 9s sweep — the new track has to be
	# ESTABLISHED when the boss spawns, not arriving with it.
	_play_track(WHISPERS_BEYOND, "realm3_whispers", 6.5)
	_fog_alpha.clear()
	for f in _fogs:
		_fog_alpha.append(f.modulate.a if is_instance_valid(f) else 0.0)
		if is_instance_valid(f):
			f.create_tween().tween_property(f, "modulate:a", 0.0, 3.2)
	tw.tween_callback(func() -> void:
		forest_drained.emit()
		# the colour finishes leaving, and it is standing there
		_spawn_mirror())


## THE MOSS FOLLOWS HER OVER THE DRAIN.
##
## The drain is a full-screen pass at z 90: everything under it is greyed,
## everything over it keeps its colour, and that is how Curiosity stays the
## last warm thing in a dead forest. But depth is one axis — lifting her also
## lifted her over the growth she is supposed to be standing IN, so the whole
## boss fight happened on top of the meadow.
##
## So the front growth is lifted too, and since it is now above the drain and
## can no longer be greyed BY it, it is greyed by hand: each sprite's own
## colour, flattened to its luminance and pushed cold, which is what the shader
## does to everything else. Handing it back at the end is just the inverse.
## Ambient by PATH, not `preload`. These two tracks are dropped into
## `assets/audio/` by hand, and a `preload` of a file that is not there yet is a
## PARSE error — it takes the whole realm down on a cold checkout and on CI. A
## quiet realm is a far smaller failure than one that will not boot.
func _play_track(path: String, track_name: String, fade: float) -> void:
	if not ResourceLoader.exists(path):
		push_warning("[R3] ambient track missing, running silent: %s" % path)
		return
	AudioManager.play_ambient(load(path), track_name, fade)


func _drain_front_growth(on: bool) -> void:
	if on and _front_base_tint.is_empty():
		for s in _front_growth:
			_front_base_tint.append(s.modulate)
	for i in _front_growth.size():
		var s: Sprite2D = _front_growth[i]
		if not is_instance_valid(s):
			continue
		var base: Color = _front_base_tint[i] if i < _front_base_tint.size() else s.modulate
		if on:
			s.z_index += DRAINED_LIFT
			var lum: float = base.r * 0.299 + base.g * 0.587 + base.b * 0.114
			s.create_tween().tween_property(s, "modulate",
					Color(lum * 0.50, lum * 0.57, lum * 0.62, base.a), 9.0) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			# colour only. The z climbs back DOWN in `_lower_front_growth`,
			# once the reverse sweep has actually finished — drop it early and
			# the growth spends seven seconds under a drain that is still on
			# screen, going grey again while everything around it comes back.
			s.create_tween().tween_property(s, "modulate", base, 7.0) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## the world settles back to its walking depths, after the colour has landed
func _lower_front_growth() -> void:
	for s in _front_growth:
		if is_instance_valid(s):
			s.z_index -= DRAINED_LIFT
	if _curi != null:
		_curi.z_index = 5


## how many are dead so far — the boss gate reads this
func kills() -> int:
	return _kills


# ---------- the mirror ----------
#
# IT IS HER. Same frames, same physics, same reach, drained to charcoal with
# red in the eyes — built by tools/make_evil_curiosity.py off her own sheets,
# so it cannot help but move like her. The fight itself lives in `Mirror.gd`;
# what belongs here is only the arrival and what its death does to the forest.
#
# It does not walk in. It is simply THERE when the colour finishes leaving,
# standing across from her, already looking at her.

## How far across from her it stands. Far enough that it reads as a figure at
## the other end of the clearing rather than something that walked up to her.
const MIRROR_GAP := 980.0
var _mirror: Mirror
## >0 while R3_BOSS is printing the fight's state once a second
var _boss_log := 0.0


func _spawn_mirror() -> void:
	if _mirror != null or _curi == null:
		return
	_mirror = Mirror.new()
	_mirror.name = "Mirror"
	add_child(_mirror)
	# SAME SIZE AS HER, exactly — and it takes her scale, her collider and her
	# movement constants off the live hero rather than repeating them here, so
	# retuning the hero retunes the boss and the two can never drift apart.
	_mirror.build_from(_curi)
	_mirror.z_index = CURI_ALIVE_Z - 1
	_mirror.global_position = _curi.global_position + Vector2(MIRROR_GAP, 0)
	_mirror.died.connect(_on_mirror_died)
	if OS.get_environment("R3_END") != "":
		_mirror.max_health = 80      # two of her swings, then the ending
		_mirror.health = 80
	# it arrives, is looked at, and only then is allowed to move
	_mirror.arrive(2.6)
	# THE MIRROR CARD, ONE SECOND AFTER IT STANDS UP (Advika). Deliberately not
	# on the drain and not on the kill: the level names what she is fighting only
	# once she has seen it, so the card confirms a thing she has already begun to
	# suspect rather than spoiling it.
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_inside_tree():
			add_child(Realm3Card.mirror()))
	# R3_END_AUTO=1 — nobody is holding the controller in a headless run, so
	# the fight has to end itself for the ending after it to be provable.
	if OS.get_environment("R3_END_AUTO") != "":
		await get_tree().create_timer(6.0).timeout
		if is_instance_valid(_mirror) and _mirror.live:
			_mirror.take_damage(99999, Vector2(-200.0, -140.0))
	if OS.get_environment("R3_BOSS") != "" or OS.get_environment("R3_END") != "":
		print("[R3] the mirror is standing at x %.0f (she is at %.0f)"
				% [_mirror.global_position.x, _curi.global_position.x])
		# unattended runs get a line of what it is doing every second. Driven
		# off _process rather than an await loop: a pending scene timer at
		# quit is what "ObjectDB instances leaked at exit" means, and a debug
		# harness should not be the thing that prints it.
		_boss_log = 1.0


# ---------- the ending ----------
#
# THE LAST FIVE MINUTES OF THE GAME, and it is built out of things the player
# has already been taught to read rather than out of anything new:
#
#   1  the eyes outlive the body and BLINK once before they go out (Mirror.gd)
#   2  the colour comes home — the drain shader run backwards over the corpse
#   3  her lantern stops being a survivor and goes back to burning like a lamp
#   4  the way out ARRIVES WHERE THE FIGHT WAS. The exit has stood at the far
#      end of the walk all level; nobody is being asked to hike thirteen
#      thousand pixels after that. The forest opens a door where she is.
#   5  one line, then black, then the menu.
#
# There is no confrontation scene and nothing is explained (Advika's ending
# rule, and the hard constraint that the player has not read the book — no
# vocabulary from it ever reaches the screen).

## how far past her the way out opens — far enough that she walks TO it, close
## enough that it is plainly for her
const ENDING_DOOR_GAP := 640.0

## THE LAST WORDS IN THE GAME — Advika's to write, this is a placeholder that
## obeys the rules: it is defiant, it explains nothing, and it pays off the one
## thing the player was actually told (the prologue: three doors, one at a
## time, each opens the next). No name from the book appears in it.
const CLOSING_LINE := "Three doors, they said."
const CLOSING_LINE_2 := "Nobody ever said what the third one opens."

var _ending := false
var _exit_root: Node2D
var _exit_lift := 0.0


## KILLING IT GIVES THE FOREST BACK. The drain is run BACKWARDS over its body —
## the same material, the same front, crossing the other way — so the grey it
## arrived with leaves with it. Nothing has to be said out loud: the player
## watches the colour come home.
func _on_mirror_died() -> void:
	_ending = true
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float) -> void:
			_drain_mat.set_shader_parameter("sweep", v), 1.55, -0.55, 7.0)
	for i in _fogs.size():
		if is_instance_valid(_fogs[i]) and i < _fog_alpha.size():
			_fogs[i].create_tween().tween_property(_fogs[i], "modulate:a",
					_fog_alpha[i], 5.0)
	# her lantern stops being the last light in a dead place and goes back to
	# being a lamp in a forest — the exact values `_begin_shift` walked it away
	# from, walked back over a longer, slower ramp
	if _curi != null:
		var lamp: PointLight2D = _curi.get_node_or_null("Lantern")
		if lamp != null:
			lamp.create_tween().tween_property(lamp, "color",
					Color(1.0, 0.851, 0.494), 6.0) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# THE CLOCK IS OVER. It froze when the forest died and it has been hanging
	# there ever since; now it goes, because there is no more time in this
	# level to be out of.
	if _glass != null:
		_glass.create_tween().tween_property(_glass, "modulate:a", 0.0, 3.5)
	# the world comes back down with the colour: she drops to her walking depth
	# and the growth drops with her, so the last walk to the door happens INSIDE
	# the meadow again rather than over it
	_drain_front_growth(false)
	tw.tween_callback(func() -> void:
		if _drain != null:
			_drain.visible = false
		_lower_front_growth())
	_open_the_way()


## THE WAY OUT ARRIVES. It is the same door that has stood at the end of the
## walk since this level was built — it is not a second one, it simply is not
## down there any more. It comes up out of nothing beside her as the colour
## crosses back, so the two events are one event: the forest lives, and the
## forest lets her go.
func _open_the_way() -> void:
	# EXCEPT IT DOES NOT ANY MORE (Advika: *"get rid of the purple door once we
	# kill the boss"*). It was built out of Realm 2's art — violet, in a realm
	# that has spent this whole fight being teal — and standing it up at the one
	# moment the colour comes home put the wrong palette in the last frame of
	# the realm. What replaces it is the black screen Advika is writing.
	#
	# It is FREED, not hidden: the walk's own copy is the same node, so leaving
	# it invisible-but-present would leave a door she can still walk into.
	if _exit_root != null and is_instance_valid(_exit_root):
		_exit_root.queue_free()
	_exit_root = null
	_exit_door = null
	_at_exit = false
	print("[R3] the boss is dead, the colour is home, and there is no door")
	# the headless run has no hands: it presses the last button itself, so the
	# closing card is proven to build rather than assumed to
	if OS.get_environment("R3_END_AUTO") != "":
		await get_tree().create_timer(12.0).timeout
		_finish_the_game()


## [Y] AT THE END OF EVERYTHING. Not `Door.trigger()` — that resolves a realm
## and walks her back to the hub, and there is no hub in the flow any more.
## The game's own handover object carries the last line instead, exactly as it
## carries Fear's line between Realms 1 and 2 and the prologue's card into
## Realm 1: black, the words, a held beat, and it waits for a key.
func _finish_the_game() -> void:
	_leaving = true
	var card := QuoteTransition.new()
	card.quote_lines = PackedStringArray([CLOSING_LINE, CLOSING_LINE_2])
	card.speaker = ""
	card.next_scene = "res://scenes/UI/MainMenu.tscn"
	card.next_track = null
	card.next_track_name = "menu"
	# it goes on the TREE ROOT, never on this level: changing scene frees the
	# running scene, and a card parented here dies mid-transition with the
	# black still up (the bug that ate an afternoon in Realm 1).
	get_tree().root.add_child(card)


# ---------- the echo ----------
#
# THE THING BEHIND HER IS HER. `Echo.gd` owns the ring buffer and the replay;
# all that belongs here is the wiring — it needs someone to record, the clock
# has to tell it how late to be, and being taken by it has to cost her an eye.
#
# It is built after the player on purpose, so it is holding a reference to a
# Curiosity that already exists.

var _echo: Echo = null


func _build_echo() -> void:
	# OFF (Advika). The thing walking behind her is gone from the walk — the
	# idea is not dead, it has been PROMOTED: the READ of how she plays is what
	# the mirror boss is built out of at the end of the level. Keeping something
	# wearing her shape stalking her through the forest as well would spend the
	# reveal early.
	# R3_ECHO=1 brings it back for comparison.
	if OS.get_environment("R3_ECHO") != "1":
		return
	_echo = Echo.new()
	_echo.name = "Echo"
	_echo.target = _curi
	_echo.haze = FOG_TINT
	if OS.get_environment("R3_DELAY") != "":
		_echo.delay_start = float(OS.get_environment("R3_DELAY"))
	# it comes out of the spot she came in at — before there is enough history
	# to replay it stands at the oldest thing she did, which is this
	_echo.position = _spawn
	add_child(_echo)
	_echo.caught.connect(_die)
	if OS.get_environment("R3_ECHO_PROBE") != "":
		_probe_left = float(OS.get_environment("R3_ECHO_PROBE"))


func _build_ui() -> void:
	# ONE ui layer. `_build_player` now needs one too (the lantern), and it runs
	# first — so this takes whatever is already there instead of replacing it
	# and orphaning what was on it.
	_ui_layer_for_lantern()
	_build_clock()
	# no instruction text over the eyes (Advika) — the realm says nothing.
	# The debug keys still exist, they are just not advertised on screen.

	# THE READ IS ALREADY RUNNING. It has been reading them since the cave
	# (Advika: it happens throughout the game, not only this level) — the
	# profile attaches itself to whatever is in the "player" group, and only a
	# new game wipes it. This just hands it today's body a frame early; the
	# reset that used to live here threw away two realms of evidence and made
	# the boss a study of the last ten minutes.
	PlayerProfile.begin(_curi)

	# the overlay that proves it is actually reading them. TAB toggles.
	_profile_lbl = Label.new()
	_profile_lbl.position = Vector2(18, 150)
	_profile_lbl.add_theme_font_size_override("font_size", 15)
	_profile_lbl.add_theme_color_override("font_color", Color(0.66, 0.95, 0.88, 0.82))
	_profile_lbl.visible = false
	_ui_layer.add_child(_profile_lbl)


# ---------- running ----------

var _t := 0.0
func _process(delta: float) -> void:
	# The level node alone keeps running while paused, ONLY so the debug pause
	# key can be un-pressed. Everything it drives — including the clock that
	# feeds the hourglass — stops here, so the sand freezes with the world.
	if get_tree().paused:
		return
	_t += delta
	for i in _fogs.size():
		_fogs[i].position.x += sin(_t * 0.11 + i * 1.7) * 0.35
	# the haze bands drift and wrap within one sprite spacing — endless
	for i in _fog_bands.size():
		var band: Node2D = _fog_bands[i][0]
		var speed: float = _fog_bands[i][1]
		var spacing: float = _fog_bands[i][2]
		band.position.x = fmod(_t * speed, spacing)
	# the backdrop breathes: each sheet slides at its own pace and wraps inside
	# its own width, and the alpha swells very slowly so the air is never flat
	for m in _bg_mist:
		var s: Sprite2D = m[0]
		var span: float = m[2]
		s.position.x = fmod(-_t * float(m[1]), span)
		if s.position.x > 0.0:
			s.position.x -= span
		s.position.x += span if int(m[4]) % 2 == 1 else 0.0
		s.modulate.a = float(m[3]) * (0.78 + sin(_t * 0.14 + float(m[4])) * 0.22)
	_fit_drain()
	if _profile_lbl != null and _profile_lbl.visible:
		_profile_lbl.text = PlayerProfile.summary()
	if _boss_log > 0.0 and _mirror != null and is_instance_valid(_mirror):
		_boss_log -= delta
		if _boss_log <= 0.0:
			_boss_log = 1.0
			print("[R3] ", _mirror.debug_state())
	_tick_clock(delta)
	_tick_droppers(delta)
	_tick_echo_probe(delta)
	_hop_log(delta)
	# the giants breathe their own light, each on its own clock — nothing in
	# this cavern should sit at a constant brightness
	for a in _auras:
		var spr: Sprite2D = a[0]
		spr.modulate.a = float(a[1]) * (0.72 + sin(_t * float(a[3]) + float(a[2])) * 0.28)
	if _cam != null:
		_hills_far.position.x = _cam.global_position.x * 0.82
		_hills_mid.position.x = _cam.global_position.x * 0.6
		_hills_near.position.x = _cam.global_position.x * 0.32
		if not _freeze_cam:
			var target := Vector2(clampf(_curi.global_position.x, WORLD_L + 600.0, WORLD_R - 350.0),
					clampf(_curi.global_position.y - 110.0, -180.0, FLOOR_Y - 190.0))
			_cam.position = _cam.position.lerp(target, 1.0 - pow(0.001, delta))
	if not _dying and _curi.global_position.y > FLOOR_Y + 700.0:
		_die()
	_tick_checkpoint()


## A ROLLING CHECKPOINT, with nothing on screen to announce it.
##
## Twenty-six thousand pixels is a fifteen-minute walk, and the echo is
## designed to take her — repeatedly, that is the level. Sending her back to
## the mouth of the forest for it would not be a punishment, it would be a
## reason to close the game. So the spawn creeps forward with her: only ever
## forward, only while she is on the ground (never mid-jump over a gap), and
## never during the death beat itself.
const CHECKPOINT_STEP := 1800.0

## Report every sprite hanging in open air.
##
## "In the air" means: its bottom edge sits clear above the meadow's growth,
## it is in the WORLD (not a parallax band, not the roof, not the backdrop),
## and there is no walkable surface underneath it. Printed with coordinates so
## the offender can be found in the source instead of guessed at.
## NOTHING FLOATS — enforced, not hoped for.
##
## This level is assembled by about forty independent builders, and when the
## six `fungalhill` rows that used to be the floor were deleted, every clump,
## sprout and glow-mushroom that had been sitting ON them stayed exactly where
## it was: 236 sprites hanging in mid-air, which is what Advika circled. Fixing
## them by hand is how the last two hours went. This fixes the CLASS.
##
## After everything is built, every world sprite is asked one question: is
## there anything under you? The answer comes from `_solid_rects` — the actual
## colliders, so a decoration resting on a mushroom platform is left alone —
## and if the answer is no, it is dropped until its base is in the meadow.
##
## Deliberately not applied to: the ceiling (it hangs on purpose), anything
## flipped vertically (also hanging), and the parallax bands (they are not
## children of this node and are judged by eye).
const SETTLE_TOLERANCE := 10.0

var _solid_rects: Array = []


func _settle_floaters() -> void:
	var moved := 0
	for child in get_children():
		if not (child is Sprite2D):
			continue
		var s: Sprite2D = child
		if s.texture == null or s.flip_v:
			continue
		if s.global_position.y < ROOF_Y + 260.0:
			continue          # the roof hangs on purpose
		if s.has_meta("air"):
			continue          # so does anything that says so
		var h: float = s.texture.get_height() * absf(s.scale.y)
		var bottom: float = s.global_position.y + (h * 0.5 if s.centered else h)
		# what is the highest surface at or below this thing?
		var support: float = FLOOR_Y + 6.0
		var found := false
		for r in _solid_rects:
			if s.global_position.x < float(r[0]) or s.global_position.x > float(r[1]):
				continue
			var top: float = float(r[2])
			if top < bottom - SETTLE_TOLERANCE:
				continue      # that surface is above it, not under it
			if not found or top < support:
				support = top
				found = true
		if bottom < support - SETTLE_TOLERANCE:
			s.position.y += support - bottom
			moved += 1
	if moved > 0:
		print("R3 SETTLE — dropped %d sprites onto the ground under them" % moved)


func _audit_alpha() -> void:
	var total := 0
	var faded := 0
	var worst: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c in cur.get_children():
			stack.append(c)
		if not (cur is Sprite2D):
			continue
		var sp := cur as Sprite2D
		if sp.texture == null:
			continue
		var p: String = sp.texture.resource_path
		# the things that are SUPPOSED to be see-through
		if p.contains("fog") or p.contains("spore") or p.contains("halo") 				or p == "":
			continue
		total += 1
		if sp.modulate.a < 0.99:
			faded += 1
			if worst.size() < 10:
				worst.append("%s a=%.2f" % [p.get_file(), sp.modulate.a])
	print("R3 ALPHA — %d opaque-by-design sprites, %d BELOW full opacity"
			% [total, faded])
	for w in worst:
		print("   ", w)


func _audit_decor() -> void:
	var items: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c in cur.get_children():
			stack.append(c)
		if not (cur is Sprite2D):
			continue
		var sp := cur as Sprite2D
		if sp.texture == null:
			continue
		var p: String = sp.texture.resource_path
		if p.contains("fog") or p.contains("spore") or p.contains("halo"):
			continue
		var fam := "other"
		for f in ["fungalhill", "fungalfrond", "mushroomcap", "mushroomglow",
				"fungalstone", "stalagmite", "moss_", "rock_moss", "tuft"]:
			if p.contains(f):
				fam = f
				break
		items.append({"x": sp.global_position.x, "y": sp.global_position.y,
				"z": sp.z_index, "fam": fam,
				"w": absf(sp.texture.get_width() * sp.scale.x)})
	print("R3 DECOR — %d decoration sprites in the level" % items.size())
	for probe in [1200.0, 6300.0, 13400.0, 20000.0]:
		var here: Array = []
		for it in items:
			if absf(float(it["x"]) - probe) < 960.0:
				here.append(it)
		var by_z := {}
		var by_fam := {}
		for it in here:
			by_z[it["z"]] = int(by_z.get(it["z"], 0)) + 1
			by_fam[it["fam"]] = int(by_fam.get(it["fam"], 0)) + 1
		print("  x=%.0f : %d sprites on screen" % [probe, here.size()])
		var zs: Array = by_z.keys()
		zs.sort()
		var zline := ""
		for z in zs:
			zline += "z%d=%d " % [z, by_z[z]]
		print("      tiers: ", zline)
		var fline := ""
		for f in by_fam:
			fline += "%s=%d " % [f, by_fam[f]]
		print("      family: ", fline)
	# how badly does same-family decor overlap its neighbour?
	var fams := {}
	for it in items:
		if not fams.has(it["fam"]):
			fams[it["fam"]] = []
		(fams[it["fam"]] as Array).append(it)
	# MEASURED PER BAND, not globally. Sorting every sprite of a family by x
	# regardless of height compares the ceiling curtain against the floor field
	# and reports overlap that does not exist on screen. Only sprites within
	# 120px of each other in Y are actually neighbours.
	for f in fams:
		var arr: Array = fams[f]
		if arr.size() < 40:
			continue
		arr.sort_custom(func(a, b): return float(a["x"]) < float(b["x"]))
		var over := 0.0
		var n := 0
		for i in range(1, arr.size()):
			if absf(float(arr[i]["y"]) - float(arr[i - 1]["y"])) > 120.0:
				continue        # different band: not neighbours
			var gap: float = float(arr[i]["x"]) - float(arr[i - 1]["x"])
			var w: float = maxf(1.0, (float(arr[i]["w"]) + float(arr[i - 1]["w"])) * 0.5)
			over += clampf(1.0 - gap / w, 0.0, 1.0)
			n += 1
		if n > 0:
			print("  %-14s n=%-5d mean same-family overlap %.0f%%"
					% [f, arr.size(), over / float(n) * 100.0])


func _audit_floaters() -> void:
	var growth_top: float = FLOOR_Y - 40.0   # the meadow reaches up to here
	var bands: Array = [_hills_far, _hills_mid]
	var found: Array = []
	var checked := 0
	for child in get_children():
		if child is Sprite2D:
			checked += 1
			var s: Sprite2D = child
			if s.texture == null:
				continue
			# skip anything hanging on purpose — from the ceiling, or flipped
			# over to hang from a roof island (the settle pass skips these for
			# the same reason, and the audit has to agree with it or it reports
			# the level's own tassels as bugs forever)
			if s.global_position.y < ROOF_Y + 260.0 or s.flip_v:
				continue
			# A NON-CENTRED SPRITE'S POSITION IS ITS TOP-LEFT, so its bottom is
			# a FULL height below it, not zero. The old line added nothing for
			# those, which reported every floor tile in the level as floating
			# and buried the two things that really were.
			var h: float = s.texture.get_height() * absf(s.scale.y)
			var bottom: float = s.global_position.y + (h * 0.5 if s.centered else h)
			if bottom >= growth_top:
				continue
			# ...and it is only FLOATING if nothing is holding it up. A frond on
			# a mushroom platform is above the meadow on purpose; the audit used
			# to report those too, which is how 175 real ones hid inside 236.
			var held := false
			for r in _solid_rects:
				if s.global_position.x < float(r[0]) or s.global_position.x > float(r[1]):
					continue
				if absf(float(r[2]) - bottom) <= 24.0:
					held = true
					break
			if not held:
				found.append([s.global_position.x, bottom, s.texture.resource_path])
	print("R3 AUDIT — checked %d world sprites" % checked)
	print("  floating (bottom above y %.0f): %d" % [growth_top, found.size()])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var cap: int = 400 if OS.get_environment("R3_AUDIT_ALL") != "" else 25
	for i in mini(found.size(), cap):
		var f: Array = found[i]
		print("    x %8.0f  bottom %7.0f  %s"
				% [f[0], f[1], String(f[2]).get_file()])
	if found.size() > cap:
		print("    ... and %d more" % (found.size() - cap))
	print("  bands skipped: %d (parallax, judged by eye not by this)" % bands.size())


func _tick_checkpoint() -> void:
	if _dying or _leaving or _curi == null:
		return
	if not _curi.is_on_floor():
		return
	if _curi.global_position.x > _spawn.x + CHECKPOINT_STEP:
		_spawn = _curi.global_position


# ---------- the clock ----------
#
# Fifteen minutes to cross the forest (Advika). The number on screen is only
# half of it: the SAME value drives how far behind the echo walks, so the
# clock running down and her own past closing in are one event. At 15:00 it is
# twelve seconds back. At 0:00 it is standing where she is standing. Nothing
# needs to announce a failure — being caught IS running out of time.

const LEVEL_SECONDS := 600.0   # 10:00 (Advika: "it'll be hard to win lol")
var _time_left := LEVEL_SECONDS
var _glass: HourglassTimer
var _profile_lbl: Label
var _timed_out := false
## the sand stops when the forest dies — see `_begin_shift`
var _clock_stopped := false


## what the clock STARTED at. Normally LEVEL_SECONDS, but R3_CLOCK_SECS must
## compress the whole curve into a short test rather than dropping us in at
## 95% pressure — the delay is measured as a fraction of the run, not of 900.
var _clock_total := LEVEL_SECONDS


func _build_clock() -> void:
	if OS.get_environment("R3_CLOCK_SECS") != "":
		_time_left = float(OS.get_environment("R3_CLOCK_SECS"))
		_clock_total = maxf(_time_left, 1.0)
	# THE CLOCK IS AN HOURGLASS, top-right. It owns no time of its own — the
	# level hands it elapsed/total every frame, which is why pausing the level
	# freezes the sand without the widget knowing what a pause is.
	_glass = HourglassTimer.new()
	_glass.total_seconds = _clock_total
	_ui_layer.add_child(_glass)


func _tick_clock(delta: float) -> void:
	if _glass == null or _leaving or _clock_stopped:
		return
	if not _timed_out:
		_time_left = maxf(0.0, _time_left - delta)
	var k: float = 1.0 - _time_left / _clock_total
	# THE CLOCK IS THE SHADOW. The sand is only the visible half of this
	# number — the other half is how many seconds behind her own past is
	# walking. Twelve at the mouth of the forest, four tenths at zero.
	if _echo != null:
		_echo.pressure = k
	# the hourglass is TOLD the time; it never counts. Pause the level and the
	# sand stops, because this line stops being called.
	_glass.set_time(_clock_total - _time_left, _clock_total)
	if _time_left <= 0.0:
		_timed_out = true
		# There is no second fail rule to explain. At zero the delay is four
		# tenths of a second, which is another way of saying it is standing
		# where she is standing — so the clock running out kills her through
		# the SAME door as being caught, and keeps doing it until her last eye
		# is gone. Running out of time IS being caught.
		if not _dying and not _leaving:
			_die()


## R3_ECHO_PROBE=<seconds> — the mechanic, proved instead of assumed.
##
## Holds move_right and prints, once a second, the four numbers that ARE the
## design: the clock, how many seconds late the echo is, how far behind her it
## actually landed, and whether it is allowed to take her yet. Run it with a
## short R3_CLOCK_SECS to watch the delay collapse and the gap close.
var _probe_left := 0.0
var _probe_t := 0.0

func _tick_echo_probe(delta: float) -> void:
	if _probe_left <= 0.0:
		return
	_probe_left -= delta
	Input.action_press("move_right")
	_probe_t += delta
	if _probe_t >= 1.0:
		_probe_t = 0.0
		if _echo != null:
			var gap: float = _curi.global_position.distance_to(_echo.global_position)
			print("ECHO t=%5.1f  delay=%5.2fs  gap=%7.1fpx  armed=%s  x=%.0f"
					% [_time_left, _echo.delay_now(), gap,
					str(_echo.is_armed()), _curi.global_position.x])
	if _probe_left <= 0.0:
		Input.action_release("move_right")
		print("ECHO PROBE DONE")
		get_tree().quit()


## R3_HOP_LOG=1 — prove where the nearest hopper actually IS, frame by frame,
## instead of theorising about why it is not coming at her
var _hop_log_t := 0.0
func _hop_log(delta: float) -> void:
	if OS.get_environment("R3_HOP_LOG") != "1":
		return
	_hop_log_t += delta
	if _hop_log_t < 0.25:
		return
	_hop_log_t = 0.0
	var best: Sporeling = null
	var bd := 1e20
	for s in _sporelings:
		if not is_instance_valid(s):
			continue
		var d: float = absf(s.global_position.x - _curi.global_position.x)
		if d < bd:
			bd = d
			best = s
	if best == null:
		print("HOP: no sporelings")
		return
	print("HOP curi.x=%.0f  shroom.x=%.0f y=%.0f  gap=%.0f  %s" % [
			_curi.global_position.x, best.global_position.x,
			best.global_position.y, bd, best.debug_state()])


func _die() -> void:
	if _dying or _leaving:
		return
	_dying = true
	if _curi.has_method("hurt"):
		_curi.hurt()
	var remaining: int = _lives.lose_eye()
	await get_tree().create_timer(0.45).timeout
	if remaining <= 0:
		get_tree().reload_current_scene()
		return
	_curi.global_position = _spawn
	_curi.velocity = Vector2.ZERO
	if _curi.has_method("refill_health"):
		_curi.refill_health()
	if _curi.has_method("grant_invuln"):
		_curi.grant_invuln(1.6)
	# the past she is about to have is not the past she just had — wipe the
	# buffer so it starts again from where she is standing rather than
	# replaying her walk into whatever just killed her
	if _echo != null:
		_echo.clear_history()
		_echo.global_position = _spawn
	_dying = false


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_leaving = true
		Transition.transition_to(HUB_SCENE)
	if event.is_action_pressed("interact") and _at_exit and _exit_door != null:
		if _ending:
			_finish_the_game()
		else:
			_leaving = true
			_exit_door.trigger()
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G:
				# rapid-cycle all sixteen: frame, vines and eye must be stone
				# still with only the sand moving
				if _glass != null:
					_glass.toggle_cycle()
			KEY_P:
				# prove the sand freezes when the level does — it reads the
				# clock rather than owning one, so a pause is nothing it knows
				get_tree().paused = not get_tree().paused
			KEY_M:
				# end the fight this instant — the ending is what is being
				# looked at, not the eight swings in front of it
				if _mirror != null and is_instance_valid(_mirror) and _mirror.live:
					_mirror.take_damage(99999, Vector2(-200.0, -140.0))
			KEY_0:
				_time_left = _clock_total          # frame 1
			KEY_9:
				_time_left = _clock_total * 0.5    # midway
			KEY_8:
				_time_left = 10.0                  # the last stage + tremble
			KEY_TAB:
				# watch the game read you, live
				if _profile_lbl != null:
					_profile_lbl.visible = not _profile_lbl.visible


## walk the whole tree and flat-colour every sprite by its art family
func _id_pass(node: Node) -> void:
	for child in node.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			var p: String = (child as Sprite2D).texture.resource_path
			var c := Color(1.0, 1.0, 1.0)
			var known := false
			if p == "":
				known = true               # code-made gradients, not art
			elif p.contains("realm2_moss"):
				c = Color(1.0, 0.0, 1.0)          # MAGENTA — Realm 2 art
			elif p.contains("fungalhill"):
				c = Color(1.0, 0.1, 0.1)          # RED
			elif p.contains("fungalfrond"):
				c = Color(0.1, 1.0, 0.1)          # GREEN
			elif p.contains("stalagmite"):
				c = Color(0.2, 0.4, 1.0)          # BLUE
			elif p.contains("mushroom"):
				c = Color(1.0, 0.95, 0.1)         # YELLOW
			elif p.contains("fungalstone") or p.contains("fungalground"):
				c = Color(0.1, 1.0, 1.0)          # CYAN
			else:
				var sz: Vector2 = (child as Sprite2D).texture.get_size() 						* (child as Sprite2D).scale
				print("R3_ID UNKNOWN ", p, "  drawn=", sz)
			if not known:
				(child as Sprite2D).modulate = c
		_id_pass(child)


func _self_screenshot(path: String) -> void:
	if OS.get_environment("R3_SHOT_X") != "":
		_curi.position = Vector2(float(OS.get_environment("R3_SHOT_X")), FLOOR_Y - 160.0)
		_curi.velocity = Vector2.ZERO
		_cam.position = Vector2(_curi.position.x, FLOOR_Y - 190.0)
	# R3_SHOT_CAMY: freeze the camera at a fixed height to inspect the jump
	# view (the roof) — _process won't lerp it back to the hero
	if OS.get_environment("R3_SHOT_CAMY") != "":
		_cam.position.y = float(OS.get_environment("R3_SHOT_CAMY"))
		_freeze_cam = true
	# R3_SHOT_AT=<seconds> holds before capturing, so a frame from the MIDDLE
	# of something can be looked at — the drained fight, the ending — instead
	# of only the first second of the level.
	var wait: float = float(OS.get_environment("R3_SHOT_AT"))
	await get_tree().create_timer(wait if wait > 0.05 else 1.0).timeout
	print("SHOT curi=", _curi.global_position)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
