extends Node2D
## REALM 1 REBUILD — CRIMSON HOLLOW, rebuilt on Realm 3's proven grammar with
## Maaot's "Cave Assets" pack (assets/realms/realm1_cavern/, sliced by
## tools/slice_cave_pack.gd — neutral dark brown, no hue shift: the warm
## crimson grade + ember glows below do ALL the warming in-scene).
## Construction laws carried from R2/R3:
##   - terrain = near-black SOIL body + staggered rows of the pack's long
##     slabs, value hierarchy strict (far darkest -> mid -> gameplay lit)
##   - a RUBBLE MAT instead of R3's meadow: every pebble/small rock picks its
##     own depth (tint slides lit->dark, z follows) — a continuous scree
##     field she wades along, never a flat strip
##   - platforms = the pack's PLATFORM BLOCKS only (chunky floats + thin
##     slats); big rocks/monoliths are DECOR, never steps (R3's law)
##   - low steps = half-buried DOMES swelling out of the rubble
##   - props live in grouped grounded assemblies; set-pieces stay RARE
##   - ONE roof line end to end; above it rock fades to near-black
## MOOD: Realm 1's own — the ember cave. Deep crimson-brown darks, warm
## grade, EMBER / GOLD / CRIMSON glow accents (the realm's coals). Purple
## stays Curiosity's.
## PLATFORMER: climb arcs low->mid->high, lone hop domes between, golem
## guards on the floor, jades riding the high path (Advika: keep both).
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
const ROOF_Y := -380.0   # ONE ceiling line, end to end (R3's law)
# anchor x of each climbing arc down the walk (low dome -> mid -> high)
const ARC_XS: Array[float] = [2200.0, 4400.0, 6600.0, 8800.0, 11000.0]

# CRIMSON HOLLOW'S DARKNESS RECIPE — R3's value ladder hue-shifted to deep
# ember brown-red. The pack's art is neutral; these tints + the warm grade
# are the realm's color. Value hierarchy strict: far silhouettes darkest ->
# mid dark -> gameplay lit. Glows are the cave's coals: ember orange, lantern
# gold, a rare crimson — never cool hues (teal is R3's, violet is hers).
const SOIL := Color(0.045, 0.020, 0.016)          # near-black earth body
const BG_TOP := Color(0.185, 0.072, 0.052)        # backdrop gradient, deep ember
const BG_BOTTOM := Color(0.070, 0.026, 0.020)
const SIL_FAR := Color(0.095, 0.040, 0.030)       # darkest, flattest
const SIL_MID := Color(0.150, 0.064, 0.048)       # midground silhouettes
const ROCK_CREST := Color(0.42, 0.30, 0.26)       # skyline row behind the floor
const ROCK_LIT := Color(0.98, 0.80, 0.68)         # the lit row she walks against
const ROCK_MID := Color(0.58, 0.42, 0.35)
const ROCK_DARK := Color(0.30, 0.20, 0.165)
const ROCK_THROUGH := Color(0.155, 0.10, 0.082)   # in front of her feet
const ROCK_LIP := Color(0.095, 0.060, 0.048)      # deepest front lip
const EMBER := Color(1.0, 0.50, 0.22)             # coal orange
const GOLD := Color(1.0, 0.80, 0.45)              # lantern gold
const CRIMSON := Color(1.0, 0.30, 0.16)           # the rare hot red
const AMBIENT := Color(0.86, 0.56, 0.46)          # the warm grade over the world
const FOG_TINT := Color(0.38, 0.18, 0.12)         # haze bands: ember dark, faint
const MASS_FILL := Color(0.030, 0.013, 0.010)     # set-piece interiors, hole-black
const MAX_GLOW_LIGHTS := 20
const MOSS_FOG := "res://assets/realms/realm2_moss/fog.png"
const MOSS_SPORE := "res://assets/realms/realm2_moss/spore.png"

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
	RenderingServer.set_default_clear_color(Color(0.06, 0.024, 0.018))
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
	# the warm dim — the backdrop CanvasLayer stays unaffected, the lantern's
	# ADDED light stays the one bright thing in the dark
	var grade := CanvasModulate.new()
	grade.color = AMBIENT
	add_child(grade)
	if OS.get_environment("R1_SHOT") != "":
		_self_screenshot(OS.get_environment("R1_SHOT"))


# ---------- shared little builders (R3's, verbatim manners) ----------

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
	# fake bloom first (web renderer has no 2D glow) — this makes a coal read
	# as a light source instead of a tinted sprite
	if host is Sprite2D:
		_bloom(host as Sprite2D, col, 0.22)
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
	# screen-anchored vertical gradient: deep ember sinking to near-black.
	# No bright band — the coals carry the light.
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
	# FAR: a monolith-and-boulder skyline, darkest + flattest — the cave
	# recedes into ranked stone, all the way back
	var fx := FAR_L + 100.0
	var fi := 0
	while fx < FAR_R:
		var b_id: int = [1, 4, 6, 7, 8, 2][fi % 6]
		var tex: Texture2D = load(BASE + _tex("bigrock", b_id))
		var sc := _rng.randf_range(0.85, 1.2)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = fi % 2 == 1
		s.position = Vector2(fx, FLOOR_Y + 40.0 - tex.get_height() * sc * 0.5)
		s.modulate = Color(SIL_FAR.r * 1.15, SIL_FAR.g * 1.15, SIL_FAR.b * 1.15)
		_hills_far.add_child(s)
		fx += _rng.randf_range(420.0, 640.0)
		fi += 1
	# far standing spires threading the skyline gaps, with a rare ember
	# glint at a foot — distant coals breathing in the dark
	var gx := FAR_L + 260.0
	var gi := 0
	while gx < FAR_R:
		var sp_id: int = [3, 5][gi % 2]
		var tex: Texture2D = load(BASE + _tex("bigrock", sp_id))
		var sc := _rng.randf_range(0.5, 0.72)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.rotation_degrees = (1.0 if _rng.randf() < 0.5 else -1.0) \
				* _rng.randf_range(1.5, 4.0)
		s.position = Vector2(gx, FLOOR_Y + 30.0 - tex.get_height() * sc * 0.5)
		s.modulate = Color(SIL_FAR.r * 1.4, SIL_FAR.g * 1.4, SIL_FAR.b * 1.4)
		_hills_far.add_child(s)
		if gi % 3 == 0:
			var g := Sprite2D.new()
			g.texture = _soft_glow_texture()
			g.position = Vector2(gx + _rng.randf_range(-40.0, 40.0), FLOOR_Y - 40.0)
			g.scale = Vector2(0.8, 0.8)
			g.modulate = Color(EMBER.r, EMBER.g, EMBER.b, 0.14)
			_hills_far.add_child(g)
		gx += _rng.randf_range(480.0, 700.0)
		gi += 1
	# MID BAND VIGNETTES — composed set-pieces on a rhythm, each one
	# overlapping silhouette group with one warm glint, then a breathing gap:
	# a monolith pair / a spike grove / a boulder family with a coal seam
	var vx := MID_L + 250.0
	var vi := 0
	while vx < MID_R:
		var mlit := Color(SIL_MID.r * 1.3, SIL_MID.g * 1.3, SIL_MID.b * 1.3)
		var mdark := Color(SIL_MID.r * 0.8, SIL_MID.g * 0.8, SIL_MID.b * 0.8)
		# a darker backdrop giant looming behind every second vignette
		if vi % 2 == 0:
			_mid_sprite(_tex("bigrock", [0, 6, 8][vi % 3]), vx + 100.0, 36.0,
					_rng.randf_range(1.0, 1.3), mdark, vi % 4 == 0)
		match vi % 3:
			0:  # monolith pair: tall stone + short leaner + seat boulder
				_mid_sprite(_tex("bigrock", [3, 5][vi % 2]), vx, 40.0,
						_rng.randf_range(0.7, 0.85), SIL_MID, vi % 2 == 0)
				_mid_sprite(_tex("rock", 32), vx + 160.0, 30.0,
						_rng.randf_range(0.5, 0.62), mdark, vi % 2 == 1)
				_mid_sprite(_tex("rock", 34), vx - 150.0, 22.0, 0.6, mdark)
			1:  # spike grove: a stalagmite cluster + one tall tooth
				_mid_sprite(_tex("combo", SPIKE_CLUSTERS[vi % 4]), vx, 40.0,
						_rng.randf_range(0.62, 0.78), SIL_MID, vi % 2 == 0)
				_mid_sprite(_tex("rock", [31, 37][vi % 2]), vx + 190.0, 30.0,
						_rng.randf_range(0.5, 0.65), mdark, vi % 2 == 1)
			2:  # boulder family on a coal seam — the warm heart vignette
				_mid_sprite(_tex("combo", [5, 7, 10][vi % 3]), vx, 28.0,
						_rng.randf_range(0.6, 0.75), mlit, vi % 2 == 0)
				_mid_sprite(_tex("rock", [15, 18][vi % 2]), vx + 170.0, 22.0,
						0.55, mdark, vi % 2 == 1)
		# every vignette holds one soft warm glint — the cave is alive with
		# buried fire, ember leading, gold rare
		var fg := Sprite2D.new()
		fg.texture = _soft_glow_texture()
		fg.position = Vector2(vx + _rng.randf_range(-60.0, 60.0),
				FLOOR_Y - _rng.randf_range(30.0, 90.0))
		fg.scale = Vector2(1.0, 1.0)
		var ghue: Color = [EMBER, EMBER, GOLD][vi % 3]
		fg.modulate = Color(ghue.r, ghue.g, ghue.b, 0.13)
		_hills_mid.add_child(fg)
		vx += _rng.randf_range(360.0, 500.0)
		vi += 1
	# distant ceiling teeth in both bands — heads buried behind the roof
	# fill, so windows between the roof's fingers show dark depth, never
	# bare gradient
	_teeth_row(_hills_far, FAR_L, FAR_R, ROOF_Y - 60.0, 0.55, 0.75,
			Color(SIL_FAR.r * 1.15, SIL_FAR.g * 1.15, SIL_FAR.b * 1.15))
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


## distant ceiling teeth for a parallax band: even rhythm, varied length,
## heads anchored above top_y so they always connect upward into the dark
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
	# THE SOIL: one near-black body under the whole walk. Art overshoots the
	# camera clamps; colliders stop at the world edge.
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, FLOOR_Y, FLOOR_Y + 900.0, 0, SOIL)
	_collider_rect(WORLD_L, WORLD_R, FLOOR_Y, FLOOR_Y + 120.0)
	# CAVERN END WALLS: dark columns past both edges — the camera's widest
	# framing at the clamps still lands inside solid dark
	_fill_rect(WORLD_L - 900.0, WORLD_L + 40.0, -1400.0, FLOOR_Y, 0)
	_collider_rect(WORLD_L - 60.0, WORLD_L + 40.0, FLOOR_Y - 900.0, FLOOR_Y)
	_fill_rect(WORLD_R - 40.0, WORLD_R + 900.0, -1400.0, FLOOR_Y, 0)
	_collider_rect(WORLD_R - 40.0, WORLD_R + 60.0, FLOOR_Y - 900.0, FLOOR_Y)
	# the walls end in STONE, not a cut line: pebble-stack columns leaning on
	# each face, feet in the soil, heads tucked behind the roof band
	for wp: Array in [[WORLD_L - 10.0, 7, 1.6, false], [WORLD_L + 130.0, 18, 1.3, true],
			[WORLD_R + 10.0, 8, 1.6, true], [WORLD_R - 130.0, 19, 1.3, false]]:
		var wtex: Texture2D = load(BASE + _tex("floor", wp[1]))
		var wsc: float = wp[2]
		_sprite(_tex("floor", wp[1]),
				Vector2(wp[0], FLOOR_Y + 40.0 - wtex.get_height() * wsc * 0.5),
				wsc, 1, Color(0.30, 0.21, 0.18), wp[3])
	_prop(_tex("bigrock", 1), WORLD_L + 110.0, FLOOR_Y + 30.0, 0.42, 2,
			Color(0.40, 0.28, 0.24))
	_prop(_tex("bigrock", 7), WORLD_R - 110.0, FLOOR_Y + 30.0, 0.42, 2,
			Color(0.40, 0.28, 0.24), true)
	# THE GROUND BAND — R2's depth-stack recipe with the pack's long slabs:
	# staggered rows, each lower + darker, one seamless rocky body fading
	# into the soil
	_slab_row(FLOOR_Y + 40.0, 0.62, 0, ROCK_CREST)          # crest skyline
	_slab_row(FLOOR_Y + 82.0, 0.55, 2, ROCK_LIT)            # the lit row
	_slab_row(FLOOR_Y + 145.0, 0.50, 3, ROCK_MID)
	_slab_row(FLOOR_Y + 212.0, 0.48, 4, ROCK_DARK)
	# THROUGH-ROW — tips rising past her feet so she walks IN the scree
	_slab_row(FLOOR_Y + 165.0, 0.44, 6, ROCK_THROUGH)
	_slab_row(FLOOR_Y + 290.0, 0.5, 6, ROCK_LIP)            # deep front lip
	_rubble_mat()


## one staggered row of long slabs: overlapping strips, random flips +
## scale/y/value jitter — rows undulate, never settle into a band
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


## the scree field — R3's meadow logic with stone: every pebble/rock picks
## its own depth t (tint slides lit->dark, z follows, size rides two slow
## waves + jitter). Continuous, never a strip.
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
		var sc := lerpf(0.10, 0.22, wave) * _rng.randf_range(0.75, 1.3)
		var h := tex.get_height() * sc
		var base := FLOOR_Y + lerpf(4.0, 30.0, t)
		var tj := _rng.randf_range(0.86, 1.14)
		var tint := Color(lerpf(ROCK_LIT.r * 0.72, ROCK_THROUGH.r, t) * tj,
				lerpf(ROCK_LIT.g * 0.72, ROCK_THROUGH.g, t) * tj,
				lerpf(ROCK_LIT.b * 0.72, ROCK_THROUGH.b, t) * tj)
		_sprite(_tex("rock", pi), Vector2(x, base - h * 0.5 + h * 0.06),
				sc, 4 if t < 0.45 else 6, tint, _rng.randf() < 0.5)
		x += tex.get_width() * sc * _rng.randf_range(0.55, 0.9)
	# woven accents: a half-sunk pebble pile or a lone small spike, at
	# random depths on a long rhythm
	var ax := WORLD_L + _rng.randf_range(200.0, 450.0)
	while ax < WORLD_R:
		var az: int = 4 if _rng.randf() < 0.5 else 6
		if _rng.randf() < 0.6:
			var pp: int = PEBBLE_PILES[_rng.randi() % PEBBLE_PILES.size()]
			_prop(_tex("floor", pp), ax, FLOOR_Y + 26.0,
					_rng.randf_range(0.28, 0.4), az,
					Color(ROCK_MID.r * 0.9, ROCK_MID.g * 0.9, ROCK_MID.b * 0.9),
					_rng.randf() < 0.5)
		else:
			var sg: int = STALAG[_rng.randi() % STALAG.size()]
			_prop(_tex("rock", sg), ax, FLOOR_Y + 18.0,
					_rng.randf_range(0.18, 0.26), az, ROCK_DARK, _rng.randf() < 0.5)
		ax += _rng.randf_range(420.0, 760.0)


# ---------- platforms (the platformer spine) ----------

func _build_platforms() -> void:
	# Walkable = the pack's PLATFORM BLOCKS + half-buried domes only; big
	# rocks and monoliths stay decor (R3's law, carried over). Each arc
	# climbs low dome -> mid block -> high block, ≤130px steps; thin slats
	# bridge some highs; lone hop domes fill the stretches between.
	# INTRO hops (before the first arc)
	_dome_step(950.0, FLOOR_Y - 115.0)
	_block_platform(1550.0, FLOOR_Y - 235.0, 3)
	for ai in ARC_XS.size():
		var amx: float = ARC_XS[ai]
		var caps: Array = [[0, 3], [2, 4], [10, 7], [3, 0], [4, 10]][ai % 5]
		_dome_step(amx, FLOOR_Y - _rng.randf_range(108.0, 128.0), ai % 2 == 0)
		_block_platform(amx + 500.0, FLOOR_Y - 240.0, caps[0], ai % 2 == 1)
		_block_platform(amx + 1000.0, FLOOR_Y - 355.0, caps[1], ai % 2 == 0)
		# a thin slat stepping off the high block — the platformer flourish
		_slat_platform(amx + 1440.0, FLOOR_Y - 300.0, PLAT_THIN[ai % 3])
		# clean rock piles at the arc feet as DECOR
		_prop(_tex("combo", ROCK_PILES[ai % ROCK_PILES.size()]), amx - 320.0,
				FLOOR_Y + 40.0, _rng.randf_range(0.4, 0.5), 3, Color.WHITE,
				ai % 2 == 1)
	# LONE HOP DOMES between the arcs (also stay clear of the set-piece
	# ground: the standing stones ~6150 and the spike garden ~12900-13520)
	var used: Array[float] = [950.0, 1550.0, 6150.0, 6390.0,
			12900.0, 13240.0, 13520.0]
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
	# scale so the dome crown (~6% below texture top) sits at top_y, base
	# buried ~200px under the floor line
	var sc := (FLOOR_Y + 200.0 - top_y) / (tex.get_height() * 0.94)
	var h := tex.get_height() * sc
	var w := tex.get_width() * sc
	# warmed down a step — raw, the pale dome art reads chalky against the grade
	_sprite(_tex("rock", d_id), Vector2(cx, FLOOR_Y + 200.0 - h * 0.5),
			sc, 1, Color(0.85, 0.66, 0.55), fh)
	_collider_rect(cx - w * 0.24, cx + w * 0.24, top_y, top_y + 24.0, true)
	# a pebble or two perched on the crown — lived-on stone
	_prop(_tex("rock", PEBBLES[_rng.randi() % PEBBLES.size()]),
			cx - w * 0.1, top_y + 12.0, 0.14, 2, Color.WHITE, _rng.randf() < 0.5)


## a floating chunky block platform — the MID/HIGH step. The pack paints a
## soft under-shadow on each block, so they read as hung stone, not paste-ons.
func _block_platform(cx: float, top_y: float, p_id: int, fh := false) -> void:
	var tex: Texture2D = load(BASE + _tex("plat", p_id))
	var target_w := 300.0
	var sc := target_w / tex.get_width()
	var h := tex.get_height() * sc
	_sprite(_tex("plat", p_id), Vector2(cx, top_y + h * 0.5 - h * 0.055),
			sc, 1, Color.WHITE, fh)
	_collider_rect(cx - target_w * 0.42, cx + target_w * 0.42, top_y,
			top_y + 24.0, true)
	# perched pebbles + one small spike on the block top — grouped, grounded
	_prop(_tex("rock", PEBBLES[_rng.randi() % PEBBLES.size()]),
			cx + target_w * 0.22, top_y + 10.0, 0.13, 2, Color.WHITE,
			_rng.randf() < 0.5)
	if _rng.randf() < 0.5:
		_prop(_tex("rock", STALAG[_rng.randi() % STALAG.size()]),
				cx - target_w * 0.24, top_y + 10.0, 0.14, 2,
				ROCK_DARK, _rng.randf() < 0.5)


## a thin slat platform — a narrow shelf off the high path
func _slat_platform(cx: float, top_y: float, p_id: int, fh := false) -> void:
	var tex: Texture2D = load(BASE + _tex("plat", p_id))
	var target_w := 230.0
	var sc := target_w / tex.get_width()
	var h := tex.get_height() * sc
	_sprite(_tex("plat", p_id), Vector2(cx, top_y + h * 0.5 - h * 0.10),
			sc, 1, Color.WHITE, fh)
	_collider_rect(cx - target_w * 0.4, cx + target_w * 0.4, top_y,
			top_y + 20.0, true)


# ---------- ceiling ----------

func _build_ceiling() -> void:
	# ONE continuous roof: gradient dark above the line, a hanging slab band
	# on it, stalactites on an even rhythm. The LINE never moves.
	var roof_deep := Color(0.030, 0.012, 0.009)
	var grad_p := Polygon2D.new()
	grad_p.polygon = PackedVector2Array([
			Vector2(WORLD_L - 900.0, -820.0), Vector2(WORLD_R + 900.0, -820.0),
			Vector2(WORLD_R + 900.0, ROOF_Y), Vector2(WORLD_L - 900.0, ROOF_Y)])
	grad_p.vertex_colors = PackedColorArray([roof_deep, roof_deep, SOIL, SOIL])
	grad_p.z_index = 0
	add_child(grad_p)
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, -1400.0, -820.0, 0, roof_deep)
	# hanging slab curtain: the ground-band recipe upside down — deep row
	# first (tight step, heads buried in the fill), then two shaped rows
	_slab_row_hang(ROOF_Y - 10.0, 0.60, 1, Color(0.13, 0.088, 0.072), 0.40, 0.5)
	_slab_row_hang(ROOF_Y - 25.0, 0.48, 1, Color(0.22, 0.15, 0.12), 0.48, 0.60)
	_slab_row_hang(ROOF_Y - 35.0, 0.36, 2, Color(0.44, 0.31, 0.26), 0.55, 0.72)
	# stalactites on an even rhythm end to end
	var stx := WORLD_L - 350.0
	var sti := 0
	while stx < WORLD_R + 350.0:
		var st_id: int = STALACT[sti % STALACT.size()]
		var st_sc := _rng.randf_range(0.55, 0.85)
		var tex: Texture2D = load(BASE + _tex("rock", st_id))
		_sprite(_tex("rock", st_id),
				Vector2(stx, ROOF_Y + 8.0 + tex.get_height() * st_sc * 0.5),
				st_sc, 3, Color(0.60, 0.44, 0.37), _rng.randf() < 0.5)
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


# ---------- set-pieces (RARE — Advika's law) ----------

func _build_setpieces() -> void:
	# 1 — THE MAW (over the zone A walk): the pack's cave-mouth mass hanging
	# off the roof, teeth dropping into open air
	var maw: Texture2D = load(BASE + _tex("combo", 2))
	var msc := 1.15
	_sprite(_tex("combo", 2), Vector2(1200.0,
			ROOF_Y + 40.0 + maw.get_height() * msc * 0.5 - 30.0), msc, 2,
			Color(0.55, 0.40, 0.34))
	# 2 — THE STANDING STONES (the breather between arcs 2 and 3, clear of
	# arc 2's slat): two monoliths rooted in the scree with a crimson coal
	# seam at their feet — the realm's one hot red moment. Decor only.
	var stones_x := 6150.0
	_prop(_tex("bigrock", 3), stones_x, FLOOR_Y + 50.0, 0.72, 3)
	_prop(_tex("bigrock", 5), stones_x + 240.0, FLOOR_Y + 44.0, 0.60, 4,
			Color(0.75, 0.60, 0.52), true)
	_prop(_tex("rock", 34), stones_x - 190.0, FLOOR_Y + 26.0, 0.55, 4,
			Color(0.62, 0.46, 0.38))
	var seam := _prop(_tex("floor", 15), stones_x + 90.0, FLOOR_Y + 34.0,
			0.4, 4)
	_glow_light(seam, CRIMSON, 0.42, 1.3)
	# 3 — THE SPIKE GARDEN (the last stretch before the door, past arc 5's
	# slat): a grove of stalagmite clusters the path threads between —
	# menace without a hitbox (yet)
	var sg_x := 12900.0
	_prop(_tex("combo", 12), sg_x, FLOOR_Y + 44.0, 0.62, 3)
	_prop(_tex("combo", 14), sg_x + 340.0, FLOOR_Y + 40.0, 0.5, 6,
			ROCK_THROUGH, true)
	_prop(_tex("combo", 15), sg_x + 620.0, FLOOR_Y + 46.0, 0.55, 3,
			Color(0.75, 0.62, 0.54))


# ---------- dressing: grouped grounded assemblies ----------

func _build_dressing() -> void:
	# rotating floor motifs stamp the assembly grammar down the whole walk:
	# boulder-and-coal / spike pair / pebble field with a gold glint /
	# rock pile with a leaning shard. One warm glow per motif, ember-led.
	var dmx := WORLD_L + 550.0
	var dmi := 0
	while dmx < WORLD_R - 500.0:
		match dmi % 4:
			0:  # boulder + coal cluster: the cave's hearths
				_prop(_tex("rock", [23, 24][dmi % 2]), dmx, FLOOR_Y + 60.0,
						_rng.randf_range(0.30, 0.38), 3, Color.WHITE, dmi % 2 == 0)
				var coal := _prop(_tex("rock", PEBBLES[dmi % 5]), dmx + 150.0,
						FLOOR_Y + 16.0, 0.2, 4, Color(1.0, 0.62, 0.42))
				_glow_light(coal, EMBER, 0.3, 1.1)
				_prop(_tex("rock", PEBBLES[(dmi + 2) % 5]), dmx + 210.0,
						FLOOR_Y + 14.0, 0.14, 4, Color(0.9, 0.5, 0.35), true)
			1:  # spike pair rising out of the scree
				_prop(_tex("rock", STALAG[dmi % 4]), dmx, FLOOR_Y + 18.0,
						_rng.randf_range(0.3, 0.4), 3, Color(0.55, 0.40, 0.34))
				_prop(_tex("rock", STALAG[(dmi + 1) % 4]), dmx + 110.0,
						FLOOR_Y + 16.0, _rng.randf_range(0.2, 0.26), 4,
						ROCK_DARK, true)
			2:  # pebble field with one gold glint
				_prop(_tex("floor", PEBBLE_PILES[dmi % 4]), dmx,
						FLOOR_Y + 28.0, _rng.randf_range(0.34, 0.44), 3,
						Color.WHITE, dmi % 2 == 1)
				var gg := _prop(_tex("rock", PEBBLES[(dmi + 1) % 5]),
						dmx + 130.0, FLOOR_Y + 14.0, 0.16, 4,
						Color(1.0, 0.85, 0.6))
				_glow_light(gg, GOLD, 0.24, 0.9)
			3:  # rock pile + leaning shard silhouette
				_prop(_tex("combo", ROCK_PILES[dmi % ROCK_PILES.size()]), dmx,
						FLOOR_Y + 38.0, _rng.randf_range(0.4, 0.5), 3,
						Color.WHITE, dmi % 2 == 0)
				_prop(_tex("rock", [10, 36][dmi % 2]), dmx + 190.0,
						FLOOR_Y + 20.0, _rng.randf_range(0.26, 0.34), 4,
						ROCK_DARK, dmi % 2 == 1)
		dmx += _rng.randf_range(620.0, 900.0)
		dmi += 1


func _build_foreground() -> void:
	# darkest silhouettes hugging the bottom frame — bases below the lowest
	# view edge so they read as stone cut by the frame, never floating
	var fore := Color(0.055, 0.026, 0.020)
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
	# continuous bottom anchor: a dark rubble band along the whole frame
	# bottom, in front of the gameplay layer
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
	# three wide haze bands at different depths, drifting slowly and
	# wrapping — ember-dark, alphas <=0.04
	for cfg: Array in [[-7, 0.04, 1.4, 5.0], [-3, 0.035, 1.0, 7.5], [7, 0.03, 1.7, 4.0]]:
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
func _build_atmosphere() -> void:
	# local fog banks: warm dark, faint
	var nfog := int((WORLD_R - WORLD_L + 1800.0) / 950.0) + 1
	for i in nfog:
		var f := Sprite2D.new()
		f.texture = load(MOSS_FOG)
		f.position = Vector2(WORLD_L - 900.0 + i * 950.0,
				FLOOR_Y - _rng.randf_range(60.0, 280.0))
		f.scale = Vector2(_rng.randf_range(2.8, 4.2), _rng.randf_range(2.0, 2.9))
		f.modulate = Color(0.42, 0.22, 0.15, _rng.randf_range(0.10, 0.15))
		f.z_index = -4 if i % 2 == 0 else 6
		add_child(f)
		_fogs.append(f)
	# drifting ash motes — slow warm sparks riding the cave air
	var motes := CPUParticles2D.new()
	motes.texture = load(MOSS_SPORE)
	motes.amount = int((WORLD_R - WORLD_L) / 320.0)
	motes.lifetime = 16.0
	motes.preprocess = 16.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2((WORLD_R - WORLD_L) * 0.5 + 300.0, 520.0)
	motes.direction = Vector2(1, -0.15)
	motes.spread = 14.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 12.0
	motes.initial_velocity_max = 30.0
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.1
	motes.color = Color(1.0, 0.62, 0.35, 0.5)
	motes.position = Vector2((WORLD_L + WORLD_R) * 0.5, FLOOR_Y - 260.0)
	motes.z_index = 6
	add_child(motes)
	# corner vignette — warm-black
	var cl := CanvasLayer.new()
	cl.layer = 15
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0),
			Color(0.045, 0.015, 0.010, 0.30)])
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
	# realm-tinted eyes: feed red, keep green, crush blue — the violet art
	# reads as ember amber, this cave's own color (not magenta)
	_lives.eye_tint = Color(1.7, 1.0, 0.30)
	add_child(_lives)
	_lives.reset(STARTING_LIVES)
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


# Golem guards on the floor between the arcs (Advika: keep the golems).
# Size carries GolemTest's golem:hero ratio (1.0 : 0.28) to this hero scale
# (0.24) -> 0.55. Short detect range so a guard only wakes up close.
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
		g.z_index = 5
		add_child(g)
		if g.has_method("set_home"):
			g.set_home(wx)


# Jades ride the high path (Advika: keep the jades): one on each arc's mid
# and high block + slat, a few on lone floor spots. Rewards climbing.
func _build_jades() -> void:
	var spots: Array[Vector2] = [
		Vector2(950.0, FLOOR_Y - 165.0),      # intro dome
		Vector2(1550.0, FLOOR_Y - 285.0),     # intro block
	]
	for ai in ARC_XS.size():
		var amx: float = ARC_XS[ai]
		spots.append(Vector2(amx + 500.0, FLOOR_Y - 290.0))
		spots.append(Vector2(amx + 1000.0, FLOOR_Y - 405.0))
		spots.append(Vector2(amx + 1440.0, FLOOR_Y - 350.0))
	# floor strays on the long gaps — walked-past rewards
	for fx: float in [3300.0, 7600.0, 12500.0, 13600.0]:
		spots.append(Vector2(fx, FLOOR_Y - 55.0))
	_jade_total = spots.size()
	for sp in spots:
		var j: Area2D = JADE_SCENE.instantiate()
		j.position = sp
		j.piece_scale = 0.15
		j.z_index = 5
		add_child(j)
		j.collected.connect(_on_jade)


func _on_jade() -> void:
	_jade_got += 1
	if _jade_lbl != null:
		_jade_lbl.text = "%d / %d" % [_jade_got, _jade_total]


# ---------- exit / camera / ui ----------

func _build_exit_door() -> void:
	# the standard arch door (Realm 1's exact recipe) at the end of the walk
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
	lbl.text = "R1 CRIMSON HOLLOW REBUILD — walk right →   (R restart · ESC hub)"
	lbl.position = Vector2(16, 12)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.62, 0.6))
	cl.add_child(lbl)
	# jade counter, top-right (the old realm's HUD habit, minimal)
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
