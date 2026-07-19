extends Node2D
## REALM 1 REBUILD — THE CAVERN, Maaot's "Cave Assets" pack ONLY (Advika
## 2026-07-19: no other packs' art in this level). The pack's own promo
## mood, kept SUBTLE: a dark green gloom in the air — carried entirely by
## the backdrop, fog masses and faint light pools (generated glows, not
## art) — while every visible piece is the cave pack in its original
## painted brown, silhouette-forward:
##   - ground = near-black soil + staggered slab rows; a rubble mat of
##     pebbles/small rocks at graded depths (LOW — enemies must read)
##   - platforms = the pack's blocks/slats; big rocks stay decor
##   - MOVING platforms (Realm 1's signature): AnimatableBody2D sine
##     tweens — arc slats alternate elevator/slider + free movers
##   - ONE roof line: pale teeth deep behind, black fingers in front
##   - set-pieces RARE: the maw / the standing stones / the spike garden
##   - golem guards + jades kept from the old realm
## Controls: Curiosity's own. R restarts. ESC returns to the Hub.
## R1_SHOT env: screenshot at 1s + quit. R1_SHOT_X: park the hero first.
## R1_SHOT_CAMY: freeze the camera at a fixed Y (inspect the roof view).

const BASE := "res://assets/realms/realm1_cavern/"
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const HUB_SCENE := "res://scenes/Hub.tscn"
const JADE_SCENE := preload("res://scenes/Jade.tscn")
const GOLEM_SCENE := preload("res://scenes/Golem.tscn")
const GOLEM_BALL_SCENE := preload("res://scenes/GolemBall.tscn")
const STARTING_LIVES: int = 3

const FLOOR_Y := 420.0
const SPAWN := Vector2(-40.0, FLOOR_Y - 140.0)
const WORLD_L := -1050.0
const WORLD_R := 14500.0
const ROOF_Y := -380.0   # ONE ceiling line, end to end
# anchor x of each climbing arc down the walk (low dome -> mid -> high)
const ARC_XS: Array[float] = [2200.0, 4400.0, 6600.0, 8800.0, 11000.0]

# SUBTLE DARK GREEN (Advika: not the bright one): the gloom sits low and
# deep — dark olive backdrop, faint haze, dim pools. The art is never
# tinted green; it silhouettes dark against the glow. Gold stays the one
# warm accent (the lantern's family).
const SOIL := Color(0.026, 0.024, 0.016)          # near-black earth body
const BG_TOP := Color(0.042, 0.055, 0.030)        # backdrop: deep dark olive
const BG_BOTTOM := Color(0.018, 0.023, 0.013)
const HAZE_GREEN := Color(0.26, 0.34, 0.18)       # the fog masses, muted
const POOL_GREEN := Color(0.40, 0.52, 0.26)       # the light pools, dimmed
const SIL_FAR := Color(0.20, 0.20, 0.18)          # far band: darkest shapes
const SIL_MID := Color(0.32, 0.32, 0.29)          # mid band silhouettes
const GOLD := Color(1.0, 0.82, 0.48)
const AMBIENT := Color(0.76, 0.79, 0.72)          # mild dim, a breath of green
const FOG_TINT := HAZE_GREEN
const MAX_GLOW_LIGHTS := 16

# ---- pack vocabulary (indices into the sliced sheets) ----
const LONG_SLABS: Array[int] = [0, 2, 3, 4, 10, 12, 13, 14]   # floor_* logs
const XL_SLABS: Array[int] = [9, 17, 21]                      # very long ridges
const MOUNDS: Array[int] = [20, 24, 25]                       # smooth big mounds
const PEBBLE_PILES: Array[int] = [15, 16, 22, 23]             # floor_* pebble blocks
const PLAT_CHUNKY: Array[int] = [0, 2, 3, 4, 7, 10]           # plat_* block steps
const PLAT_THIN: Array[int] = [6, 8, 9]                       # plat_* slats
const STALACT: Array[int] = [13, 14, 20, 21, 22]              # rock_* hangers
const STALAG: Array[int] = [29, 31, 33, 37]                   # rock_* floor spikes
const SPIKE_CLUSTERS: Array[int] = [12, 13, 14, 15]           # combo_* spike groups
const ROCK_PILES: Array[int] = [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11]  # combo_*
const PEBBLES: Array[int] = [25, 26, 27, 28, 30]              # rock_* fist-size
const MED_ROCKS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 8, 9, 11, 15, 16, 17, 18, 19, 34]
const DOMES: Array[int] = [23, 24]                            # rock_* buried hop domes

var _curi: CharacterBody2D
var _cam: Camera2D
var _lives: LivesHUD
var _exit_door: Area2D
var _at_exit := false
var _freeze_cam := false
var _dying := false
var _leaving := false
var _glow_lights := 0
var _hills_far: Node2D
var _hills_mid: Node2D
var _jade_total := 0
var _jade_got := 0
var _jade_lbl: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.030, 0.038, 0.022))
	_rng.seed = 20260719
	_build_backdrop()
	_build_background()
	_build_terrain()
	_build_platforms()
	_build_ceiling()
	_build_setpieces()
	_build_dressing()
	_build_foreground()
	_build_atmosphere()
	_build_fog_layers()
	_build_player()
	_build_golems()
	_build_jades()
	_build_exit_door()
	_build_camera()
	_build_ui()
	# a mild dim with a breath of green — the art keeps its painted browns;
	# the lantern's ADDED gold stays the brightest thing in the cave
	var grade := CanvasModulate.new()
	grade.color = AMBIENT
	add_child(grade)
	if OS.get_environment("R1_SHOT") != "":
		_self_screenshot(OS.get_environment("R1_SHOT"))


# ---------- shared little builders ----------

func _tex(prefix: String, idx: int) -> String:
	return "%s_%02d.png" % [prefix, idx]


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
		col := SOIL) -> void:
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


func _glow_light(host: Node2D, col: Color, energy: float, tsc: float) -> void:
	if host is Sprite2D:
		_bloom(host as Sprite2D, col, 0.18)
	if _glow_lights >= MAX_GLOW_LIGHTS:
		return
	_glow_lights += 1
	var l := PointLight2D.new()
	l.texture = _soft_glow_texture()
	l.color = col
	l.energy = energy * 0.7
	l.texture_scale = tsc * 1.8
	host.add_child(l)


func _bloom(host: Sprite2D, tint: Color, alpha: float) -> void:
	var g := Sprite2D.new()
	g.texture = _soft_glow_texture()
	g.show_behind_parent = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	g.modulate = Color(tint.r, tint.g, tint.b, alpha)
	var target_px := host.texture.get_width() * 2.2
	g.scale = Vector2.ONE * (target_px / 256.0)
	g.position = Vector2(0.0, -host.texture.get_height() * 0.18)
	host.add_child(g)


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


# ---------- backdrop / background ----------

func _build_backdrop() -> void:
	# screen-anchored vertical gradient: deep dark olive sinking to
	# near-black — the gloom, not a glow
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([BG_TOP,
			BG_TOP.lerp(BG_BOTTOM, 0.45), BG_BOTTOM])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)


## Bands move at cam*0.82 (far) and cam*0.6 (mid): an item at base x appears
## at base + factor*cam. For cam in [-450, 14150] the far band only ever
## samples [-820, 3000], mid [-990, 6100]. Populate those plus margin.
const FAR_L := -900.0
const FAR_R := 3200.0
const MID_L := -1050.0
const MID_R := 6300.0

func _build_background() -> void:
	_hills_far = Node2D.new()
	_hills_far.z_index = -8
	add_child(_hills_far)
	_hills_mid = Node2D.new()
	_hills_mid.z_index = -6
	add_child(_hills_mid)
	# FAR: the promo's TEETH FOREST — ranks of stalagmite silhouettes
	# receding into the gloom, two interleaved depths, with a few big soft
	# boulder masses looming between them
	_spike_forest(_hills_far, FAR_L, FAR_R, FLOOR_Y + 60.0, 0.40, 0.62,
			Color(SIL_FAR.r * 0.9, SIL_FAR.g * 0.9, SIL_FAR.b * 0.9),
			170.0, 280.0)
	_spike_forest(_hills_far, FAR_L + 90.0, FAR_R, FLOOR_Y + 45.0, 0.62, 0.9,
			Color(SIL_FAR.r * 1.2, SIL_FAR.g * 1.2, SIL_FAR.b * 1.2),
			260.0, 420.0)
	var fx := FAR_L + 300.0
	var fi := 0
	while fx < FAR_R:
		var b_id: int = [1, 4, 6, 7, 8, 2][fi % 6]
		var tex: Texture2D = load(BASE + _tex("bigrock", b_id))
		var sc := _rng.randf_range(0.85, 1.15)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = fi % 2 == 1
		s.position = Vector2(fx, FLOOR_Y + 40.0 - tex.get_height() * sc * 0.5)
		s.modulate = Color(SIL_FAR.r * 1.1, SIL_FAR.g * 1.1, SIL_FAR.b * 1.1)
		_hills_far.add_child(s)
		fx += _rng.randf_range(750.0, 1100.0)
		fi += 1
	# MID BAND VIGNETTES — composed silhouette groups on a rhythm: monolith
	# pair / spike grove / boulder family; each holds one faint gold glint
	var vx := MID_L + 250.0
	var vi := 0
	while vx < MID_R:
		var mdark := Color(SIL_MID.r * 0.75, SIL_MID.g * 0.75, SIL_MID.b * 0.75)
		if vi % 2 == 0:
			_mid_sprite(_tex("bigrock", [0, 6, 8][vi % 3]), vx + 100.0, 36.0,
					_rng.randf_range(1.0, 1.3), mdark, vi % 4 == 0)
		match vi % 3:
			0:  # monolith pair + seat boulder
				_mid_sprite(_tex("bigrock", [3, 5][vi % 2]), vx, 40.0,
						_rng.randf_range(0.7, 0.85), SIL_MID, vi % 2 == 0)
				_mid_sprite(_tex("rock", 32), vx + 160.0, 30.0,
						_rng.randf_range(0.5, 0.62), mdark, vi % 2 == 1)
				_mid_sprite(_tex("rock", 34), vx - 150.0, 22.0, 0.6, mdark)
			1:  # spike grove + one tall tooth
				_mid_sprite(_tex("combo", SPIKE_CLUSTERS[vi % 4]), vx, 40.0,
						_rng.randf_range(0.62, 0.78), SIL_MID, vi % 2 == 0)
				_mid_sprite(_tex("rock", [31, 37][vi % 2]), vx + 190.0, 30.0,
						_rng.randf_range(0.5, 0.65), mdark, vi % 2 == 1)
			2:  # boulder family
				_mid_sprite(_tex("combo", [5, 7, 10][vi % 3]), vx, 28.0,
						_rng.randf_range(0.6, 0.75), SIL_MID, vi % 2 == 0)
				_mid_sprite(_tex("rock", [15, 18][vi % 2]), vx + 170.0, 22.0,
						0.55, mdark, vi % 2 == 1)
		var fg := Sprite2D.new()
		fg.texture = _soft_glow_texture()
		fg.position = Vector2(vx + _rng.randf_range(-60.0, 60.0),
				FLOOR_Y - _rng.randf_range(30.0, 90.0))
		fg.scale = Vector2(1.0, 1.0)
		fg.modulate = Color(GOLD.r, GOLD.g, GOLD.b, 0.07)
		_hills_mid.add_child(fg)
		vx += _rng.randf_range(360.0, 500.0)
		vi += 1
	# distant ceiling teeth in both bands
	_teeth_row(_hills_far, FAR_L, FAR_R, ROOF_Y - 60.0, 0.55, 0.75,
			Color(SIL_FAR.r * 1.1, SIL_FAR.g * 1.1, SIL_FAR.b * 1.1))
	_teeth_row(_hills_mid, MID_L, MID_R, ROOF_Y - 40.0, 0.6, 0.85, SIL_MID)


## a bottom-anchored silhouette sprite in the MID parallax band
func _mid_sprite(tex_name: String, x: float, sink: float, sc: float,
		tint: Color, fh := false) -> Sprite2D:
	var tex: Texture2D = load(BASE + tex_name)
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(sc, sc)
	s.flip_h = fh
	s.position = Vector2(x, FLOOR_Y + sink - tex.get_height() * sc * 0.5)
	s.modulate = tint
	_hills_mid.add_child(s)
	return s


## a rank of floor teeth for a parallax band — stalagmite clusters and
## single spikes tiled tightly into a continuous silhouette skyline
func _spike_forest(band: Node2D, x0: float, x1: float, base_y: float,
		sc_lo: float, sc_hi: float, tint: Color,
		step_lo: float, step_hi: float) -> void:
	var x := x0 + _rng.randf_range(0.0, 100.0)
	var i := 0
	while x < x1:
		var use_cluster := i % 3 != 2
		var tex_name: String
		if use_cluster:
			tex_name = _tex("combo", SPIKE_CLUSTERS[i % 4])
		else:
			tex_name = _tex("rock", STALAG[i % 4])
		var tex: Texture2D = load(BASE + tex_name)
		var sc := _rng.randf_range(sc_lo, sc_hi) * (0.55 if not use_cluster else 1.0)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.position = Vector2(x, base_y - tex.get_height() * sc * 0.5)
		s.modulate = tint
		band.add_child(s)
		x += _rng.randf_range(step_lo, step_hi)
		i += 1


## distant ceiling teeth for a parallax band
func _teeth_row(band: Node2D, x0: float, x1: float, top_y: float,
		sc_lo: float, sc_hi: float, tint: Color) -> void:
	var x := x0 + _rng.randf_range(0.0, 120.0)
	var i := 0
	while x < x1:
		var t_id: int = STALACT[i % STALACT.size()]
		var tex: Texture2D = load(BASE + _tex("rock", t_id))
		var sc := _rng.randf_range(sc_lo, sc_hi)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.position = Vector2(x, top_y + tex.get_height() * sc * 0.5)
		s.modulate = tint
		band.add_child(s)
		x += _rng.randf_range(260.0, 400.0)
		i += 1


# ---------- terrain ----------

func _build_terrain() -> void:
	# THE SOIL: one near-black body under the whole walk
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, FLOOR_Y, FLOOR_Y + 900.0, 0, SOIL)
	_collider_rect(WORLD_L, WORLD_R, FLOOR_Y, FLOOR_Y + 120.0)
	# CAVERN END WALLS: dark columns past both edges
	_fill_rect(WORLD_L - 900.0, WORLD_L + 40.0, -1400.0, FLOOR_Y, 0)
	_collider_rect(WORLD_L - 60.0, WORLD_L + 40.0, FLOOR_Y - 900.0, FLOOR_Y)
	_fill_rect(WORLD_R - 40.0, WORLD_R + 900.0, -1400.0, FLOOR_Y, 0)
	_collider_rect(WORLD_R - 40.0, WORLD_R + 60.0, FLOOR_Y - 900.0, FLOOR_Y)
	# the walls end in STONE, not a cut line: pebble-stack columns leaning
	# on each face
	for wp: Array in [[WORLD_L - 10.0, 7, 1.6, false], [WORLD_L + 130.0, 18, 1.3, true],
			[WORLD_R + 10.0, 8, 1.6, true], [WORLD_R - 130.0, 19, 1.3, false]]:
		var wtex: Texture2D = load(BASE + _tex("floor", wp[1]))
		var wsc: float = wp[2]
		_sprite(_tex("floor", wp[1]),
				Vector2(wp[0], FLOOR_Y + 40.0 - wtex.get_height() * wsc * 0.5),
				wsc, 1, Color(0.28, 0.28, 0.26), wp[3])
	_prop(_tex("bigrock", 1), WORLD_L + 110.0, FLOOR_Y + 30.0, 0.42, 2,
			Color(0.32, 0.32, 0.30))
	_prop(_tex("bigrock", 7), WORLD_R - 110.0, FLOOR_Y + 30.0, 0.42, 2,
			Color(0.32, 0.32, 0.30), true)
	# THE GROUND BAND — staggered slab rows, silhouette-forward: dark against
	# the gloom, the walk row holding just enough light to read its brown
	_slab_row(FLOOR_Y + 40.0, 0.62, 0, Color(0.30, 0.30, 0.28))   # crest skyline
	_slab_row(FLOOR_Y + 82.0, 0.55, 2, Color(0.62, 0.62, 0.58))   # the walk row
	_slab_row(FLOOR_Y + 145.0, 0.50, 3, Color(0.40, 0.40, 0.37))
	_slab_row(FLOOR_Y + 212.0, 0.48, 4, Color(0.26, 0.26, 0.24))
	# THE PEBBLE STRIP (the promo's ground line): pebble-row pieces tiled
	# along the walk line — the floor SHE reads, riding the walk row's crest
	var strip_x := WORLD_L - 200.0
	var si := 0
	while strip_x < WORLD_R + 200.0:
		var sp_id: int = [22, 23][si % 2]
		var tex: Texture2D = load(BASE + _tex("floor", sp_id))
		var sc := _rng.randf_range(0.42, 0.52)
		var b := _rng.randf_range(0.48, 0.60)
		_sprite(_tex("floor", sp_id),
				Vector2(strip_x, FLOOR_Y + 34.0 - tex.get_height() * sc * 0.5),
				sc, 3, Color(b, b, b), _rng.randf() < 0.5)
		strip_x += tex.get_width() * sc * _rng.randf_range(0.72, 0.9)
		si += 1
	# THROUGH-ROW — kept LOW and sparse (Advika: the floor must never hide
	# a golem): a shallow scree lip, not a hedge
	_slab_row(FLOOR_Y + 195.0, 0.38, 6, Color(0.16, 0.16, 0.15),
			WORLD_L - 250.0, WORLD_R + 250.0, 0.72, 0.95)
	_slab_row(FLOOR_Y + 290.0, 0.5, 6, Color(0.10, 0.10, 0.09))   # deep front lip
	# TINY BLACK TEETH in the front row (the promo's foreground): short
	# spikes — ankle-height, they can never mask a golem
	var tx := WORLD_L - 200.0
	var ti := 0
	while tx < WORLD_R + 200.0:
		var tg_id: int = STALAG[ti % 4]
		var tex2: Texture2D = load(BASE + _tex("rock", tg_id))
		var tsc := _rng.randf_range(0.07, 0.13)
		_sprite(_tex("rock", tg_id),
				Vector2(tx, FLOOR_Y + 26.0 - tex2.get_height() * tsc * 0.42),
				tsc, 6, Color(0.055, 0.055, 0.05), _rng.randf() < 0.5)
		tx += _rng.randf_range(90.0, 200.0)
		ti += 1
	_rubble_mat()


## one staggered row of long slabs
func _slab_row(base_y: float, sc_base: float, z: int, tint: Color,
		x0 := WORLD_L - 250.0, x1 := WORLD_R + 250.0,
		step_lo := 0.55, step_hi := 0.72) -> void:
	var x := x0
	while x < x1:
		var si: int
		if _rng.randf() < 0.18:
			si = XL_SLABS[_rng.randi() % XL_SLABS.size()]
		elif _rng.randf() < 0.3:
			si = MOUNDS[_rng.randi() % MOUNDS.size()]
		else:
			si = LONG_SLABS[_rng.randi() % LONG_SLABS.size()]
		var tex: Texture2D = load(BASE + _tex("floor", si))
		var sc := sc_base * _rng.randf_range(0.78, 1.22)
		var h := tex.get_height() * sc
		var y := base_y + _rng.randf_range(-24.0, 24.0)
		var tj := _rng.randf_range(0.85, 1.12)
		var vt := Color(tint.r * tj, tint.g * tj, tint.b * tj)
		_sprite(_tex("floor", si), Vector2(x, y - h * 0.5), sc, z, vt,
				_rng.randf() < 0.5)
		x += tex.get_width() * sc * _rng.randf_range(step_lo, step_hi)


## the scree field: pebbles and small rocks at graded depths. The FRONT
## depth stays sparse and small — nothing tall enough to mask an enemy.
func _rubble_mat() -> void:
	var x := WORLD_L - 200.0
	while x < WORLD_R + 200.0:
		var t := _rng.randf()
		var pi: int
		if _rng.randf() < 0.62:
			pi = PEBBLES[_rng.randi() % PEBBLES.size()]
		else:
			pi = MED_ROCKS[_rng.randi() % MED_ROCKS.size()]
		var tex: Texture2D = load(BASE + _tex("rock", pi))
		var wave: float = clampf(0.5 + 0.28 * sin(x * 0.0021)
				+ 0.22 * sin(x * 0.0063 + 1.7), 0.0, 1.0)
		var sc := lerpf(0.10, 0.20, wave) * _rng.randf_range(0.75, 1.3)
		if t >= 0.45:
			sc *= 0.7   # the front depth shrinks — the walk line stays open
		var h := tex.get_height() * sc
		var base := FLOOR_Y + lerpf(4.0, 30.0, t)
		var b := lerpf(0.55, 0.20, t) * _rng.randf_range(0.86, 1.14)
		_sprite(_tex("rock", pi), Vector2(x, base - h * 0.5 + h * 0.06),
				sc, 4 if t < 0.45 else 6, Color(b, b, b), _rng.randf() < 0.5)
		x += tex.get_width() * sc * _rng.randf_range(0.85, 1.3)
	# woven accents: a half-sunk pebble pile or a lone small spike, on a
	# long rhythm, always in the BACK depth
	var ax := WORLD_L + _rng.randf_range(200.0, 450.0)
	while ax < WORLD_R:
		if _rng.randf() < 0.6:
			var pp: int = PEBBLE_PILES[_rng.randi() % PEBBLE_PILES.size()]
			_prop(_tex("floor", pp), ax, FLOOR_Y + 26.0,
					_rng.randf_range(0.28, 0.4), 4,
					Color(0.35, 0.35, 0.33), _rng.randf() < 0.5)
		else:
			var sg: int = STALAG[_rng.randi() % STALAG.size()]
			_prop(_tex("rock", sg), ax, FLOOR_Y + 18.0,
					_rng.randf_range(0.18, 0.26), 4,
					Color(0.28, 0.28, 0.26), _rng.randf() < 0.5)
		ax += _rng.randf_range(420.0, 760.0)


# ---------- platforms (the platformer spine) ----------

func _build_platforms() -> void:
	# Walkable = platform blocks + half-buried domes; big rocks stay decor.
	_dome_step(950.0, FLOOR_Y - 115.0)
	_pillar(1550.0, FLOOR_Y - 235.0, 0)
	# free-standing movers on the long gaps — the ride is part of the walk
	_moving_platform(3450.0, FLOOR_Y - 200.0, 8, "side", 220.0, 6.5)
	_moving_platform(7450.0, FLOOR_Y - 190.0, 6, "updown", -150.0, 5.5)
	_moving_platform(12480.0, FLOOR_Y - 210.0, 9, "side", -220.0, 6.0)
	for ai in ARC_XS.size():
		var amx: float = ARC_XS[ai]
		_dome_step(amx, FLOOR_Y - _rng.randf_range(108.0, 128.0), ai % 2 == 0)
		# the promo's climb: a grounded PILLAR carries the mid step, a small
		# floating slab hops the gap, the high step alternates tall pillar /
		# floating block
		_pillar(amx + 500.0, FLOOR_Y - 240.0, ai % 2, ai % 2 == 1)
		_float_slab(amx + 760.0, FLOOR_Y - 300.0, ai % 2 == 0)
		if ai % 2 == 0:
			_pillar(amx + 1000.0, FLOOR_Y - 355.0, (ai + 1) % 2, ai % 4 == 0)
		else:
			_block_platform(amx + 1000.0, FLOOR_Y - 355.0,
					PLAT_CHUNKY[ai % PLAT_CHUNKY.size()], ai % 2 == 0)
		# the step off the high point MOVES (Realm 1's signature)
		if ai % 2 == 0:
			_moving_platform(amx + 1440.0, FLOOR_Y - 300.0, PLAT_THIN[ai % 3],
					"updown", -130.0, 5.2)
		else:
			_moving_platform(amx + 1440.0, FLOOR_Y - 300.0, PLAT_THIN[ai % 3],
					"side", 200.0, 6.0)
		# a boulder MOUND at the arc's feet (the promo's rounded piles)
		_boulder_mound(amx - 320.0)
	# LONE HOP DOMES between the arcs (clear of the set-piece ground)
	var used: Array[float] = [950.0, 1550.0, 3450.0, 7450.0, 12480.0,
			6150.0, 6390.0, 12900.0, 13240.0, 13520.0]
	for amx in ARC_XS:
		for off in [0.0, 500.0, 1000.0, 1440.0]:
			used.append(amx + off)
	var hx := 700.0
	var hpi := 0
	while hx < WORLD_R - 700.0:
		var clear := true
		for ux in used:
			if absf(hx - ux) < 430.0:
				clear = false
				break
		if clear:
			_dome_step(hx, FLOOR_Y - _rng.randf_range(100.0, 135.0), hpi % 2 == 1)
			hpi += 1
		hx += _rng.randf_range(680.0, 980.0)


## a half-buried dome swelling out of the scree — the LOW step
func _dome_step(cx: float, top_y: float, fh := false) -> void:
	var d_id: int = DOMES[int(absf(cx)) % DOMES.size()]
	var tex: Texture2D = load(BASE + _tex("rock", d_id))
	var sc := (FLOOR_Y + 200.0 - top_y) / (tex.get_height() * 0.94)
	var h := tex.get_height() * sc
	var w := tex.get_width() * sc
	_sprite(_tex("rock", d_id), Vector2(cx, FLOOR_Y + 200.0 - h * 0.5),
			sc, 1, Color(0.52, 0.52, 0.49), fh)
	_collider_rect(cx - w * 0.24, cx + w * 0.24, top_y, top_y + 24.0, true)
	# a pebble or two perched on the crown — lived-on stone
	_prop(_tex("rock", PEBBLES[_rng.randi() % PEBBLES.size()]),
			cx - w * 0.1, top_y + 12.0, 0.14, 2, Color(0.5, 0.5, 0.47),
			_rng.randf() < 0.5)


## a PILLAR (the pack's promo grammar): vertical pebble-stack pieces tiled
## into a tower rising from the soil, capped with a thin slab — the cap is
## the platform. Black core, pale pebble rims: the art's own light.
func _pillar(cx: float, top_y: float, style := 0, fh := false) -> void:
	var col_ids: Array = [[18, 19], [7, 8]][style % 2]
	var seg: Texture2D = load(BASE + _tex("floor", col_ids[0]))
	var sc := 200.0 / seg.get_width() * _rng.randf_range(0.92, 1.05)
	var seg_h := seg.get_height() * sc
	var base_y := FLOOR_Y + 80.0
	var n := maxi(1, ceili((base_y - top_y - 20.0) / (seg_h * 0.86)))
	var y := base_y
	for i in n:
		var cid: int = col_ids[i % 2]
		var t: Texture2D = load(BASE + _tex("floor", cid))
		var h := t.get_height() * sc
		_sprite(_tex("floor", cid), Vector2(cx, y - h * 0.5), sc, 1,
				Color(0.55, 0.55, 0.52), fh if i % 2 == 0 else not fh)
		y -= h * 0.86
	# the cap slab, a touch wider than the shaft, top flush with top_y
	var cap_id: int = [6, 8][style % 2]
	var cap: Texture2D = load(BASE + _tex("plat", cap_id))
	var csc := 250.0 / cap.get_width()
	var ch := cap.get_height() * csc
	_sprite(_tex("plat", cap_id), Vector2(cx, top_y + ch * 0.5 - ch * 0.18),
			csc, 1, Color(0.42, 0.42, 0.40), fh)
	_collider_rect(cx - 112.0, cx + 112.0, top_y, top_y + 22.0, true)
	# a pebble perched on the cap
	_prop(_tex("rock", PEBBLES[_rng.randi() % PEBBLES.size()]),
			cx + _rng.randf_range(-60.0, 60.0), top_y + 10.0, 0.13, 2,
			Color(0.5, 0.5, 0.47), _rng.randf() < 0.5)


## a small floating slab fragment (the promo's lone hovering step)
func _float_slab(cx: float, top_y: float, fh := false) -> void:
	var f_id: int = [6, 11, 12, 13, 14][int(absf(cx)) % 5]
	var tex: Texture2D = load(BASE + _tex("floor", f_id))
	var sc := _rng.randf_range(0.62, 0.78)
	var w := tex.get_width() * sc
	var h := tex.get_height() * sc
	_sprite(_tex("floor", f_id), Vector2(cx, top_y + h * 0.5 - h * 0.10),
			sc, 1, Color(0.45, 0.45, 0.42), fh)
	_collider_rect(cx - w * 0.38, cx + w * 0.38, top_y, top_y + 18.0, true)


## a boulder MOUND (the promo's rounded piles): rounded rocks stacked and
## overlapped into one merged mass behind the walk line — decor only
func _boulder_mound(cx: float, z := 3) -> void:
	var ids: Array = [15, 16, 17, 18, 23, 24]
	var n := 3 + (_rng.randi() % 2)
	var x := cx
	for i in n:
		var r_id: int = ids[_rng.randi() % ids.size()]
		var tex: Texture2D = load(BASE + _tex("rock", r_id))
		var sc := _rng.randf_range(0.30, 0.5) * (1.25 if i == 1 else 1.0)
		var b := _rng.randf_range(0.36, 0.5)
		_sprite(_tex("rock", r_id),
				Vector2(x, FLOOR_Y + 24.0 - tex.get_height() * sc * 0.32
				+ _rng.randf_range(0.0, 12.0)), sc, z, Color(b, b, b),
				_rng.randf() < 0.5)
		x += tex.get_width() * sc * 0.55


## a floating chunky block platform — dark stone, rim of light
func _block_platform(cx: float, top_y: float, p_id: int, fh := false) -> void:
	var tex: Texture2D = load(BASE + _tex("plat", p_id))
	var target_w := 300.0
	var sc := target_w / tex.get_width()
	var h := tex.get_height() * sc
	_sprite(_tex("plat", p_id), Vector2(cx, top_y + h * 0.5 - h * 0.055),
			sc, 1, Color(0.50, 0.50, 0.47), fh)
	_collider_rect(cx - target_w * 0.42, cx + target_w * 0.42, top_y,
			top_y + 24.0, true)
	# perched pebbles + an occasional small spike — grouped, grounded
	_prop(_tex("rock", PEBBLES[_rng.randi() % PEBBLES.size()]),
			cx + target_w * 0.22, top_y + 10.0, 0.13, 2,
			Color(0.5, 0.5, 0.47), _rng.randf() < 0.5)
	if _rng.randf() < 0.5:
		_prop(_tex("rock", STALAG[_rng.randi() % STALAG.size()]),
				cx - target_w * 0.24, top_y + 10.0, 0.14, 2,
				Color(0.34, 0.34, 0.32), _rng.randf() < 0.5)


## a thin slat platform — a narrow shelf off the high path
func _slat_platform(cx: float, top_y: float, p_id: int, fh := false) -> void:
	var tex: Texture2D = load(BASE + _tex("plat", p_id))
	var target_w := 230.0
	var sc := target_w / tex.get_width()
	var h := tex.get_height() * sc
	_sprite(_tex("plat", p_id), Vector2(cx, top_y + h * 0.5 - h * 0.10),
			sc, 1, Color(0.50, 0.50, 0.47), fh)
	_collider_rect(cx - target_w * 0.4, cx + target_w * 0.4, top_y,
			top_y + 20.0, true)


## a MOVING platform — Realm 1's signature. AnimatableBody2D with
## sync_to_physics, driven by a looping sine tween, so she rides it.
## motion: "side" / "updown".
func _moving_platform(cx: float, top_y: float, p_id: int, motion: String,
		dist: float, period: float) -> void:
	var tex: Texture2D = load(BASE + _tex("plat", p_id))
	var target_w := 250.0
	var sc := target_w / tex.get_width()
	var h := tex.get_height() * sc
	var body := AnimatableBody2D.new()
	body.sync_to_physics = true
	body.position = Vector2(cx, top_y)
	add_child(body)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(sc, sc)
	spr.position = Vector2(0.0, h * 0.5 - h * 0.08)
	spr.z_index = 1
	spr.modulate = Color(0.50, 0.50, 0.47)
	body.add_child(spr)
	# a pebble riding the mover — telegraphs the motion
	var pt: Texture2D = load(BASE + _tex("rock", PEBBLES[_rng.randi() % PEBBLES.size()]))
	var pb := Sprite2D.new()
	pb.texture = pt
	pb.scale = Vector2(0.13, 0.13)
	pb.position = Vector2(target_w * 0.18, 6.0 - pt.get_height() * 0.13 * 0.4)
	pb.z_index = 2
	pb.modulate = Color(0.5, 0.5, 0.47)
	body.add_child(pb)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(target_w * 0.8, 20.0)
	cs.shape = rect
	cs.position = Vector2(0.0, 10.0)
	cs.one_way_collision = true
	body.add_child(cs)
	var delta := Vector2(dist, 0.0) if motion == "side" else Vector2(0.0, dist)
	var tw := create_tween().set_loops()
	tw.tween_property(body, "position", Vector2(cx, top_y) + delta, period * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(body, "position", Vector2(cx, top_y), period * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------- ceiling ----------

func _build_ceiling() -> void:
	# ONE continuous roof: gradient dark above the line, a hanging slab
	# curtain, stalactites — pale teeth deep behind, black fingers in front
	var roof_deep := Color(0.022, 0.020, 0.014)
	var grad_p := Polygon2D.new()
	grad_p.polygon = PackedVector2Array([
			Vector2(WORLD_L - 900.0, -820.0), Vector2(WORLD_R + 900.0, -820.0),
			Vector2(WORLD_R + 900.0, ROOF_Y), Vector2(WORLD_L - 900.0, ROOF_Y)])
	grad_p.vertex_colors = PackedColorArray([roof_deep, roof_deep, SOIL, SOIL])
	grad_p.z_index = 0
	add_child(grad_p)
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, -1400.0, -820.0, 0, roof_deep)
	_slab_row_hang(ROOF_Y - 30.0, 0.50, 1, Color(0.48, 0.48, 0.44), 0.48, 0.60)
	_slab_row_hang(ROOF_Y - 18.0, 0.55, 1, Color(0.26, 0.26, 0.24), 0.44, 0.55)
	_slab_row_hang(ROOF_Y - 8.0, 0.62, 2, Color(0.115, 0.115, 0.105), 0.40, 0.5)
	# stalactites end to end — alternating pale (behind) and near-black
	# (front), the two-depth teeth
	var stx := WORLD_L - 350.0
	var sti := 0
	while stx < WORLD_R + 350.0:
		var st_id: int = STALACT[sti % STALACT.size()]
		var st_sc := _rng.randf_range(0.55, 0.85)
		var dark_tooth := sti % 3 != 1
		var tex: Texture2D = load(BASE + _tex("rock", st_id))
		_sprite(_tex("rock", st_id),
				Vector2(stx, ROOF_Y + 8.0 + tex.get_height() * st_sc * 0.5),
				st_sc, 3 if dark_tooth else 1,
				Color(0.13, 0.13, 0.12) if dark_tooth else Color(0.55, 0.55, 0.50),
				_rng.randf() < 0.5)
		stx += _rng.randf_range(330.0, 430.0)
		sti += 1


## the slab row upside down, for the roof curtain
func _slab_row_hang(base_y: float, sc_base: float, z: int, tint: Color,
		step_lo: float, step_hi: float) -> void:
	var x := WORLD_L - 250.0
	while x < WORLD_R + 250.0:
		var si: int = LONG_SLABS[_rng.randi() % LONG_SLABS.size()]
		if _rng.randf() < 0.2:
			si = MOUNDS[_rng.randi() % MOUNDS.size()]
		var tex: Texture2D = load(BASE + _tex("floor", si))
		var sc := sc_base * _rng.randf_range(0.8, 1.2)
		var h := tex.get_height() * sc
		var y := base_y + _rng.randf_range(-20.0, 20.0)
		var tj := _rng.randf_range(0.85, 1.1)
		_sprite(_tex("floor", si), Vector2(x, y + h * 0.5),
				sc, z, Color(tint.r * tj, tint.g * tj, tint.b * tj),
				_rng.randf() < 0.5, true)
		x += tex.get_width() * sc * _rng.randf_range(step_lo, step_hi)


# ---------- set-pieces (RARE) ----------

func _build_setpieces() -> void:
	# 1 — THE MAW (over the zone A walk): the cave-mouth mass hanging off
	# the roof, teeth dropping into open air
	var maw: Texture2D = load(BASE + _tex("combo", 2))
	var msc := 1.15
	_sprite(_tex("combo", 2), Vector2(1200.0,
			ROOF_Y + 40.0 + maw.get_height() * msc * 0.5 - 30.0), msc, 2,
			Color(0.30, 0.30, 0.28))
	# 2 — THE STANDING STONES (the breather between arcs 2 and 3): two
	# monoliths rooted in the scree, one faint gold seam at their feet
	var stones_x := 6150.0
	_prop(_tex("bigrock", 3), stones_x, FLOOR_Y + 50.0, 0.72, 3,
			Color(0.48, 0.48, 0.45))
	_prop(_tex("bigrock", 5), stones_x + 240.0, FLOOR_Y + 44.0, 0.60, 4,
			Color(0.38, 0.38, 0.36), true)
	_prop(_tex("rock", 34), stones_x - 190.0, FLOOR_Y + 26.0, 0.55, 4,
			Color(0.42, 0.42, 0.40))
	var seam := _prop(_tex("floor", 15), stones_x + 90.0, FLOOR_Y + 34.0,
			0.4, 4, Color(0.55, 0.55, 0.50))
	_glow_light(seam, GOLD, 0.30, 1.2)
	# 3 — THE SPIKE GARDEN (the last stretch before the door): stalagmite
	# clusters the path threads between
	var sg_x := 12900.0
	_prop(_tex("combo", 12), sg_x, FLOOR_Y + 44.0, 0.62, 3,
			Color(0.52, 0.52, 0.48))
	_prop(_tex("combo", 14), sg_x + 340.0, FLOOR_Y + 40.0, 0.5, 6,
			Color(0.15, 0.15, 0.14), true)
	_prop(_tex("combo", 15), sg_x + 620.0, FLOOR_Y + 46.0, 0.55, 3,
			Color(0.40, 0.40, 0.37))


# ---------- dressing: grouped grounded assemblies, cave pack only ----------

func _build_dressing() -> void:
	# rotating floor motifs down the whole walk: dome + pebbles / spike
	# pair / pebble field with a gold glint / rock pile + leaning shard.
	# All in the BACK depths — the walk line stays open for enemies to read.
	var dmx := WORLD_L + 550.0
	var dmi := 0
	while dmx < WORLD_R - 500.0:
		match dmi % 4:
			0:  # a rounded boulder mound (the promo's piles)
				_boulder_mound(dmx, 3 if dmi % 2 == 0 else 4)
			1:  # spike pair rising out of the scree
				_prop(_tex("rock", STALAG[dmi % 4]), dmx, FLOOR_Y + 18.0,
						_rng.randf_range(0.3, 0.4), 3, Color(0.40, 0.40, 0.37))
				_prop(_tex("rock", STALAG[(dmi + 1) % 4]), dmx + 110.0,
						FLOOR_Y + 16.0, _rng.randf_range(0.2, 0.26), 4,
						Color(0.30, 0.30, 0.28), true)
			2:  # pebble field with one faint gold glint
				_prop(_tex("floor", PEBBLE_PILES[dmi % 4]), dmx,
						FLOOR_Y + 28.0, _rng.randf_range(0.34, 0.44), 3,
						Color(0.45, 0.45, 0.42), dmi % 2 == 1)
				var gg := _prop(_tex("rock", PEBBLES[(dmi + 1) % 5]),
						dmx + 130.0, FLOOR_Y + 14.0, 0.16, 4,
						Color(0.7, 0.62, 0.45))
				_glow_light(gg, GOLD, 0.20, 0.9)
			3:  # rock pile + leaning shard silhouette
				_prop(_tex("combo", ROCK_PILES[dmi % ROCK_PILES.size()]), dmx,
						FLOOR_Y + 38.0, _rng.randf_range(0.4, 0.5), 3,
						Color(0.42, 0.42, 0.40), dmi % 2 == 0)
				_prop(_tex("rock", [10, 36][dmi % 2]), dmx + 190.0,
						FLOOR_Y + 20.0, _rng.randf_range(0.26, 0.34), 4,
						Color(0.30, 0.30, 0.28), dmi % 2 == 1)
		dmx += _rng.randf_range(620.0, 900.0)
		dmi += 1


func _build_foreground() -> void:
	# darkest silhouettes hugging the bottom frame — stone cut by the frame
	var fore := Color(0.075, 0.075, 0.070)
	var fsx := WORLD_L + 250.0
	var fsi := 0
	while fsx < WORLD_R:
		var fs_id: int = [32, 23, 19, 24, 33, 12][fsi % 6]
		var tex: Texture2D = load(BASE + _tex("rock", fs_id))
		var sc := _rng.randf_range(0.6, 0.75)
		_sprite(_tex("rock", fs_id), Vector2(fsx, 840.0 - tex.get_height() * sc * 0.5),
				sc, 8, fore, _rng.randf() < 0.5)
		fsx += _rng.randf_range(700.0, 980.0)
		fsi += 1
	# continuous bottom anchor band
	var x := WORLD_L - 200.0
	while x < WORLD_R + 200.0:
		var pi: int = MED_ROCKS[_rng.randi() % MED_ROCKS.size()]
		var tex: Texture2D = load(BASE + _tex("rock", pi))
		var sc := _rng.randf_range(0.5, 0.72)
		_sprite(_tex("rock", pi), Vector2(x, 830.0 - tex.get_height() * sc * 0.5),
				sc, 9, fore, _rng.randf() < 0.5)
		x += tex.get_width() * sc * 0.6


# ---------- atmosphere ----------

var _fog_bands: Array = []
func _build_fog_layers() -> void:
	# THE GLOOM: drifting cumulus masses of muted green behind the gameplay —
	# subtle (Advika: dark green, not bright), the rock reads darker still
	for cfg: Array in [[-7, 0.055, 1.5, 5.0], [-5, 0.045, 1.1, 7.5], [7, 0.025, 1.8, 4.0]]:
		var band := Node2D.new()
		band.z_index = int(cfg[0])
		add_child(band)
		var spacing := 780.0 * (cfg[2] as float)
		var x := WORLD_L - 1400.0
		while x < WORLD_R + 1400.0:
			for p in 3:
				var f := Sprite2D.new()
				f.texture = _soft_glow_texture()
				f.position = Vector2(x + _rng.randf_range(-260.0, 260.0),
						FLOOR_Y - _rng.randf_range(80.0, 420.0))
				var ps := _rng.randf_range(0.8, 1.6) * (cfg[2] as float)
				f.scale = Vector2(ps * 2.6, ps * 1.7)
				f.modulate = Color(FOG_TINT.r, FOG_TINT.g, FOG_TINT.b,
						(cfg[1] as float) * _rng.randf_range(0.7, 1.3))
				band.add_child(f)
			x += spacing
		_fog_bands.append([band, cfg[3] as float, spacing])
	# LIGHT POOLS — dim green blooms high in the air, sparse
	var px := WORLD_L - 400.0
	while px < WORLD_R + 400.0:
		var pool := Sprite2D.new()
		pool.texture = _soft_glow_texture()
		pool.position = Vector2(px + _rng.randf_range(-200.0, 200.0),
				_rng.randf_range(-240.0, 40.0))
		pool.scale = Vector2(_rng.randf_range(3.2, 4.6), _rng.randf_range(2.6, 3.8))
		pool.z_index = -6
		pool.modulate = Color(POOL_GREEN.r, POOL_GREEN.g, POOL_GREEN.b,
				_rng.randf_range(0.06, 0.10))
		add_child(pool)
		px += _rng.randf_range(1800.0, 2600.0)


var _fogs: Array[Sprite2D] = []
func _build_atmosphere() -> void:
	# local fog banks: generated soft glows, muted green, faint
	var nfog := int((WORLD_R - WORLD_L + 1800.0) / 950.0) + 1
	for i in nfog:
		var f := Sprite2D.new()
		f.texture = _soft_glow_texture()
		f.position = Vector2(WORLD_L - 900.0 + i * 950.0,
				FLOOR_Y - _rng.randf_range(60.0, 280.0))
		f.scale = Vector2(_rng.randf_range(2.4, 3.6), _rng.randf_range(1.2, 1.8))
		f.modulate = Color(HAZE_GREEN.r, HAZE_GREEN.g, HAZE_GREEN.b,
				_rng.randf_range(0.05, 0.08))
		f.z_index = -4 if i % 2 == 0 else 6
		add_child(f)
		_fogs.append(f)
	# drifting dust motes — the cave's slow gold, sparse
	var motes := CPUParticles2D.new()
	motes.texture = _soft_glow_texture()
	motes.amount = int((WORLD_R - WORLD_L) / 550.0)
	motes.lifetime = 16.0
	motes.preprocess = 16.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2((WORLD_R - WORLD_L) * 0.5 + 300.0, 520.0)
	motes.direction = Vector2(1, -0.1)
	motes.spread = 14.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 26.0
	motes.scale_amount_min = 0.02
	motes.scale_amount_max = 0.05
	motes.color = Color(1.0, 0.88, 0.6, 0.35)
	motes.position = Vector2((WORLD_L + WORLD_R) * 0.5, FLOOR_Y - 260.0)
	motes.z_index = 6
	add_child(motes)
	# corner vignette — neutral black
	var cl := CanvasLayer.new()
	cl.layer = 15
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0),
			Color(0.0, 0.0, 0.0, 0.34)])
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


# ---------- player / golems / jades ----------

func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = SPAWN
	_curi.scale = Vector2(0.24, 0.24)
	_curi.z_index = 5   # in front of props (<=4), behind fore silhouettes (8)
	add_child(_curi)
	_lives = LIVES_HUD.instantiate() as LivesHUD
	_lives.eye_scale = 0.22
	_lives.eye_spacing = 112.0
	add_child(_lives)
	_lives.reset(STARTING_LIVES)
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


# Golem guards on the floor between the arcs. Size carries the old realm's
# golem:hero proportion (0.4 : 0.17) to this hero scale (0.24) -> 0.55.
const GOLEM_SCALE := 0.55
const GOLEM_DETECT := 260.0
const GOLEM_SPAWN_X: Array[float] = [1900.0, 3400.0, 5150.0, 7000.0,
		8300.0, 9500.0, 10500.0, 12200.0]

func _build_golems() -> void:
	for wx in GOLEM_SPAWN_X:
		var g: CharacterBody2D = GOLEM_SCENE.instantiate()
		g.ball_scene = GOLEM_BALL_SCENE
		g.scale = Vector2(GOLEM_SCALE, GOLEM_SCALE)
		g.detect_range = GOLEM_DETECT
		g.position = Vector2(wx, FLOOR_Y - 60.0)
		# in front of the whole floor stack (through-row included) — a guard
		# must never be masked by scenery (Advika)
		g.z_index = 7
		add_child(g)
		if g.has_method("set_home"):
			g.set_home(wx)


# Jades ride the high path: each arc's mid + high block + mover, plus a few
# floor strays on the long gaps
func _build_jades() -> void:
	var spots: Array[Vector2] = [
		Vector2(950.0, FLOOR_Y - 165.0),
		Vector2(1550.0, FLOOR_Y - 285.0),
	]
	for ai in ARC_XS.size():
		var amx: float = ARC_XS[ai]
		spots.append(Vector2(amx + 500.0, FLOOR_Y - 290.0))
		spots.append(Vector2(amx + 1000.0, FLOOR_Y - 405.0))
		spots.append(Vector2(amx + 1440.0, FLOOR_Y - 350.0))
	for fx: float in [3300.0, 7600.0, 12500.0, 13600.0]:
		spots.append(Vector2(fx, FLOOR_Y - 55.0))
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


# ---------- exit / camera / ui ----------

func _build_exit_door() -> void:
	var arch: Texture2D = load("res://assets/scenes/hub/door_arch.png")
	var root := Node2D.new()
	root.name = "ExitDoor"
	root.position = Vector2(WORLD_R - 420.0,
			FLOOR_Y + 8.0 - arch.get_height() * 0.5)
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
	area.door_id = "Realm1RebuildExit"
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
	cl.layer = 20
	add_child(cl)
	var lbl := Label.new()
	lbl.text = "R1 CAVERN REBUILD — walk right →   (R restart · ESC hub)"
	lbl.position = Vector2(16, 12)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.86, 0.72, 0.6))
	cl.add_child(lbl)
	_jade_lbl = Label.new()
	_jade_lbl.text = "0 / %d" % _jade_total
	_jade_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_jade_lbl.position = Vector2(-140.0, 12.0)
	_jade_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6, 0.75))
	cl.add_child(_jade_lbl)


# ---------- running ----------

var _t := 0.0
func _process(delta: float) -> void:
	_t += delta
	for i in _fogs.size():
		_fogs[i].position.x += sin(_t * 0.11 + i * 1.7) * 0.35
	for i in _fog_bands.size():
		var band: Node2D = _fog_bands[i][0]
		var speed: float = _fog_bands[i][1]
		var spacing: float = _fog_bands[i][2]
		band.position.x = fmod(_t * speed, spacing)
	if _cam != null:
		_hills_far.position.x = _cam.global_position.x * 0.82
		_hills_mid.position.x = _cam.global_position.x * 0.6
		if not _freeze_cam:
			var target := Vector2(
					clampf(_curi.global_position.x, WORLD_L + 600.0, WORLD_R - 350.0),
					clampf(_curi.global_position.y - 110.0, -180.0, FLOOR_Y - 190.0))
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
	if event.is_action_pressed("interact") and _at_exit and _exit_door != null:
		_leaving = true
		_exit_door.trigger()
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _self_screenshot(path: String) -> void:
	if OS.get_environment("R1_SHOT_X") != "":
		_curi.position = Vector2(float(OS.get_environment("R1_SHOT_X")), FLOOR_Y - 160.0)
		_curi.velocity = Vector2.ZERO
		_cam.position = Vector2(_curi.position.x, FLOOR_Y - 190.0)
	if OS.get_environment("R1_SHOT_CAMY") != "":
		_cam.position.y = float(OS.get_environment("R1_SHOT_CAMY"))
		_freeze_cam = true
	await get_tree().create_timer(1.0).timeout
	print("SHOT curi=", _curi.global_position)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
