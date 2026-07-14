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
##   - background = LUMINOUS MIST with pale spire/mushroom silhouettes
##     dissolving into it; foreground = darkest silhouettes; corner vignette
## THE PACK KEEPS ITS OWN COLORS (Advika, hard rule). No purple grade.
## Environment ONLY: no enemies, no puzzle. Zones, left to right:
##   A cavern mouth (ref 3) -> B pot-strewn floor + hanging chunk (ref 1)
##   -> C overgrown platform stack under a fringed ceiling (ref 2).
## Controls: Curiosity's own. R restarts. ESC returns to the Hub.
## R3_SHOT env: screenshot at 1s + quit. R3_SHOT_X: park the hero first.

const BASE := "res://assets/realms/realm3_fungal/"
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const HUB_SCENE := "res://scenes/Hub.tscn"
const STARTING_LIVES: int = 3

const FLOOR_Y := 420.0
const SPAWN := Vector2(-40.0, FLOOR_Y - 140.0)
const WORLD_L := -1050.0
const WORLD_R := 4250.0

# sampled off the reference images — the pack's own hues
const FILL_DARK := Color(0.05, 0.07, 0.10)        # terrain body near-black navy
const MIST := Color(0.60, 0.67, 0.77)             # the luminous fog band
const MIST_SIL := Color(0.66, 0.72, 0.81)         # far silhouettes sunk in mist
const GLOW_WARM := Color(1.0, 0.85, 0.62)         # amber caps / gold stalks
const GLOW_COOL := Color(0.85, 0.92, 1.0)         # white glower mushrooms
const FRINGE_LIT := Color(0.96, 0.98, 1.05)       # midground fringe, catching mist
const FRINGE_NEAR := Color(0.62, 0.66, 0.78)      # foreground fringe, darker
const FRINGE_HANG := Color(0.55, 0.60, 0.72)      # ceiling fringe, dimmer still
const MAX_GLOW_LIGHTS := 12
const MOSS_FOG := "res://assets/realms/realm2_moss/fog.png"
const MOSS_SPORE := "res://assets/realms/realm2_moss/spore.png"

# frond cluster slices used for fringe rows (clusters only — singles read thin)
const FRINGE_TEX: Array[int] = [2, 3, 4, 10, 11, 16, 3, 10, 11]

var _curi: CharacterBody2D
var _cam: Camera2D
var _lives: LivesHUD
var _lbl: Label
var _dying := false
var _leaving := false
var _glow_lights := 0
var _hills_far: Node2D
var _hills_mid: Node2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.16, 0.19, 0.25))
	_rng.seed = 20260714
	_build_backdrop()
	_build_background()
	_build_terrain()
	_build_platforms()
	_build_ceiling()
	_build_dressing()
	_build_foreground()
	_build_atmosphere()
	_build_player()
	_build_camera()
	_build_ui()
	# no grade — the pack's own blue-grey carries the realm (hard rule)
	var grade := CanvasModulate.new()
	grade.color = Color(0.96, 0.97, 1.0)
	add_child(grade)
	if OS.get_environment("R3_SHOT") != "":
		_self_screenshot(OS.get_environment("R3_SHOT"))


# ---------- shared little builders ----------

func _sprite(tex_name: String, pos: Vector2, sc: float, z: int,
		tint := Color.WHITE, fh := false, fv := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(BASE + tex_name)
	s.scale = Vector2(sc, sc)
	s.position = pos
	s.z_index = z
	s.modulate = tint
	s.flip_h = fh
	s.flip_v = fv
	add_child(s)
	return s


## bottom-anchored prop: base sits ON base_y (sunk a touch so nothing floats)
func _prop(tex_name: String, x: float, base_y: float, sc: float, z: int,
		tint := Color.WHITE, fh := false) -> Sprite2D:
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


func _collider_rect(x0: float, x1: float, y0: float, y1: float) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, y1 - y0)
	cs.shape = rect
	cs.position = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
	body.add_child(cs)
	add_child(body)


## pebble strip riding an edge line (the refs' platform/ground rims)
func _pebble_row(x0: float, x1: float, y: float, sc: float, z: int,
		tint := Color.WHITE) -> void:
	var names := ["fungalground22.png", "fungalground26.png"]
	var x := x0
	var i := 0
	while true:
		var tex: Texture2D = load(BASE + names[i % 2])
		var w := tex.get_width() * sc
		if x + w > x1 + w * 0.12:
			break   # whole tile must fit — no strays past the span
		_sprite(names[i % 2], Vector2(x + w * 0.5, y), sc, z, tint,
				_rng.randf() < 0.5)
		x += w * 0.88
		i += 1


## vertical pebble strip (the refs' wall/side rims), tiled downward
func _pebble_col(x: float, y0: float, y1: float, sc: float, z: int,
		tint := Color.WHITE) -> void:
	var names := ["fungalground20.png", "fungalground21.png"]
	var y := y0
	var i := 0
	while true:
		var tex: Texture2D = load(BASE + names[i % 2])
		var h := tex.get_height() * sc
		if y + h > y1 + h * 0.12:
			break
		_sprite(names[i % 2], Vector2(x, y + h * 0.5), sc, z, tint,
				_rng.randf() < 0.5)
		y += h * 0.88
		i += 1


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
		var sink := h * 0.14 + 6.0
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
	if _glow_lights >= MAX_GLOW_LIGHTS:
		return
	_glow_lights += 1
	var l := PointLight2D.new()
	l.texture = _soft_glow_texture()
	l.color = col
	l.energy = energy
	l.texture_scale = tsc
	host.add_child(l)


# ---------- backdrop / background ----------

func _build_backdrop() -> void:
	# screen-anchored vertical gradient: cavern dark above, luminous mist
	# band through the middle, floor shadow below (the refs' light)
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.13, 0.16, 0.22), Color(0.40, 0.47, 0.57), MIST,
		Color(0.33, 0.38, 0.47), Color(0.17, 0.20, 0.27)])
	grad.offsets = PackedFloat32Array([0.0, 0.40, 0.58, 0.80, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)


func _build_background() -> void:
	# two hand-driven parallax bands (Realm 2's manners).
	# FAR: pale spires + glowing mushroom ghosts DISSOLVED into the mist.
	# MID: deeper silhouettes — fringed mounds, spires, a pot ghost.
	_hills_far = Node2D.new()
	_hills_far.z_index = -8
	add_child(_hills_far)
	_hills_mid = Node2D.new()
	_hills_mid.z_index = -6
	add_child(_hills_mid)
	# soft luminous cores hung in the mist (the refs' bright pockets)
	for core in [[500.0, -20.0, 15.0], [2000.0, -60.0, 12.0], [3300.0, -30.0, 14.0]]:
		var g := Sprite2D.new()
		g.texture = _soft_glow_texture()
		g.position = Vector2(core[0], core[1])
		g.scale = Vector2(core[2], core[2] * 0.72)
		g.modulate = Color(0.78, 0.85, 0.95, 0.38)
		_hills_far.add_child(g)
	# far spires (ref 3): stalagmiteb, barely darker than the fog
	for sp in [[-700.0, 1, 0.55], [-330.0, 3, 0.72], [180.0, 2, 0.5],
			[820.0, 4, 0.62], [1450.0, 5, 0.5], [2050.0, 1, 0.66],
			[2650.0, 3, 0.55], [3250.0, 2, 0.68], [3850.0, 4, 0.55]]:
		var tex: Texture2D = load(BASE + "stalagmiteb%d.png" % sp[1])
		var sc: float = sp[2]
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.position = Vector2(sp[0], FLOOR_Y + 40.0 - tex.get_height() * sc * 0.5)
		s.modulate = Color(MIST_SIL.r, MIST_SIL.g, MIST_SIL.b, 0.55)
		_hills_far.add_child(s)
	# far mushroom ghosts w/ soft glow (ref 2's background glimmers)
	for mg in [[-80.0, 17, 0.5], [1150.0, 23, 0.42], [2380.0, 24, 0.55],
			[3600.0, 17, 0.45]]:
		var tex: Texture2D = load(BASE + "mushroomglow%d.png" % mg[1])
		var sc: float = mg[2]
		var g := Sprite2D.new()
		g.texture = _soft_glow_texture()
		g.position = Vector2(mg[0], FLOOR_Y - 90.0 - tex.get_height() * sc * 0.5)
		g.scale = Vector2(2.4, 2.4)
		g.modulate = Color(0.85, 0.90, 1.0, 0.30)
		_hills_far.add_child(g)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.position = Vector2(mg[0], FLOOR_Y + 8.0 - tex.get_height() * sc * 0.5)
		s.modulate = Color(0.82, 0.87, 0.96, 0.5)
		_hills_far.add_child(s)
	# mid band: fringed mounds + deeper spires, the pack's hue dimmed blue
	var mid_tint := Color(0.34, 0.40, 0.52, 0.9)
	var mx := -850.0
	while mx < WORLD_R:
		var hi := 1 + _rng.randi() % 5
		if hi == 2 or hi == 5:
			hi = 3   # radial bursts read wrong as ground mounds
		var tex: Texture2D = load(BASE + "fungalhill%d.png" % hi)
		var sc := _rng.randf_range(0.55, 0.8)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.position = Vector2(mx, FLOOR_Y + 26.0 - tex.get_height() * sc * 0.5)
		s.modulate = mid_tint
		_hills_mid.add_child(s)
		mx += _rng.randf_range(560.0, 860.0)
	for sp in [[350.0, 3, 0.5], [1750.0, 5, 0.45], [3050.0, 10, 0.4]]:
		var tex: Texture2D = load(BASE + "stalagmite%d.png" % sp[1])
		var sc: float = sp[2]
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.position = Vector2(sp[0], FLOOR_Y + 20.0 - tex.get_height() * sc * 0.5)
		s.modulate = Color(0.40, 0.46, 0.57, 0.85)
		_hills_mid.add_child(s)


# ---------- terrain: ground + ceiling + platforms ----------

func _build_terrain() -> void:
	# THE GROUND: one dark body under the whole walk (the refs' bottom mass).
	# Art overshoots the camera clamps; colliders stop at the world edge.
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, FLOOR_Y, FLOOR_Y + 900.0, 0)
	_collider_rect(WORLD_L, WORLD_R, FLOOR_Y, FLOOR_Y + 120.0)
	# CAVERN END WALLS (ref 2's left edge): dark column + vertical pebble rim.
	# Walls run 900px past the world edge — the camera's widest framing at
	# the clamps still lands inside solid dark, nothing leaks through.
	_fill_rect(WORLD_L - 900.0, WORLD_L + 40.0, -1400.0, FLOOR_Y, 0)
	_pebble_col(WORLD_L + 44.0, -270.0, FLOOR_Y - 30.0, 0.7, 1)
	_collider_rect(WORLD_L - 60.0, WORLD_L + 40.0, FLOOR_Y - 900.0, FLOOR_Y)
	_fill_rect(WORLD_R - 40.0, WORLD_R + 900.0, -1400.0, FLOOR_Y, 0)
	_pebble_col(WORLD_R - 44.0, -150.0, FLOOR_Y - 30.0, 0.7, 1)
	_collider_rect(WORLD_R - 40.0, WORLD_R + 60.0, FLOOR_Y - 900.0, FLOOR_Y)
	# pebble rim segments along the floor line (refs pebble it in stretches)
	_pebble_row(-950.0, 150.0, FLOOR_Y - 8.0, 0.62, 1)
	_pebble_row(700.0, 1900.0, FLOOR_Y - 8.0, 0.66, 1)
	_pebble_row(2450.0, 4150.0, FLOOR_Y - 8.0, 0.62, 1)
	# the fringe rows: a paler row BEHIND the pebbles, a darker row IN FRONT
	# (the refs' two-deep coral carpet)
	_fringe(WORLD_L + 40.0, WORLD_R - 40.0, FLOOR_Y - 12.0, false, 0.20, 0.30, 2, FRINGE_LIT)
	_fringe(WORLD_L + 10.0, WORLD_R - 10.0, FLOOR_Y + 14.0, false, 0.22, 0.32, 4, FRINGE_NEAR, 0.62)


func _build_platforms() -> void:
	# ZONE B (ref 1): a grounded pedestal + a floating block above-right
	_frame_platform(Vector2(950.0, FLOOR_Y - 130.0), "wide", true)
	_frame_platform(Vector2(1500.0, FLOOR_Y - 245.0), "block", false)
	# ZONE C (ref 2): the overgrown stack — pedestal, float, high float
	_frame_platform(Vector2(2950.0, FLOOR_Y - 120.0), "wide", true, true)
	_frame_platform(Vector2(3350.0, FLOOR_Y - 235.0), "block", false)
	_frame_platform(Vector2(3750.0, FLOOR_Y - 350.0), "block", false)


## a ref-style platform: dark fill body + pebble frame + fringe.
## top_y = the walkable surface height. grounded platforms merge into the
## floor mass below; floating ones hang fringe from their underside.
func _frame_platform(top: Vector2, kind: String, grounded: bool,
		fh := false) -> void:
	var tex_name := "fungalground14.png" if kind == "wide" else "fungalground15.png"
	var tex: Texture2D = load(BASE + tex_name)
	var sc := 0.5 if kind == "wide" else 0.85
	var w := tex.get_width() * sc
	var h := tex.get_height() * sc
	var cy := top.y + h * 0.5
	# fill body: inset behind the pebble rim; grounded bodies run to the floor
	var bottom := FLOOR_Y + 60.0 if grounded else top.y + h - 10.0
	_fill_rect(top.x - w * 0.5 + 10.0, top.x + w * 0.5 - 10.0,
			top.y + 8.0, bottom, 0)
	_sprite(tex_name, Vector2(top.x, cy), sc, 1, Color.WHITE, fh)
	_collider_rect(top.x - w * 0.5 + 8.0, top.x + w * 0.5 - 8.0,
			top.y + 4.0, bottom if grounded else top.y + h)
	# the growth: fringe up top, fringe dripping below if it floats
	_fringe(top.x - w * 0.5 + 24.0, top.x + w * 0.5 - 24.0, top.y + 4.0,
			false, 0.16, 0.24, 2, FRINGE_LIT, 0.5)
	if not grounded:
		_fringe(top.x - w * 0.5 + 30.0, top.x + w * 0.5 - 30.0,
				top.y + h - 8.0, true, 0.14, 0.20, 2, FRINGE_HANG, 0.5)


func _build_ceiling() -> void:
	# ZONE A (ref 3): high roof, pebbled edge, pale stalactites hanging off it
	_fill_rect(WORLD_L - 900.0, 680.0, -1400.0, -280.0, 0)
	_pebble_row(WORLD_L + 20.0, 660.0, -284.0, 0.6, 1)
	for st in [[-820.0, 12, 0.75], [-560.0, 14, 0.9], [-240.0, 13, 0.7],
			[60.0, 15, 0.85], [380.0, 12, 0.65], [620.0, 16, 0.8]]:
		var tex: Texture2D = load(BASE + "stalagmite%d.png" % st[1])
		var sc: float = st[2]
		_sprite("stalagmite%d.png" % st[1],
				Vector2(st[0], -272.0 + tex.get_height() * sc * 0.5),
				sc, 1, Color(0.72, 0.77, 0.86), _rng.randf() < 0.5, true)
	# ZONE B (ref 1): the hanging chunk — dark mass rimmed on every exposed
	# edge (bottom row, side columns, corner knuckles), fringe + a curl
	_fill_rect(680.0, 1560.0, -1400.0, -40.0, 0)
	_pebble_row(700.0, 1540.0, -44.0, 0.62, 1)
	_pebble_col(696.0, -270.0, -70.0, 0.62, 1)
	_pebble_col(1544.0, -350.0, -70.0, 0.62, 1)
	_sprite("fungalground9.png", Vector2(712.0, -56.0), 0.55, 1)
	_sprite("fungalground1.png", Vector2(1532.0, -60.0), 0.6, 1, Color.WHITE, true)
	_fringe(720.0, 1520.0, -30.0, true, 0.20, 0.30, 2, FRINGE_HANG)
	_prop_hang("fungalfrond18.png", 1440.0, -34.0, 0.3, 2, FRINGE_HANG)
	for st in [[840.0, 13, 0.8], [1300.0, 15, 0.75]]:
		var tex: Texture2D = load(BASE + "stalagmite%d.png" % st[1])
		var sc: float = st[2]
		_sprite("stalagmite%d.png" % st[1],
				Vector2(st[0], -40.0 + tex.get_height() * sc * 0.5),
				sc, 1, Color(0.60, 0.65, 0.76), false, true)
	# the span between chunk and zone C: bare high roof, edged + lightly hung
	_fill_rect(1560.0, 2500.0, -1400.0, -360.0, 0)
	_pebble_row(1580.0, 2480.0, -364.0, 0.6, 1)
	_fringe(1600.0, 2460.0, -350.0, true, 0.18, 0.26, 2, FRINGE_HANG, 0.6)
	# ZONE C (ref 2): lower roof shelf wearing a heavy hanging fringe
	_fill_rect(2500.0, WORLD_R + 900.0, -1400.0, -160.0, 0)
	_pebble_row(2520.0, 4180.0, -164.0, 0.62, 1)
	_fringe(2540.0, 4160.0, -148.0, true, 0.24, 0.36, 2, FRINGE_HANG, 0.5)


## top-anchored hanging prop (curls off the chunk's underside)
func _prop_hang(tex_name: String, x: float, top_y: float, sc: float, z: int,
		tint := Color.WHITE) -> void:
	var tex: Texture2D = load(BASE + tex_name)
	var h := tex.get_height() * sc
	_sprite(tex_name, Vector2(x, top_y + h * 0.5 - 8.0), sc, z, tint,
			_rng.randf() < 0.5, true)


# ---------- dressing: the grouped assemblies ----------

func _build_dressing() -> void:
	# ZONE A — the mushroom shelf (ref 3 left): boulder mound carrying a
	# family of big blue flat-caps, amber stalks leaning on its shoulder
	_prop("fungalstone20.png", -620.0, FLOOR_Y + 10.0, 0.6, 3)
	_prop("mushroomcap9.png", -700.0, FLOOR_Y - 130.0, 0.5, 4)
	_prop("mushroomcap6.png", -540.0, FLOOR_Y - 138.0, 0.38, 4, Color.WHITE, true)
	_prop("mushroomcap4.png", -620.0, FLOOR_Y - 60.0, 0.26, 5)
	var amber_a := _prop("mushroomglow5.png", -430.0, FLOOR_Y + 6.0, 0.34, 3)
	_glow_light(amber_a, GLOW_WARM, 0.3, 1.2)
	_prop("mushroomglow7.png", -380.0, FLOOR_Y + 8.0, 0.26, 3, Color.WHITE, true)
	# spawn-side boulder pair so the start reads placed, not empty
	_prop("fungalstone22.png", -120.0, FLOOR_Y + 10.0, 0.55, 3)
	_prop("fungalstone2.png", -20.0, FLOOR_Y + 12.0, 0.4, 3, Color.WHITE, true)

	# ZONE B — ref 1's floor life. Assembly 1: pot cluster + boulder + curl
	_prop("fungalstone18.png", 640.0, FLOOR_Y + 14.0, 0.5, 3)
	_prop("fungalfrond29.png", 700.0, FLOOR_Y + 10.0, 0.28, 4)
	_prop("fungalfrond27.png", 560.0, FLOOR_Y + 8.0, 0.22, 4, Color.WHITE, true)
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
	var amber_b := _prop("mushroomglow4.png", 2060.0, FLOOR_Y + 8.0, 0.34, 3, Color.WHITE, true)
	_glow_light(amber_b, GLOW_WARM, 0.3, 1.3)
	# assembly 4: foreground stalagmites + boulders (ref 3's right edge)
	_prop("stalagmite7.png", 2250.0, FLOOR_Y + 16.0, 0.5, 3, Color(0.55, 0.60, 0.72))
	_prop("fungalstone1.png", 2360.0, FLOOR_Y + 12.0, 0.45, 4)
	_prop("mushroomglow11.png", 2300.0, FLOOR_Y + 6.0, 0.28, 4)

	# ZONE C — ref 2's white glowers, on the stack and at its feet
	for wg in [[2950.0, FLOOR_Y - 120.0, 23, 0.32], [2870.0, FLOOR_Y - 120.0, 24, 0.24],
			[3350.0, FLOOR_Y - 235.0, 17, 0.5], [3420.0, FLOOR_Y - 235.0, 24, 0.26],
			[3750.0, FLOOR_Y - 350.0, 23, 0.3], [2680.0, FLOOR_Y + 8.0, 17, 0.55],
			[3150.0, FLOOR_Y + 10.0, 24, 0.38]]:
		var m := _prop("mushroomglow%d.png" % wg[2], wg[0], wg[1], wg[3], 3,
				Color.WHITE, _rng.randf() < 0.5)
		_glow_light(m, GLOW_COOL, 0.38, 1.1)
	_prop("mushroomglow16.png", 3050.0, FLOOR_Y + 8.0, 0.3, 4)
	_prop("mushroomglow19.png", 3550.0, FLOOR_Y + 10.0, 0.32, 4)
	_prop("fungalfrond23.png", 4020.0, FLOOR_Y + 8.0, 0.3, 3)
	_prop("fungalstone5.png", 3900.0, FLOOR_Y + 26.0, 0.45, 3, Color(0.78, 0.80, 0.88))


func _build_foreground() -> void:
	# darkest silhouettes hugging the bottom frame (refs' near plane).
	# Their bases sit BELOW the lowest view edge (~y 830) so they always
	# read as growth cut by the frame, never as floating shapes.
	for fs in [[-780.0, "fungalfrond10.png", 0.62], [200.0, "fungalfrond3.png", 0.55],
			[1050.0, "stalagmite5.png", 0.7], [1620.0, "fungalfrond16.png", 0.6],
			[2550.0, "fungalfrond4.png", 0.58], [3480.0, "fungalfrond10.png", 0.65],
			[4130.0, "stalagmite3.png", 0.6]]:
		var tex: Texture2D = load(BASE + (fs[1] as String))
		var sc: float = fs[2]
		_sprite(fs[1] as String,
				Vector2(fs[0], 920.0 - tex.get_height() * sc * 0.5),
				sc, 8, Color(0.16, 0.20, 0.28), _rng.randf() < 0.5)


# ---------- atmosphere ----------

var _fogs: Array[Sprite2D] = []
func _build_atmosphere() -> void:
	for i in 6:
		var f := Sprite2D.new()
		f.texture = load(MOSS_FOG)
		f.position = Vector2(-900.0 + i * 950.0, FLOOR_Y - _rng.randf_range(60.0, 280.0))
		f.scale = Vector2(_rng.randf_range(2.8, 4.2), _rng.randf_range(2.0, 2.9))
		f.modulate = Color(0.72, 0.79, 0.90, _rng.randf_range(0.20, 0.32))
		f.z_index = -4 if i % 2 == 0 else 6
		add_child(f)
		_fogs.append(f)
	var motes := CPUParticles2D.new()
	motes.texture = load(MOSS_SPORE)
	motes.amount = 32
	motes.lifetime = 14.0
	motes.preprocess = 14.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(2700.0, 500.0)
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 6.0
	motes.initial_velocity_max = 20.0
	motes.spread = 180.0
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.1
	motes.color = Color(0.95, 0.97, 1.0, 0.8)
	motes.position = Vector2(1600.0, FLOOR_Y - 260.0)
	motes.z_index = 6
	add_child(motes)
	# corner vignette (screen-anchored; the refs darken hard at the edges)
	var cl := CanvasLayer.new()
	cl.layer = 15
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0),
			Color(0.02, 0.04, 0.08, 0.42)])
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
	_curi.scale = Vector2(0.24, 0.24)
	# she walks IN FRONT of props + fringe (<=4), behind fore silhouettes (8)
	_curi.z_index = 5
	add_child(_curi)
	_lives = LIVES_HUD.instantiate() as LivesHUD
	_lives.eye_scale = 0.22
	_lives.eye_spacing = 112.0
	add_child(_lives)
	_lives.reset(STARTING_LIVES)
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


func _build_camera() -> void:
	_cam = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := 0.9 * vp.y / 1080.0
	_cam.zoom = Vector2(z, z)
	_cam.position = SPAWN + Vector2(0, -80)
	add_child(_cam)
	_cam.make_current()
	var hcam: Camera2D = _curi.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	_lbl = Label.new()
	_lbl.text = "R3 FUNGAL SHELL — walk right →   (R restart · ESC hub)"
	_lbl.position = Vector2(16, 12)
	_lbl.add_theme_color_override("font_color", Color(0.73, 0.78, 0.92, 0.6))
	cl.add_child(_lbl)


# ---------- running ----------

var _t := 0.0
func _process(delta: float) -> void:
	_t += delta
	for i in _fogs.size():
		_fogs[i].position.x += sin(_t * 0.11 + i * 1.7) * 0.35
	if _cam != null:
		_hills_far.position.x = _cam.global_position.x * 0.82
		_hills_mid.position.x = _cam.global_position.x * 0.6
		var target := Vector2(clampf(_curi.global_position.x, -450.0, 3900.0),
				clampf(_curi.global_position.y - 110.0, -400.0, FLOOR_Y - 190.0))
		_cam.position = _cam.position.lerp(target, 1.0 - pow(0.001, delta))
	if not _dying and _curi.global_position.y > FLOOR_Y + 700.0:
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
	_curi.global_position = SPAWN
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _self_screenshot(path: String) -> void:
	if OS.get_environment("R3_SHOT_X") != "":
		_curi.position = Vector2(float(OS.get_environment("R3_SHOT_X")), FLOOR_Y - 160.0)
		_curi.velocity = Vector2.ZERO
		_cam.position = Vector2(_curi.position.x, FLOOR_Y - 190.0)
	await get_tree().create_timer(1.0).timeout
	print("SHOT curi=", _curi.global_position)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
