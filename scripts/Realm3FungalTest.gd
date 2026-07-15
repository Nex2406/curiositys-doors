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

const BASE := "res://assets/realms/realm3_fungal/"
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const HUB_SCENE := "res://scenes/Hub.tscn"
const STARTING_LIVES: int = 3

const FLOOR_Y := 420.0
const SPAWN := Vector2(-40.0, FLOOR_Y - 140.0)
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
const SIL_FAR := Color(0.045, 0.085, 0.078)       # darkest, flat
const SIL_MID := Color(0.07, 0.125, 0.115)        # midground silhouettes
# the giant caps carry a LOUD hue each (Advika: increase it) — teal /
# moss / blue, saturated, still a step under the gameplay layer's light
const CAP_HUES: Array[Color] = [Color(0.16, 0.33, 0.31),
		Color(0.19, 0.30, 0.16), Color(0.14, 0.26, 0.36)]
const GLOW_WARM := Color(1.0, 0.85, 0.62)         # amber caps / gold stalks
const GLOW_COOL := Color(0.68, 0.95, 0.90)        # pale cyan — white glowers
const GLOW_MOSS := Color(0.62, 0.95, 0.58)        # bioluminescent moss green
const FRINGE_LIT := Color(0.95, 1.0, 0.97)        # gameplay fringe (grade teals it)
const FRINGE_NEAR := Color(0.55, 0.68, 0.63)      # front row, darker
const FRINGE_HANG := Color(0.45, 0.58, 0.54)      # ceiling fringe, dimmer still
const MAX_GLOW_LIGHTS := 24
const AMBIENT := Color(0.55, 0.72, 0.68)          # the teal grade (R2-dark)
const FOG_TINT := Color(0.20, 0.38, 0.34)         # haze bands: deep teal, faint
const MOSS_FOG := "res://assets/realms/realm2_moss/fog.png"
const MOSS_SPORE := "res://assets/realms/realm2_moss/spore.png"
const MOSS_FIREFLY := "res://assets/realms/realm2_moss/firefly.png"

# frond cluster slices used for fringe rows (clusters only — singles read thin)
const FRINGE_TEX: Array[int] = [2, 3, 4, 10, 11, 16, 3, 10, 11]

var _curi: CharacterBody2D
var _cam: Camera2D
var _lives: LivesHUD
var _exit_door: Area2D
var _at_exit := false
var _lbl: Label
var _dying := false
var _leaving := false
var _glow_lights := 0
var _hills_far: Node2D
var _hills_mid: Node2D
var _ghosts := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.09, 0.08))
	_rng.seed = 20260714
	_build_backdrop()
	_build_background()
	_build_terrain()
	_build_platforms()
	_build_ceiling()
	_build_dressing()
	_build_density()
	_build_foreground()
	_build_atmosphere()
	_build_fog_layers()
	_build_player()
	_build_exit_door()
	_build_camera()
	_build_ui()
	# hazy blue-grey ambient — a soft cool dim over the world (the backdrop
	# CanvasLayer is unaffected, so the mist keeps glowing behind everything
	# and the lantern's ADDED light stays the one warm thing)
	var grade := CanvasModulate.new()
	grade.color = AMBIENT
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
		_bloom(host as Sprite2D, col, 0.22)
	if _glow_lights >= MAX_GLOW_LIGHTS:
		return
	_glow_lights += 1
	# softened: bigger pool, lower energy — light pools, not spotlights
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


## Bands move at cam*0.82 (far) and cam*0.6 (mid), so an item at base x
## appears at base + factor*cam. For cam in [-450, 25650] the view only ever
## samples base positions far: [-916, 5452], mid: [-1015, 11095]. Populate
## those ranges (plus margin) — full coverage, no layer edge ever on screen.
const FAR_L := -950.0
const FAR_R := 5600.0
const MID_L := -1050.0
const MID_R := 11300.0

func _build_background() -> void:
	# two hand-driven parallax bands (Realm 2's manners), dark teal
	# silhouettes per the value hierarchy: far = darkest + flattest.
	_hills_far = Node2D.new()
	_hills_far.z_index = -8
	add_child(_hills_far)
	_hills_mid = Node2D.new()
	_hills_mid.z_index = -6
	add_child(_hills_mid)
	# far spires: CLUSTERS of 2-3 on a loose rhythm across the whole far
	# range — loops, not hand lists, so any world length stays covered
	var spx := FAR_L + 150.0
	var spi := 0
	while spx < FAR_R:
		var sp_ids: Array = [[1, 3], [2, 4, 5], [3, 1], [5, 2]][spi % 4]
		_spire_cluster(_hills_far, spx, sp_ids, _rng.randf_range(0.52, 0.68), SIL_FAR)
		spx += _rng.randf_range(400.0, 620.0)
		spi += 1
	# far cap skyline — giant dark caps stacked behind everything: the
	# cavern is mushrooms all the way back (use the pack to the hilt)
	var fcx := FAR_L + 120.0
	var fci := 0
	while fcx < FAR_R:
		var fct: Texture2D = load(BASE + "mushroomcap%d.png" % [3, 4, 6, 9, 10][fci % 5])
		var fcs := _rng.randf_range(0.9, 1.3)
		var fs2 := Sprite2D.new()
		fs2.texture = fct
		fs2.scale = Vector2(fcs, fcs)
		fs2.flip_h = fci % 2 == 1
		fs2.position = Vector2(fcx, FLOOR_Y + 40.0 - fct.get_height() * fcs * 0.5)
		fs2.modulate = Color(SIL_FAR.r * 1.15, SIL_FAR.g * 1.15, SIL_FAR.b * 1.15)
		_hills_far.add_child(fs2)
		fcx += _rng.randf_range(540.0, 780.0)
		fci += 1
	# far mushroom ghosts: dark shapes, each holding a small glint — the
	# glints alternate amber / cyan / moss (the realm's own fireflies)
	var mgx := FAR_L + 350.0
	while mgx < FAR_R:
		var mg_id: int = [17, 23, 24][_ghosts % 3]
		var tex: Texture2D = load(BASE + "mushroomglow%d.png" % mg_id)
		var sc := _rng.randf_range(0.42, 0.52)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.position = Vector2(mgx, FLOOR_Y + 8.0 - tex.get_height() * sc * 0.5)
		s.modulate = Color(SIL_FAR.r * 1.6, SIL_FAR.g * 1.6, SIL_FAR.b * 1.6, 0.9)
		_hills_far.add_child(s)
		var g := Sprite2D.new()
		g.texture = _soft_glow_texture()
		g.position = s.position + Vector2(0, -tex.get_height() * sc * 0.30)
		g.scale = Vector2(0.9, 0.9)
		var ghue: Color = [GLOW_WARM, GLOW_COOL, GLOW_MOSS][_ghosts % 3]
		_ghosts += 1
		g.modulate = Color(ghue.r, ghue.g, ghue.b, 0.16)
		_hills_far.add_child(g)
		mgx += _rng.randf_range(380.0, 560.0)
	# mid band: mound skyline + one spire cluster, a step lighter than far
	var mx := MID_L
	while mx < MID_R:
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
		s.modulate = SIL_MID
		_hills_mid.add_child(s)
		mx += _rng.randf_range(380.0, 560.0)
	# MID BAND VIGNETTES (Advika: denser AND intentional) — the mid depth
	# is composed set-pieces, each overlapping into one silhouette with one
	# hue glint, then a breathing gap: a giant cap with its child and a
	# stone seat / a spire grove / a cap flanked by thin stalks / a glow
	# garden. Rotating, never a strip.
	var vx := MID_L + 250.0
	var vi := 0
	while vx < MID_R:
		var hue: Color = CAP_HUES[vi % 3]
		var dhue := Color(hue.r * 0.7, hue.g * 0.7, hue.b * 0.7)
		var mlit := Color(SIL_MID.r * 1.35, SIL_MID.g * 1.35, SIL_MID.b * 1.35)
		# a darker BACKDROP GIANT looming behind every second vignette —
		# the crowd behind the crowd
		if vi % 3 == 0:
			_mid_sprite("mushroomcap%d.png" % [3, 9, 6, 4, 10][vi % 5],
					vx + 90.0, 34.0, _rng.randf_range(1.0, 1.25),
					Color(dhue.r * 0.8, dhue.g * 0.8, dhue.b * 0.8), vi % 2 == 0)
		match vi % 4:
			0:  # cap family: giant + child at the stem + stone seat
				var big0 := _mid_sprite("mushroomcap%d.png" % [9, 6, 4][vi % 3],
						vx, 30.0, _rng.randf_range(0.82, 0.95), hue, vi % 2 == 0)
				_cap_aura(big0, vi)
				_mid_sprite("mushroomcap%d.png" % [10, 3][vi % 2], vx + 175.0,
						26.0, _rng.randf_range(0.42, 0.5), dhue, vi % 2 == 1)
				_mid_sprite("fungalstone%d.png" % [18, 20, 22][vi % 3],
						vx - 165.0, 20.0, 0.5, dhue)
			1:  # spire grove: tall column, short spire, pale glower at foot
				_mid_sprite("stalagmiteb%d.png" % [2, 3, 1, 5][vi % 4], vx,
						50.0, _rng.randf_range(0.70, 0.80), SIL_MID, vi % 2 == 0)
				_mid_sprite("stalagmiteb%d.png" % [5, 1][vi % 2], vx + 150.0,
						45.0, _rng.randf_range(0.34, 0.42), dhue, vi % 2 == 1)
				_mid_sprite("mushroomglow%d.png" % [17, 23][vi % 2],
						vx - 130.0, 22.0, 0.3, mlit)
			2:  # a hued cap flanked by tall thin stalks
				_mid_sprite("mushroomglow%d.png" % [1, 7][vi % 2], vx - 140.0,
						18.0, 0.55, dhue, vi % 2 == 0)
				var big2 := _mid_sprite("mushroomcap%d.png" % [4, 10, 6][vi % 3],
						vx, 30.0, _rng.randf_range(0.72, 0.85), hue, vi % 2 == 1)
				_cap_aura(big2, vi)
				_mid_sprite("mushroomglow%d.png" % [7, 11][vi % 2], vx + 150.0,
						20.0, 0.48, dhue, vi % 2 == 0)
			3:  # glow garden: clean stone + a family of pale glowers
				_mid_sprite("fungalstone%d.png" % [20, 22, 18][vi % 3], vx,
						20.0, 0.55, mlit, vi % 2 == 0)
				for gi in 3:
					_mid_sprite("mushroomglow%d.png" % [17, 23, 24][gi],
							vx + 90.0 + gi * 70.0, 24.0,
							_rng.randf_range(0.22, 0.3), mlit, gi % 2 == 0)
		# every vignette holds one soft palette glint — the alive bit
		var fg := Sprite2D.new()
		fg.texture = _soft_glow_texture()
		fg.position = Vector2(vx + _rng.randf_range(-60.0, 60.0),
				FLOOR_Y - _rng.randf_range(60.0, 130.0))
		fg.scale = Vector2(1.1, 1.1)
		var ghue2: Color = [GLOW_MOSS, GLOW_WARM, GLOW_COOL][vi % 3]
		fg.modulate = Color(ghue2.r, ghue2.g, ghue2.b, 0.13)
		_hills_mid.add_child(fg)
		vx += _rng.randf_range(330.0, 470.0)
		vi += 1
	# tall slender mushrooms threading the vignette gaps — the pack's thin
	# species (caps 1/2/5/7/8), hued dark, so no air stays empty
	var ttx := MID_L + 140.0
	var tti := 0
	while ttx < MID_R:
		var thue: Color = CAP_HUES[tti % 3]
		_mid_sprite("mushroomcap%d.png" % [1, 2, 5, 7, 8][tti % 5], ttx,
				24.0, _rng.randf_range(0.5, 0.75),
				Color(thue.r * 0.8, thue.g * 0.8, thue.b * 0.8), tti % 2 == 0)
		ttx += _rng.randf_range(500.0, 720.0)
		tti += 1
	# and tall thin mushrooms deeper still, sunk into the far dark
	var tmx := FAR_L + 80.0
	var tmi := 0
	while tmx < FAR_R:
		var tm_id: int = [1, 7, 11, 2, 8, 5][tmi % 6]
		var tex: Texture2D = load(BASE + "mushroomglow%d.png" % tm_id)
		var sc := _rng.randf_range(0.5, 0.62)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = _rng.randf() < 0.5
		s.position = Vector2(tmx, FLOOR_Y + 16.0 - tex.get_height() * sc * 0.5)
		s.modulate = Color(SIL_FAR.r * 1.3, SIL_FAR.g * 1.3, SIL_FAR.b * 1.3)
		_hills_far.add_child(s)
		tmx += _rng.randf_range(280.0, 420.0)
		tmi += 1
	# UPPER AIR (Advika: background too plain) — distant stalactite teeth
	# hanging in both bands. Their heads bury behind the gameplay roof fill,
	# so every window between the roof's fingers shows dark depth, never
	# bare gradient. Far teeth: short, darkest. Mid teeth: longer, a step up.
	_teeth_row(_hills_far, FAR_L, FAR_R, ROOF_Y - 60.0, 0.55, 0.75,
			Color(SIL_FAR.r * 1.15, SIL_FAR.g * 1.15, SIL_FAR.b * 1.15))
	_teeth_row(_hills_mid, MID_L, MID_R, ROOF_Y - 40.0, 0.6, 0.85, SIL_MID)
	# (pillars + mid floor life now live inside the vignettes above)


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


## a soft hue aura wrapped around a giant background cap — every giant
## glows its own color (Advika: hues that GLOW)
func _cap_aura(cap: Sprite2D, hue_i: int) -> void:
	var gc: Color = [GLOW_COOL, GLOW_MOSS, Color(0.55, 0.75, 1.0)][hue_i % 3]
	var g := Sprite2D.new()
	g.texture = _soft_glow_texture()
	var w: float = cap.texture.get_width() * cap.scale.x
	var h: float = cap.texture.get_height() * cap.scale.y
	g.position = cap.position + Vector2(0, -h * 0.24)
	g.scale = Vector2(w / 150.0, w / 215.0)
	g.modulate = Color(gc.r, gc.g, gc.b, 0.24)
	_hills_mid.add_child(g)


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
				wsc, 1, Color(0.30, 0.40, 0.36), wp[3])
	_prop("fungalstoneb4.png", WORLD_L + 100.0, FLOOR_Y + 30.0, 0.5, 2,
			Color(0.45, 0.55, 0.50))
	_prop("fungalstoneb7.png", WORLD_R - 100.0, FLOOR_Y + 30.0, 0.5, 2,
			Color(0.45, 0.55, 0.50), true)
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
	# CREST — tall dark skyline row behind everything on the floor
	_hill_row(FLOOR_Y + 40.0, 0.55, 0, Color(0.32, 0.42, 0.38))
	# BRIGHTEST row — the lit fringe she walks against (behind her, z<5)
	_hill_row(FLOOR_Y + 85.0, 0.48, 2, Color(0.62, 0.72, 0.68))
	# then down into the dark: each row lower + darker, same big fingers
	_hill_row(FLOOR_Y + 150.0, 0.44, 3, Color(0.38, 0.47, 0.43))
	_hill_row(FLOOR_Y + 215.0, 0.42, 4, Color(0.20, 0.27, 0.24))
	# THE THROUGH-ROW — in front of the hero, tips rising ABOVE her feet
	# (~50px past the floor line) so she wades THROUGH the growth, never
	# stands ON it. Dark enough that she still reads clearly behind it.
	_hill_row(FLOOR_Y + 160.0, 0.40, 6, Color(0.13, 0.19, 0.17))
	# and a deeper front lip fading to the frame bottom
	_hill_row(FLOOR_Y + 290.0, 0.45, 6, Color(0.08, 0.12, 0.11))
	# THE FOREST FLOOR MAT — continuous (she is never in the air) but
	# BLENDED (Advika: no moss strips): tip heights swell and sink on slow
	# waves, two staggered depths interleave, tiny mushrooms and curls are
	# woven in — one dense meadow, never a hedge line
	_floor_mat()


## the meadow builder — ONE gradient field, not stacked flat layers
## (Advika: the dark front band read as a strip). Every clump draws its
## own depth t: tint slides continuously from the lit back value to the
## dark front value, z follows t, height rides TWO overlapped waves plus
## jitter. The walk line becomes a zigzag of value and height — there is
## no boundary anywhere for the eye to follow.
func _floor_mat() -> void:
	var dark := Color(0.11, 0.16, 0.145)
	var x := WORLD_L - 200.0
	while x < WORLD_R + 200.0:
		var t := _rng.randf()
		var idx: int = FRINGE_TEX[_rng.randi() % FRINGE_TEX.size()]
		var tex: Texture2D = load(BASE + "fungalfrond%d.png" % idx)
		var wave: float = clampf(0.5 + 0.28 * sin(x * 0.0021)
				+ 0.22 * sin(x * 0.0063 + 1.7), 0.0, 1.0)
		var sc := lerpf(0.11, 0.24, wave) * _rng.randf_range(0.78, 1.25)
		var h := tex.get_height() * sc
		var base := FLOOR_Y + lerpf(6.0, 34.0, t)
		var sk := h * 0.14 + 6.0 + _rng.randf_range(0.0, 10.0)
		var tj := _rng.randf_range(0.86, 1.14)
		var tint := Color(lerpf(FRINGE_NEAR.r, dark.r, t) * tj,
				lerpf(FRINGE_NEAR.g, dark.g, t) * tj,
				lerpf(FRINGE_NEAR.b, dark.b, t) * tj)
		_sprite("fungalfrond%d.png" % idx, Vector2(x, base - h * 0.5 + sk),
				sc, 4 if t < 0.45 else 6, tint, _rng.randf() < 0.5)
		x += tex.get_width() * sc * _rng.randf_range(0.30, 0.5)
	# woven accents at random depths: tiny mushrooms and curled sprouts
	var ax := WORLD_L + _rng.randf_range(150.0, 400.0)
	while ax < WORLD_R:
		var az: int = 4 if _rng.randf() < 0.5 else 6
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
					csc, az, Color(0.30, 0.40, 0.36), _rng.randf() < 0.5)
		ax += _rng.randf_range(380.0, 700.0)
	# (the old seam-belt tuft strip is gone — Advika: it read as a
	# continuous moss band above the ground. The undulating rows + meadow
	# interlock on their own now.)


## the same recipe upside down for a cave-roof edge: a near-solid deep
## CURTAIN first (big strips, tight step — heads buried in the fill, no
## background window survives between fingers), then two shaped rows in
## front. The ceiling reads as one grown underside, end to end.
func _roof_band(x0: float, x1: float, edge_y: float) -> void:
	_hill_row(edge_y - 10.0, 0.55, 1, Color(0.13, 0.19, 0.17), true, x0, x1,
			0.38, 0.48)
	_hill_row(edge_y - 25.0, 0.44, 1, Color(0.22, 0.30, 0.27), true, x0, x1,
			0.46, 0.58)
	_hill_row(edge_y - 35.0, 0.32, 2, Color(0.45, 0.55, 0.51), true, x0, x1)


func _build_platforms() -> void:
	# Platforms are MUSHROOMS ONLY (Advika: rocks are decor, never steps).
	# Each arc climbs low -> mid -> high. The LOW step is a giant cap
	# half-buried in the meadow — a dome swelling out of the growth; the
	# higher steps are full mushrooms with visible stems.
	# ZONE B
	_shroom_platform(950.0, FLOOR_Y - 130.0, 9, false, 210.0)
	_shroom_platform(1500.0, FLOOR_Y - 245.0, 9)
	# ZONE C: the overgrown stack
	_shroom_platform(2950.0, FLOOR_Y - 120.0, 6, true, 210.0)
	_shroom_platform(3350.0, FLOOR_Y - 235.0, 6)
	_shroom_platform(3750.0, FLOOR_Y - 350.0, 4, true)
	# ZONE D
	_shroom_platform(4750.0, FLOOR_Y - 125.0, 4, false, 210.0)
	_shroom_platform(5250.0, FLOOR_Y - 240.0, 10)
	_shroom_platform(5750.0, FLOOR_Y - 355.0, 9, true)
	# THE LONG WALK — climbing arcs repeat down the cavern, each with its
	# own cap species mix; clean boulder piles sit at the arc feet as DECOR
	var arc_caps: Array = [[9, 6, 9], [6, 4, 10], [10, 10, 6], [4, 9, 4]]
	for ai in ARC_XS.size():
		var amx: float = ARC_XS[ai]
		var caps: Array = arc_caps[ai % arc_caps.size()]
		_shroom_platform(amx, FLOOR_Y - 125.0, caps[0], ai % 2 == 0, 210.0)
		_shroom_platform(amx + 500.0, FLOOR_Y - 240.0, caps[1], ai % 2 == 1)
		_shroom_platform(amx + 1000.0, FLOOR_Y - 355.0, caps[2], ai % 2 == 0)
		_boulder_decor(amx - 320.0, ai % 2 == 1)
		_shroom_cluster(amx + 490.0, FLOOR_Y - 234.0, (ai + 1) % 3)
	# LONE HOP CAPS (Advika: mushrooms to jump on) — playful single domes
	# swelling from the meadow down every stretch between the arcs
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
			_shroom_platform(hx, FLOOR_Y - _rng.randf_range(108.0, 140.0),
					[9, 6, 4, 10][hpi % 4], hpi % 2 == 1, 210.0)
			hpi += 1
		hx += _rng.randf_range(680.0, 980.0)


## rocks are DECOR (Advika): a clean half-sunk pile in the meadow —
## no growth on the stone, no collider, nothing to stand on
func _boulder_decor(cx: float, fh := false) -> void:
	_prop("fungalstoneb%d.png" % [6, 4, 1][int(absf(cx)) % 3], cx,
			FLOOR_Y + 60.0, _rng.randf_range(0.36, 0.44), 3, Color.WHITE, fh)
	_prop("fungalstoneb%d.png" % [1, 6, 4][int(absf(cx)) % 3], cx + 130.0,
			FLOOR_Y + 50.0, _rng.randf_range(0.24, 0.30), 4,
			Color(0.72, 0.80, 0.76), not fh)


## a giant mushroom rooted in the floor — the cap is the platform.
## bury = how deep the base sits under the floor line: 40 keeps the stem
## visible; ~210 sinks it so only the dome swells out of the meadow.
func _shroom_platform(cx: float, top_y: float, cap_id: int, fh := false,
		bury := 40.0) -> void:
	var tex: Texture2D = load(BASE + "mushroomcap%d.png" % cap_id)
	# scale so the cap's walkable dome (~8% below the texture top) is top_y
	var sc := (FLOOR_Y + bury - top_y) / (tex.get_height() * 0.92)
	var h := tex.get_height() * sc
	var w := tex.get_width() * sc
	_sprite("mushroomcap%d.png" % cap_id,
			Vector2(cx, FLOOR_Y + bury - h * 0.5), sc, 1, Color.WHITE, fh)
	# one-way slab across the cap — she can hop up through it, walk off it
	_collider_rect(cx - w * 0.26, cx + w * 0.26, top_y, top_y + 24.0, true)
	# a couple of tiny caps perched on the dome — overgrown, lived-on
	_prop("mushroomglow%d.png" % ([16, 20, 25][_rng.randi() % 3]),
			cx - w * 0.14, top_y + 10.0, 0.16, 2, Color.WHITE, _rng.randf() < 0.5)
	_prop("mushroomglow%d.png" % ([18, 21, 22][_rng.randi() % 3]),
			cx + w * 0.17, top_y + 12.0, 0.13, 2, Color.WHITE, _rng.randf() < 0.5)


const ROOF_Y := -380.0   # ONE ceiling line, end to end (Advika: uniform, higher)

func _build_ceiling() -> void:
	# ONE continuous roof: a single fill + a single hanging hill band the
	# whole way — no chunks, no steps, no gaps. Stalactites and half-sunk
	# boulders vary the silhouette; the LINE never moves.
	# ABOVE the dressed edge the rock fades SMOOTHLY into near-black: a
	# vertex-color gradient polygon, so a high jump reads as looking up
	# into thick dark stone — no bands, no seams, no shapes (Advika
	# 2026-07-15: the jump view must be clean)
	var grad_p := Polygon2D.new()
	grad_p.polygon = PackedVector2Array([
			Vector2(WORLD_L - 900.0, -800.0), Vector2(WORLD_R + 900.0, -800.0),
			Vector2(WORLD_R + 900.0, ROOF_Y), Vector2(WORLD_L - 900.0, ROOF_Y)])
	grad_p.vertex_colors = PackedColorArray([SOIL, SOIL, FILL_DARK, FILL_DARK])
	grad_p.z_index = 0
	add_child(grad_p)
	_fill_rect(WORLD_L - 900.0, WORLD_R + 900.0, -1400.0, -800.0, 0, SOIL)
	_roof_band(WORLD_L - 250.0, WORLD_R + 250.0, ROOF_Y)
	# stalactites on an even rhythm end to end (the old hand list bunched
	# left and starved the right half — uniform means uniform)
	var stx := WORLD_L - 350.0
	var sti := 0
	while stx < WORLD_R + 350.0:
		var st_id: int = [12, 14, 13, 15, 16][sti % 5]
		var st_sc := _rng.randf_range(0.62, 0.9)
		var tex: Texture2D = load(BASE + "stalagmite%d.png" % st_id)
		_sprite("stalagmite%d.png" % st_id,
				Vector2(stx, ROOF_Y + 8.0 + tex.get_height() * st_sc * 0.5),
				st_sc, 3, Color(0.66, 0.76, 0.72), _rng.randf() < 0.5, true)
		stx += _rng.randf_range(330.0, 430.0)
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
	_prop("stalagmite7.png", 2250.0, FLOOR_Y + 16.0, 0.5, 3, Color(0.50, 0.62, 0.57))
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
				Color.WHITE, _rng.randf() < 0.5)
		_glow_light(m, GLOW_COOL if wgi % 2 == 0 else GLOW_MOSS, 0.38, 1.1)
		wgi += 1
	_prop("mushroomglow16.png", 3050.0, FLOOR_Y + 8.0, 0.3, 4)
	_prop("mushroomglow19.png", 3550.0, FLOOR_Y + 10.0, 0.32, 4)
	_prop("fungalfrond23.png", 4020.0, FLOOR_Y + 8.0, 0.3, 3)
	_prop("fungalstone5.png", 3900.0, FLOOR_Y + 26.0, 0.45, 3, Color(0.70, 0.78, 0.74))

	# ZONE D — the long dark garden (the new stretch): pot fields, stalk
	# pairs, a moss-lit grove climbing to the second stack, wall-base seal
	_prop("fungalstone18.png", 4350.0, FLOOR_Y + 14.0, 0.55, 3)
	_prop("fungalfrond27.png", 4460.0, FLOOR_Y + 8.0, 0.24, 4, Color.WHITE, true)
	var stalk_d1 := _prop("mushroomcap5.png", 4560.0, FLOOR_Y + 6.0, 0.32, 4)
	_glow_light(stalk_d1, GLOW_WARM, 0.3, 1.5)
	var moss_d1 := _prop("mushroomglow12.png", 5000.0, FLOOR_Y + 8.0, 0.34, 3)
	_glow_light(moss_d1, GLOW_MOSS, 0.32, 1.3)
	_prop("mushroomglow21.png", 5090.0, FLOOR_Y + 10.0, 0.22, 4)
	_prop("fungalstone19.png", 5450.0, FLOOR_Y + 14.0, 0.5, 3, Color.WHITE, true)
	var cool_d1 := _prop("mushroomglow23.png", 5560.0, FLOOR_Y + 8.0, 0.4, 3)
	_glow_light(cool_d1, GLOW_COOL, 0.36, 1.2)
	# the terminal grove — the level ends in a garden of mixed glows
	var moss_d2 := _prop("mushroomglow17.png", 6050.0, FLOOR_Y + 8.0, 0.5, 3,
			Color.WHITE, true)
	_glow_light(moss_d2, GLOW_MOSS, 0.34, 1.4)
	var amber_d := _prop("mushroomglow5.png", 6220.0, FLOOR_Y + 6.0, 0.34, 4)
	_glow_light(amber_d, GLOW_WARM, 0.3, 1.3)
	_prop("mushroomglow24.png", 6320.0, FLOOR_Y + 10.0, 0.3, 3)
	_prop("fungalfrond29.png", 6150.0, FLOOR_Y + 10.0, 0.26, 4)
	_prop("fungalstone22.png", 6420.0, FLOOR_Y + 12.0, 0.5, 3)
	_prop("fungalfrond23.png", 6500.0, FLOOR_Y + 8.0, 0.28, 4, Color.WHITE, true)

	# THE LONG WALK (Advika: a 5-minute level) — past x 6800 rotating floor
	# motifs stamp the same grouped-assembly grammar down the whole cavern:
	# pot fields, glower pairs, stalagmite groves, moss gardens
	var dmx := 6800.0
	var dmi := 0
	while dmx < WORLD_R - 500.0:
		match dmi % 4:
			0:  # pot field + gold stalk
				_prop("fungalstone18.png", dmx, FLOOR_Y + 14.0, 0.5, 3,
						Color.WHITE, dmi % 8 < 4)
				_prop("fungalfrond27.png", dmx + 110.0, FLOOR_Y + 8.0, 0.22, 4)
				var stalk := _prop("mushroomcap%d.png" % ([5, 1][dmi % 2]),
						dmx + 210.0, FLOOR_Y + 6.0, 0.3, 4)
				_glow_light(stalk, GLOW_WARM, 0.3, 1.4)
			1:  # white/cyan glower pair
				var wgm := _prop("mushroomglow%d.png" % ([17, 23, 24][dmi % 3]),
						dmx, FLOOR_Y + 8.0, 0.42, 3, Color.WHITE, dmi % 2 == 0)
				_glow_light(wgm, GLOW_COOL, 0.34, 1.2)
				_prop("mushroomglow%d.png" % ([16, 19][dmi % 2]),
						dmx + 95.0, FLOOR_Y + 10.0, 0.24, 4)
			2:  # stalagmite pair + boulder
				_prop("stalagmite%d.png" % ([7, 9, 2][dmi % 3]), dmx,
						FLOOR_Y + 16.0, 0.5, 3, Color(0.50, 0.62, 0.57))
				_prop("fungalstone%d.png" % ([1, 5, 2][dmi % 3]), dmx + 120.0,
						FLOOR_Y + 12.0, 0.45, 4, Color.WHITE, dmi % 2 == 1)
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
			[950.0, FLOOR_Y - 124.0, 2],      # zone B dome crown
			[1495.0, FLOOR_Y - 239.0, 2],     # P2 cap top
			[1890.0, FLOOR_Y + 12.0, 0],      # the mound's feet
			[2290.0, FLOOR_Y + 14.0, 2],      # fore stalagmite base
			[2940.0, FLOOR_Y - 114.0, 1],     # zone C pedestal top
			[2740.0, FLOOR_Y + 12.0, 1],      # stack feet
			[3340.0, FLOOR_Y - 229.0, 1],     # P4 top
			[3590.0, FLOOR_Y + 12.0, 2],      # zone C floor run
			[3960.0, FLOOR_Y + 14.0, 2],      # zone C/D border
			[4740.0, FLOOR_Y - 119.0, 2],     # D mound top
			[4480.0, FLOOR_Y + 12.0, 0],      # D pot field
			[5240.0, FLOOR_Y - 234.0, 1],     # D cap top
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
				1 if _rng.randf() < 0.5 else 4, Color.WHITE, _rng.randf() < 0.5)
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
				base_y + _rng.randf_range(0.0, 8.0), sc, z, Color.WHITE,
				_rng.randf() < 0.5)
		var hue: Color = [GLOW_WARM, GLOW_COOL, GLOW_MOSS][style]
		if i == 0:
			_glow_light(m, hue, 0.25, 1.2)
		elif _rng.randf() < 0.4:
			_bloom(m, hue, 0.15)


func _build_foreground() -> void:
	# darkest silhouettes hugging the bottom frame (R2's foreground foliage
	# principle). Bases sit BELOW the lowest view edge (~y 830) so they read
	# as growth cut by the frame, never as floating shapes.
	var fore := Color(0.03, 0.065, 0.058)   # near-black teal, darkest layer
	var fsx := WORLD_L + 250.0
	var fsi := 0
	while fsx < WORLD_R:
		var fs_name: String = ["fungalfrond10.png", "fungalfrond3.png",
				"stalagmite5.png", "fungalfrond16.png", "fungalfrond4.png",
				"stalagmite3.png"][fsi % 6]
		var tex: Texture2D = load(BASE + fs_name)
		var sc := _rng.randf_range(0.55, 0.68)
		_sprite(fs_name, Vector2(fsx, 840.0 - tex.get_height() * sc * 0.5),
				sc, 8, fore, _rng.randf() < 0.5)
		fsx += _rng.randf_range(680.0, 950.0)
		fsi += 1
	# CONTINUOUS bottom anchor: a dark fringe silhouette band along the
	# whole frame bottom, in front of the gameplay layer — no dead dark
	# band, the frame is held (R2 does this with its foreground canopy)
	var x := WORLD_L - 200.0
	while x < WORLD_R + 200.0:
		var idx: int = FRINGE_TEX[_rng.randi() % FRINGE_TEX.size()]
		var tex: Texture2D = load(BASE + "fungalfrond%d.png" % idx)
		var sc := _rng.randf_range(0.42, 0.62)
		_sprite("fungalfrond%d.png" % idx,
				Vector2(x, 820.0 - tex.get_height() * sc * 0.5),
				sc, 9, fore, _rng.randf() < 0.5)
		x += tex.get_width() * sc * 0.6


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
	_curi.scale = Vector2(0.24, 0.24)
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
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


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
	# the haze bands drift and wrap within one sprite spacing — endless
	for i in _fog_bands.size():
		var band: Node2D = _fog_bands[i][0]
		var speed: float = _fog_bands[i][1]
		var spacing: float = _fog_bands[i][2]
		band.position.x = fmod(_t * speed, spacing)
	if _cam != null:
		_hills_far.position.x = _cam.global_position.x * 0.82
		_hills_mid.position.x = _cam.global_position.x * 0.6
		var target := Vector2(clampf(_curi.global_position.x, WORLD_L + 600.0, WORLD_R - 350.0),
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
	if OS.get_environment("R3_SHOT_X") != "":
		_curi.position = Vector2(float(OS.get_environment("R3_SHOT_X")), FLOOR_Y - 160.0)
		_curi.velocity = Vector2.ZERO
		_cam.position = Vector2(_curi.position.x, FLOOR_Y - 190.0)
	await get_tree().create_timer(1.0).timeout
	print("SHOT curi=", _curi.global_position)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
