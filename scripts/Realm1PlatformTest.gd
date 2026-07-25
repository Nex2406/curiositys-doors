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
const TAROT_DELAY := 3.5    # Advika: card lands ~3-4s after entering the realm
const CURIOSITY_SCALE := 0.3    # Advika: bigger — she read too tiny in this level
const CURIOSITY_JUMP := -500.0           # Advika: higher jump for this level (base -356)
const GOLEM_SCALE := 0.62                # Advika: bigger golems
const FLOOR_TOP := 470.0                 # world y of the walkable ground surface
const GOLEM_SPAWN_X := [1100.0, 3500.0, 6300.0, 8600.0]
const MAX_GOLEMS := 12
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
const CLIFF_R := 9720.0

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
const PLAT_META := {
	"wall_ledge": [-145.0, 20.0, 390.0, 160.0, 400.0],
	"small_a": [-50.0, -95.0, 95.0, 75.0, 240.0],
	"small_b": [-42.0, -100.0, 85.0, 55.0, 240.0],
	"medium_a": [-72.0, -140.0, 140.0, 95.0, 340.0],
	"medium_b": [-64.0, -160.0, 80.0, 110.0, 300.0],
	"large_b": [-117.0, -150.0, 150.0, 170.0, 340.0],
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


func _ready() -> void:
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
	_fused("large_b", Vector2(2700, 180), Vector2(250, 220), 0.10, [
			["Grass2_00000.png", 84.0, -108.0, 0.2, true]], "bob", true)
	_fused("small_b", Vector2(3100, 20), Vector2(170, 150), 0.10, [], "side")
	_fused("medium_a", Vector2(3600, -120), Vector2(250, 170), 0.10, [
			["Grass2_00000.png", 96.0, -60.0, 0.22, false]])
	_fused("small_a", Vector2(3950, 60), Vector2(180, 150), 0.10, [], "updown")
	_fused("medium_b", Vector2(4300, 260), Vector2(240, 190), 0.10, [], "static")
	_fused("small_b", Vector2(4800, 80), Vector2(170, 150), 0.10, [], "side")
	_fused("medium_a", Vector2(5250, -100), Vector2(250, 170), 0.10, [])
	_fused("small_a", Vector2(5600, 120), Vector2(180, 150), 0.10, [], "updown")
	_fused("large_b", Vector2(6050, 280), Vector2(250, 220), 0.10, [], "bob", true)
	_fused("small_b", Vector2(6500, 60), Vector2(170, 150), 0.10, [], "side")
	_fused("small_a", Vector2(6900, -140), Vector2(180, 150), 0.10, [])
	_fused("medium_b", Vector2(7250, 40), Vector2(240, 190), 0.10, [], "static")
	_fused("medium_a", Vector2(7700, 220), Vector2(250, 170), 0.10, [
			["Grass2_00000.png", 96.0, -60.0, 0.22, false]])
	_fused("small_a", Vector2(8150, 0), Vector2(180, 150), 0.10, [], "updown")
	_fused("small_b", Vector2(8600, -120), Vector2(170, 150), 0.10, [], "side")
	_fused("medium_b", Vector2(9000, 120), Vector2(240, 190), 0.10, [], "static")
	_fused("large_b", Vector2(9400, 260), Vector2(250, 220), 0.10, [
			["Grass2_00000.png", 84.0, -108.0, 0.2, true]], "bob", true)
	# extra rest-ledges, relocated OUT of the congested 5000-5600 cluster into
	# clear gaps at a separated height so nothing overlaps (Advika: space them out)
	_fused("small_b", Vector2(2050, 220), Vector2(170, 150), 0.10, [])
	_fused("small_a", Vector2(4500, -110), Vector2(180, 150), 0.10, [])
	# right level-end wall: the left wall's mirror, world-space (step 6b)
	var wr := Sprite2D.new()
	wr.texture = _tex(SOFT, "plat_wall_ledge.png")
	wr.centered = false
	wr.scale = Vector2(-1, 1)
	wr.position = Vector2(9980, -800)
	wr.material = _plat_ramp
	wr.z_index = 5
	add_child(wr)
	var wall_back_r := ColorRect.new()
	wall_back_r.position = Vector2(9720, -1600)
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
	if OS.get_environment("PLAT_NOPLAY") == "":
		_setup_play()
	if OS.get_environment("PLAT_CAM_X") != "":
		_cam.position.x = float(OS.get_environment("PLAT_CAM_X"))
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
	const CEIL_CLEAR := -250.0
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
	var target_x: float
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
	var a := _assembly(pos)
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
		_add_plat_collision(a, pname, pname != "large_b")
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
func _add_plat_collision(a: Node2D, pname: String, is_mover: bool) -> void:
	var m: Array = PLAT_META[pname]
	var top: float = float(m[0])
	var x0: float = float(m[1])
	var x1: float = float(m[2])
	var body: PhysicsBody2D = AnimatableBody2D.new() if is_mover else StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	if is_mover:
		(body as AnimatableBody2D).sync_to_physics = true
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(x1 - x0, 46.0)
	cs.shape = r
	cs.position = Vector2((x0 + x1) * 0.5, top + 23.0)   # box TOP sits at the rim
	body.add_child(cs)
	a.add_child(body)


## Spawn Curiosity, the ground/wall colliders, and the golems, then wire death.
func _setup_play() -> void:
	_add_static_floor()
	_add_end_walls()
	_player = CURIOSITY.instantiate()
	_player.scale = Vector2(CURIOSITY_SCALE, CURIOSITY_SCALE)
	_player.position = _spawn_pos
	_player.z_index = 10        # in front of ground (z6) / platforms (z5)
	_player.jump_velocity = CURIOSITY_JUMP
	_player.max_air_jumps = 1   # Advika: double jump in this level
	add_child(_player)
	var pcam := _player.get_node_or_null("Camera")
	if pcam != null:
		pcam.enabled = false        # the level's clamped camera drives the view
	_player.died.connect(_on_player_died)
	# (Advika: golems removed for now — she's generating new golem art. Re-enable via
	# _spawn_golem when they land.)
	# (Card disabled: it will be rebuilt from Realm 2's painted TarotReading card as a
	# template — recoloured, with a jade piece in place of the void moth and the new
	# golem in place of the wizard. Wired once the golem art arrives.)


## Show the instructions tarot — the code-drawn card, themed to Realm 1's warm cave
## palette (deep-rock face, gold frame) with Realm-1 content (jade + golems), NOT
## R2's violet wizard/moth card. Pauses the game; any input dismisses it.
func _show_tarot() -> void:
	if not is_inside_tree():
		return
	var card := TarotCard.new()
	card.numeral = "I"
	card.card_title = "THE HOLLOW"
	card.portrait = _tex(SOFT, "plat_medium_a.png")   # a cave-rock illustration
	card.verses = [
		"gather the jade",
		"leap the drifting stones",
		"double-jump — press jump twice",
	]
	# warm cave theming (deep rock face + warm dim; the gold frame already fits R1)
	card.card_face = Color(0.14, 0.09, 0.05)
	card.overlay_color = Color(0.03, 0.02, 0.012, 0.84)
	add_child(card)


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


## Curiosity died: close an eye. If lives remain, respawn at the start with a mercy
## invulnerability; if the last eye closed, reload the level.
func _on_player_died() -> void:
	if _lives_hud == null:
		return
	var remaining: int = _lives_hud.lose_eye()
	if remaining > 0:
		_player.global_position = _spawn_pos
		_player.velocity = Vector2.ZERO
		_player.refill_health()
		_player.grant_invuln(1.6)
	else:
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
	base.size = Vector2(13100, 280)
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


func _assembly(pos: Vector2) -> Node2D:
	var a := Node2D.new()
	a.position = pos
	a.z_index = 5
	add_child(a)
	return a


func _shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
