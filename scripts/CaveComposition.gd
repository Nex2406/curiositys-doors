extends Node2D
## LOOP 1 — one static screen matched to docs/reference/cave_ref_01.png.
## No gameplay, no level. Just the composition: fog core, vignette, ceiling
## band, two big columns, a floating slab, background masses, one rim light.
## Advika judges this frame; nothing else gets built until it passes.
## COMP_SHOT=<path> screenshots at 1s and quits.
## Verification (her spec): the fog-center pixel must sample within ±20 of
## RGB(134, 131, 60). The value prints on every screenshot run.

const CAVE := "res://assets/environment/cave/"
const SHEET_PLATFORMS := CAVE + "Cave - Platforms.png"
const SHEET_FLOOR := CAVE + "Cave - Floor.png"
const SHEET_COMBOS := CAVE + "Cave - RockCombinations1.png"
const SHEET_SMALLROCKS := CAVE + "Cave - SmallRocks.png"

# region atlas (Advika's build spec)
const R_COL_LARGE := Rect2(28, 225, 562, 363)
const R_COL_LARGE_VAR := Rect2(616, 398, 389, 364)
const R_COL_NARROW := Rect2(48, 644, 191, 364)
const R_COL_SMALL := Rect2(22, 25, 191, 189)
const R_LEDGE := Rect2(268, 902, 389, 104)
const R_LEDGE_SMALL := Rect2(722, 889, 191, 104)
const R_ROCK_MOUND := Rect2(293, 721, 267, 158)
const R_SLAB_MOVE := Rect2(274, 645, 303, 62)
const R_GROUND_XW := Rect2(55, 800, 1467, 161)
const R_CEIL_A := Rect2(822, 1655, 791, 307)
const R_CEIL_B := Rect2(15, 1754, 791, 239)
const R_STALACT_A := Rect2(1668, 860, 141, 374)
const R_STALACT_B := Rect2(1867, 859, 124, 378)
const R_MASS_TALL := Rect2(44, 1234, 574, 597)
const R_MASS_MED := Rect2(989, 77, 470, 357)
const R_MASS_WIDE := Rect2(1310, 748, 693, 372)

# the art's own painted values do the black-core/pale-rim split — the
# modulate just seats it under the wash (ref columns: rims ~90, cores ~15)
const MOD_GEO := Color(0.58, 0.58, 0.50)
# the ref's background masses are a clearly LIGHTER olive plane — they sit
# IN the fog, lit by it, so they run brighter than the near geometry
const MOD_MID := Color(1.45, 1.50, 1.15)
const MOD_FORE := Color(0.03, 0.03, 0.03)
const WASH := Color(0.62, 0.66, 0.42)
const RIM_LIGHT := Color(0.722, 0.769, 0.416)
# the REAL hanging teeth / floor spikes are in SmallRocks — the Floor-sheet
# "stalactite" regions are actually pebble-column pieces. Using the sliced
# pack pieces (same art, pre-cropped) for teeth.
const SLICES := "res://assets/realms/realm1_cavern/"
const TEETH: Array[String] = ["rock_13.png", "rock_14.png", "rock_20.png",
		"rock_21.png", "rock_22.png"]
const SPIKES: Array[String] = ["rock_29.png", "rock_31.png", "rock_33.png",
		"rock_37.png"]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.020, 0.024, 0.016))
	_build_fog()
	_build_mid_masses()
	_build_columns()
	_build_ceiling()
	_build_ground()
	_build_moss()
	_build_foreground()
	_build_lighting()
	var cam := Camera2D.new()
	cam.position = Vector2.ZERO
	add_child(cam)
	cam.make_current()
	if OS.get_environment("COMP_SHOT") != "":
		_self_screenshot(OS.get_environment("COMP_SHOT"))


func _decal(sheet: String, region: Rect2, pos: Vector2, sc := 1.0,
		fh := false, tint := Color.WHITE, z := 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(sheet)
	s.region_enabled = true
	s.region_rect = region
	s.position = pos
	s.scale = Vector2(-sc if fh else sc, sc)
	s.modulate = tint
	s.z_index = z
	add_child(s)
	return s


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


func _build_fog() -> void:
	# fog on its OWN CanvasLayer (-100), outside the CanvasModulate's canvas
	var cl := CanvasLayer.new()
	cl.layer = -100
	add_child(cl)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cave_fog.gdshader")
	fog.material = mat
	cl.add_child(fog)


func _build_mid_masses() -> void:
	# the ref: soft dimmer rock planes peeking BEHIND and BETWEEN the columns
	var mid := Node2D.new()
	mid.modulate = MOD_MID
	mid.z_index = -2
	add_child(mid)
	for m: Array in [
			[R_MASS_TALL, -180.0, -40.0, 0.85, false],   # behind left column's crown
			[R_MASS_MED, 210.0, 330.0, 0.7, true],       # soft toothed mass, low + right
			[R_MASS_WIDE, 700.0, 260.0, 0.95, false],    # behind right column
			[R_MASS_TALL, -820.0, 120.0, 0.8, true]]:    # behind the left wall
		var r: Rect2 = m[0]
		var s := Sprite2D.new()
		s.texture = load(SHEET_COMBOS)
		s.region_enabled = true
		s.region_rect = r
		s.position = Vector2(m[1], m[2])
		var sc: float = m[3]
		s.scale = Vector2(-sc if m[4] else sc, sc)
		mid.add_child(s)


func _build_columns() -> void:
	# LEFT COLUMN (the hero): ~230 wide, cap slab, crown mound behind its top
	_column(-280.0, -230.0, 470.0, 0)
	# RIGHT COLUMN: lower, cap slab
	_column(620.0, -30.0, 470.0, 1)
	# LEFT WALL sliver at the frame edge
	_column(-950.0, -120.0, 470.0, 0)
	# crown mound peeking behind the left column's cap (ref: rocks above cap)
	_decal(SHEET_PLATFORMS, R_ROCK_MOUND, Vector2(-250.0, -300.0), 0.9,
			false, MOD_GEO, -1)
	# the floating slab fragment between the columns
	_decal(SHEET_PLATFORMS, R_SLAB_MOVE, Vector2(350.0, 120.0), 0.55,
			false, Color(0.34, 0.34, 0.29))


## stacked column: shaft pieces bottom-up (±20px x jitter), cap slab on top
func _column(cx: float, cap_top_y: float, base_y: float, style: int) -> void:
	var shaft: Array[Rect2] = []
	if style == 0:
		shaft.assign([R_COL_NARROW, R_COL_LARGE_VAR])
	else:
		shaft.assign([R_COL_LARGE_VAR, R_COL_NARROW])
	var y := base_y + 120.0
	var i := 0
	while y > cap_top_y + 90.0:
		var r: Rect2 = shaft[i % 2]
		var sc := 230.0 / r.size.x * (1.0 if r == R_COL_NARROW else 0.62)
		sc *= 1.3
		var h := r.size.y * sc
		_decal(SHEET_PLATFORMS, r,
				Vector2(cx + (12.0 if i % 2 == 1 else -10.0), y - h * 0.5),
				sc, i % 2 == 1, MOD_GEO)
		y -= h * 0.78
		i += 1
	var cap_sc := 0.72
	_decal(SHEET_PLATFORMS, R_LEDGE,
			Vector2(cx, cap_top_y + R_LEDGE.size.y * cap_sc * 0.5 - 8.0),
			cap_sc, style == 1, Color(0.26, 0.26, 0.23))


func _build_ceiling() -> void:
	# the band lives mostly ABOVE the frame — a dark upper mass whose lip
	# just enters the top edge; the visible read is the TEETH hanging off it
	var x := -1150.0
	var i := 0
	while x < 1300.0:
		var r: Rect2 = R_CEIL_A if i % 2 == 0 else R_CEIL_B
		var sc := 1.0
		_decal(SHEET_FLOOR, r, Vector2(x, -540.0 - r.size.y * sc * 0.5 + 90.0),
				sc, i % 3 == 1, MOD_GEO, 1)
		x += r.size.x * sc - 100.0
		i += 1
	# pale mid-value teeth hanging from the band (the ref's tan teeth row)
	for st: Array in [[-620.0, 0.85, 0], [-260.0, 0.6, 2], [-80.0, 0.75, 4],
			[300.0, 0.55, 1], [520.0, 0.95, 3], [880.0, 0.65, 0]]:
		var tex: Texture2D = load(SLICES + TEETH[st[2]])
		var sc2: float = st[1]
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc2, sc2)
		s.position = Vector2(st[0], -540.0 + tex.get_height() * sc2 * 0.5 - 14.0)
		s.modulate = MOD_GEO
		s.z_index = 1
		add_child(s)


func _build_ground() -> void:
	# ground = the wide slab at full scale, dark; a PEBBLE-ROW lip riding it
	# (the ref's ground line), tiny scatter on top
	_decal(SHEET_FLOOR, R_GROUND_XW, Vector2(-350.0, 505.0), 1.1, false,
			Color(0.34, 0.34, 0.29))
	_decal(SHEET_FLOOR, R_GROUND_XW, Vector2(760.0, 515.0), 1.0, true,
			Color(0.30, 0.30, 0.25))
	var px := -1000.0
	var i := 0
	while px < 1050.0:
		var tex: Texture2D = load(SLICES + ["floor_22.png", "floor_23.png"][i % 2])
		var sc := 0.5
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = i % 3 == 1
		s.position = Vector2(px, 462.0 - tex.get_height() * sc * 0.5 + 20.0)
		s.modulate = Color(0.50, 0.50, 0.43)
		add_child(s)
		px += tex.get_width() * sc * 0.8
		i += 1
	for dx: Array in [[-700.0, 0.22], [-320.0, 0.18], [40.0, 0.25], [430.0, 0.2]]:
		var dr := Rect2(64.0 + 256.0 * float((int(absf(dx[0])) / 3) % 6),
				64.0 + 256.0 * float((int(absf(dx[0])) / 7) % 4), 200.0, 190.0)
		_decal(SHEET_SMALLROCKS, dr, Vector2(dx[0], 448.0), dx[1], false,
				Color(0.18, 0.18, 0.15))


# ---------- moss boundaries (Advika 2026-07-19: the level-2 pack's moss,
# in its green, wrapped around the rock EDGES — the flat faces stay bare
# rock, the silhouette lines grow) ----------

const MBASE := "res://assets/realms/realm1_moss/"

func _moss(tex_name: String, pos: Vector2, sc: float, b: float,
		fh := false, fv := false, z := 2, rot := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(MBASE + tex_name)
	s.position = pos
	s.scale = Vector2(-sc if fh else sc, sc)
	s.flip_v = fv
	s.modulate = Color(b, b, b)
	s.z_index = z
	s.rotation_degrees = rot
	add_child(s)
	return s


func _build_moss() -> void:
	# LEFT COLUMN (cx -280, cap top -230, lit from the left/above):
	# a moss lip riding the cap, hangers dripping off it, tufts hugging the
	# shaft edges — lit side brighter, shadow side dim
	_moss("moss_mat.png", Vector2(-280.0, -234.0), 0.078, 0.72)
	_moss("hang_fern_1.png", Vector2(-392.0, -212.0), 0.30, 0.62)
	_moss("hang_beard_0.png", Vector2(-168.0, -206.0), 0.26, 0.44)
	for t: Array in [[-398.0, -60.0, 0.14, 0.60, true], [-390.0, 160.0, 0.11, 0.52, true],
			[-396.0, 330.0, 0.13, 0.45, true], [-162.0, 40.0, 0.12, 0.38, false],
			[-170.0, 260.0, 0.10, 0.34, false]]:
		_moss("tuft_%d.png" % (int(absf(t[0] + t[1])) % 3), Vector2(t[0], t[1]),
				t[2], t[3], t[4], false, 2, (-8.0 if t[4] else 8.0))
	_moss("tuft_1.png", Vector2(-330.0, 442.0), 0.20, 0.50)     # base clump
	_moss("tuft_2.png", Vector2(-220.0, 450.0), 0.15, 0.42, true)

	# RIGHT COLUMN (cx 620, cap top -30): same treatment, dimmer overall
	_moss("moss_mat.png", Vector2(620.0, -34.0), 0.075, 0.60, true)
	_moss("hang_fern_3.png", Vector2(510.0, -8.0), 0.28, 0.52)
	_moss("hang_curl_1.png", Vector2(742.0, -14.0), 0.24, 0.40, true)
	for t2: Array in [[498.0, 150.0, 0.12, 0.48, true], [504.0, 330.0, 0.11, 0.40, true],
			[744.0, 220.0, 0.11, 0.32, false], [738.0, 390.0, 0.10, 0.28, false]]:
		_moss("tuft_%d.png" % (int(t2[0] + t2[1]) % 3), Vector2(t2[0], t2[1]),
				t2[2], t2[3], t2[4], false, 2, (-8.0 if t2[4] else 8.0))
	_moss("tuft_0.png", Vector2(560.0, 446.0), 0.18, 0.46)

	# the floating slab wears a sprig; the maw mound gets a lit crest
	_moss("tuft_2.png", Vector2(322.0, 96.0), 0.10, 0.55)
	_moss("moss_mat.png", Vector2(210.0, 240.0), 0.060, 0.50, true)
	_moss("tuft_1.png", Vector2(140.0, 242.0), 0.13, 0.44, true)

	# ground line: sprigs woven between the pebbles, brightest at the light
	for g: Array in [[-760.0, 0.14, 0.40], [-450.0, 0.11, 0.46], [-60.0, 0.15, 0.55],
			[300.0, 0.12, 0.50], [760.0, 0.13, 0.38], [1000.0, 0.11, 0.33]]:
		_moss("tuft_%d.png" % (int(absf(g[0])) % 3), Vector2(g[0], 444.0),
				g[1], g[2], int(g[0]) % 2 == 0, false, 3)
	# and a beard dripping from the ceiling band into the lit gap
	_moss("hang_beard_1.png", Vector2(140.0, -470.0), 0.26, 0.42)


func _build_foreground() -> void:
	# near-black teeth silhouettes: a row along the frame bottom, black
	# fingers overhanging the ceiling band (the ref's front curtain)
	var fore := Node2D.new()
	fore.modulate = MOD_FORE
	fore.z_index = 10
	add_child(fore)
	# short black spikes along the frame bottom (real stalagmite pieces —
	# nothing rotated)
	for bx: Array in [[-820.0, 0.32], [-560.0, 0.2], [-120.0, 0.28], [230.0, 0.18],
			[660.0, 0.3], [900.0, 0.24]]:
		var tex: Texture2D = load(SLICES + SPIKES[int(absf(bx[0])) % 4])
		var sc: float = bx[1]
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.position = Vector2(bx[0], 560.0 - tex.get_height() * sc * 0.35)
		fore.add_child(s)
	# the black teeth curtain overhanging the top of frame (the ref's front
	# fingers) — big, sharp, silhouette
	for tx: Array in [[-900.0, 1.0, 0], [-540.0, 0.75, 3], [-260.0, 1.15, 1],
			[60.0, 0.85, 4], [380.0, 1.1, 2], [700.0, 0.8, 0], [950.0, 1.05, 3]]:
		var tex2: Texture2D = load(SLICES + TEETH[tx[2]])
		var sc2: float = tx[1]
		var s2 := Sprite2D.new()
		s2.texture = tex2
		s2.scale = Vector2(sc2, sc2)
		s2.position = Vector2(tx[0], -540.0 + tex2.get_height() * sc2 * 0.42)
		fore.add_child(s2)


func _build_lighting() -> void:
	var wash := CanvasModulate.new()
	wash.color = WASH
	add_child(wash)
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var vr := ColorRect.new()
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	vr.material = mat
	cl.add_child(vr)
	# rim lights: the lit gap behind/above the left column, a lesser answer
	# on the right cap, a faint glint at the floor line
	for lp: Array in [[-420.0, -330.0, 1.0, 3.2], [740.0, -140.0, 0.5, 2.4],
			[-100.0, 420.0, 0.3, 2.0]]:
		var l := PointLight2D.new()
		l.texture = _soft_glow()
		l.color = RIM_LIGHT
		l.energy = lp[2]
		l.texture_scale = lp[3]
		l.position = Vector2(lp[0], lp[1])
		add_child(l)


func _self_screenshot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	# her verification: sample the fog center (UV 0.5, 0.35) and report
	var px := img.get_pixel(int(img.get_width() * 0.5), int(img.get_height() * 0.35))
	print("FOG SAMPLE @(0.5,0.35) = RGB(%d, %d, %d)  target (134, 131, 60) ±20" %
			[int(px.r * 255.0), int(px.g * 255.0), int(px.b * 255.0)])
	get_tree().quit()
