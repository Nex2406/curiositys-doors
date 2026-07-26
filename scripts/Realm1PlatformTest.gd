extends Node2D
## Realm 1 PLATFORM GALLERY — small/medium/large floating platform
## assemblies over the locked parallax background. Ref: cave_ref_04's
## chunky dark blocks with fog-lit cap stones — deliberately NOT the
## mossy-overhang look Realm 2 uses. Every platform is ONE Node2D assembly
## (nothing floats); two variants per size so nothing reads copy-pasted.
## Hold LEFT/RIGHT to pan. PLAT_SHOT=<path> screenshots and quits.

const Realm1Bg := preload("res://scripts/Realm1Bg.gd")
const CUT := "res://assets/realms/realm1_cut/"
const SOFT := "res://assets/realms/realm1_soft/"
# ported gameplay layer (jade + HUDs). The scenes are realm-agnostic; Realm 1 tints
# them to the warm cave palette here rather than editing the source art.
const JADE_SCENE := preload("res://scenes/Jade.tscn")
const PLAYER_HUD := preload("res://scenes/UI/PlayerHUD.tscn")
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
# Advika: recolour to match the cave — jade reads as a warm GOLD shard (the lantern-
# gold focal accent), the life-eyes glow warm amber instead of R2's cool violet.
# A luminance ramp (recolor_warm.gdshader) does the true hue change; modulate can't.
const RECOLOR := preload("res://shaders/recolor_warm.gdshader")
const EYE_LO := Color(0.18, 0.07, 0.02)
const EYE_HI := Color(1.0, 0.66, 0.28)
const JADE_DARKEN := Color(0.52, 0.56, 0.5)   # dim the jade (keeps its green hue)
# playable layer — Curiosity + golems (physics). Platforms carry her via
# AnimatableBody2D (sync_to_physics), the floor/walls are StaticBody2D.
const CURIOSITY := preload("res://scenes/Curiosity.tscn")
const GOLEM_SCENE := preload("res://scenes/Golem.tscn")
const GOLEM_BALL := preload("res://scenes/GolemBall.tscn")
const BOULDER_GOLEM := preload("res://scripts/BoulderGolem.gd")   # new rolling cave golem
const TAROT_DELAY := 5.0    # Advika: the card lands 5s after the player is in the level
const CURIOSITY_SCALE := 0.235  # Advika: bigger than default, then smaller, twice
const CURIOSITY_DIM := Color(0.62, 0.6, 0.64)   # Advika: dim the bright purple cloak
# measured SOLID rock top-row per platform texture (where the rock is actually solid,
# not the feathered edge) — the collider top sits here so Curiosity plants, no float.
const PLAT_SLAB_H := 5.0    # a thin red LINE — just the standable outline, not a slab
const PLAT_SINK := 5.0      # sit that line slightly BELOW the rim for a perfect planted sit
const CEILING_Y := -340.0         # world y Curiosity's head stops at (roof collider)
## The ceiling golem's cling spot — up IN the roof rock, over the flat early ground.
## y is set from the MEASURED roof silhouette here (bottom edge ≈ -380 world at this
## x, per a lit-column scan of the render): his cling body spans node-82..node-33.
## At -330 (Advika: push him further in) his whole rock chunk is INSIDE the roof —
## only the body's bottom lip, one glowing eye and a little loose rubble break the
## ceiling line. Past ~-340 he vanishes entirely and only stray pebbles show.
## Ceiling art is z40, he is z8 — the stalactites draw OVER him, so he reads as one
## more lump of roof until the eyes move.
## (the node moved to -381 when BoulderGolem started pinning the drop art per frame —
## the cling body now draws AT the node instead of ~50px above it. Same look on screen.)
const CEIL_GOLEM := Vector2(830.0, -381.0)
## Advika 2026-07-26: "drop a buncha golems including ceiling ones in this level".
## Ceiling y per spot is the roof's MEASURED silhouette bottom at that x (a lit-column
## scan of gallery renders across the level — the roof rides between -354 and -409),
## because burying them by a single number would leave some hanging in open air and
## others swallowed whole. Spots are spread along the route, off the start ledge and
## clear of the door pocket.
## Each spot is a FLAT stretch of roof (edge varies <26px across his body width) and
## y = that stretch's measured edge - 1, the rule calibrated on the approved x=830.
## Picked by `tools/measure_roof_line.py`; a spot chosen without that check swallows
## him whole (the roof is not level — it rides between -334 and -420 along the walk).
## Advika 2026-07-26: no two golems may cluster — GROUND and CEILING spots are laid
## out on ONE timeline with >=1150px between neighbours of either kind, so every
## encounter is its own beat. (The old 830 clinger was dropped: it sat 680px from
## the teaching golem at 150.)
const CEIL_GOLEMS: Array[Vector2] = [
	Vector2(2150.0, -360.0),
	Vector2(3875.0, -380.0),
	Vector2(6625.0, -381.0),
	Vector2(7825.0, -366.0),
]
## ground golems, dormant until she nears — they fill the gaps in that same timeline
const GROUND_GOLEMS: Array[float] = [150.0, 5150.0, 9000.0]
const CURIOSITY_JUMP := -500.0           # Advika: higher jump for this level (base -356)
const GOLEM_SCALE := 0.62                # Advika: bigger golems
const FLOOR_TOP := 470.0                 # world y of the walkable ground surface
const GOLEM_SPAWN_X := [1100.0, 3500.0, 6300.0, 8600.0]
const GOLEM_TINT := Color(0.95, 0.74, 0.46)   # darker warm — blends into the cave rock
const MAX_GOLEMS := 12
# Realm 2 portal door at the level end — floats in the cleared pocket, mist looping.
const DOOR_SCALE := 1.25                       # a grand portal, taller than the 0.3 hero
# It is not a floating portal any more — it ERUPTS from the ground, so the cell's
# contact row (10px above the bottom of the new 252x404 art, measured) sits exactly
# on FLOOR_TOP: 470 - (393.5 - 202) * DOOR_SCALE.
const DOOR_POS := Vector2(9250.0, 231.0)
const DOOR_PURPLE := Color("7a3b8c")           # Realm 2's violet, spilling onto R1 gold
# golems recoloured to the dark cave-rock shade so they read as the ground/platform
# stone rather than R2's pale golem art (Advika: match the ground's shade).
const GOLEM_LO := Color(0.05, 0.04, 0.03)
const GOLEM_HI := Color(0.34, 0.27, 0.17)
const CAM_SPEED := 700.0
## level bounds: the camera's SCREEN EDGE may never pan past the closing cliffs
## (Advika: crop out the backdrop gap beyond the walls, both sides). These are the
## cliffs' solid inner-of-outer x; the clamp keeps the view edge on solid rock so
## no backdrop shows beyond the walls at ANY window aspect (halfwidth is dynamic).
# These land the SCREEN EDGE on the cliffs' dense solid-rock column (texture cols
# ~180-380 are 85% opaque; everything outward of that is thin transparent ledge that
# leaked backdrop). Cutting the view here = solid stone at the edge, no gap beyond.
const CLIFF_L := -720.0
const CLIFF_R := 9700.0   # the view now cuts just before the end-wall art begins

var _cache := {}
var _cam: Camera2D
## STEP 6: one seeded stream feeds every plant's own frame/speed/flip draw —
## deterministic layout, but no two instances in sync.
var _veg_rng := RandomNumberGenerator.new()
## the old placement keys still passed by _fused/_ground, mapped to the new
## packed sequences (comp1 == the old PlantSmall art)
const KEY2SEQ := {
	"PlantSmall_00000.png": "comp1",
	"Grass2_00000.png": "grass2",
	"GroupPlants_00000.png": "groupplant",
	"grass3": "grass3",   # tall blades — floor accents
	"grass4": "grass4",
}

## STEP 5: per-platform geometry for rim / underside rocks / shadow
## (assembly-local): rim y (top edge), rim x0..x1, bottom y, width
## 2026-07-26 — rim y + x0..x1 RE-MEASURED from the painted art (the hand-typed
## values were off by -7..+16px, which is exactly why Curiosity's sit varied from
## platform to platform: she floated on medium_a/large_b and sank on small_a).
## Numbers come from `tools/measure_plat_rims.py` (repeatable): per column, the
## first row with alpha >= 190 (solid rock, not the feathered edge); the rim is
## the widest FLAT run of that profile, the span is where that flat top exists.
## The little rubble mound in the middle of each slab is decor — the collider is
## the flat slab line, she walks past the mound, not over it.
const PLAT_META := {
	"wall_ledge": [-145.0, 20.0, 390.0, 160.0, 400.0],
	"small_a": [-51.0, -95.0, 96.0, 75.0, 240.0],
	"small_b": [-36.0, -98.0, 95.0, 55.0, 240.0],
	"medium_a": [-57.0, -132.0, 129.0, 95.0, 340.0],
	"medium_b": [-58.0, -158.0, 78.0, 110.0, 300.0],
	"large_b": [-100.0, -140.0, 138.0, 170.0, 340.0],
}
var _plat_ramp: ShaderMaterial
var _plat_fill: ShaderMaterial
var _floor_ramp: ShaderMaterial
## every moving platform, recorded during build; motion is solved afterwards so
## no two platforms' motion envelopes ever overlap
var _movers: Array = []
## grounded pillar structures (large_b) + walls: static, and obstacles the
## moving platforms must never sweep into
var _static_obs: Array = []
## jade + HUD state (ported gameplay layer)
var _jade_rng := RandomNumberGenerator.new()
var _hud: CanvasLayer
var _lives_hud: CanvasLayer
var _jade_total: int = 0
var _jade_got: int = 0
## playable layer
var _player: CharacterBody2D
var _golems: Array = []
var _jade_plats: Array = []      # {node, pname, pos} for platforms that got a jade
var _spawn_pos := Vector2(-380.0, 360.0)
## PLAT_SIT=<pname> — contact harness: freeze every mover, drop Curiosity onto the
## first platform of that type, frame it close. Proves her feet meet the painted
## rock (no float, no sink) on each platform SHAPE, one at a time.
var _sit := ""
var _sit_freecam := false       # PLAT_SIT=ceiling*: hold the framing, don't chase her
var _plats: Array = []          # {pname, pos} for every standable platform
## the Realm 2 portal door at the level end — hidden until every jade is gathered
var _door: AnimatedSprite2D
var _door_light: PointLight2D
var _door_revealed: bool = false    # the eruption has started
var _door_ready: bool = false       # it has finished — only now does [Y] work
var _door_trigger: Area2D
var _door_prompt: Label
var _leaving: bool = false          # the quote card has taken over; ignore further input
var _door_armed: bool = false       # every jade gathered — it erupts once she's near
var _door_aura_nodes: Array = []    # the scattered light, in world space (not on the door)


func _ready() -> void:
	_sit = OS.get_environment("PLAT_SIT")
	_veg_rng.seed = 606
	_jade_rng.seed = 909
	Realm1Bg.build(self)
	# each platform is ONE fused texture (tools/compose_platforms.gd) —
	# internal seams melted offline; plants ride on top as crisp accents
	# left CLOSING cliff — the mirror of the right end-wall (Advika: same closing
	# structure both sides). Pulled inward so its inner face reads as a full-height
	# cliff at the left boundary, symmetric with the right.
	_fused("wall_ledge", Vector2(-740, 0), Vector2(240, 800), 0.10, [
			["GroupPlants_00000.png", 95.0, 205.0, 0.28, false]])
	var wall_back := ColorRect.new()
	wall_back.position = Vector2(-3600, -1600)
	wall_back.size = Vector2(2880, 3200)   # solid dark right up to the screen-cut (-720)
	wall_back.color = Color(0.02, 0.019, 0.017)
	wall_back.z_index = 4
	add_child(wall_back)
	_fused("small_a", Vector2(-140, 40), Vector2(180, 150), 0.10, [])
	_fused("medium_a", Vector2(350, 180), Vector2(250, 170), 0.10, [
			["Grass2_00000.png", 96.0, -60.0, 0.22, false]], "bob", true)
	_fused("small_b", Vector2(540, -150), Vector2(170, 150), 0.10, [])
	_fused("medium_b", Vector2(0, 300), Vector2(240, 190), 0.10, [
			["Grass2_00000.png", -34.0, -66.0, 0.18, true]])
	_fused("large_b", Vector2(830, 300), Vector2(250, 220), 0.10, [
			["Grass2_00000.png", 84.0, -108.0, 0.2, true]])
	# THE ROUTE v2 (Advika: longer, remixed arrangement — stair arcs,
	# mover bridges, rest ledges; no even spacing)
	_fused("small_a", Vector2(1250, 140), Vector2(180, 150), 0.10, [], "updown")
	_fused("small_b", Vector2(1600, 20), Vector2(170, 150), 0.10, [])
	_fused("small_a", Vector2(1850, -140), Vector2(180, 150), 0.10, [])
	_fused("medium_b", Vector2(2250, -60), Vector2(240, 190), 0.10, [], "static")
	# (Advika 2026-07-26: this pillar's column ended 120px above the floor — a
	# grounded structure has to REACH the ground. y 180 -> 300 puts its base exactly
	# on FLOOR_TOP, same as the pillar at x830.)
	_fused("large_b", Vector2(2700, 300), Vector2(250, 220), 0.10, [
			["Grass2_00000.png", 84.0, -108.0, 0.2, true]], "bob", true)
	_fused("small_b", Vector2(3100, 20), Vector2(170, 150), 0.10, [], "side")
	# (Advika 2026-07-26: this one sat too high — dropped 100px so it reads as a step
	# in the arc off small_b@3100 instead of a spike you can't reach.)
	_fused("medium_a", Vector2(3600, -20), Vector2(250, 170), 0.10, [
			["Grass2_00000.png", 96.0, -60.0, 0.22, false]])
	_fused("small_a", Vector2(3950, 60), Vector2(180, 150), 0.10, [], "updown")
	_fused("medium_b", Vector2(4300, 260), Vector2(240, 190), 0.10, [], "static")
	_fused("small_b", Vector2(4800, 80), Vector2(170, 150), 0.10, [], "side")
	_fused("medium_a", Vector2(5250, -100), Vector2(250, 170), 0.10, [])
	_fused("small_a", Vector2(5600, 120), Vector2(180, 150), 0.10, [], "updown")
	_fused("large_b", Vector2(6050, 300), Vector2(250, 220), 0.10, [], "bob", true)
	_fused("small_b", Vector2(6500, 60), Vector2(170, 150), 0.10, [], "side")
	_fused("small_a", Vector2(6900, -140), Vector2(180, 150), 0.10, [])
	_fused("medium_b", Vector2(7250, 40), Vector2(240, 190), 0.10, [], "static")
	_fused("medium_a", Vector2(7700, 220), Vector2(250, 170), 0.10, [
			["Grass2_00000.png", 96.0, -60.0, 0.22, false]])
	_fused("small_a", Vector2(8150, 0), Vector2(180, 150), 0.10, [], "updown")
	_fused("small_b", Vector2(8600, -120), Vector2(170, 150), 0.10, [], "side")
	# (Removed the final two platforms — medium_b@9000 + the large_b@9400 pillar — to
	# open a clear pocket at the level end where the Realm 2 portal door floats. The
	# player drops from small_b@8600 to the ground and walks up to the door. See
	# _add_realm2_door.)
	# extra rest-ledges, relocated OUT of the congested 5000-5600 cluster into
	# clear gaps at a separated height so nothing overlaps (Advika: space them out)
	_fused("small_b", Vector2(2050, 220), Vector2(170, 150), 0.10, [])
	_fused("small_a", Vector2(4500, -110), Vector2(180, 150), 0.10, [])
	# Right level-end wall: the left wall's mirror, world-space (step 6b).
	# Advika 2026-07-26: at x9980 its 800px-wide art reached back to 9180 and sat ON
	# the door pocket, so the end of the level read as stacked blocks behind the
	# portal. Pushed out to 10500 (art now spans 9700..10500) and the camera cut
	# (CLIFF_R) brought in to meet it, so the frame ends on dark rock instead.
	var wr := Sprite2D.new()
	wr.texture = _tex(SOFT, "plat_wall_ledge.png")
	wr.centered = false
	wr.scale = Vector2(-1, 1)
	wr.position = Vector2(10500, -800)
	wr.material = _plat_ramp
	wr.z_index = 5
	add_child(wr)
	var wall_back_r := ColorRect.new()
	wall_back_r.position = Vector2(9700, -1600)
	wall_back_r.size = Vector2(2880, 3200)   # solid dark right up to the screen-cut (9720)
	wall_back_r.color = Color(0.02, 0.019, 0.017)
	wall_back_r.z_index = 4
	add_child(wall_back_r)
	# (Advika 2026-07-25: the rock wall read HORRID — scrapped. The right end-wall
	# above already bounds the level right at the last platform; nothing else here.)
	_ground()
	_assign_motion()
	_setup_hud()
	_cam = Camera2D.new()
	_cam.position = Vector2.ZERO
	_cam.zoom = Vector2(1.05, 1.05)   # Advika: zoomed in, then out a bit more
	add_child(_cam)
	_cam.make_current()
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	# PLAT_NOPLAY=1 keeps the old camera-pan gallery (for screenshot harnesses);
	# otherwise spawn Curiosity + golems and make it playable.
	# PLAT_SPAWN_X=<x>: start Curiosity at a given world x (used to frame the
	# level-end door for verification shots). Must run before _setup_play spawns them.
	if OS.get_environment("PLAT_SPAWN_X") != "":
		_spawn_pos.x = float(OS.get_environment("PLAT_SPAWN_X"))
	if OS.get_environment("PLAT_SPAWN_Y") != "":
		_spawn_pos.y = float(OS.get_environment("PLAT_SPAWN_Y"))
	# PLAT_SIT=<pname|ground>: drop her onto that platform type and frame it close
	var sit_focus := Vector2.ZERO
	if _sit != "":
		sit_focus = _sit_place()
	if OS.get_environment("PLAT_NOPLAY") == "":
		_setup_play()
	if _sit != "":
		# gameplay zoom is 1.05 — the harness reads closer (the portal is tall, so it
		# gets a wider one than the contact shots)
		var z: float = 1.5 if _sit == "door" else 2.4
		_cam.zoom = Vector2(z, z)
		_cam.position = sit_focus
	if OS.get_environment("PLAT_CAM_X") != "":
		_cam.position.x = float(OS.get_environment("PLAT_CAM_X"))
	if OS.get_environment("PLAT_CAM_Y") != "":
		_cam.position.y = float(OS.get_environment("PLAT_CAM_Y"))   # frame the ceiling for shots
	# SOLO_BG_NEAR=1: hide everything except the bg_near band (measurement)
	if OS.get_environment("SOLO_BG_NEAR") != "":
		for child in get_children():
			if child is ParallaxBackground:
				for l in child.get_children():
					l.visible = l.name == "bg_near"
			elif child is CanvasLayer:
				child.visible = false
			elif child is CanvasItem:
				child.visible = false
	print("STEP 6 vegetation instances: ", Realm1Bg.veg_instance_count)
	# VEG_FPS_PROBE=1: run windowed for 5s, print the frame rate, quit
	if OS.get_environment("VEG_FPS_PROBE") != "":
		_fps_probe()
	# QUOTE_TEST=1: run the realm-2 handover immediately, for reviewing the card
	if OS.get_environment("QUOTE_TEST") != "":
		await get_tree().create_timer(0.4).timeout
		_on_realm2_door_entered(_player)
	# DOOR_PRESS=1: the REAL chain, hands-off — stand her in the portal's mouth, let
	# the ground open, then actually press [Y] so the door's own input path runs.
	if OS.get_environment("DOOR_PRESS") != "":
		_door_press_probe()
	if OS.get_environment("PLAT_SHOT") != "":
		_shot(OS.get_environment("PLAT_SHOT"))


func _fps_probe() -> void:
	await get_tree().create_timer(5.0).timeout
	print("VEG_FPS: ", Engine.get_frames_per_second(), " fps | instances: ",
			Realm1Bg.veg_instance_count)
	get_tree().quit()


## Give every platform the biggest possible up/down OR left/right motion whose
## full ENVELOPE (rest box grown by the amplitude along the motion axis) never
## intersects another platform's envelope or a wall — so no two can EVER overlap,
## while the level still has big, varied, fun-and-hard movement.
func _assign_motion() -> void:
	const CAP := 105.0
	const MARGIN := 7.0
	const STEP := 6.0
	# static obstacles: the two end-wall columns + the grounded pillar structures,
	# PLUS a full-width ceiling-clearance line (Advika: the tiles that go up sit too
	# close to the ceiling) — any platform whose envelope would rise above CEIL_CLEAR
	# gets its up/down travel capped here, keeping a safe gap under the roof.
	const CEIL_CLEAR := -210.0   # keep top platforms low enough to clear the roof collider
	var walls: Array = [[-980.0, -560.0, -500.0, 560.0],
			[9945.0, -820.0, 10165.0, 560.0],
			[-2000.0, -3000.0, 16000.0, CEIL_CLEAR]]
	walls.append_array(_static_obs)
	var n := _movers.size()
	var axes: Array = []
	var amps: Array = []
	var boxes: Array = []
	# 1) pick each platform's roomier axis from static clearances
	for i in n:
		var P: Dictionary = _movers[i]
		var xc := 9999.0
		var yc := 9999.0
		for j in n:
			if j == i:
				continue
			var Q: Dictionary = _movers[j]
			var dx: float = absf(P.cx - Q.cx)
			var dy: float = absf(P.cy - Q.cy)
			if dy < P.hy + Q.hy + 40.0:
				xc = minf(xc, dx - P.hx - Q.hx)
			if dx < P.hx + Q.hx + 40.0:
				yc = minf(yc, dy - P.hy - Q.hy)
		axes.append("x" if xc >= yc else "y")
		amps.append(0.0)
		boxes.append(_swept_box(P, axes[i], 0.0, MARGIN))
	# 2) grow all amplitudes round-robin until none can grow (fair, no overlap)
	for _iter in range(60):
		var grew := false
		for i in n:
			if amps[i] >= CAP:
				continue
			var test: float = minf(amps[i] + STEP, CAP)
			var tb: Array = _swept_box(_movers[i], axes[i], test, MARGIN)
			var ok := true
			for w: Array in walls:
				if _box_overlap(tb, w):
					ok = false
					break
			if ok:
				for j in n:
					if j != i and _box_overlap(tb, boxes[j]):
						ok = false
						break
			if ok:
				amps[i] = test
				boxes[i] = tb
				grew = true
		if not grew:
			break
	# self-check: no two final envelopes may overlap (the whole guarantee)
	var overlaps := 0
	var moving := 0
	for i in n:
		if amps[i] >= 5.0:
			moving += 1
		for j in range(i + 1, n):
			if _box_overlap(boxes[i], boxes[j]):
				overlaps += 1
				print("  overlap: (%.0f,%.0f) <-> (%.0f,%.0f)" % [
						_movers[i].cx, _movers[i].py, _movers[j].cx, _movers[j].py])
	print("MOTION: %d/%d platforms move, envelope overlaps=%d (must be 0)"
			% [moving, n, overlaps])
	# 3) start each platform's loop on its axis, phase-randomised
	for i in n:
		_start_mover(_movers[i], axes[i], amps[i])


func _swept_box(P: Dictionary, axis: String, amp: float, margin: float) -> Array:
	var ex: float = P.hx + margin + (amp if axis == "x" else 0.0)
	var ey: float = P.hy + margin + (amp if axis == "y" else 0.0)
	return [P.cx - ex, P.cy - ey, P.cx + ex, P.cy + ey]


func _box_overlap(a: Array, b: Array) -> bool:
	return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]


func _start_mover(P: Dictionary, axis: String, amp: float) -> void:
	var node: Node2D = P.node
	if _sit != "":
		return      # contact harness: everything holds still so the sit is readable
	if amp < 5.0:
		return   # boxed in — leave it static rather than jitter
	var rest: float = P.px if axis == "x" else P.py
	var prop: String = "position:x" if axis == "x" else "position:y"
	var dur := _veg_rng.randf_range(2.4, 4.4)
	# vertical movers RISE much less than they drop (Advika: shorter up-travel) —
	# both legs still stay inside the solver's symmetric ±amp reserved envelope, so
	# no two platforms can ever overlap. Horizontal movers stay symmetric.
	var up_amp := amp * 0.4 if axis == "y" else amp
	var lo := rest - up_amp     # highest point
	var hi := rest + amp        # lowest point
	# same travel speed on both legs (dur scales with each leg's distance)
	var dur_up := dur * (up_amp / amp)
	# random starting phase so nothing pulses in sync
	var start := lo + _veg_rng.randf_range(0.0, hi - lo)
	if axis == "x":
		node.position.x = start
	else:
		node.position.y = start
	# run in the PHYSICS step so the platform's AnimatableBody2D carries a rider
	# (Curiosity) smoothly instead of jittering against the idle-step tween.
	var tw := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(node, prop, lo, dur_up) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, prop, hi, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## a SOLID rocky wall filling a vertical gap — the ceiling recipe rotated: a
## solid backing column so nothing shows through, then DENSE overlapping rocks
## poking inward (left) off it with a ragged inner edge, reading as one mass.
func _rock_wall(wall_x: float, top_y: float, bottom_y: float) -> void:
	var pool: Array[String] = ["combo_08.png", "combo_10.png", "combo_00.png",
			"combo_05.png", "combo_06.png", "combo_09.png", "bigrock_02.png",
			"bigrock_08.png", "combo_11.png"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(wall_x)
	# solid backing column (blackened by the platform ramp's dark end)
	var band := ColorRect.new()
	band.position = Vector2(wall_x - 30.0, top_y - 60.0)
	band.size = Vector2(360.0, bottom_y - top_y + 160.0)
	band.color = Color(0.05, 0.04, 0.03)
	band.z_index = 5
	add_child(band)
	# dense rows of overlapping rocks extending INWARD, ragged inner edge
	var y := top_y
	while y < bottom_y:
		var reach := rng.randf_range(190.0, 360.0)   # how far this row pokes in
		var x := wall_x + 40.0
		while x > wall_x - reach:
			var tex := _tex(CUT, pool[rng.randi() % pool.size()])
			var w := rng.randf_range(150.0, 250.0)
			var sc := w / float(tex.get_width())
			var s := Sprite2D.new()
			s.texture = tex
			s.scale = Vector2(-sc if rng.randf() < 0.5 else sc,
					sc * rng.randf_range(0.9, 1.35))
			s.position = Vector2(x + rng.randf_range(-25.0, 25.0),
					y + rng.randf_range(-28.0, 28.0))
			s.material = _plat_ramp   # lit like the platforms
			s.z_index = 6
			add_child(s)
			x -= w * rng.randf_range(0.38, 0.52)   # heavy overlap = solid
		y += rng.randf_range(85.0, 130.0)



func _process(delta: float) -> void:
	if _cam == null:
		return
	# half the visible world width, live (so it holds under any window resize)
	var hw: float = get_viewport().get_visible_rect().size.x * 0.5 / _cam.zoom.x
	var lo: float = CLIFF_L + hw
	var hi: float = CLIFF_R - hw
	if lo > hi:               # window wider than the level: just center it
		lo = (CLIFF_L + CLIFF_R) * 0.5
		hi = lo
	# armed and close enough to witness it: the ground opens
	if _door_armed and not _door_revealed and _player != null and is_instance_valid(_player) \
			and _player.global_position.x > DOOR_POS.x - 1250.0:
		_erupt_door()

	var target_x: float
	if _sit_freecam:
		return                    # harness: the shot's framing is fixed
	if _player != null and is_instance_valid(_player):
		target_x = _player.global_position.x           # follow Curiosity
		_cam.position.x = clampf(lerpf(_cam.position.x, target_x, clampf(delta * 6.0, 0.0, 1.0)), lo, hi)
	else:
		# gallery fallback (PLAT_NOPLAY): hold LEFT/RIGHT to pan
		_cam.position.x = clampf(_cam.position.x
				+ Input.get_axis("ui_left", "ui_right") * CAM_SPEED * delta, lo, hi)


func _tex(dir: String, tex_name: String) -> Texture2D:
	var key := dir + tex_name
	if not _cache.has(key):
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir + tex_name))
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


func _p(parent: Node2D, tex_name: String, pos: Vector2, sc: float,
		tint: Color, z: int, fh := false, dir := CUT) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(dir, tex_name)
	s.position = pos
	s.scale = Vector2(-sc if fh else sc, sc)
	s.modulate = tint
	s.z_index = z
	parent.add_child(s)
	return s


## one fused platform: the pre-composed texture, art lit by the local fog
## (detail 1.0 — shading is baked into the texture), SWAYING plants on top,
## and a slow bob (floating platforms breathe; the wall ledge stays rooted)
func _fused(pname: String, pos: Vector2, origin: Vector2, lift: float,
		plants: Array, motion: String = "bob", _hang_vines := false) -> void:
	# movers = everything except the rooted end-wall and the grounded large_b pillar;
	# their root must BE the AnimatableBody2D so tweening it carries a rider.
	var is_mover: bool = pname != "wall_ledge" and pname != "large_b"
	var a := _assembly(pos, is_mover)
	if _plat_ramp == null:
		_plat_ramp = ShaderMaterial.new()
		_plat_ramp.shader = load("res://shaders/plat_form.gdshader")
		# Advika: the tiles read pure black — lift the ramp so their painted
		# form/texture shows (still dark, but no longer a flat silhouette)
		# NOTE: dark_c/cap_c are source_color (sRGB->linear on upload), so these
		# read darker than the number; pushed up to compensate.
		_plat_ramp.set_shader_parameter("dark_c", Color(0.30, 0.25, 0.19))
		_plat_ramp.set_shader_parameter("cap_c", Color(0.62, 0.53, 0.37))
		_plat_ramp.set_shader_parameter("gamma_v", 1.0)
		_plat_ramp.set_shader_parameter("lift", Vector3(0.06, 0.05, 0.03))
	# lit fill behind the tile, using its own silhouette — the fused texture
	# fades to transparent toward the bottom, so without this the body shows the
	# dark cave through it and reads black. (Advika: lighten the platforms.)
	if _plat_fill == null:
		_plat_fill = ShaderMaterial.new()
		_plat_fill.shader = load("res://shaders/plat_fill.gdshader")
	var fillspr := Sprite2D.new()
	fillspr.texture = _tex(SOFT, "plat_%s.png" % pname)
	fillspr.centered = false
	fillspr.position = -origin
	fillspr.material = _plat_fill
	fillspr.z_index = -1
	a.add_child(fillspr)
	var s := Sprite2D.new()
	s.texture = _tex(SOFT, "plat_%s.png" % pname)
	s.centered = false
	s.position = -origin
	s.material = _plat_ramp
	a.add_child(s)
	# plants sit ON the platform top only — nothing hangs into open air
	# (Advika 2026-07-25: no floating plants, ever).
	for p: Array in plants:
		_plant(a, p[0], Vector2(p[1], p[2]), p[3], p[4])
	# platforms with no hand-placed plants still get a little rooted growth on
	# their rim (Advika wants MORE vegetation) — base sunk into the platform.
	if plants.is_empty() and pname != "wall_ledge":
		var m: Array = PLAT_META[pname]
		for _k in range(_veg_rng.randi_range(1, 2)):
			var pkey: String = ["Grass2_00000.png", "PlantSmall_00000.png",
					"grass3", "Grass2_00000.png"][_veg_rng.randi() % 4]
			var psc: float = 0.16 if pkey == "grass3" else 0.22
			_plant(a, pkey, Vector2(_veg_rng.randf_range(m[1] + 22.0, m[2] - 22.0),
					float(m[0]) - 4.0), psc, false)
	# jade shard on a RANDOM subset of platforms (not the walls). Parented to the
	# assembly, so it rides the platform's motion. (Advika: jade on random platforms.)
	if pname != "wall_ledge" and _jade_rng.randf() < 0.6:
		_place_jade(a, pname)
		_jade_plats.append({"node": a, "pname": pname, "pos": pos})
	# standable collision on the platform TOP. Movers carry Curiosity via an
	# AnimatableBody2D (sync_to_physics); the grounded large_b pillar is a StaticBody.
	if pname != "wall_ledge":
		_add_plat_collision(a, pname, is_mover, origin)
		_plats.append({"pname": pname, "pos": pos, "node": a})
	# the wall stays rooted; every other platform is RECORDED here and gets its
	# motion assigned once ALL platforms are placed, so the solver can give each
	# the biggest move that never overlaps a neighbour (Advika: big up/down/left/
	# right movement, but no two platforms ever collide/layer).
	if pname == "wall_ledge":
		return
	var meta2: Array = PLAT_META[pname]
	var cyb: float = pos.y + (float(meta2[0]) + float(meta2[3])) * 0.5
	var hxb: float = float(meta2[4]) * 0.5
	var hyb: float = (float(meta2[3]) - float(meta2[0])) * 0.5
	# large_b is a pillar STRUCTURE (cap on a column) — it reads as grounded, so
	# it stays rooted and becomes an obstacle the movers avoid.
	if pname == "large_b":
		_static_obs.append([pos.x - hxb, cyb - hyb, pos.x + hxb, cyb + hyb])
		return
	_movers.append({
		"node": a, "px": pos.x, "py": pos.y,
		"cx": pos.x, "cy": cyb, "hx": hxb, "hy": hyb,
	})


## Drop a spinning jade shard onto a platform's top rim, parented to the assembly
## so it rides the platform's motion. Tinted warm gold for the cave. Collection is
## wired via `collected` (fires once a player body exists in the scene).
func _place_jade(a: Node2D, pname: String) -> void:
	var meta: Array = PLAT_META[pname]
	var rim_y: float = float(meta[0])
	var x0: float = float(meta[1])
	var x1: float = float(meta[2])
	var jade := JADE_SCENE.instantiate()
	jade.piece_scale = 0.16
	jade.position = Vector2(_jade_rng.randf_range(x0 + 34.0, x1 - 34.0), rim_y - 40.0)
	jade.z_index = 3
	jade.modulate = JADE_DARKEN   # Advika: darker jade — keep the green hue, dim it
	a.add_child(jade)
	jade.collected.connect(_on_jade_collected)
	_jade_total += 1


## Build the two HUD counters (jade + eye-lives), recoloured to the cave palette.
func _setup_hud() -> void:
	_hud = PLAYER_HUD.instantiate()
	add_child(_hud)
	_hud.set_jade(_jade_got, _jade_total)   # jade icon stays its natural green
	print("JADE TOTAL: ", _jade_total, " on ", _plats.size(), " platforms")
	_lives_hud = LIVES_HUD.instantiate()
	_lives_hud.eye_tint = Color(1, 1, 1)   # let the recolor shader own the colour
	add_child(_lives_hud)
	_lives_hud.reset(3)
	# recolour the violet life-eyes to warm amber (shader, not modulate)
	var eye_mat := _recolor_mat(EYE_LO, EYE_HI, 2.0)
	for eye in _lives_hud._eyes:
		eye.material = eye_mat


func _on_jade_collected() -> void:
	_jade_got += 1
	if _hud != null:
		_hud.set_jade(_jade_got, _jade_total)
	# The last jade ARMS the portal (the card promises "gather all the jade; the way
	# opens itself"). It then erupts the moment she is near enough to watch it happen
	# — see _process. Landing on the final platform also fires it, but that alone
	# missed anyone who walked the ground to the level end (Advika: "I collected all
	# jades but where's the door").
	if _jade_got >= _jade_total:
		_door_armed = true


## A warm luminance-ramp recolor material (lo=shadow, hi=highlight, boost lifts
## dim source art). Turns R2's green jade / violet eyes into the cave's gold/amber.
func _recolor_mat(lo: Color, hi: Color, boost: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = RECOLOR
	m.set_shader_parameter("lo", lo)
	m.set_shader_parameter("hi", hi)
	m.set_shader_parameter("boost", boost)
	return m


# ─── playable layer: Curiosity + golems ──────────────────────────────────────

## Standable collision on a platform's TOP rim. Movers use an AnimatableBody2D
## (sync_to_physics carries a rider); the grounded pillar uses a StaticBody2D.
## Both on collision layer 2 — the layer Curiosity's mask (3) collides with.
func _add_plat_collision(a: Node2D, pname: String, is_mover: bool, _origin: Vector2) -> void:
	# ONE source of truth for the top surface: PLAT_META[pname] — the SAME rim the
	# jade and plants sit on (already in assembly-local space). A THIN cap hanging
	# just BELOW that rim, spanning only the real standable width. Bodies stand
	# exactly on the painted rock — no float, no bulky invisible box above/around it.
	var meta: Array = PLAT_META[pname]
	# sink the cap a touch BELOW the painted rim so Curiosity's feet leak INTO the rock
	# (grounded/planted read) instead of perching on the very top edge (Advika).
	var surf_top: float = float(meta[0]) + PLAT_SINK
	var left: float = float(meta[1])
	var right: float = float(meta[2])
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(right - left, PLAT_SLAB_H)
	cs.shape = r
	cs.position = Vector2((left + right) * 0.5, surf_top + PLAT_SLAB_H * 0.5)
	if is_mover:
		# `a` IS the AnimatableBody2D (see _assembly): the shape lives directly on the
		# moving root, so tweening it carries Curiosity along via sync_to_physics.
		a.add_child(cs)
	else:
		# grounded pillar: a plain static body under the Node2D assembly.
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.add_child(cs)
		a.add_child(body)
	if OS.get_environment("DEBUG_COLLISION") != "":
		var dbg := ColorRect.new()
		dbg.color = Color(1, 0, 0, 0.4)
		dbg.position = Vector2(left, surf_top)
		dbg.size = Vector2(right - left, PLAT_SLAB_H)
		dbg.z_index = 30
		a.add_child(dbg)


## PLAT_SIT=door: replay the eruption forever so the beat can be judged on its own —
## born, settled, held, gone, born again.
func _door_loop() -> void:
	await get_tree().create_timer(1.2).timeout
	while is_inside_tree():
		_door_revealed = false
		_door_ready = false
		if _door_prompt != null:
			_door_prompt.modulate.a = 0.0
		if _door_trigger != null:
			_door_trigger.monitoring = false
		_erupt_door()
		await get_tree().create_timer(11.0).timeout
		if _door != null:
			_door.visible = false
			if _door_light != null:
				_door_light.energy = 0.0
		for n in _door_aura_nodes:            # the loose aura goes with it
			if is_instance_valid(n):
				n.queue_free()
		_door_aura_nodes.clear()
		await get_tree().create_timer(1.2).timeout


## A LIVING GLIMPSE OF REALM 2 inside the arch (Advika 2026-07-26: "the player could
## see the life of level 2 through this purple door... instead of the black screen
## show them this"). The door art's interior is fully opaque, so the view is painted
## OVER it and shaped by `portal_window.gdshader` — a soft ellipse matching the
## opening, so it dissolves into the stone rather than ending on a straight edge.
## Everything inside is Realm 2's own art (its moon, its far silhouette band, its
## spores), dimmed and violet-shifted: a window, not a poster.
func _door_window(door: AnimatedSprite2D) -> void:
	# REALM 2 ITSELF, captured from the built level: assets/realms/realm1_door/
	# r2_forest_peek.png is a straight screenshot of the opening forest with the HUD
	# cropped off. Rebuilding Realm2Background live only ever gave sky and parallax
	# bands — this is the mossy dark forest she actually made, fireflies and all
	# (Advika: "why can't you just show them the beautiful dark forest we made").
	var win := Sprite2D.new()
	win.name = "PortalWindow"
	win.texture = load("res://assets/realms/realm1_door/r2_forest_peek.png")
	win.position = Vector2(0.0, 26.0)          # the opening's centre, door-local
	win.scale = Vector2(0.30, 0.30)            # 480x729 art over the ~90x234 opening
	win.z_index = 1                            # over the opaque interior
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/portal_window.gdshader")
	mat.set_shader_parameter("centre", Vector2(0.5, 0.5))
	mat.set_shader_parameter("radius", Vector2(0.46, 0.44))
	mat.set_shader_parameter("feather", 0.40)
	mat.set_shader_parameter("brightness", 1.3)   # lift the forest out of the dark
	win.material = mat
	door.add_child(win)
	# the other side breathes: a slow drift and a whisper of zoom
	var drift := create_tween().set_loops()
	drift.tween_property(win, "position:x", 7.0, 13.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(win, "position:x", -7.0, 13.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var breathe := create_tween().set_loops()
	breathe.tween_property(win, "scale", Vector2(0.325, 0.325), 9.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(win, "scale", Vector2(0.30, 0.30), 9.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# VIOLET MOTES around the arch (Advika: "surround the door with the purple hue
	# dots"). Realm 2's own spore art, rising and fading on the Realm 1 side of the
	# threshold — the other realm leaking through.
	var srng := RandomNumberGenerator.new()
	srng.seed = 5150
	# ROUND glowing motes, not Realm 2's spore dashes — those read as little purple
	# streaks (Advika 2026-07-26: "not these, the purple balls used for atmosphere").
	# A soft radial, additively blended, so each one is a bead of light.
	var mote_tex := _radial_light_tex()
	var mote_mat := CanvasItemMaterial.new()
	mote_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(40):
		var sp := Sprite2D.new()
		sp.texture = mote_tex
		sp.material = mote_mat
		# SMALL. 256px radial down to 4-11px beads — glowing specks in the air, not
		# the disco balls the first pass produced.
		var s: float = srng.randf_range(0.016, 0.044)
		sp.scale = Vector2(s, s)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * srng.randf_range(40.0, 180.0)
		var y0: float = srng.randf_range(-20.0, 200.0)
		sp.position = Vector2(x, y0)
		sp.modulate = Color(0.62, 0.34, 1.0, srng.randf_range(0.30, 0.75))
		sp.z_index = 2
		door.add_child(sp)
		var dur: float = srng.randf_range(4.0, 8.0)
		var t := create_tween().set_loops()
		t.tween_property(sp, "position",
				Vector2(x + srng.randf_range(-26.0, 26.0), y0 - srng.randf_range(150.0, 260.0)),
				dur).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(sp, "modulate:a", 0.0, dur)
		t.tween_callback(func() -> void:
			sp.position = Vector2(x, y0)
			sp.modulate.a = srng.randf_range(0.35, 0.95))


## Roof rock drawn OVER a clinger's shoulders — same art, same shader and same
## colour as the ceiling frame, at z41 (his z is 8), so his top edge is inside
## stone no matter how the painted roof happens to fall at that exact x.
## Advika 2026-07-26: "make sure the ceiling golems are IN THE CEILING, I legit
## just saw one that wasn't." Tuning each spot by eye kept missing, because the
## roof's lower edge wanders within a golem's own width — covering him is the fix
## that cannot come loose. This is NOT a floating anchor rock: it is roof, it
## overlaps the roof, and it hangs no lower than his own shoulders.
func _ceiling_cover(spot: Vector2) -> void:
	var pool: Array[String] = ["combo_00.png", "combo_05.png",
			"bigrock_02.png", "combo_08.png"]
	var blur := ShaderMaterial.new()
	blur.shader = load("res://shaders/frame_blur.gdshader")
	# his cling body's top, in world units (cell rows 6..129 of a 322 cell, pinned
	# to the node by CEIL_FRAME_OFF, at BoulderGolem.SCALE)
	var body_top: float = spot.y - 27.0
	for i in range(2):
		var tex := _tex(CUT, pool[(int(spot.x / 97.0) + i * 2) % pool.size()])
		var h: float = 165.0 + 45.0 * float(i)
		var sc: float = h / float(tex.get_height())
		var s := Sprite2D.new()
		s.texture = tex
		s.flip_v = true                      # roof rocks hang the other way up
		s.flip_h = i == 1
		s.scale = Vector2(sc * 1.75, sc)
		# its BOTTOM edge sits ~22px below his shoulders, so the seam is buried
		s.position = Vector2(spot.x + (-30.0 if i == 0 else 34.0),
				body_top + 22.0 - h * 0.5)
		s.material = blur
		s.modulate = Color("665033")         # the ceiling frame's own colour
		s.z_index = 41                       # over the golem, with the roof
		add_child(s)


## Contact harness (PLAT_SIT): put Curiosity above the first platform of the named
## type — or on the ground — so she falls and lands on it, and return the point the
## camera should frame. Movers are already frozen (see _start_mover).
func _sit_place() -> Vector2:
	if _sit == "ground":
		_spawn_pos = Vector2(600.0, FLOOR_TOP - 260.0)
		return Vector2(600.0, FLOOR_TOP - 90.0)
	# ceiling  = the clinger dormant, camouflaged (she waits far away, out of range)
	# ceildrop = the same golem mid-detach (she stands under it and triggers the fall)
	# PLAT_SIT=door — the portal on its own: she waits far away, the camera holds the
	# arch, and the eruption replays on a loop so the whole beat can be watched.
	if _sit == "door":
		_sit_freecam = true
		_spawn_pos = Vector2(200.0, FLOOR_TOP - 40.0)
		_door_loop()
		return DOOR_POS + Vector2(0.0, -120.0)
	if _sit == "ceiling" or _sit == "ceildrop":
		_sit_freecam = true
		_spawn_pos = Vector2(CEIL_GOLEM.x if _sit == "ceildrop" else 60.0, FLOOR_TOP - 40.0)
		return CEIL_GOLEM + Vector2(0.0, 40.0)
	for p: Dictionary in _plats:
		if p.pname != _sit:
			continue
		var rim: float = float(PLAT_META[p.pname][0])
		var pos: Vector2 = p.pos
		# 18px right of centre (off the middle rubble mound), dropped from just above
		_spawn_pos = Vector2(pos.x + 18.0, pos.y + rim - 150.0)
		return Vector2(pos.x + 18.0, pos.y + rim - 60.0)
	push_warning("PLAT_SIT: no platform named '%s'" % _sit)
	return Vector2.ZERO


## Spawn Curiosity, the ground/wall colliders, and the golems, then wire death.
func _setup_play() -> void:
	# "Echoed Blades (Loop)" — Realm 1's background track (Advika's JRPG pack,
	# 2026-07-26). Loop flag lives in the .ogg's import settings.
	AudioManager.play_ambient(preload("res://assets/audio/realm1_echoed_blades.ogg"), "realm1")
	_add_static_floor()
	_add_end_walls()
	_add_ceiling()
	_player = CURIOSITY.instantiate()
	_player.scale = Vector2(CURIOSITY_SCALE, CURIOSITY_SCALE)
	_player.position = _spawn_pos
	_player.z_index = 10        # in front of ground (z6) / platforms (z5)
	_player.jump_velocity = CURIOSITY_JUMP
	_player.max_air_jumps = 1   # Advika: double jump in this level
	# moving-platform fixes: snap to a descending platform (no jitter/float on the
	# up/down movers), and don't inherit the platform's velocity when jumping off
	# (Advika: the launch off rising platforms).
	_player.floor_snap_length = 34.0
	_player.platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	add_child(_player)
	# dim just the cloak sprite (not the lantern) so the bright purple sits back
	var pv := _player.get_node_or_null("Visual")
	if pv != null:
		pv.modulate = CURIOSITY_DIM
	var pcam := _player.get_node_or_null("Camera")
	if pcam != null:
		pcam.enabled = false        # the level's clamped camera drives the view
	_player.died.connect(_on_player_died)
	# boulder golems along the walk — dormant/camouflaged until Curiosity nears,
	# then they roll-charge her. GOLEM_SIT=<x> parks the FIRST one where a contact
	# harness is looking, and drops the rest, so a shot stays readable.
	var ground_xs: Array = GROUND_GOLEMS
	if OS.get_environment("GOLEM_SIT") != "":
		ground_xs = [float(OS.get_environment("GOLEM_SIT"))]
	for gx: float in ground_xs:
		var g := BOULDER_GOLEM.new()
		g.body_tint = GOLEM_TINT
		g.position = Vector2(gx, FLOOR_TOP)
		g.z_index = 8
		add_child(g)
	# ceiling golems buried in the roof — they drop when Curiosity walks under.
	# Each body sits UP in the roof rock and the ceiling frame (z40) draws over the
	# golem (z8), so it reads as PART of the ceiling until it lets go.
	if OS.get_environment("NO_CEILING") == "":
		var ceil_spots: Array = CEIL_GOLEMS
		# CEIL_GOLEM_Y=<y>: sweep how deep the first one sits, alone, without editing code
		if OS.get_environment("CEIL_GOLEM_Y") != "":
			ceil_spots = [Vector2(CEIL_GOLEM.x, float(OS.get_environment("CEIL_GOLEM_Y")))]
		elif _sit == "ceiling" or _sit == "ceildrop":
			ceil_spots = [CEIL_GOLEM]      # harness: judge one, not six
		print("CEILING GOLEMS: ", ceil_spots.size(), " at ", ceil_spots)
		for spot: Vector2 in ceil_spots:
			var gc := BOULDER_GOLEM.new()
			gc.ceiling_spawner = true
			gc.body_tint = GOLEM_TINT
			gc.position = spot
			gc.z_index = 8
			add_child(gc)
			_ceiling_cover(spot)
	_add_realm2_door()
	_arm_door_trigger()
	# the instructions card, 3s in. Skipped for the screenshot/contact harnesses —
	# it pauses the whole tree, which would freeze whatever they are shooting.
	# (TAROT_SHOT=1 forces it back on so the card itself can be shot in-level.)
	if _sit == "" and OS.get_environment("NO_TAROT") == "" \
			and (OS.get_environment("PLAT_SHOT") == ""
					or OS.get_environment("TAROT_SHOT") != ""):
		_tarot_beat()


## The instructions card, TAROT_DELAY after Curiosity lands in the realm (Advika
## 2026-07-26: "the card comes 3 seconds after the player is in the level").
## Content + colour live in scripts/Realm1Card.gd — the same card the review rigs
## show. It pauses the game and ducks the music itself; any input dismisses it.
func _tarot_beat() -> void:
	await get_tree().create_timer(TAROT_DELAY).timeout
	_show_tarot()


func _show_tarot() -> void:
	if not is_inside_tree():
		return
	add_child(Realm1Card.build())


## The animated Realm 2 portal door that waits at the level end. Placement + idle
## animation only — it floats and bobs, its mist loops, and its purple glow spills
## onto the gold cave rock (the two palettes meeting = intentional foreshadowing).
## The actual teleport is a TODO on TransitionTrigger (wired in the next step).
func _add_realm2_door() -> void:
	var door := AnimatedSprite2D.new()
	door.name = "Realm2Door"
	# ONE-SHOT ERUPTION, not a loop (Advika 2026-07-26): the portal tears itself out
	# of the ground — crack (1-2), rupture (3-4), the arch assembling (5-6), settling
	# (7-12) — then HOLDS on the last frame forever. Frames 1-6 run at 12fps, 7-12 at
	# 8fps (a per-frame duration of 1.5), so the birth is sharp and the settle eases.
	var sf := SpriteFrames.new()
	sf.add_animation("erupt")
	sf.set_animation_loop("erupt", false)
	# Advika 2026-07-26: the birth read as a jolt — 12/8fps -> 7/4.7 -> 3/2fps, so
	# the ground takes a full 5 seconds to tear open (2s cracking, 3s settling).
	# The twelve frames play SMOOTHLY at 9fps (stretching them over 5s turned the
	# birth into a slideshow — Advika: "I hate the animation, make it smoother").
	# The five-second length comes from the arch GROWING out of the ground instead
	# (see _erupt_door): a continuous tween, slow at first and then accelerating,
	# which no frame count can stutter.
	sf.set_animation_speed("erupt", 9.0)
	for i in range(1, 13):
		sf.add_frame("erupt", load("res://assets/realms/realm1_door/realm1door%d.png" % i))
	# and the standing portal it becomes: the final frame, held
	sf.add_animation("standing")
	sf.set_animation_loop("standing", true)
	sf.set_animation_speed("standing", 1.0)
	sf.add_frame("standing", load("res://assets/realms/realm1_door/realm1door12.png"))
	door.sprite_frames = sf
	door.animation = "erupt"
	door.scale = Vector2(DOOR_SCALE, DOOR_SCALE)
	door.position = DOOR_POS
	door.z_index = 7                          # in front of platforms (z5), behind hero (z10)
	# a touch dimmed + cooled so the bright portal settles into the dark cave
	door.modulate = Color(0.86, 0.82, 0.92)
	door.visible = false          # there is no door until the ground gives one up
	add_child(door)
	_door = door
	# NOTE: completion is driven by the GROWTH tween, not by animation_finished —
	# the frames finish in 1.3s while the arch is still climbing for another 3.7s,
	# and hooking the signal made the [Y] prompt appear over a half-born door.

	# GLOW BEHIND — like the tarot card's halo. A big soft radial that BRIDGES the two
	# realms' palettes: warm R1 gold at the core melting out to R2 violet at the rim.
	# The aura is deliberately NOT a child of the door: parented to the door it
	# scaled WITH the growth, so the light expanded as one clean circle and read as
	# machinery (Advika 2026-07-26: "the aura just expanded like a circle expanding,
	# it looks too controlled"). It lives in the level instead, and each patch of it
	# arrives on its OWN delay during the birth, at its own size, in its own place.
	# See _door_aura(), fired from _erupt_door().

	# purple portal light washing onto the surrounding warm rock (R2 reaching into R1);
	# dark until the door is revealed.
	var light := PointLight2D.new()
	light.color = DOOR_PURPLE
	light.energy = 0.0
	light.texture = _radial_light_tex()
	light.texture_scale = 3.0
	door.add_child(light)
	_door_light = light

	# (The old levitation bob is gone: a portal that tore itself OUT OF THE GROUND
	# must not float. It stands where it broke through.)
	_door_window(door)

	# TransitionTrigger: senses Curiosity (layer 1) standing in the opening. Monitoring
	# stays OFF until the portal has finished erupting — no entering a half-born door.
	var trigger := Area2D.new()
	trigger.name = "TransitionTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.monitoring = false
	var tcs := CollisionShape2D.new()
	var trect := RectangleShape2D.new()
	trect.size = Vector2(150.0, 340.0)        # local (pre-scale) — covers the opening
	tcs.shape = trect
	tcs.position = Vector2(0.0, 40.0)
	trigger.add_child(tcs)
	door.add_child(trigger)
	_door_trigger = trigger

	# the [Y] prompt, in world space over the arch — invisible until it stands.
	# Cinzel with letter spacing: the game's own carved-serif voice (the tarot card's
	# titles), not a system Georgia (Advika 2026-07-26: "the press y font is
	# completely wrong").
	# Advika picked the tarot card's own prompt voice: EB Garamond, lowercase, dim
	# cream — the same line that reads "click or press any key to begin".
	var prompt := Label.new()
	prompt.text = "Press Y to enter"
	prompt.add_theme_font_override("font", load("res://assets/fonts/eb_garamond.ttf"))
	# EXACTLY the card's prompt: EB Garamond at 20 (the card draws 18 in a layer that
	# isn't zoomed; the level camera sits at 1.05) in CREAM_DIM — same weight, same
	# quiet. No outline: the card's has none, and that was half of what read wrong.
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color("EAE6DA", 0.55))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(360.0, 44.0)
	prompt.position = DOOR_POS + Vector2(-180.0, -300.0)
	prompt.z_index = 11
	prompt.modulate.a = 0.0
	add_child(prompt)
	_door_prompt = prompt

	# The eruption is EARNED: the ground gives the portal up once every jade is
	# gathered and she is near enough to see it happen (see _on_jade_collected and
	# _process); landing on the last platform fires it too. DOOR_REVEAL=1 arms it
	# without the jade, for screenshots and for testing the end of the level.
	if OS.get_environment("DOOR_REVEAL") != "":
		_door_armed = true


## An Area2D lying across the LAST platform in the level — landing on it is what
## calls the portal up out of the ground. It rides the platform (it is a child of
## the assembly), so a moving last platform carries its own trigger.
func _arm_door_trigger() -> void:
	if _plats.is_empty():
		return
	var last: Dictionary = _plats[0]
	for p: Dictionary in _plats:
		if p.pos.x > last.pos.x:
			last = p
	var meta: Array = PLAT_META[last.pname]
	var area := Area2D.new()
	area.name = "DoorCueTrigger"
	area.collision_layer = 0
	area.collision_mask = 1                # Curiosity's layer
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(float(meta[2]) - float(meta[1]), 150.0)
	cs.shape = r
	# sits ON the platform: the box straddles the rim so a landing registers
	cs.position = Vector2((float(meta[1]) + float(meta[2])) * 0.5, float(meta[0]) - 55.0)
	area.add_child(cs)
	last.node.add_child(area)
	area.body_entered.connect(_on_final_platform_reached)


## She landed on the last platform. If the realm has been emptied of jade, the
## ground tears open and the portal is born; otherwise nothing stirs yet.
func _on_final_platform_reached(body: Node2D) -> void:
	if body != _player or _door_revealed or _door == null:
		return
	if _jade_total > 0 and _jade_got < _jade_total \
			and OS.get_environment("DOOR_REVEAL") == "":
		return                              # the jade is the price; the card says so
	_erupt_door()


## The portal tears itself out of the ground: the art plays ONCE, the light comes up
## with it, and it holds on its final frame as the standing door.
const DOOR_BIRTH := 5.0        # seconds for the ground to give the arch up
const DOOR_CONTACT := 191.5    # px from the art's centre down to its contact row

func _erupt_door() -> void:
	if _door_revealed or _door == null:
		return
	_door_revealed = true
	_door.visible = true
	_door.modulate.a = 0.0
	_door.frame = 0
	_door.play("erupt")
	# it CLIMBS out: scaled from a seam in the floor to full height over DOOR_BIRTH,
	# easing IN so it strains at first and then comes fast — and always rooted, since
	# the growth keeps its contact row pinned to the floor line.
	_grow_door(0.18)
	var g := create_tween()
	g.tween_method(_grow_door, 0.18, 1.0, DOOR_BIRTH) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	g.tween_callback(_on_door_erupted)
	# the ground answers: shakes staged across the birth, rubble at the moment it tears
	_quake_sequence()
	_door_aura()
	if _door_light != null:
		var t := create_tween()
		t.tween_property(_door_light, "energy", 0.9, DOOR_BIRTH * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## End-to-end proof that the door connects the realms: she is placed in the arch,
## the portal is armed and erupts, and once it STANDS a real "interact" press is
## injected — so the level's own [Y] handler, its overlap test and the handover to
## QuoteTransition all run exactly as they do under a player's hands.
func _door_press_probe() -> void:
	await get_tree().create_timer(0.3).timeout
	if _player == null or not is_instance_valid(_player):
		return
	_player.global_position = Vector2(DOOR_POS.x, FLOOR_TOP - 60.0)
	_door_armed = true
	print("PROBE: in the arch, waiting for the portal")
	while not _door_ready:
		await get_tree().create_timer(0.2).timeout
	print("PROBE: portal stands — overlap=",
			_door_trigger.get_overlapping_bodies().has(_player), " pressing Y")
	await get_tree().create_timer(0.6).timeout
	Input.action_press("interact")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("interact")


## The light bleeding out of the tear — in WORLD space, not on the door, so it never
## scales with the growth. Sixteen patches, each with its own delay across the birth,
## its own size, hue and place, each drifting and breathing on its own clock. Nothing
## here is centred on the arch and nothing arrives at the same moment, so the aura
## spreads like something leaking rather than a circle being inflated.
func _door_aura() -> void:
	for n in _door_aura_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_door_aura_nodes.clear()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# THE CARD'S HUE (Advika 2026-07-26: "I want the hue to mirror that of the card's
	# hue, that's the end goal") — the tarot's cream core melting to its warm gold,
	# not the violet/rose of the first pass. The portal's own rim light stays violet;
	# it is the LIGHT IN THE AIR that now belongs to the card's palette.
	var gtex := _card_glow_tex()
	var hues: Array[Color] = [
		Color("EAE6DA"),              # the card's cream
		Color("E8C88A"),              # the quote card's gold
		Color(1.00, 0.84, 0.52),      # warm gold, the card's lit lines
		Color(0.92, 0.89, 0.82),      # moon-cream, the card's own halo
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var root := Vector2(DOOR_POS.x, FLOOR_TOP - 150.0)
	for i in range(16):
		var glow := Sprite2D.new()
		glow.texture = gtex
		var sx: float = rng.randf_range(0.4, 1.7)
		var sy: float = sx * rng.randf_range(0.40, 1.6)
		glow.rotation = rng.randf_range(-1.4, 1.4)
		var px: float = root.x + rng.randf_range(-300.0, 300.0)
		var py: float = root.y + rng.randf_range(-240.0, 210.0)
		glow.position = Vector2(px, py)
		var c: Color = hues[rng.randi() % hues.size()]
		var target_a: float = rng.randf_range(0.10, 0.38)
		c.a = 0.0
		glow.modulate = c
		glow.scale = Vector2(sx, sy) * rng.randf_range(0.2, 0.5)
		glow.z_index = 6                       # behind the door art (z7), over the rock
		glow.material = mat
		add_child(glow)
		_door_aura_nodes.append(glow)
		# it arrives when it arrives — spread right across the 5s birth
		var t := create_tween()
		t.tween_interval(rng.randf_range(0.0, DOOR_BIRTH * 0.8))
		t.tween_property(glow, "modulate:a", target_a, rng.randf_range(0.5, 1.6)) \
				.set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(glow, "scale", Vector2(sx, sy),
				rng.randf_range(0.8, 2.4)).set_trans(Tween.TRANS_SINE)
		# ...and then never sits still
		var per: float = rng.randf_range(2.6, 6.4)
		var wander := create_tween().set_loops()
		wander.tween_property(glow, "position",
				Vector2(px + rng.randf_range(-45.0, 45.0),
					py + rng.randf_range(-38.0, 38.0)), per) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wander.tween_property(glow, "position", Vector2(px, py), per) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## One step of the birth: `f` is 0..1 of full size. The arch scales about its BASE
## (its contact row stays on FLOOR_TOP), so it rises out of the floor rather than
## inflating in mid-air.
func _grow_door(f: float) -> void:
	if _door == null:
		return
	var s: float = DOOR_SCALE * f
	_door.scale = Vector2(s, s)
	_door.position = Vector2(DOOR_POS.x, FLOOR_TOP - DOOR_CONTACT * s)
	_door.modulate.a = clampf(f * 2.2, 0.0, 1.0)


func _quake_sequence() -> void:
	_shake_camera(1.4, 10.0)                       # the first strain
	await get_tree().create_timer(1.5).timeout
	if _door == null:
		return
	_shake_camera(1.9, 30.0)                       # the ground gives way
	_ground_rupture()
	await get_tree().create_timer(1.8).timeout
	_shake_camera(1.3, 15.0)                       # the arch heaving up
	await get_tree().create_timer(1.4).timeout
	_shake_camera(0.9, 6.0)                        # settling


## The rupture frames kick the camera HARD (Advika: "make the camera shake violently
## when the door spawns") — a long, heavy rumble through the tearing frames, riding
## on the camera's offset so it never fights the level's hand-driven position.


## The floor tearing open: chips of cave rock thrown up out of the seam, and a low
## band of rubble left heaped around the base afterwards, so the portal reads as
## something that RIPPED through the ground rather than something placed on it.
func _ground_rupture() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8801
	var base := Vector2(DOOR_POS.x, FLOOR_TOP - 6.0)
	# thrown chips
	for i in range(26):
		var chip := Polygon2D.new()
		var r: float = rng.randf_range(2.5, 8.0)
		var pts := PackedVector2Array()
		for a in range(5):
			var ang: float = TAU * float(a) / 5.0 + rng.randf_range(-0.3, 0.3)
			pts.append(Vector2(cos(ang), sin(ang)) * r * rng.randf_range(0.6, 1.3))
		chip.polygon = pts
		chip.color = Color(0.24, 0.19, 0.14) * rng.randf_range(0.7, 1.3)
		chip.color.a = 1.0
		chip.position = base + Vector2(rng.randf_range(-120.0, 120.0), 0.0)
		chip.z_index = 9
		add_child(chip)
		var up: float = rng.randf_range(120.0, 320.0)
		var side: float = rng.randf_range(-190.0, 190.0)
		var life: float = rng.randf_range(0.7, 1.4)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(chip, "position",
				chip.position + Vector2(side, -up), life * 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(chip, "rotation", rng.randf_range(-6.0, 6.0), life)
		t.chain().tween_property(chip, "position",
				chip.position + Vector2(side * 1.5, 10.0), life * 0.55) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_property(chip, "modulate:a", 0.0, 0.5)
		t.chain().tween_callback(chip.queue_free)
	# the heap it leaves behind — real cave rock, sunk into the floor line
	var pool: Array[String] = ["combo_05.png", "combo_00.png", "bigrock_02.png",
			"combo_08.png", "bigrock_08.png"]
	for i in range(7):
		var tex := _tex(CUT, pool[i % pool.size()])
		var h: float = rng.randf_range(70.0, 130.0)
		var sc: float = h / float(tex.get_height())
		var rock := Sprite2D.new()
		rock.texture = tex
		rock.scale = Vector2(-sc if i % 2 == 0 else sc, sc)
		rock.position = base + Vector2(rng.randf_range(-160.0, 160.0),
				rng.randf_range(-6.0, 16.0))
		rock.material = _floor_mat()
		rock.z_index = 9
		rock.modulate.a = 0.0
		add_child(rock)
		var rt := create_tween()
		rt.tween_interval(rng.randf_range(0.0, 0.5))
		rt.tween_property(rock, "modulate:a", 1.0, 0.5)


func _shake_camera(dur: float, amount: float) -> void:
	if _cam == null:
		return
	var t := create_tween()
	var steps := int(dur / 0.03)
	for i in range(steps):
		var fade: float = 1.0 - float(i) / float(maxi(steps, 1))
		t.tween_property(_cam, "offset", Vector2(
				randf_range(-amount, amount) * fade,
				randf_range(-amount, amount) * fade), 0.03)
	t.tween_property(_cam, "offset", Vector2.ZERO, 0.06)


## The portal has finished being born: hold the last frame, let it breathe, and only
## NOW does the prompt appear and [Y] mean anything.
func _on_door_erupted() -> void:
	if _door == null or _door_ready:
		return
	_grow_door(1.0)                 # exactly full size, exactly on the floor line
	_door.play("standing")
	_door_ready = true
	if _door_trigger != null:
		_door_trigger.monitoring = true
	if _door_prompt != null:
		var t := create_tween()
		t.tween_property(_door_prompt, "modulate:a", 1.0, 0.8)
	_start_door_flicker()


## Once revealed, the portal light breathes with the mist (±0.12 energy, ~2.2s period).
func _start_door_flicker() -> void:
	if _door_light == null:
		return
	var flick := create_tween().set_loops()
	flick.tween_property(_door_light, "energy", 0.9 + 0.12, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flick.tween_property(_door_light, "energy", 0.9 - 0.12, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## [Y] in the standing portal's mouth. Dead until the eruption has finished — there
## is no prompt and no input before that.
func _unhandled_input(event: InputEvent) -> void:
	if not _door_ready or _door_trigger == null:
		return
	if not event.is_action_pressed("interact"):
		return
	if not _door_trigger.get_overlapping_bodies().has(_player):
		return
	get_viewport().set_input_as_handled()
	_on_realm2_door_entered(_player)


func _on_realm2_door_entered(_body: Node2D) -> void:
	if _leaving:
		return
	_leaving = true
	# Hand over to the quote card. It goes on the TREE ROOT, not on this level:
	# change_scene_to_file frees the running scene, so a card parented here died
	# mid-transition and the black never lifted.
	get_tree().root.add_child(QuoteTransition.new())


## A two-tone radial halo for BEHIND the door — warm R1 gold core melting to R2 violet
## at the rim, the two realms' palettes meeting (the door as a bridge). Additive-blended
## where it's used, so it reads as light, not paint.
func _door_glow_tex() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.72, 0.36, 0.60))   # warm gold core (Realm 1)
	grad.set_color(1, Color(0.46, 0.22, 0.56, 0.0))   # violet rim, fading out (Realm 2)
	grad.add_point(0.5, Color(0.74, 0.40, 0.60, 0.30))  # rose midway — the blend
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	return gtex


## The tarot card's own light, as a radial: cream at the core, its warm gold at the
## middle, gone at the rim. Used for the door's scattered aura so the air around the
## portal carries the card's palette.
func _card_glow_tex() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color("EAE6DA", 0.55))          # cream core
	grad.set_color(1, Color(0.90, 0.72, 0.40, 0.0))   # warm gold, fading out
	grad.add_point(0.45, Color("E8C88A", 0.28))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	return gtex


## A soft radial falloff texture for the portal's PointLight2D (built in code so the
## door carries no external light-gradient asset dependency).
func _radial_light_tex() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	return gtex


## Solid ground across the whole level (collision layer 1 — floor/world), its top
## aligned to the painted ground surface so Curiosity and the golems stand on it.
func _add_static_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(13100.0, 600.0)
	cs.shape = r
	cs.position = Vector2(3850.0, FLOOR_TOP + 300.0)   # top edge at FLOOR_TOP
	body.add_child(cs)
	add_child(body)


## A solid roof so Curiosity can't jump up through the ceiling into the void. Its
## bottom sits at CEILING_Y — above the top platforms + her height, so she never
## squishes standing on them, and roughly at the (raised) visual ceiling underside.
func _add_ceiling() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(13100.0, 400.0)
	cs.shape = r
	cs.position = Vector2(3850.0, CEILING_Y - 200.0)   # bottom edge at CEILING_Y
	body.add_child(cs)
	add_child(body)


## Invisible end walls just inside the cliffs so Curiosity can't leave the level.
func _add_end_walls() -> void:
	for wx in [CLIFF_L - 30.0, CLIFF_R + 30.0]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(80.0, 2400.0)
		cs.shape = r
		cs.position = Vector2(wx, -400.0)
		body.add_child(cs)
		add_child(body)


## A golem: patrols, wakes and fires a ball when Curiosity nears. Recoloured to the
## dark cave-rock shade. `on_platform` golems stand on the platforms (mask 3) and
## turn at the ledges instead of walking off.
func _spawn_golem(pos: Vector2, on_platform: bool) -> void:
	var g: CharacterBody2D = GOLEM_SCENE.instantiate()
	g.ball_scene = GOLEM_BALL
	g.scale = Vector2(GOLEM_SCALE, GOLEM_SCALE)
	g.detect_range = 520.0
	g.z_index = 8
	g.position = pos
	if on_platform:
		g.collision_mask = 3          # floor + platforms (bit 1 + bit 2)
		g.patrol_ledge_only = true
		g.patrol_range = 700.0
	add_child(g)
	g.get_node("Visual").material = _recolor_mat(GOLEM_LO, GOLEM_HI, 1.0)
	if g.has_method("set_home"):
		g.set_home(pos.x)
	_golems.append(g)


## Curiosity died: close an eye.
## Advika 2026-07-26 — one eye: she comes back RIGHT WHERE SHE FELL (on the ground
## under that spot, not at the level start), keeping her jade and the golems as they
## are, with a mercy invulnerability. The LAST eye: a full reset — jade back to zero,
## every golem home, the card again, the track from its first bar.
func _on_player_died() -> void:
	if _lives_hud == null:
		return
	var remaining: int = _lives_hud.lose_eye()
	if remaining > 0:
		# straight down onto the floor at the x she died on, inside the level bounds
		var back_x: float = clampf(_player.global_position.x,
				CLIFF_L + 220.0, CLIFF_R - 220.0)
		_player.global_position = Vector2(back_x, FLOOR_TOP - 60.0)
		_player.velocity = Vector2.ZERO
		_player.refill_health()
		_player.grant_invuln(1.6)
	else:
		# stop the ambient so the reloaded level starts the track over rather than
		# letting AudioManager no-op on a re-request of the same one
		AudioManager.stop_ambient()
		get_tree().reload_current_scene()


## STEP 6: a plant playing its pack animation (the wind lives in the frames).
## Delegates to Realm1Bg.make_plant so the per-instance random frame/speed/
## flip lives in exactly one place. `sc` stays the old scale factor (target
## height = sc * native frame height); the passed `fh` is ignored — flip is
## now randomized per instance. `tint` defaults to the platform-lip colour.
## `pos` is the rock SURFACE the plant roots into. Every plant grows OUT of a
## socket rock drawn IN FRONT of its base (z 2 over the plant's z 1), so the base
## is hidden and it reads as INSIDE the rock — never a sprig on a bare lip.
func _plant(parent: Node2D, key: String, pos: Vector2, sc: float,
		_fh: bool, tint := Color("574a2e")) -> void:
	var seq: String = KEY2SEQ.get(key, "grass2")
	var native_h: float = Realm1Bg.VEG_SPEC[seq][2]
	var height: float = sc * native_h
	# the plant, base sunk ~12px into the surface (measured base fraction)
	parent.add_child(Realm1Bg.make_plant(seq, pos, height, tint, 1,
			_veg_rng, false, false, true, 12.0))
	# the socket rock the plant emerges from — sits over the base, bulk below
	var rtex := _tex(CUT, ["combo_08.png", "combo_10.png", "rock_08.png",
			"rock_10.png", "rock_03.png"][_veg_rng.randi() % 5])
	var rsc := (height * _veg_rng.randf_range(0.8, 1.2)) / float(rtex.get_width())
	var rock := Sprite2D.new()
	rock.texture = rtex
	rock.centered = true
	rock.scale = Vector2(-rsc if _veg_rng.randf() < 0.5 else rsc, rsc)
	rock.position = Vector2(pos.x + _veg_rng.randf_range(-5.0, 5.0),
			pos.y + rtex.get_height() * rsc * 0.5 - height * 0.14)
	rock.material = _floor_mat()
	rock.z_index = 2
	parent.add_child(rock)


## the FLOOR (cave_ref_04's bottom grammar): a solid near-black ground
## band, knobbly rock lip, washed mounds sitting ON it, dark piles, sparse
## black spikes, and the plants growing FROM the line — spike forest rises
## behind it
func _ground() -> void:
	var g := _assembly(Vector2.ZERO)
	g.z_index = 6
	var base := ColorRect.new()
	base.position = Vector2(-2700, 470)
	base.size = Vector2(13100, 1100)   # deep enough that no window sees under it
	base.color = Color(0.020, 0.016, 0.013)
	g.add_child(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# the ref's COBBLE ROW: pebble pieces shoulder to shoulder along the
	# line, tops catching the fog light faintly
	var x := -2600.0
	var i := 0
	while x < 10200.0:
		var piece: String = ["floor_22.png", "floor_23.png"][i % 2]
		var sc := rng.randf_range(0.50, 0.58)
		var tex := _tex(CUT, piece)
		var s0 := Sprite2D.new()
		s0.texture = tex
		s0.position = Vector2(x, 486.0 - tex.get_height() * sc * 0.30
				+ rng.randf_range(-4.0, 4.0))
		s0.scale = Vector2(-sc if rng.randf() < 0.5 else sc, sc)
		s0.material = _floor_mat()
		s0.z_index = 1
		g.add_child(s0)
		x += tex.get_width() * sc * 0.80
		i += 1
	# STEP 6 (Advika 2026-07-25): a DENSE overlapping mound ridge so the floor
	# reads as ONE solid ragged mass — no bright pockets peeking between lumps.
	# Lit by the floor ramp so the rock texture reads instead of flat black.
	var mound_pool: Array[String] = ["combo_08.png", "combo_10.png",
			"combo_00.png", "combo_05.png", "bigrock_02.png", "bigrock_08.png"]
	var mx := -2800.0
	var mi := 0
	while mx < 10400.0:
		var mtex := _tex(CUT, mound_pool[mi % mound_pool.size()])
		var mh := rng.randf_range(160.0, 260.0)
		var msc := mh / float(mtex.get_height())
		var mnd := Sprite2D.new()
		mnd.texture = mtex
		mnd.scale = Vector2(-msc if rng.randf() < 0.5 else msc, msc)
		mnd.position = Vector2(mx + rng.randf_range(-18.0, 18.0),
				494.0 - mh * rng.randf_range(0.30, 0.46))
		mnd.material = _floor_mat()
		mnd.z_index = 0
		g.add_child(mnd)
		mx += mtex.get_width() * msc * rng.randf_range(0.40, 0.56)  # heavy overlap
		mi += 1
	# DEPTH BELOW THE WALK LINE (Advika 2026-07-26: "even the floor is inconsistent
	# and weird, lets add more rocks"). Under the mound ridge sat a flat black slab —
	# on a window taller than 16:9 (stretch aspect is "expand", so tall windows reveal
	# MORE world) it filled the bottom of the screen as a dead bar. Three more rows of
	# real rock, each deeper, bigger and dimmer, carry the floor off the bottom of any
	# window instead. Rows go BEHIND the ridge (negative z within the assembly).
	for row in range(3):
		var row_y: float = 600.0 + float(row) * 150.0
		var row_dim := Color(1, 1, 1) * (0.74 - 0.16 * float(row))
		row_dim.a = 1.0
		var rx := -2800.0
		var ri := row
		while rx < 10400.0:
			var rtex := _tex(CUT, mound_pool[ri % mound_pool.size()])
			var rh2 := rng.randf_range(200.0, 330.0) * (1.0 + 0.15 * float(row))
			var rsc := rh2 / float(rtex.get_height())
			var rock := Sprite2D.new()
			rock.texture = rtex
			rock.scale = Vector2(-rsc if rng.randf() < 0.5 else rsc, rsc)
			rock.position = Vector2(rx + rng.randf_range(-24.0, 24.0),
					row_y + rng.randf_range(-26.0, 26.0))
			rock.material = _floor_mat()
			rock.modulate = row_dim          # deeper rows sink into the dark
			rock.z_index = -1 - row
			g.add_child(rock)
			rx += rtex.get_width() * rsc * rng.randf_range(0.42, 0.60)
			ri += 1
	# STEP 6 (Advika 2026-07-25): every floor plant grows from its OWN foot-
	# rock and sinks its base into the floor mass — NOTHING floats. z-order:
	# foot-rock (2) then plant (3) so the plant reads as rising out of the rock.
	# STEP 6 (denser — Advika 2026-07-25 wants MORE vegetation, all grounded):
	# a plant roughly every ~350px along the floor, mixed sequences incl. the
	# tall grass3/grass4 blades as accents. [key, x, scale, flip(ignored)]
	for pl: Array in [["PlantSmall_00000.png", -1320.0, 0.30, false],
			["grass4", -980.0, 0.17, false],
			["Grass2_00000.png", -550.0, 0.28, false],
			["PlantSmall_00000.png", -180.0, 0.27, true],
			["GroupPlants_00000.png", 220.0, 0.30, false],
			["Grass2_00000.png", 480.0, 0.26, true],
			["grass3", 780.0, 0.18, false],
			["GroupPlants_00000.png", 960.0, 0.34, false],
			["PlantSmall_00000.png", 1300.0, 0.28, false],
			["Grass2_00000.png", 1680.0, 0.26, true],
			["grass4", 2050.0, 0.16, true],
			["PlantSmall_00000.png", 2350.0, 0.29, false],
			["Grass2_00000.png", 2800.0, 0.28, false],
			["PlantSmall_00000.png", 3180.0, 0.27, true],
			["grass3", 3500.0, 0.19, false],
			["GroupPlants_00000.png", 3900.0, 0.31, true],
			["GroupPlants_00000.png", 4300.0, 0.32, true],
			["Grass2_00000.png", 4680.0, 0.27, false],
			["Grass2_00000.png", 5000.0, 0.26, true],
			["grass4", 5380.0, 0.17, false],
			["PlantSmall_00000.png", 5700.0, 0.29, false],
			["Grass2_00000.png", 6100.0, 0.27, true],
			["Grass2_00000.png", 6600.0, 0.27, false],
			["grass3", 7000.0, 0.18, true],
			["PlantSmall_00000.png", 7400.0, 0.28, true],
			["GroupPlants_00000.png", 7850.0, 0.30, false],
			["GroupPlants_00000.png", 8300.0, 0.31, false],
			["grass4", 8700.0, 0.17, false],
			["Grass2_00000.png", 9200.0, 0.28, true]]:
		# _plant now adds the socket rock + roots the base uniformly (floor y 480)
		_plant(g, pl[0], Vector2(pl[1], 480.0), pl[2], pl[3], Color("463a22"))
	# the ref's one lit tuft — a single grass by the light (floor colour), rooted
	var lit := Realm1Bg.make_plant("grass2", Vector2(-680, 480),
			0.30 * Realm1Bg.VEG_SPEC["grass2"][2], Color("463a22"), 4, _veg_rng,
			false, false, true, 12.0)
	lit.play("default")
	g.add_child(lit)


func _floor_mat() -> ShaderMaterial:
	if _floor_ramp == null:
		_floor_ramp = ShaderMaterial.new()
		_floor_ramp.shader = load("res://shaders/plat_ramp.gdshader")
		_floor_ramp.set_shader_parameter("cap", Color(0.175, 0.135, 0.088))
		_floor_ramp.set_shader_parameter("gamma_v", 1.3)
	return _floor_ramp


## The root of a platform. MOVERS are an AnimatableBody2D so that tweening THIS
## node's own position (in the physics step) makes sync_to_physics generate the
## carry-velocity that sweeps Curiosity along — the old plain-Node2D root left the
## collider a child that never moved in its own frame, so riders were never carried.
func _assembly(pos: Vector2, is_mover: bool = false) -> Node2D:
	var a: Node2D
	if is_mover:
		var ab := AnimatableBody2D.new()
		ab.sync_to_physics = true
		ab.collision_layer = 2
		ab.collision_mask = 0
		a = ab
	else:
		a = Node2D.new()
	a.position = pos
	a.z_index = 5
	add_child(a)
	return a


func _shot(path: String) -> void:
	var delay := 1.0
	if OS.get_environment("PLAT_SHOT_DELAY") != "":
		delay = float(OS.get_environment("PLAT_SHOT_DELAY"))
	await get_tree().create_timer(delay).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
