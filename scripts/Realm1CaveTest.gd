extends Node2D
## REALM 1 REBUILD — THE MOSSY CAVERN, built the way Realm 2 was built
## (Advika 2026-07-19: "exactly like level 2, keep the original palette").
## Two Maaot packs in their ORIGINAL colors — no hue shift, no color grade:
##   - "Cave Assets" (assets/realms/realm1_cavern/, tools/slice_cave_pack.gd):
##     brown painterly rock — ground slabs, platform blocks, boulders,
##     stalagmites/stalactites, rubble
##   - the Mossy pack in its native GREEN (assets/realms/realm1_moss/,
##     tools/tint_moss_green.gd rotates the proven realm2_moss slices back
##     to the pack's original palette, same crops + names)
## Realm 2's dressing grammar, carried whole:
##   - grounded TREE assemblies: vine trunk rooted in the floor, canopy moss
##     slab on the crown, hangers underneath (no twins), rock at the base,
##     an animated plant breathing beside it
##   - GRAND landmarks: twin trunks + grand ledge + dark cascade + hangers
##   - boulder clusters half-buried, leaning together — merged, never slivers
##   - UNDERGROWTH CARPET: a tuft/rock/plant every ~150px, deterministic,
##     so no stretch ever rolls bare
##   - platforms wear moss: fringe lip on top, hangers under the edges
## Layout is a PLATFORMER: climb arcs (dome -> block -> high block -> slat),
## lone hop domes, golem guards + jades kept from the old realm.
## Controls: Curiosity's own. R restarts. ESC returns to the Hub.
## R1_SHOT env: screenshot at 1s + quit. R1_SHOT_X: park the hero first.
## R1_SHOT_CAMY: freeze the camera at a fixed Y (inspect the roof view).

const BASE := "res://assets/realms/realm1_cavern/"
const MBASE := "res://assets/realms/realm1_moss/"
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

# THE PACK'S OWN MOOD (Advika's reference, 2026-07-19 — the promo shot):
# near-black rock silhouettes swimming in a GREEN-LIT haze. No color grade —
# the green lives in the backdrop, the fog masses and the light pools; the
# art keeps its painted colors and reads dark against the glow. Depth is
# value: background haze is the brightest thing, gameplay rock is dark with
# a rim of light, the lantern's gold is the one warm accent.
const SOIL := Color(0.030, 0.026, 0.018)          # near-black earth body
const BG_TOP := Color(0.062, 0.078, 0.042)        # backdrop: dark olive-green
const BG_BOTTOM := Color(0.022, 0.028, 0.016)
const HAZE_GREEN := Color(0.46, 0.55, 0.30)       # the fog masses' green
const POOL_GREEN := Color(0.62, 0.78, 0.40)       # the bright light pools
const SIL_FAR := Color(0.22, 0.22, 0.20)          # far band: darkest shapes
const SIL_MID := Color(0.34, 0.34, 0.31)          # mid band silhouettes
const GOLD := Color(1.0, 0.82, 0.48)              # the lantern's family
const AMBIENT := Color(0.82, 0.84, 0.78)          # mild dim, a breath of green
const FOG_TINT := HAZE_GREEN                      # haze bands ride the green
const MAX_GLOW_LIGHTS := 16
const MOSS_FOG := "res://assets/realms/realm2_moss/fog.png"
const MOSS_SPORE := "res://assets/realms/realm2_moss/spore.png"
const MOSS_FIREFLY := "res://assets/realms/realm2_moss/firefly.png"

# ---- cave-pack vocabulary (indices into the sliced sheets) ----
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

# moss texture pools, loaded once in _ready
var _m_vines: Array[Texture2D] = []
var _m_plats: Array[Texture2D] = []
var _m_ferns: Array[Texture2D] = []
var _m_beards: Array[Texture2D] = []
var _m_rocks: Array[Texture2D] = []
var _m_boulders: Array[Texture2D] = []
var _m_tufts: Array[Texture2D] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.045, 0.036, 0.028))
	_rng.seed = 20260719
	_load_moss_pools()
	_build_backdrop()
	_build_background()
	_build_terrain()
	_build_platforms()
	_build_ceiling()
	_build_setpieces()
	_build_forest()
	_build_undergrowth()
	_build_foreground()
	_build_atmosphere()
	_build_fog_layers()
	_build_player()
	_build_golems()
	_build_jades()
	_build_exit_door()
	_build_camera()
	_build_ui()
	# a mild neutral dim — hue-honest, so both packs keep their own colors;
	# the lantern's ADDED gold stays the brightest thing in the cave
	var grade := CanvasModulate.new()
	grade.color = AMBIENT
	add_child(grade)
	if OS.get_environment("R1_SHOT") != "":
		_self_screenshot(OS.get_environment("R1_SHOT"))


func _load_moss_pools() -> void:
	for n in ["vine_trunk_0", "vine_trunk_1", "vine_trunk_2", "vine_trunk_3"]:
		_m_vines.append(load(MBASE + n + ".png"))
	for n in ["platform_wide_0", "platform_wide_1", "platform_wide_2"]:
		_m_plats.append(load(MBASE + n + ".png"))
	for n in ["hang_fern_0", "hang_fern_1", "hang_fern_2", "hang_fern_3",
			"hang_fern_4", "hang_curl_0", "hang_curl_1", "hang_curl_2"]:
		_m_ferns.append(load(MBASE + n + ".png"))
	for n in ["hang_beard_0", "hang_beard_1"]:
		_m_beards.append(load(MBASE + n + ".png"))
	for n in ["rock_moss_0", "rock_moss_1", "rock_moss_2"]:
		_m_rocks.append(load(MBASE + n + ".png"))
	for n in ["boulder_0", "boulder_1", "boulder_2"]:
		_m_boulders.append(load(MBASE + n + ".png"))
	for n in ["tuft_0", "tuft_1", "tuft_2"]:
		_m_tufts.append(load(MBASE + n + ".png"))


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


## a raw-texture sprite (for the moss pools, already loaded)
func _tsprite(tex: Texture2D, pos: Vector2, sc: float, z: int,
		tint := Color.WHITE, fh := false, fv := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(sc, sc)
	s.position = pos
	s.z_index = z
	s.modulate = tint
	s.flip_h = fh
	s.flip_v = fv
	add_child(s)
	return s


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
		_bloom(host as Sprite2D, col, 0.20)
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


## the pack's animated plants (flower / plant1 / plant_wind), original green.
## Realm 2's recipe: SpriteFrames off the frame_%03d.png strips.
func _plant(dir: String, fps: float, sc: float) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("sway")
	frames.set_animation_loop("sway", true)
	frames.set_animation_speed("sway", fps)
	var i := 0
	while ResourceLoader.exists(MBASE + dir + "/frame_%03d.png" % i):
		frames.add_frame("sway", load(MBASE + dir + "/frame_%03d.png" % i))
		i += 1
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.scale = Vector2(sc, sc)
	a.play("sway")
	a.frame = _rng.randi() % maxi(1, frames.get_frame_count("sway"))
	add_child(a)
	return a


# ---------- backdrop / background ----------

func _build_backdrop() -> void:
	# screen-anchored vertical gradient: deep neutral brown sinking to
	# near-black. The art carries the color; the backdrop just recedes.
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
	# FAR: a boulder-and-monolith skyline at 35% value — ranked stone
	# receding into the dark, the art's own browns kept
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
		s.modulate = SIL_FAR
		_hills_far.add_child(s)
		fx += _rng.randf_range(420.0, 640.0)
		fi += 1
	# far vine ghosts threading the skyline — the cavern grew green long ago
	var gx := FAR_L + 260.0
	var gi := 0
	while gx < FAR_R:
		var vt: Texture2D = _m_vines[gi % _m_vines.size()]
		var sc := _rng.randf_range(0.4, 0.55)
		var s := Sprite2D.new()
		s.texture = vt
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.position = Vector2(gx, FLOOR_Y + 20.0 - vt.get_height() * sc * 0.5)
		s.modulate = Color(SIL_FAR.r * 1.2, SIL_FAR.g * 1.25, SIL_FAR.b * 1.15)
		_hills_far.add_child(s)
		gx += _rng.randf_range(520.0, 780.0)
		gi += 1
	# MID BAND VIGNETTES — composed silhouette groups on a rhythm, each with
	# one warm gold glint: monolith + mossy boulder / spike grove + vine /
	# boulder family under a tuft crown
	var vx := MID_L + 250.0
	var vi := 0
	while vx < MID_R:
		if vi % 2 == 0:
			_mid_sprite(load(BASE + _tex("bigrock", [0, 6, 8][vi % 3])),
					vx + 100.0, 36.0, _rng.randf_range(1.0, 1.3),
					Color(SIL_MID.r * 0.7, SIL_MID.g * 0.7, SIL_MID.b * 0.7),
					vi % 4 == 0)
		match vi % 3:
			0:  # monolith + mossy boulder at its foot
				_mid_sprite(load(BASE + _tex("bigrock", [3, 5][vi % 2])), vx,
						40.0, _rng.randf_range(0.7, 0.85), SIL_MID, vi % 2 == 0)
				_mid_sprite(_m_boulders[vi % 3], vx + 170.0, 26.0,
						_rng.randf_range(0.3, 0.4), SIL_MID, vi % 2 == 1)
			1:  # spike grove + a vine rising behind it
				_mid_sprite(_m_vines[vi % 4], vx + 120.0, 30.0,
						_rng.randf_range(0.45, 0.6),
						Color(SIL_MID.r * 0.85, SIL_MID.g * 0.9, SIL_MID.b * 0.8),
						vi % 2 == 1)
				_mid_sprite(load(BASE + _tex("combo", SPIKE_CLUSTERS[vi % 4])), vx,
						40.0, _rng.randf_range(0.62, 0.78), SIL_MID, vi % 2 == 0)
			2:  # boulder family wearing a tuft
				_mid_sprite(load(BASE + _tex("combo", [5, 7, 10][vi % 3])), vx,
						28.0, _rng.randf_range(0.6, 0.75), SIL_MID, vi % 2 == 0)
				_mid_sprite(_m_tufts[vi % 3], vx - 60.0, 16.0,
						_rng.randf_range(0.22, 0.3), SIL_MID, vi % 2 == 1)
		# one soft gold glint per vignette — distant lantern-kin in the dark
		var fg := Sprite2D.new()
		fg.texture = _soft_glow_texture()
		fg.position = Vector2(vx + _rng.randf_range(-60.0, 60.0),
				FLOOR_Y - _rng.randf_range(30.0, 90.0))
		fg.scale = Vector2(1.0, 1.0)
		fg.modulate = Color(GOLD.r, GOLD.g, GOLD.b, 0.10)
		_hills_mid.add_child(fg)
		vx += _rng.randf_range(360.0, 500.0)
		vi += 1
	# distant ceiling teeth in both bands — the windows between the roof's
	# fingers show dark depth, never bare gradient
	_teeth_row(_hills_far, FAR_L, FAR_R, ROOF_Y - 60.0, 0.55, 0.75,
			Color(SIL_FAR.r * 1.1, SIL_FAR.g * 1.1, SIL_FAR.b * 1.1))
	_teeth_row(_hills_mid, MID_L, MID_R, ROOF_Y - 40.0, 0.6, 0.85, SIL_MID)


## a bottom-anchored silhouette sprite in the MID parallax band
func _mid_sprite(tex: Texture2D, x: float, sink: float, sc: float,
		tint: Color, fh := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(sc, sc)
	s.flip_h = fh
	s.position = Vector2(x, FLOOR_Y + sink - tex.get_height() * sc * 0.5)
	s.modulate = tint
	_hills_mid.add_child(s)
	return s


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
	# the walls end in STONE + GROWTH, not a cut line: pebble columns with a
	# vine leaning on each face
	for wp: Array in [[WORLD_L - 10.0, 7, 1.6, false], [WORLD_L + 130.0, 18, 1.3, true],
			[WORLD_R + 10.0, 8, 1.6, true], [WORLD_R - 130.0, 19, 1.3, false]]:
		var wtex: Texture2D = load(BASE + _tex("floor", wp[1]))
		var wsc: float = wp[2]
		_sprite(_tex("floor", wp[1]),
				Vector2(wp[0], FLOOR_Y + 40.0 - wtex.get_height() * wsc * 0.5),
				wsc, 1, Color(0.30, 0.30, 0.28), wp[3])
	var wl_vine: Texture2D = _m_vines[1]
	_tsprite(wl_vine, Vector2(WORLD_L + 120.0,
			FLOOR_Y + 20.0 - wl_vine.get_height() * 0.55 * 0.5), 0.55, 2,
			Color(0.5, 0.5, 0.5))
	var wr_vine: Texture2D = _m_vines[2]
	_tsprite(wr_vine, Vector2(WORLD_R - 120.0,
			FLOOR_Y + 20.0 - wr_vine.get_height() * 0.55 * 0.5), 0.55, 2,
			Color(0.5, 0.5, 0.5), true)
	# THE GROUND BAND — staggered slab rows, silhouette-forward (the ref:
	# ground reads dark against the green haze, the walk row catches just
	# enough light to hold its painted brown)
	_slab_row(FLOOR_Y + 40.0, 0.62, 0, Color(0.30, 0.30, 0.28))   # crest skyline
	_slab_row(FLOOR_Y + 82.0, 0.55, 2, Color(0.62, 0.62, 0.58))   # the walk row
	_slab_row(FLOOR_Y + 145.0, 0.50, 3, Color(0.40, 0.40, 0.37))
	_slab_row(FLOOR_Y + 212.0, 0.48, 4, Color(0.26, 0.26, 0.24))
	# THROUGH-ROW — tips rising past her feet so she walks IN the scree
	_slab_row(FLOOR_Y + 165.0, 0.44, 6, Color(0.17, 0.17, 0.16))
	_slab_row(FLOOR_Y + 290.0, 0.5, 6, Color(0.10, 0.10, 0.09))   # deep front lip
	# THE MOSS LINE — Realm 2's walk-line move: green moss mats riding the
	# lit row's crest, undulating, the cave floor wearing its growth
	_moss_line()
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


## green moss mats along the walk line: moss_mat strips riding the lit row,
## height and value undulating — a continuous grown lip, never a hedge
func _moss_line() -> void:
	var mat: Texture2D = load(MBASE + "moss_mat.png")
	var front: Texture2D = load(MBASE + "moss_front.png")
	var x := WORLD_L - 200.0
	var i := 0
	while x < WORLD_R + 200.0:
		var tex := mat if i % 3 != 2 else front
		var sc := _rng.randf_range(0.30, 0.44)
		var w := tex.get_width() * sc
		var h := tex.get_height() * sc
		var b := _rng.randf_range(0.55, 0.75)
		var z := 3 if i % 2 == 0 else 6
		if z == 6:
			b *= 0.45   # the front passes sit in shadow, same value law as the rock
		_tsprite(tex, Vector2(x, FLOOR_Y + 26.0 - h * 0.5 +
				_rng.randf_range(-8.0, 10.0)), sc, z, Color(b, b, b),
				_rng.randf() < 0.5)
		x += w * _rng.randf_range(0.55, 0.75)
		i += 1


## the scree field between the moss: pebbles and small rocks at their own
## depths — the cave floor under the growth
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
		var h := tex.get_height() * sc
		var base := FLOOR_Y + lerpf(4.0, 30.0, t)
		var b := lerpf(0.58, 0.18, t) * _rng.randf_range(0.86, 1.14)
		_sprite(_tex("rock", pi), Vector2(x, base - h * 0.5 + h * 0.06),
				sc, 4 if t < 0.45 else 6, Color(b, b, b), _rng.randf() < 0.5)
		x += tex.get_width() * sc * _rng.randf_range(0.7, 1.1)


# ---------- platforms (the platformer spine) ----------

func _build_platforms() -> void:
	# Walkable = platform blocks + half-buried domes; big rocks stay decor.
	# Every walkable top wears MOSS (the R2 overhang law: fringe lip + tufts
	# + hangers under the edges).
	_dome_step(950.0, FLOOR_Y - 115.0)
	_block_platform(1550.0, FLOOR_Y - 235.0, 3)
	# free-standing movers on the long gaps — the ride is part of the walk
	_moving_platform(3450.0, FLOOR_Y - 200.0, 8, "side", 220.0, 6.5)
	_moving_platform(7450.0, FLOOR_Y - 190.0, 6, "updown", -150.0, 5.5)
	_moving_platform(12480.0, FLOOR_Y - 210.0, 9, "side", -220.0, 6.0)
	for ai in ARC_XS.size():
		var amx: float = ARC_XS[ai]
		var caps: Array = [[0, 3], [2, 4], [10, 7], [3, 0], [4, 10]][ai % 5]
		_dome_step(amx, FLOOR_Y - _rng.randf_range(108.0, 128.0), ai % 2 == 0)
		_block_platform(amx + 500.0, FLOOR_Y - 240.0, caps[0], ai % 2 == 1)
		_block_platform(amx + 1000.0, FLOOR_Y - 355.0, caps[1], ai % 2 == 0)
		# the step off the high block MOVES (Realm 1's signature): rising
		# elevators and sliding shelves alternate down the walk
		if ai % 2 == 0:
			_moving_platform(amx + 1440.0, FLOOR_Y - 300.0, PLAT_THIN[ai % 3],
					"updown", -130.0, 5.2)
		else:
			_moving_platform(amx + 1440.0, FLOOR_Y - 300.0, PLAT_THIN[ai % 3],
					"side", 200.0, 6.0)
		# mossy boulder cluster resting at the arc's feet — DECOR
		_boulder_cluster(amx - 320.0)
	# LONE HOP DOMES between the arcs (clear of set-piece ground: stones
	# ~6150, spike garden ~12900-13520)
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


## moss dressing for any walkable top: a green fringe lip sunk into the
## surface, a tuft or two, hangers tucked under the edges (no twins)
func _moss_top(cx: float, top_y: float, half_w: float, under_y: float) -> void:
	# the lip: two moss mats overlapping across the span, crowns above the top
	var mat: Texture2D = load(MBASE + "moss_mat.png")
	var msc := half_w * 2.2 / mat.get_width() * 0.62
	for i in 2:
		var mx := cx + (-half_w * 0.42 if i == 0 else half_w * 0.42)
		var b := _rng.randf_range(0.58, 0.75)
		_tsprite(mat, Vector2(mx, top_y + 6.0 - mat.get_height() * msc * 0.32),
				msc, 2, Color(b, b, b), i == 1)
	# a tuft breaking the lip line
	var tt: Texture2D = _m_tufts[_rng.randi() % _m_tufts.size()]
	var tsc := _rng.randf_range(0.14, 0.2)
	_tsprite(tt, Vector2(cx + _rng.randf_range(-half_w * 0.5, half_w * 0.5),
			top_y + 8.0 - tt.get_height() * tsc * 0.38), tsc, 2,
			Color(0.65, 0.65, 0.60), _rng.randf() < 0.5)
	# hangers under the edges — no twins, halves split (the R2 law)
	var pool: Array[Texture2D] = []
	pool.append_array(_m_ferns)
	pool.append_array(_m_beards)
	var n_hang := 1 + (_rng.randi() % 2)
	for i in n_hang:
		var pick := _rng.randi() % pool.size()
		var ht: Texture2D = pool[pick]
		pool.remove_at(pick)
		var hsc := _rng.randf_range(0.26, 0.4)
		var hg := Sprite2D.new()
		hg.texture = ht
		hg.centered = false
		hg.offset = Vector2(-ht.get_width() * 0.5, -24.0)
		hg.scale = Vector2(hsc, hsc)
		hg.flip_h = _rng.randf() < 0.5
		var hx := -half_w * 0.7 if (n_hang == 2 and i == 0) \
				else (half_w * 0.7 if n_hang == 2 else _rng.randf_range(-half_w * 0.6, half_w * 0.6))
		hg.position = Vector2(cx + hx, under_y - 6.0)
		hg.z_index = 2
		var hb := _rng.randf_range(0.5, 0.68)
		hg.modulate = Color(hb, hb, hb)
		add_child(hg)
	# an animated plant breathing on some tops
	if _rng.randf() < 0.5:
		var pdir: String = ["flower", "plant1", "plant_wind"][_rng.randi() % 3]
		var plant := _plant(pdir, _rng.randf_range(7.0, 10.0),
				_rng.randf_range(0.14, 0.2))
		plant.position = Vector2(cx + _rng.randf_range(-half_w * 0.4, half_w * 0.4),
				top_y - 4.0)
		plant.z_index = 2


## a half-buried dome swelling out of the scree — the LOW step, mossed
func _dome_step(cx: float, top_y: float, fh := false) -> void:
	var d_id: int = DOMES[int(absf(cx)) % DOMES.size()]
	var tex: Texture2D = load(BASE + _tex("rock", d_id))
	var sc := (FLOOR_Y + 200.0 - top_y) / (tex.get_height() * 0.94)
	var h := tex.get_height() * sc
	var w := tex.get_width() * sc
	_sprite(_tex("rock", d_id), Vector2(cx, FLOOR_Y + 200.0 - h * 0.5),
			sc, 1, Color(0.52, 0.52, 0.49), fh)
	_collider_rect(cx - w * 0.24, cx + w * 0.24, top_y, top_y + 24.0, true)
	_moss_top(cx, top_y, w * 0.24, top_y + 60.0)


## a floating chunky block platform — the MID/HIGH step, mossed
func _block_platform(cx: float, top_y: float, p_id: int, fh := false) -> void:
	var tex: Texture2D = load(BASE + _tex("plat", p_id))
	var target_w := 300.0
	var sc := target_w / tex.get_width()
	var h := tex.get_height() * sc
	# dark block, rim of light — the ref's floating steps
	_sprite(_tex("plat", p_id), Vector2(cx, top_y + h * 0.5 - h * 0.055),
			sc, 1, Color(0.50, 0.50, 0.47), fh)
	_collider_rect(cx - target_w * 0.42, cx + target_w * 0.42, top_y,
			top_y + 24.0, true)
	_moss_top(cx, top_y, target_w * 0.42, top_y + h * 0.8)


## a thin slat platform — a narrow shelf off the high path, mossed lightly
func _slat_platform(cx: float, top_y: float, p_id: int, fh := false) -> void:
	var tex: Texture2D = load(BASE + _tex("plat", p_id))
	var target_w := 230.0
	var sc := target_w / tex.get_width()
	var h := tex.get_height() * sc
	_sprite(_tex("plat", p_id), Vector2(cx, top_y + h * 0.5 - h * 0.10),
			sc, 1, Color(0.50, 0.50, 0.47), fh)
	_collider_rect(cx - target_w * 0.4, cx + target_w * 0.4, top_y,
			top_y + 20.0, true)
	var tt: Texture2D = _m_tufts[_rng.randi() % _m_tufts.size()]
	var tsc := _rng.randf_range(0.12, 0.16)
	_tsprite(tt, Vector2(cx + _rng.randf_range(-target_w * 0.3, target_w * 0.3),
			top_y + 6.0 - tt.get_height() * tsc * 0.38), tsc, 2,
			Color(0.62, 0.62, 0.58), _rng.randf() < 0.5)


## a MOVING platform — Realm 1's signature, carried into the rebuild.
## AnimatableBody2D with sync_to_physics, driven by a looping sine tween,
## so she rides it (the old realm's proven recipe). motion: "side" / "updown".
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
	# a tuft riding the mover — alive, and telegraphs the motion
	var tt: Texture2D = _m_tufts[_rng.randi() % _m_tufts.size()]
	var tsc := 0.13
	var tuft := Sprite2D.new()
	tuft.texture = tt
	tuft.scale = Vector2(tsc, tsc)
	tuft.position = Vector2(target_w * 0.18, 4.0 - tt.get_height() * tsc * 0.38)
	tuft.z_index = 2
	tuft.modulate = Color(0.62, 0.62, 0.58)
	body.add_child(tuft)
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


## a mossy boulder cluster: masses half-buried, leaning together — merged
func _boulder_cluster(cx: float, z := 3) -> void:
	var n := 2 + (_rng.randi() % 2)
	var x := cx
	for i in n:
		var tex: Texture2D
		if _rng.randf() < 0.55:
			tex = _m_boulders[_rng.randi() % _m_boulders.size()]
		else:
			tex = _m_rocks[_rng.randi() % _m_rocks.size()]
		var sc := _rng.randf_range(0.26, 0.42)
		var b := _rng.randf_range(0.5, 0.72)
		_tsprite(tex, Vector2(x, FLOOR_Y + 14.0 - tex.get_height() * sc * 0.30),
				sc, z, Color(b, b, b), _rng.randf() < 0.5)
		x += tex.get_width() * sc * 0.62


# ---------- ceiling ----------

func _build_ceiling() -> void:
	# ONE continuous roof: gradient dark above the line, a hanging slab
	# curtain, stalactites on an even rhythm — and GREEN dripping off it
	# (beards + ferns among the teeth, the R2 corridor's underside idiom)
	var roof_deep := Color(0.026, 0.020, 0.015)
	var grad_p := Polygon2D.new()
	grad_p.polygon = PackedVector2Array([
			Vector2(WORLD_L - 900.0, -820.0), Vector2(WORLD_R + 900.0, -820.0),
			Vector2(WORLD_R + 900.0, ROOF_Y), Vector2(WORLD_L - 900.0, ROOF_Y)])
	grad_p.vertex_colors = PackedColorArray([roof_deep, roof_deep, SOIL, SOIL])
	grad_p.z_index = 0
	add_child(grad_p)
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, -1400.0, -820.0, 0, roof_deep)
	# the ref's roof read: PALE teeth deep behind, BLACK fingers in front
	_slab_row_hang(ROOF_Y - 30.0, 0.50, 1, Color(0.48, 0.48, 0.44), 0.48, 0.60)
	_slab_row_hang(ROOF_Y - 18.0, 0.55, 1, Color(0.26, 0.26, 0.24), 0.44, 0.55)
	_slab_row_hang(ROOF_Y - 8.0, 0.62, 2, Color(0.115, 0.115, 0.105), 0.40, 0.5)
	# stalactites end to end — alternating pale (behind) and near-black
	# (front), the ref's two-depth teeth
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
	# green hangers between the teeth — tops tucked into the curtain
	var hgx := WORLD_L - 150.0
	while hgx < WORLD_R + 150.0:
		var pool: Array[Texture2D] = _m_beards if _rng.randf() < 0.4 else _m_ferns
		var ht: Texture2D = pool[_rng.randi() % pool.size()]
		var hsc := _rng.randf_range(0.3, 0.5)
		var hg := Sprite2D.new()
		hg.texture = ht
		hg.centered = false
		hg.offset = Vector2(-ht.get_width() * 0.5, -24.0)
		hg.scale = Vector2(hsc, hsc)
		hg.flip_h = _rng.randf() < 0.5
		hg.position = Vector2(hgx, ROOF_Y + 6.0)
		hg.z_index = 2
		var hb := _rng.randf_range(0.38, 0.58)
		hg.modulate = Color(hb, hb, hb)
		add_child(hg)
		hgx += _rng.randf_range(420.0, 680.0)


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
	# the roof, a beard dripping from its lip
	var maw: Texture2D = load(BASE + _tex("combo", 2))
	var msc := 1.15
	_sprite(_tex("combo", 2), Vector2(1200.0,
			ROOF_Y + 40.0 + maw.get_height() * msc * 0.5 - 30.0), msc, 2,
			Color(0.30, 0.30, 0.28))
	var mb: Texture2D = _m_beards[0]
	var mbs := Sprite2D.new()
	mbs.texture = mb
	mbs.centered = false
	mbs.offset = Vector2(-mb.get_width() * 0.5, -24.0)
	mbs.scale = Vector2(0.45, 0.45)
	mbs.position = Vector2(1310.0, ROOF_Y + maw.get_height() * msc - 60.0)
	mbs.z_index = 2
	mbs.modulate = Color(0.6, 0.6, 0.6)
	add_child(mbs)
	# 2 — THE STANDING STONES (the breather between arcs 2 and 3): two
	# monoliths rooted in the moss, vines climbing them, one gold glint
	var stones_x := 6150.0
	_prop(_tex("bigrock", 3), stones_x, FLOOR_Y + 50.0, 0.72, 3,
			Color(0.48, 0.48, 0.45))
	_prop(_tex("bigrock", 5), stones_x + 240.0, FLOOR_Y + 44.0, 0.60, 4,
			Color(0.38, 0.38, 0.36), true)
	var sv: Texture2D = _m_vines[3]
	_tsprite(sv, Vector2(stones_x - 40.0,
			FLOOR_Y + 20.0 - sv.get_height() * 0.5 * 0.5), 0.5, 4,
			Color(0.52, 0.52, 0.48))
	_prop(_tex("rock", 34), stones_x - 190.0, FLOOR_Y + 26.0, 0.55, 4,
			Color(0.42, 0.42, 0.40))
	var seam := _prop(_tex("floor", 15), stones_x + 90.0, FLOOR_Y + 34.0,
			0.4, 4)
	_glow_light(seam, GOLD, 0.36, 1.2)
	# 3 — THE SPIKE GARDEN (the last stretch before the door): stalagmite
	# clusters the path threads between, moss creeping to their feet
	var sg_x := 12900.0
	_prop(_tex("combo", 12), sg_x, FLOOR_Y + 44.0, 0.62, 3,
			Color(0.52, 0.52, 0.48))
	_prop(_tex("combo", 14), sg_x + 340.0, FLOOR_Y + 40.0, 0.5, 6,
			Color(0.15, 0.15, 0.14), true)
	_prop(_tex("combo", 15), sg_x + 620.0, FLOOR_Y + 46.0, 0.55, 3,
			Color(0.40, 0.40, 0.37))
	_boulder_cluster(sg_x + 180.0, 4)


# ---------- the forest pass (Realm 2's grammar, whole) ----------

## keep-clear test for tree/landmark posts: the platform arcs' ground
## footprints, the set-pieces, the spawn and the door
func _ground_clear(x: float) -> bool:
	if x < WORLD_L + 300.0 or x > WORLD_R - 800.0:
		return false
	for amx in ARC_XS:
		if x > amx - 260.0 and x < amx + 1650.0:
			return false
	if absf(x - 950.0) < 260.0 or absf(x - 1550.0) < 260.0:
		return false
	if x > 5850.0 and x < 6550.0:
		return false      # standing stones
	if x > 12650.0 and x < 13800.0:
		return false      # spike garden
	return true


func _build_forest() -> void:
	# GRAND landmarks at fixed posts down the walk — the exclamation marks
	for gx in [-700.0, 3350.0, 7750.0, 10050.0]:
		_spawn_grand(gx)
	# trees + boulder clusters where the ground is clear — SPARSER than R2's
	# forest (the ref is a cave wearing growth, not a jungle: rock leads,
	# green punctuates)
	var x := WORLD_L + 350.0
	while x < WORLD_R - 800.0:
		if _ground_clear(x):
			if _rng.randf() < 0.38:
				_spawn_tree(x)
			else:
				_boulder_cluster(x, 3 if _rng.randf() < 0.6 else 4)
		x += _rng.randf_range(430.0, 700.0)


## one grounded tree: trunk rooted in the moss line, canopy slab on the
## crown, hangers underneath (no twins), a rock at the base, a plant beside
func _spawn_tree(x: float) -> void:
	var depth := _rng.randf()   # 0 = far/dim/small, 1 = near/lit/tall
	var b := lerpf(0.26, 0.58, depth)   # silhouettes against the haze (the ref)
	var grp := Node2D.new()
	grp.position = Vector2(x, FLOOR_Y + 18.0)
	grp.z_index = 1 if depth < 0.5 else 2
	add_child(grp)
	var vt: Texture2D = _m_vines[_rng.randi() % _m_vines.size()]
	var vsc := _rng.randf_range(0.42, 0.78) * lerpf(0.7, 1.0, depth)
	var vh := vt.get_height() * vsc
	# the crown stays under the roof line — a canopy scraping the curtain
	# reads as growth into the dark, but beards from nothing are banned
	const MAX_TREE_H := 640.0
	if vh > MAX_TREE_H:
		vsc *= MAX_TREE_H / vh
		vh = MAX_TREE_H
	var flip := _rng.randf() < 0.5
	var trunk := Sprite2D.new()
	trunk.texture = vt
	trunk.scale = Vector2(vsc, vsc)
	trunk.flip_h = flip
	trunk.position = Vector2(0.0, -vh * 0.5 + 26.0)
	trunk.modulate = Color(b, b, b)
	grp.add_child(trunk)
	# canopy: a moss slab resting ON the crown, fringe sunk into the trunk top
	if _rng.randf() < 0.45:
		var pt: Texture2D = _m_plats[_rng.randi() % _m_plats.size()]
		var psc := _rng.randf_range(0.34, 0.48) * lerpf(0.75, 1.0, depth)
		var ph := pt.get_height() * psc
		var canopy := Sprite2D.new()
		canopy.texture = pt
		canopy.scale = Vector2(psc, psc)
		canopy.flip_h = _rng.randf() < 0.5
		canopy.position = Vector2(_rng.randf_range(-40.0, 40.0),
				-vh + 26.0 + ph * 0.30)
		canopy.modulate = Color(b, b, b)
		grp.add_child(canopy)
		# a mossy rock perched on the crown sometimes
		if _rng.randf() < 0.4:
			var prt: Texture2D = _m_rocks[_rng.randi() % _m_rocks.size()]
			var prsc := _rng.randf_range(0.16, 0.26) * psc / 0.4
			var prk := Sprite2D.new()
			prk.texture = prt
			prk.scale = Vector2(prsc, prsc)
			prk.flip_h = _rng.randf() < 0.5
			prk.position = canopy.position + Vector2(
					_rng.randf_range(-pt.get_width() * psc * 0.25,
					pt.get_width() * psc * 0.25),
					-ph * 0.30 - prt.get_height() * prsc * 0.35)
			prk.modulate = Color(b * 0.95, b * 0.95, b * 0.95)
			grp.add_child(prk)
		# hangers under the canopy fringe — no twins, halves split
		var n_hang := 1 + (_rng.randi() % 2)
		var pool: Array[Texture2D] = []
		pool.append_array(_m_ferns)
		pool.append_array(_m_beards)
		for i in n_hang:
			var pick := _rng.randi() % pool.size()
			var ht: Texture2D = pool[pick]
			pool.remove_at(pick)
			var hsc := _rng.randf_range(0.30, 0.48) * psc / 0.4
			var hg := Sprite2D.new()
			hg.texture = ht
			hg.centered = false
			hg.offset = Vector2(-ht.get_width() * 0.5, -24.0)
			hg.scale = Vector2(hsc, hsc)
			hg.flip_h = _rng.randf() < 0.5
			var span := pt.get_width() * psc * 0.32
			var hx := _rng.randf_range(-span, -span * 0.2) if (n_hang == 2 and i == 0) \
					else (_rng.randf_range(span * 0.2, span) if n_hang == 2 \
					else _rng.randf_range(-span, span))
			hg.position = canopy.position + Vector2(hx, ph * 0.24)
			var hbr := b * _rng.randf_range(0.8, 1.05)
			hg.modulate = Color(hbr, hbr, hbr)
			grp.add_child(hg)
	# a rock hugging the base — the CAVE pack's rock under the MOSS pack's
	# tree: the two packs grown together
	if _rng.randf() < 0.7:
		var use_cave := _rng.randf() < 0.5
		var rt: Texture2D = load(BASE + _tex("rock",
				MED_ROCKS[_rng.randi() % MED_ROCKS.size()])) if use_cave \
				else _m_rocks[_rng.randi() % _m_rocks.size()]
		var rsc := _rng.randf_range(0.20, 0.34) * lerpf(0.75, 1.0, depth)
		var rk := Sprite2D.new()
		rk.texture = rt
		rk.scale = Vector2(rsc, rsc)
		rk.flip_h = _rng.randf() < 0.5
		rk.position = Vector2((1.0 if flip else -1.0) * _rng.randf_range(40.0, 90.0),
				-rt.get_height() * rsc * 0.30 + 8.0)
		var rb := b * _rng.randf_range(0.85, 1.0)
		rk.modulate = Color(rb, rb, rb)
		grp.add_child(rk)
	# an animated plant breathing at the roots
	if _rng.randf() < 0.5:
		var pdir: String = ["flower", "plant1", "plant_wind"][_rng.randi() % 3]
		var plant := _plant(pdir, _rng.randf_range(7.0, 10.0),
				_rng.randf_range(0.16, 0.26) * lerpf(0.75, 1.0, depth))
		plant.position = Vector2(x + (-1.0 if flip else 1.0) * _rng.randf_range(50.0, 110.0),
				FLOOR_Y + 12.0)
		plant.z_index = grp.z_index
		plant.modulate = Color(b, b, b)


## a grand landmark: twin trunks, a grand ledge across the crowns, a dark
## cascade off the lip, hangers, a perched rock
func _spawn_grand(x: float) -> void:
	if not _ground_clear(x):
		return
	var b := _rng.randf_range(0.48, 0.64)
	var grp := Node2D.new()
	grp.position = Vector2(x, FLOOR_Y + 18.0)
	grp.z_index = 2
	add_child(grp)
	var vi := _rng.randi() % _m_vines.size()
	var trunk_h := 0.0
	for t in 2:
		var vt: Texture2D = _m_vines[(vi + 1 + t) % _m_vines.size()]
		var vsc := _rng.randf_range(0.50, 0.62)
		var vh := vt.get_height() * vsc
		if vh > 560.0:
			vsc *= 560.0 / vh
			vh = 560.0
		trunk_h = maxf(trunk_h, vh)
		var trunk := Sprite2D.new()
		trunk.texture = vt
		trunk.scale = Vector2(vsc, vsc)
		trunk.flip_h = t == 1
		trunk.position = Vector2(-70.0 + 140.0 * t, -vh * 0.5 + 26.0)
		var tb := b * _rng.randf_range(0.85, 1.0)
		trunk.modulate = Color(tb, tb, tb)
		grp.add_child(trunk)
	var lt: Texture2D = load(MBASE + ("platform_grand.png" if _rng.randf() < 0.6
			else "platform_tall.png"))
	var lsc := _rng.randf_range(0.40, 0.50)
	var lh := lt.get_height() * lsc
	var ledge := Sprite2D.new()
	ledge.texture = lt
	ledge.scale = Vector2(lsc, lsc)
	ledge.flip_h = _rng.randf() < 0.5
	ledge.position = Vector2(0.0, -trunk_h + 26.0 + lh * 0.28)
	ledge.modulate = Color(b, b, b)
	grp.add_child(ledge)
	# the cascade: a moss-fall off the ledge lip, top buried in the fringe
	var ct: Texture2D = load(MBASE + ("cascade_dark.png" if _rng.randf() < 0.7
			else "cascade.png"))
	var csc := _rng.randf_range(0.34, 0.44)
	var ch := ct.get_height() * csc
	var casc := Sprite2D.new()
	casc.texture = ct
	casc.scale = Vector2(csc, csc)
	casc.flip_h = _rng.randf() < 0.5
	casc.position = Vector2(_rng.randf_range(-lt.get_width() * lsc * 0.25,
			lt.get_width() * lsc * 0.25),
			ledge.position.y + lh * 0.20 + ch * 0.42)
	var cb := b * _rng.randf_range(0.7, 0.85)
	casc.modulate = Color(cb, cb, cb)
	grp.add_child(casc)
	# hangers off the ledge — no twins, halves split
	var pool: Array[Texture2D] = []
	pool.append_array(_m_ferns)
	pool.append_array(_m_beards)
	for i in 2:
		var pick := _rng.randi() % pool.size()
		var ht: Texture2D = pool[pick]
		pool.remove_at(pick)
		var hsc := _rng.randf_range(0.36, 0.52)
		var hg := Sprite2D.new()
		hg.texture = ht
		hg.centered = false
		hg.offset = Vector2(-ht.get_width() * 0.5, -24.0)
		hg.scale = Vector2(hsc, hsc)
		hg.flip_h = _rng.randf() < 0.5
		var span := lt.get_width() * lsc * 0.34
		var hx := _rng.randf_range(-span, -span * 0.25) if i == 0 \
				else _rng.randf_range(span * 0.25, span)
		hg.position = ledge.position + Vector2(hx, lh * 0.22)
		var hbr := b * _rng.randf_range(0.8, 1.0)
		hg.modulate = Color(hbr, hbr, hbr)
		grp.add_child(hg)
	# a rock perched on the ledge crown
	var prt: Texture2D = _m_rocks[_rng.randi() % _m_rocks.size()]
	var prsc := _rng.randf_range(0.20, 0.30)
	var prk := Sprite2D.new()
	prk.texture = prt
	prk.scale = Vector2(prsc, prsc)
	prk.flip_h = _rng.randf() < 0.5
	prk.position = ledge.position + Vector2(
			_rng.randf_range(-lt.get_width() * lsc * 0.2, lt.get_width() * lsc * 0.2),
			-lh * 0.30 - prt.get_height() * prsc * 0.35)
	prk.modulate = Color(b * 0.95, b * 0.95, b * 0.95)
	grp.add_child(prk)


## THE UNDERGROWTH CARPET — the R2 guarantee: a small tuft / mossy rock /
## animated plant cluster every ~150px across the WHOLE map, deterministic,
## so no stretch can ever roll bare
func _build_undergrowth() -> void:
	var ux := WORLD_L - 200.0
	while ux < WORLD_R + 100.0:
		var b := _rng.randf_range(0.35, 0.65)
		var roll := _rng.randf()
		if roll < 0.5:
			var tt: Texture2D = _m_tufts[_rng.randi() % _m_tufts.size()]
			var tsc := _rng.randf_range(0.16, 0.30)
			var z := 3 if _rng.randf() < 0.6 else 6
			if z == 6:
				b *= 0.5
			_tsprite(tt, Vector2(ux, FLOOR_Y + 16.0 - tt.get_height() * tsc * 0.38),
					tsc, z, Color(b, b, b), _rng.randf() < 0.5)
		elif roll < 0.75:
			var rt: Texture2D = _m_rocks[_rng.randi() % _m_rocks.size()]
			var rsc := _rng.randf_range(0.12, 0.22)
			_tsprite(rt, Vector2(ux, FLOOR_Y + 14.0 - rt.get_height() * rsc * 0.30),
					rsc, 3, Color(b, b, b), _rng.randf() < 0.5)
		else:
			var pdir: String = ["flower", "plant1", "plant_wind"][_rng.randi() % 3]
			var plant := _plant(pdir, _rng.randf_range(7.0, 10.0),
					_rng.randf_range(0.12, 0.20))
			plant.position = Vector2(ux, FLOOR_Y + 8.0)
			plant.z_index = 3
			plant.modulate = Color(b, b, b)
		ux += _rng.randf_range(120.0, 210.0)


func _build_foreground() -> void:
	# darkest silhouettes hugging the bottom frame — rock and growth cut by
	# the frame, never floating
	var fore := Color(0.10, 0.10, 0.10)
	var fsx := WORLD_L + 250.0
	var fsi := 0
	while fsx < WORLD_R:
		if fsi % 3 == 2:
			var tt: Texture2D = _m_tufts[fsi % 3]
			var tsc := _rng.randf_range(0.5, 0.68)
			_tsprite(tt, Vector2(fsx, 850.0 - tt.get_height() * tsc * 0.5),
					tsc, 8, fore, _rng.randf() < 0.5)
		else:
			var fs_id: int = [32, 23, 19, 24, 33, 12][fsi % 6]
			var tex: Texture2D = load(BASE + _tex("rock", fs_id))
			var sc := _rng.randf_range(0.6, 0.75)
			_sprite(_tex("rock", fs_id),
					Vector2(fsx, 840.0 - tex.get_height() * sc * 0.5),
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
	# THE GREEN HAZE (the ref's whole atmosphere): drifting cumulus masses
	# of soft green filling the cavern air behind the gameplay, brighter than
	# everything else — the rock reads as silhouette against them
	for cfg: Array in [[-7, 0.10, 1.5, 5.0], [-5, 0.08, 1.1, 7.5], [7, 0.045, 1.8, 4.0]]:
		var band := Node2D.new()
		band.z_index = int(cfg[0])
		add_child(band)
		var spacing := 780.0 * (cfg[2] as float)
		var x := WORLD_L - 1400.0
		while x < WORLD_R + 1400.0:
			# each station is a small CLUSTER of overlapping puffs — cumulus,
			# not a smooth wash
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
	# LIGHT POOLS — the ref's glowing core: every stretch gets one bright
	# green bloom high in the air, as if daylight leaks through the rock
	var px := WORLD_L - 400.0
	while px < WORLD_R + 400.0:
		var pool := Sprite2D.new()
		pool.texture = _soft_glow_texture()
		pool.position = Vector2(px + _rng.randf_range(-200.0, 200.0),
				_rng.randf_range(-240.0, 40.0))
		pool.scale = Vector2(_rng.randf_range(3.2, 4.6), _rng.randf_range(2.6, 3.8))
		pool.z_index = -6
		pool.modulate = Color(POOL_GREEN.r, POOL_GREEN.g, POOL_GREEN.b,
				_rng.randf_range(0.10, 0.16))
		add_child(pool)
		px += _rng.randf_range(1500.0, 2300.0)


var _fogs: Array[Sprite2D] = []
func _build_atmosphere() -> void:
	# local fog banks: neutral dark, faint
	var nfog := int((WORLD_R - WORLD_L + 1800.0) / 950.0) + 1
	for i in nfog:
		var f := Sprite2D.new()
		f.texture = load(MOSS_FOG)
		f.position = Vector2(WORLD_L - 900.0 + i * 950.0,
				FLOOR_Y - _rng.randf_range(60.0, 280.0))
		f.scale = Vector2(_rng.randf_range(2.8, 4.2), _rng.randf_range(2.0, 2.9))
		f.modulate = Color(0.32, 0.32, 0.28, _rng.randf_range(0.09, 0.13))
		f.z_index = -4 if i % 2 == 0 else 6
		add_child(f)
		_fogs.append(f)
	# drifting spores — the cave's slow golden dust
	var motes := CPUParticles2D.new()
	motes.texture = load(MOSS_SPORE)
	motes.amount = int((WORLD_R - WORLD_L) / 320.0)
	motes.lifetime = 16.0
	motes.preprocess = 16.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2((WORLD_R - WORLD_L) * 0.5 + 300.0, 520.0)
	motes.direction = Vector2(1, -0.1)
	motes.spread = 14.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 12.0
	motes.initial_velocity_max = 30.0
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.1
	motes.color = Color(1.0, 0.9, 0.6, 0.45)
	motes.position = Vector2((WORLD_L + WORLD_R) * 0.5, FLOOR_Y - 260.0)
	motes.z_index = 6
	add_child(motes)
	# FIREFLIES — Realm 2's living air, gold in the dark
	var flies := CPUParticles2D.new()
	flies.texture = load(MOSS_FIREFLY)
	flies.amount = int((WORLD_R - WORLD_L) / 900.0)
	flies.lifetime = 9.0
	flies.preprocess = 9.0
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2((WORLD_R - WORLD_L) * 0.5 + 300.0, 300.0)
	flies.direction = Vector2(0, -1)
	flies.spread = 180.0
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 6.0
	flies.initial_velocity_max = 18.0
	flies.scale_amount_min = 0.5
	flies.scale_amount_max = 0.9
	flies.color = Color(1.0, 0.85, 0.5, 0.8)
	flies.position = Vector2((WORLD_L + WORLD_R) * 0.5, FLOOR_Y - 160.0)
	flies.z_index = 7
	add_child(flies)
	# corner vignette — neutral black
	var cl := CanvasLayer.new()
	cl.layer = 15
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0),
			Color(0.0, 0.0, 0.0, 0.32)])
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
	# eyes keep their own violet — original palettes everywhere today
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
		g.z_index = 5
		add_child(g)
		if g.has_method("set_home"):
			g.set_home(wx)


# Jades ride the high path: each arc's mid + high block + slat, plus a few
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
		j.z_index = 5
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
	lbl.text = "R1 MOSSY CAVERN REBUILD — walk right →   (R restart · ESC hub)"
	lbl.position = Vector2(16, 12)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.78, 0.6))
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
