extends Node2D
## REALM 1 — THE CAVE (built to Advika's build spec, 2026-07-19).
## CaveAssetsMaaot is a DECAL PACK, not a tileset: visuals are hand-placed
## region Sprite2Ds (overlapping, layered, zero collision); collision is
## separate invisible rectangles matching the art's silhouette; the LOOK is
## the lighting stack — near-black geometry, olive wash, radial fog core,
## heavy vignette, sparse rim lights, her lantern the warmest thing alive.
## Layout (~6000px, two descents; fear = committing to jumps you can't see
## the end of):
##   A landing -> B widening gaps (180/240/300) -> C chasm mover ->
##   D staggered descent -> E phased vertical movers -> F the dark stretch
##   (lantern-only, movers lit by their own small lights) -> G the door.
## Golems + jades kept from the old realm. R restart, ESC hub.
## R1_SHOT env: screenshot at 1s + quit. R1_SHOT_X / R1_SHOT_Y park the
## hero first. R1_SHOT_CAMY freezes the camera height.

const CAVE := "res://assets/environment/cave/"
const SHEET_PLATFORMS := CAVE + "Cave - Platforms.png"
const SHEET_FLOOR := CAVE + "Cave - Floor.png"
const SHEET_COMBOS := CAVE + "Cave - RockCombinations1.png"
const SHEET_BIGROCKS := CAVE + "Cave - BigRocks1.png"
const SHEET_SMALLROCKS := CAVE + "Cave - SmallRocks.png"

const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const JADE_SCENE := preload("res://scenes/Jade.tscn")
const GOLEM_SCENE := preload("res://scenes/Golem.tscn")
const GOLEM_BALL_SCENE := preload("res://scenes/GolemBall.tscn")
const MOVER := preload("res://scripts/moving_platform.gd")
const HUB_SCENE := "res://scenes/Hub.tscn"
const STARTING_LIVES: int = 3

# ---- region atlas (from the build spec, verified against the sheets) ----
# Platforms.png
const R_COL_SMALL := Rect2(22, 25, 191, 189)
const R_COL_WIDE_HEAD := Rect2(233, 23, 389, 188)
const R_TALL_BLOCK := Rect2(670, 56, 308, 323)
const R_COL_LARGE := Rect2(28, 225, 562, 363)      # hero piece
const R_COL_LARGE_VAR := Rect2(616, 398, 389, 364)
const R_COL_NARROW := Rect2(48, 644, 191, 364)
const R_SLAB_MOVE := Rect2(274, 645, 303, 62)      # thin slab — mover
const R_ROCK_MOUND := Rect2(293, 721, 267, 158)
const R_SLAB_MOVE_W := Rect2(628, 793, 355, 63)    # thin slab wide — mover
const R_LEDGE := Rect2(268, 902, 389, 104)
const R_LEDGE_SMALL := Rect2(722, 889, 191, 104)
# Floor.png
const R_GROUND_XW := Rect2(55, 800, 1467, 161)
const R_GROUND_W := Rect2(67, 1068, 1423, 258)
const R_GROUND_M := Rect2(68, 360, 991, 81)
const R_CEIL_A := Rect2(822, 1655, 791, 307)
const R_CEIL_B := Rect2(15, 1754, 791, 239)
const R_STALACT_A := Rect2(1668, 860, 141, 374)
const R_STALACT_B := Rect2(1867, 859, 124, 378)
const R_LEDGE_FLOOR := Rect2(79, 676, 289, 77)
# RockCombinations1.png
const R_MASS_TALL := Rect2(44, 1234, 574, 597)
const R_MASS_TALL_N := Rect2(701, 1287, 421, 668)
const R_MASS_TALL_N2 := Rect2(1166, 1250, 362, 644)
const R_MASS_WIDE := Rect2(1310, 748, 693, 372)
const R_MASS_WIDE2 := Rect2(27, 71, 573, 342)
const R_MASS_MED := Rect2(989, 77, 470, 357)

# ---- lighting stack values (from the spec, sampled off the references) ----
const MOD_GEO := Color(0.30, 0.30, 0.26)
const MOD_MID := Color(0.22, 0.24, 0.18)
const MOD_FAR := Color(0.14, 0.16, 0.12)
const MOD_FORE := Color(0.03, 0.03, 0.03)
const WASH := Color(0.62, 0.66, 0.42)             # CanvasModulate olive
const RIM_LIGHT := Color(0.722, 0.769, 0.416)     # #B8C46A
const VOID := Color(0.020, 0.024, 0.016)          # #050604 — fills/walls

# ---- layout (beats A..G; y grows downward, upper floor at UP_Y) ----
const UP_Y := 400.0            # sections A..C walk line
const LOW_Y := 1250.0          # sections D-bottom..G walk line
const CEIL_Y := -140.0
const WORLD_L := -350.0
const WORLD_R := 6250.0
const KILL_Y := 1650.0
const SPAWN := Vector2(-100.0, UP_Y - 140.0)
const CURI_SCALE := 0.24

# checkpoints: passing one (grounded) arms it; death respawns at the last
const CHECKPOINTS: Array[Vector2] = [
	Vector2(-100.0, UP_Y - 140.0),      # A spawn
	Vector2(2430.0, UP_Y - 140.0),      # after B's gaps
	Vector2(3400.0, UP_Y - 140.0),      # after C's chasm
	Vector2(3600.0, LOW_Y - 140.0),     # D bottom
	Vector2(4680.0, LOW_Y - 140.0),     # after E
	Vector2(5540.0, LOW_Y - 140.0),     # after F, the door stretch
]

var _curi: CharacterBody2D
var _cam: Camera2D
var _lives: LivesHUD
var _exit_door: Area2D
var _geometry: Node2D
var _par_far: Parallax2D
var _par_mid: Parallax2D
var _par_near: Parallax2D
var _at_exit := false
var _dying := false
var _leaving := false
var _freeze_cam := false
var _checkpoint := SPAWN
var _jade_total := 0
var _jade_got := 0
var _jade_lbl: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(VOID)
	_rng.seed = 20260719
	_build_background()
	_build_parallax()
	_build_geometry()
	_build_movers()
	_build_foreground()
	_build_lighting()
	_build_particles()
	_build_player()
	_build_golems()
	_build_jades()
	_build_exit_door()
	_build_camera()
	_build_ui()
	if OS.get_environment("R1_SHOT") != "":
		_self_screenshot(OS.get_environment("R1_SHOT"))


# ---------- decal helper: a region sprite, pure decoration ----------

func _decal(parent: Node, sheet: String, region: Rect2, pos: Vector2,
		sc := 1.0, fh := false, tint := Color.WHITE, z := 0,
		rot := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(sheet)
	s.region_enabled = true
	s.region_rect = region
	s.position = pos
	s.scale = Vector2(-sc if fh else sc, sc)
	s.modulate = tint
	s.z_index = z
	s.rotation_degrees = rot
	parent.add_child(s)
	return s


## bottom-anchored decal: the region's base sits ON base_y
func _decal_on(parent: Node, sheet: String, region: Rect2, x: float,
		base_y: float, sc := 1.0, fh := false, tint := Color.WHITE,
		z := 0) -> Sprite2D:
	return _decal(parent, sheet, region,
			Vector2(x, base_y - region.size.y * sc * 0.5 + 6.0), sc, fh, tint, z)


func _fill(parent: Node, x0: float, x1: float, y0: float, y1: float,
		z := 0, col := VOID) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0),
			Vector2(x1, y1), Vector2(x0, y1)])
	p.color = col
	p.z_index = z
	parent.add_child(p)


## invisible collision rectangle (the ONLY collision there is)
func _solid(parent: Node, x0: float, x1: float, y0: float, y1: float,
		one_way := false) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, y1 - y0)
	cs.shape = rect
	cs.position = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
	cs.one_way_collision = one_way
	body.add_child(cs)
	parent.add_child(body)


var _glow_tex: GradientTexture2D = null
func _soft_glow() -> GradientTexture2D:
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


# ---------- background: the fog core ----------

func _build_background() -> void:
	var cl := CanvasLayer.new()
	cl.name = "Background"
	cl.layer = -100
	add_child(cl)
	var fog := ColorRect.new()
	fog.name = "FogGradient"
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cave_fog.gdshader")
	fog.material = mat
	cl.add_child(fog)


# ---------- parallax rock masses ----------

func _build_parallax() -> void:
	# FAR (0.25): RockCombinations masses, darkest
	_par_far = Parallax2D.new()
	_par_far.name = "ParallaxFar"
	_par_far.scroll_scale = Vector2(0.25, 0.9)
	add_child(_par_far)
	var far := Node2D.new()
	far.name = "RockMasses"
	# ONE modulate per layer (the spec's value) — never stacked twice
	far.modulate = MOD_FAR
	_par_far.add_child(far)
	var masses: Array[Rect2] = [R_MASS_TALL, R_MASS_TALL_N, R_MASS_WIDE,
			R_MASS_TALL_N2, R_MASS_MED, R_MASS_WIDE2]
	var x := WORLD_L * 0.25 - 300.0
	var i := 0
	# the far band only ever samples ~[cam*0.25] — cover generously
	while x < WORLD_R * 0.25 + 1900.0:
		var r: Array[Rect2] = [masses[i % 6]]
		var sc := _rng.randf_range(0.85, 1.3)
		_decal_on(far, SHEET_COMBOS, r[0], x,
				(UP_Y + 210.0 if x < 900.0 else LOW_Y + 260.0) \
				if _rng.randf() < 0.5 else UP_Y + 210.0,
				sc, i % 2 == 0)
		x += r[0].size.x * sc * _rng.randf_range(0.60, 0.75)
		i += 1
	# MID (0.55): combos + big rocks, a step lighter
	_par_mid = Parallax2D.new()
	_par_mid.name = "ParallaxMid"
	_par_mid.scroll_scale = Vector2(0.55, 0.95)
	add_child(_par_mid)
	var mid := Node2D.new()
	mid.name = "RockMassesMid"
	mid.modulate = MOD_MID
	_par_mid.add_child(mid)
	var mx := WORLD_L * 0.55 - 400.0
	var mi := 0
	while mx < WORLD_R * 0.55 + 2600.0:
		if mi % 3 == 2:
			var br: Rect2 = [Rect2(28, 40, 700, 570), Rect2(1400, 60, 560, 520)][mi % 2]
			_decal_on(mid, SHEET_BIGROCKS, br, mx,
					(UP_Y + 160.0) if mi % 2 == 0 else (LOW_Y + 200.0),
					_rng.randf_range(0.9, 1.2), mi % 2 == 1)
		else:
			var r2: Rect2 = [R_MASS_MED, R_MASS_WIDE, R_MASS_TALL_N2][mi % 3]
			_decal_on(mid, SHEET_COMBOS, r2, mx,
					(UP_Y + 170.0) if mi % 2 == 0 else (LOW_Y + 210.0),
					_rng.randf_range(0.85, 1.25), mi % 2 == 0)
		mx += _rng.randf_range(420.0, 620.0)
		mi += 1


# ---------- level geometry (decals + invisible collision) ----------

func _build_geometry() -> void:
	_geometry = Node2D.new()
	_geometry.name = "LevelGeometry"
	add_child(_geometry)
	var ceiling := Node2D.new()
	ceiling.name = "Ceiling"
	_geometry.add_child(ceiling)
	var ground := Node2D.new()
	ground.name = "Ground"
	_geometry.add_child(ground)
	var columns := Node2D.new()
	columns.name = "Columns"
	_geometry.add_child(columns)
	var coll := Node2D.new()
	coll.name = "Collision"
	_geometry.add_child(coll)

	# == CEILING first (spec rule 4): strips edge to edge, ~100px overlap,
	# stalactites hung below at random x ==
	var cx := WORLD_L - 200.0
	var ci := 0
	while cx < WORLD_R + 400.0:
		var r: Rect2 = R_CEIL_A if ci % 2 == 0 else R_CEIL_B
		var sc := _rng.randf_range(0.9, 1.15)
		_decal(ceiling, SHEET_FLOOR, r,
				Vector2(cx, CEIL_Y + r.size.y * sc * 0.5 - 60.0), sc,
				ci % 3 == 1, MOD_GEO)
		cx += r.size.x * sc - 100.0
		ci += 1
	var sx := WORLD_L + _rng.randf_range(60.0, 200.0)
	while sx < WORLD_R:
		var r2: Rect2 = R_STALACT_A if _rng.randf() < 0.5 else R_STALACT_B
		var sc2 := _rng.randf_range(0.5, 1.0)
		_decal(ceiling, SHEET_FLOOR, r2,
				Vector2(sx, CEIL_Y + 90.0 + r2.size.y * sc2 * 0.5), sc2,
				_rng.randf() < 0.5, MOD_GEO)
		sx += _rng.randf_range(240.0, 520.0)
	_fill(ceiling, WORLD_L - 400.0, WORLD_R + 400.0, CEIL_Y - 1200.0, CEIL_Y - 30.0)
	_solid(coll, WORLD_L, WORLD_R, CEIL_Y - 80.0, CEIL_Y + 10.0)

	# == A — LANDING (0..900): flat, wide; establishes mood ==
	_ground_run(ground, coll, WORLD_L - 80.0, 950.0, UP_Y)
	# boundary wall left
	_fill(_geometry, WORLD_L - 400.0, WORLD_L + 20.0, CEIL_Y, UP_Y + 400.0)
	_solid(coll, WORLD_L - 60.0, WORLD_L + 20.0, CEIL_Y, UP_Y)
	_decal_on(columns, SHEET_BIGROCKS, Rect2(28, 40, 700, 570), WORLD_L + 60.0,
			UP_Y + 60.0, 0.9, false, MOD_GEO)

	# == B — FIRST GAPS (900..2320): three columns, gaps 180/240/300 ==
	_column(columns, coll, 1120.0, 372.0, 0)   # span ~1024..1216
	_column(columns, coll, 1492.0, 348.0, 1)   # gap 180
	_column(columns, coll, 1924.0, 368.0, 2)   # gap 240
	# gap 300 -> the B-exit ledge, then a short shelf into C
	_ground_run(ground, coll, 2320.0, 2650.0, UP_Y)

	# == C — CHASM (2650..3350): the 700px crossing (mover built later) ==
	_ground_run(ground, coll, 3350.0, 3470.0, UP_Y)

	# == D — DESCENT (3470..3950 shaft): staggered ledges, alternating ==
	# shaft walls: the upper world ends here — right wall above, void below
	_fill(_geometry, 3720.0, 3950.0, CEIL_Y, UP_Y - 240.0)
	_solid(coll, 3740.0, 3950.0, CEIL_Y, UP_Y - 260.0)
	for i in 5:
		var lx := 3560.0 if i % 2 == 0 else 3830.0
		var ly := 560.0 + i * 160.0
		_ledge(columns, coll, lx, ly, i % 2 == 1)
	# shaft sides dressed with tall masses so the drop reads as a throat
	_decal_on(columns, SHEET_COMBOS, R_MASS_TALL_N, 3420.0, 1000.0, 0.9,
			false, MOD_GEO)
	_decal_on(columns, SHEET_COMBOS, R_MASS_TALL_N2, 3980.0, 1080.0, 0.95,
			true, MOD_GEO)
	# bottom floor of the descent
	_ground_run(ground, coll, 3380.0, 3950.0, LOW_Y)
	# left wall under the upper floor (so the lower cave is closed leftward)
	_fill(_geometry, 3320.0, 3400.0, UP_Y + 120.0, LOW_Y)
	_solid(coll, 3340.0, 3400.0, UP_Y + 60.0, LOW_Y)

	# == E — VERTICAL MOVERS (3950..4620): chasm; crossing ledge mid-air ==
	_ledge(columns, coll, 4300.0, 860.0, false, true)
	_ground_run(ground, coll, 4620.0, 4900.0, LOW_Y)

	# == F — THE DARK STRETCH (4900..5480): lantern-only; two lit movers ==
	_ground_run(ground, coll, 5150.0, 5260.0, LOW_Y)
	_ground_run(ground, coll, 5480.0, WORLD_R + 80.0, LOW_Y)
	# boundary wall right
	_fill(_geometry, WORLD_R - 20.0, WORLD_R + 400.0, CEIL_Y, LOW_Y + 400.0)
	_solid(coll, WORLD_R - 20.0, WORLD_R + 60.0, CEIL_Y, LOW_Y)

	# == G — THE DOOR (5480..6250): opens out; plinth carries the arch ==
	_plinth(columns, coll, 5880.0, 1112.0)


## a run of standable ground: near-black fill body + wide slab decals on
## the lip, overlapping 25-40%, scale/flip varied (spec placement rules)
func _ground_run(ground: Node2D, coll: Node2D, x0: float, x1: float,
		top_y: float) -> void:
	_fill(_geometry, x0, x1, top_y + 8.0, KILL_Y + 400.0)
	_solid(coll, x0, x1, top_y, top_y + 140.0)
	# ground = the WIDE slabs, full scale, end to end with ~150px overlap
	# (Advika: one slab spans a big bite of the frame; SmallRocks are
	# scatter on top, never the ground itself)
	var x := x0 - 60.0
	var i := 0
	while x < x1 + 60.0:
		var r: Rect2 = R_GROUND_XW if i % 2 == 0 else R_GROUND_W
		var sc := _rng.randf_range(1.0, 1.2)
		var w := r.size.x * sc
		_decal(ground, SHEET_FLOOR, r,
				Vector2(x + w * 0.5, top_y + r.size.y * sc * 0.5 - 16.0
				+ _rng.randf_range(-6.0, 6.0)), sc, _rng.randf() < 0.4, MOD_GEO)
		x += w - 150.0
		i += 1
	# debris along the lip: small rocks, sparse
	var dx := x0 + _rng.randf_range(40.0, 140.0)
	while dx < x1 - 40.0:
		var dr := Rect2(64.0 + 256.0 * float(_rng.randi() % 6),
				64.0 + 256.0 * float(_rng.randi() % 4), 200.0, 190.0)
		_decal(ground, SHEET_SMALLROCKS, dr,
				Vector2(dx, top_y - 8.0 + _rng.randf_range(0.0, 10.0)),
				_rng.randf_range(0.16, 0.3), _rng.randf() < 0.5,
				Color(0.22, 0.22, 0.19))
		dx += _rng.randf_range(160.0, 340.0)


## a standing COLUMN (spec rule 5): 2-4 column regions stacked bottom-up
## with ±15-30px x offsets, capped with the ledge region — the cap reads
## "you can stand here". Collision: one rect, top 10px under the cap lip,
## width 85% of the cap.
func _column(columns: Node2D, coll: Node2D, cx: float, top_y: float,
		style: int) -> void:
	var shaft: Array[Rect2] = [R_COL_NARROW, R_COL_LARGE_VAR, R_COL_SMALL,
			R_TALL_BLOCK]
	var y := UP_Y + 620.0   # rooted deep below the gap line
	var i := 0
	while y > top_y + 120.0:
		var r: Rect2 = shaft[(style + i) % shaft.size()]
		var sc := _rng.randf_range(0.85, 1.05)
		var h := r.size.y * sc
		_decal(columns, SHEET_PLATFORMS, r,
				Vector2(cx + _rng.randf_range(-25.0, 25.0), y - h * 0.5),
				sc, _rng.randf() < 0.4, MOD_GEO)
		y -= h * 0.72
		i += 1
	var cap_sc := 0.62
	var cap_w := R_LEDGE.size.x * cap_sc
	_decal(columns, SHEET_PLATFORMS, R_LEDGE,
			Vector2(cx, top_y + R_LEDGE.size.y * cap_sc * 0.5 - 10.0),
			cap_sc, style % 2 == 1, MOD_GEO)
	_solid(coll, cx - cap_w * 0.425, cx + cap_w * 0.425, top_y + 10.0,
			top_y + 620.0)


## a wall ledge for the descent (one-way: she lands from above)
func _ledge(columns: Node2D, coll: Node2D, cx: float, top_y: float,
		fh := false, small := false) -> void:
	var r := R_LEDGE_SMALL if small else R_LEDGE
	var sc := 0.66
	var w := r.size.x * sc
	_decal(columns, SHEET_PLATFORMS, r,
			Vector2(cx, top_y + r.size.y * sc * 0.5 - 10.0), sc, fh, MOD_GEO)
	_solid(coll, cx - w * 0.425, cx + w * 0.425, top_y + 8.0, top_y + 30.0, true)


## the door plinth: tall block + cap, solid, reachable from the G floor
func _plinth(columns: Node2D, coll: Node2D, cx: float, top_y: float) -> void:
	_decal(columns, SHEET_PLATFORMS, R_TALL_BLOCK,
			Vector2(cx, LOW_Y - R_TALL_BLOCK.size.y * 0.55 * 0.5 + 20.0),
			0.55, false, MOD_GEO)
	_decal(columns, SHEET_PLATFORMS, R_LEDGE,
			Vector2(cx, top_y + R_LEDGE.size.y * 0.6 * 0.5 - 10.0), 0.6,
			false, MOD_GEO)
	_solid(coll, cx - 118.0, cx + 118.0, top_y + 10.0, LOW_Y)


# ---------- moving platforms ----------

func _build_movers() -> void:
	var movers := Node2D.new()
	movers.name = "MovingPlatforms"
	_geometry.add_child(movers)
	# C — one horizontal mover across the 700px chasm: slow, long dwell
	_mover(movers, Vector2(2760.0, UP_Y - 10.0), Vector2(480.0, 0.0),
			60.0, 1.4, 0.0, R_SLAB_MOVE_W)
	# E — two vertical movers out of phase: ride up, cross, ride down
	_mover(movers, Vector2(4060.0, LOW_Y - 40.0), Vector2(0.0, -320.0),
			60.0, 1.0, 0.0, R_SLAB_MOVE)
	_mover(movers, Vector2(4480.0, LOW_Y - 40.0), Vector2(0.0, -320.0),
			60.0, 1.0, 2.5, R_SLAB_MOVE)
	# F — two movers in the dark, visible only by their own small light
	_mover(movers, Vector2(4980.0, LOW_Y - 30.0), Vector2(110.0, 0.0),
			55.0, 0.8, 0.0, R_SLAB_MOVE, true)
	_mover(movers, Vector2(5330.0, LOW_Y - 30.0), Vector2(95.0, 0.0),
			55.0, 0.8, 1.6, R_SLAB_MOVE_W, true)


func _mover(parent: Node, pos: Vector2, travel: Vector2, speed: float,
		dwell: float, delay: float, region: Rect2, lit := false) -> void:
	var body: AnimatableBody2D = MOVER.new()
	body.position = pos
	body.travel = travel
	body.speed = speed
	body.dwell = dwell
	body.start_delay = delay
	parent.add_child(body)
	var sc := 0.8
	var spr := Sprite2D.new()
	spr.texture = load(SHEET_PLATFORMS)
	spr.region_enabled = true
	spr.region_rect = region
	spr.scale = Vector2(sc, sc)
	spr.position = Vector2(0.0, region.size.y * sc * 0.5 - 8.0)
	spr.modulate = MOD_GEO
	body.add_child(spr)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(region.size.x * sc * 0.85, 22.0)
	cs.shape = rect
	cs.position = Vector2(0.0, 11.0)
	cs.one_way_collision = true
	body.add_child(cs)
	if lit:
		# section F: the mover carries its own small light — it exists only
		# where light touches it
		var l := PointLight2D.new()
		l.texture = _soft_glow()
		l.color = RIM_LIGHT
		l.energy = 0.35
		l.texture_scale = 0.8
		body.add_child(l)


# ---------- foreground scatter ----------

func _build_foreground() -> void:
	_par_near = Parallax2D.new()
	_par_near.name = "ParallaxNear"
	_par_near.scroll_scale = Vector2(1.35, 1.0)
	add_child(_par_near)
	var fore := Node2D.new()
	fore.name = "ForegroundScatter"
	fore.z_index = 20
	_par_near.add_child(fore)
	# near-black small rocks along the bottom edge; a few stalactites at top
	var x := WORLD_L * 1.35 - 500.0
	while x < WORLD_R * 1.35 + 1000.0:
		var dr := Rect2(64.0 + 256.0 * float(_rng.randi() % 7),
				64.0 + 256.0 * float(_rng.randi() % 7), 210.0, 200.0)
		var low_zone := x > 3300.0 * 1.35
		var by := (LOW_Y if low_zone else UP_Y) + _rng.randf_range(240.0, 300.0)
		_decal(fore, SHEET_SMALLROCKS, dr, Vector2(x, by),
				_rng.randf_range(0.7, 1.15), _rng.randf() < 0.5, MOD_FORE)
		x += _rng.randf_range(420.0, 780.0)
	var tx := WORLD_L * 1.35 - 300.0
	while tx < WORLD_R * 1.35 + 800.0:
		var r: Rect2 = R_STALACT_A if _rng.randf() < 0.5 else R_STALACT_B
		var sc := _rng.randf_range(0.9, 1.3)
		_decal(fore, SHEET_FLOOR, r,
				Vector2(tx, CEIL_Y + r.size.y * sc * 0.5 - 120.0), sc,
				_rng.randf() < 0.5, MOD_FORE)
		tx += _rng.randf_range(900.0, 1600.0)


# ---------- the lighting stack ----------

func _build_lighting() -> void:
	var lighting := Node2D.new()
	lighting.name = "Lighting"
	add_child(lighting)
	var wash := CanvasModulate.new()
	wash.color = WASH
	lighting.add_child(wash)
	# vignette — heavy, the outer frame goes to black
	var cl := CanvasLayer.new()
	cl.name = "Vignette"
	cl.layer = 100
	add_child(cl)
	var vr := ColorRect.new()
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	vr.material = mat
	cl.add_child(vr)
	# ambient rim lights: sparse pools behind/above the standable lips.
	# NONE between 4600..5400 — that darkness is section F's whole point.
	var lights := Node2D.new()
	lights.name = "AmbientLights"
	lighting.add_child(lights)
	for p: Array in [
			[250.0, UP_Y - 260.0, 0.7], [1120.0, 240.0, 0.65],
			[1924.0, 230.0, 0.6], [2440.0, UP_Y - 250.0, 0.55],
			[2990.0, UP_Y - 300.0, 0.5], [3420.0, UP_Y - 260.0, 0.6],
			[3650.0, 820.0, 0.55], [4300.0, 700.0, 0.6],
			[5700.0, LOW_Y - 260.0, 0.65], [5880.0, 990.0, 0.8]]:
		var l := PointLight2D.new()
		l.texture = _soft_glow()
		l.color = RIM_LIGHT
		l.energy = p[2]
		l.texture_scale = 2.4
		l.position = Vector2(p[0], p[1])
		lights.add_child(l)


func _build_particles() -> void:
	# dust motes — dim, slow; Realm 2 owns glow
	var parts := Node2D.new()
	parts.name = "Particles"
	add_child(parts)
	var motes := GPUParticles2D.new()
	motes.amount = 40
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1300.0, 700.0, 1.0)
	pm.gravity = Vector3(2.0, -6.0, 0.0)
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 8.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	motes.process_material = pm
	var dot := GradientTexture2D.new()
	var dg := Gradient.new()
	dg.colors = PackedColorArray([Color(0.769, 0.8, 0.541, 0.25),
			Color(0.769, 0.8, 0.541, 0.0)])
	dot.gradient = dg
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 8
	dot.height = 8
	motes.texture = dot
	motes.z_index = 6
	parts.add_child(motes)
	_motes = motes


var _motes: GPUParticles2D


# ---------- player / golems / jades / door ----------

func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.name = "Player"
	_curi.position = SPAWN
	_curi.scale = Vector2(CURI_SCALE, CURI_SCALE)
	_curi.z_index = 5
	add_child(_curi)
	# her lantern reads as the warmest thing on screen — bump it for this realm
	_bump_lantern(_curi)
	_lives = LIVES_HUD.instantiate() as LivesHUD
	_lives.eye_scale = 0.22
	_lives.eye_spacing = 112.0
	add_child(_lives)
	_lives.reset(STARTING_LIVES)
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


func _bump_lantern(node: Node) -> void:
	for c in node.get_children():
		if c is PointLight2D:
			(c as PointLight2D).energy *= 1.15
		_bump_lantern(c)


const GOLEM_SCALE := 0.55
const GOLEM_DETECT := 260.0
# sparse guards on real ground (fear realm: the dark is the enemy) —
# section F stays empty, a golem in pitch black would be unfair
const GOLEM_SPOTS: Array[Vector2] = [
	Vector2(700.0, UP_Y - 60.0),
	Vector2(3800.0, LOW_Y - 60.0),
	Vector2(5620.0, LOW_Y - 60.0),
]

func _build_golems() -> void:
	for sp in GOLEM_SPOTS:
		var g: CharacterBody2D = GOLEM_SCENE.instantiate()
		g.ball_scene = GOLEM_BALL_SCENE
		g.scale = Vector2(GOLEM_SCALE, GOLEM_SCALE)
		g.detect_range = GOLEM_DETECT
		g.position = sp
		g.z_index = 7
		add_child(g)
		if g.has_method("set_home"):
			g.set_home(sp.x)


func _build_jades() -> void:
	var spots: Array[Vector2] = [
		Vector2(350.0, UP_Y - 60.0),        # A — plain sight
		Vector2(700.0, UP_Y - 60.0),        # A — plain sight
		Vector2(1924.0, 318.0),             # B — third column top
		Vector2(3560.0, 510.0),             # D — first descent ledge
		Vector2(4060.0, 880.0),             # E — apex of the harder ride
		Vector2(5205.0, LOW_Y - 60.0),      # F — the island in the dark
	]
	_jade_total = spots.size()
	for sp in spots:
		var j: Area2D = JADE_SCENE.instantiate()
		j.position = sp
		j.piece_scale = 0.15
		j.z_index = 7
		add_child(j)
		j.collected.connect(_on_jade)


func _on_jade() -> void:
	_jade_got += 1
	if _jade_lbl != null:
		_jade_lbl.text = "%d / %d" % [_jade_got, _jade_total]


func _build_exit_door() -> void:
	var arch: Texture2D = load("res://assets/scenes/hub/door_arch.png")
	var root := Node2D.new()
	root.name = "ExitDoor"
	root.position = Vector2(5880.0, 1112.0 + 8.0 - arch.get_height() * 0.5)
	root.z_index = 3
	add_child(root)
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
	area.door_id = "Realm1CaveExit"
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
	var z := 1.0 * vp.y / 1080.0
	_cam.zoom = Vector2(z, z)
	_cam.position = SPAWN + Vector2(0, -80)
	add_child(_cam)
	_cam.make_current()
	var hcam: Camera2D = _curi.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 120
	add_child(cl)
	var lbl := Label.new()
	lbl.text = "R1 CAVE — walk right →   (R restart · ESC hub)"
	lbl.position = Vector2(16, 12)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.84, 0.62, 0.6))
	cl.add_child(lbl)
	_jade_lbl = Label.new()
	_jade_lbl.text = "0 / %d" % _jade_total
	_jade_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_jade_lbl.position = Vector2(-140.0, 12.0)
	_jade_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6, 0.75))
	cl.add_child(_jade_lbl)


# ---------- running ----------

func _process(_delta: float) -> void:
	if _cam == null:
		return
	if _motes != null:
		_motes.position = _cam.get_screen_center_position() + Vector2(0, -100)
	if not _freeze_cam:
		var target := Vector2(
				clampf(_curi.global_position.x, WORLD_L + 560.0, WORLD_R - 500.0),
				clampf(_curi.global_position.y - 100.0, CEIL_Y + 340.0, LOW_Y - 150.0))
		_cam.position = _cam.position.lerp(target, 1.0 - pow(0.001, _delta))
	# rolling checkpoints: passing one on the ground arms it
	if _curi.is_on_floor():
		for cp in CHECKPOINTS:
			if _curi.global_position.x >= cp.x \
					and absf(_curi.global_position.y - cp.y) < 260.0 \
					and cp.x > _checkpoint.x - 0.5:
				_checkpoint = cp
	if not _dying and _curi.global_position.y > KILL_Y:
		_die()


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
	_curi.global_position = _checkpoint
	_curi.velocity = Vector2.ZERO
	if _curi.has_method("refill_health"):
		_curi.refill_health()
	if _curi.has_method("grant_invuln"):
		_curi.grant_invuln(1.6)
	_dying = false


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_leaving = true
		Transition.transition_to(HUB_SCENE)
	if event.is_action_pressed("interact") and _at_exit and _exit_door != null:
		_leaving = true
		_exit_door.trigger()
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _self_screenshot(path: String) -> void:
	if OS.get_environment("R1_SHOT_X") != "":
		var px := float(OS.get_environment("R1_SHOT_X"))
		var py := UP_Y - 160.0
		if OS.get_environment("R1_SHOT_Y") != "":
			py = float(OS.get_environment("R1_SHOT_Y"))
		_curi.position = Vector2(px, py)
		_curi.velocity = Vector2.ZERO
		_cam.position = Vector2(px, py - 100.0)
	if OS.get_environment("R1_SHOT_CAMY") != "":
		_cam.position.y = float(OS.get_environment("R1_SHOT_CAMY"))
		_freeze_cam = true
	await get_tree().create_timer(1.0).timeout
	print("SHOT curi=", _curi.global_position)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
