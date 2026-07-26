extends Node2D
## HAND-COPY of docs/reference/cave_ref_04.png (Advika's call 2026-07-22:
## no procedural generation — every element placed by eye to match the
## promo frame). Coordinates are ref-image UVs mapped to world via _P().
## REF_SHOT=<path> screenshots at 1s, prints render-vs-ref anchor samples,
## and quits. Iterate until the deltas are whispers, THEN show Advika.

const CAVE := "res://assets/environment/cave/"
const SHEET_PLATFORMS := CAVE + "Cave - Platforms.png"
const SHEET_FLOOR := CAVE + "Cave - Floor.png"
const SLICES := "res://assets/realms/realm1_cavern/"
const SOFT := "res://assets/realms/realm1_soft/"
const PLANTS := "res://assets/realms/realm1_plants/"
const REF_IMG := "res://docs/reference/cave_ref_04.png"

# her build-spec region atlas (canon, from CaveComposition)
const R_LEDGE := Rect2(268, 902, 389, 104)
const R_LEDGE_SMALL := Rect2(722, 889, 191, 104)
const R_CEIL_A := Rect2(822, 1655, 791, 307)
const R_CEIL_B := Rect2(15, 1754, 791, 239)
const R_GROUND_XW := Rect2(55, 800, 1467, 161)

# near-black framing: art multiplied way down — stone shading survives as
# a whisper, outlines drown (that is how the promo hides them)
const DARK := Color(0.13, 0.11, 0.10)
const DARK_DEEP := Color(0.08, 0.07, 0.065)

var _rt_cache := {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.008, 0.008, 0.006))
	_fog()
	_billows()
	_distant_spikes()
	_right_background()
	_ground_mounds()
	_platforms()
	_left_wall()
	_right_wall()
	_ceiling()
	_ground()
	_plants()
	_mist()
	var cam := Camera2D.new()
	cam.position = Vector2.ZERO
	add_child(cam)
	cam.make_current()
	if OS.get_environment("REF_SHOT") != "":
		_shot(OS.get_environment("REF_SHOT"))


## ref-image UV -> world position
func _P(u: float, v: float) -> Vector2:
	return Vector2((u - 0.5) * 1920.0, (v - 0.5) * 1080.0)


func _rt_tex(dir: String, tex_name: String) -> Texture2D:
	var key := dir + tex_name
	if not _rt_cache.has(key):
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir + tex_name))
		_rt_cache[key] = ImageTexture.create_from_image(img)
	return _rt_cache[key]


## dark framing piece: plain multiply modulate (raw slice)
func _dark(tex_name: String, pos: Vector2, sc: float, tint: Color, z: int,
		fh := false, rot := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(SLICES + tex_name)
	s.position = pos
	s.scale = Vector2(-sc if fh else sc, sc)
	s.modulate = tint
	s.z_index = z
	s.rotation_degrees = rot
	add_child(s)
	return s


## dark framing piece from a sheet region
func _dark_region(sheet: String, region: Rect2, pos: Vector2, sc: float,
		tint: Color, z: int, fh := false) -> Sprite2D:
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


## fog-lit background piece (calibrated shader)
func _lit(dir: String, tex_name: String, pos: Vector2, sc: float, lift: float,
		detail: float, z: int, fh := false,
		brighten := Vector3(1.05, 0.95, 0.85)) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _rt_tex(dir, tex_name) if dir != SLICES else load(SLICES + tex_name)
	s.position = pos
	s.scale = Vector2(-sc if fh else sc, sc)
	s.z_index = z
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog_mass_screen.gdshader")
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("detail", detail)
	mat.set_shader_parameter("brighten", brighten)
	s.material = mat
	add_child(s)
	return s


func _fog() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -100
	add_child(cl)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cave_fog_spill.gdshader")
	fog.material = mat
	cl.add_child(fog)


func _billows() -> void:
	# the smoke bank behind the left ledge, drifting right and sinking —
	# soft lobes a whisper above the fog
	for b: Array in [
			["bigrock_07_soft.png", 0.13, 0.30, 0.55, false],
			["bigrock_00_soft.png", 0.20, 0.42, 0.60, false],
			["bigrock_06_soft.png", 0.30, 0.34, 0.50, true],
			["bigrock_08_soft.png", 0.38, 0.50, 0.65, false],
			["bigrock_02_soft.png", 0.47, 0.58, 0.70, false],
			["bigrock_01_soft.png", 0.55, 0.66, 0.60, true]]:
		_lit(SOFT, b[0], _P(b[1], b[2]), b[3], 1.04, 0.0, -8, b[4])


func _distant_spikes() -> void:
	# the faded warm spike rows standing in the mist, center-right —
	# pieces and scales hand-varied so nothing reads as a repeated stamp
	for r: Array in [
			["combo_12.png", 0.38, 0.63, 0.20, false],
			["combo_14.png", 0.44, 0.68, 0.16, true],
			["combo_13.png", 0.50, 0.645, 0.24, false],
			["combo_15.png", 0.545, 0.70, 0.14, false],
			["combo_12.png", 0.60, 0.66, 0.27, true],
			["combo_13.png", 0.655, 0.71, 0.17, false],
			["combo_14.png", 0.70, 0.68, 0.21, false]]:
		_lit(SLICES, r[0], _P(r[1], r[2]), r[3], 0.90, 0.50, -7, r[4])


func _right_background() -> void:
	# tall warm spires behind the right wall's cap
	_lit(SLICES, "combo_12.png", _P(0.90, 0.50), 0.55, 0.80, 0.50, -6)
	_lit(SLICES, "bigrock_05.png", _P(0.945, 0.46), 0.60, 0.80, 0.50, -6, true)
	_lit(SLICES, "combo_15.png", _P(0.78, 0.62), 0.35, 0.85, 0.50, -6)


func _ground_mounds() -> void:
	# washed rock mounds sitting IN the ground mist
	for m: Array in [
			["combo_07.png", 0.46, 0.83, 0.42, false, 0.95],
			["combo_10.png", 0.55, 0.86, 0.45, true, 0.90],
			["combo_11.png", 0.65, 0.84, 0.40, false, 0.92],
			["combo_07.png", 0.74, 0.87, 0.38, true, 0.85]]:
		_lit(SLICES, m[0], _P(m[1], m[2]), m[3], m[5], 0.45, -3, m[4])
	# darker rock piles in front of them
	for d: Array in [
			["combo_10.png", 0.44, 0.90, 0.40, false],
			["combo_08.png", 0.52, 0.92, 0.38, true],
			["combo_11.png", 0.60, 0.91, 0.42, false]]:
		_dark(d[0], _P(d[1], d[2]), d[3], Color(0.22, 0.19, 0.17), -2, d[4])


func _platforms() -> void:
	# the ref's floating blocks are the pack's chunky plat pieces — near
	# silhouette, faint top light, a small fog-lit rock behind the top edge
	_lit(SLICES, "combo_04.png", _P(0.408, 0.545), 0.22, 0.92, 0.5, 0)
	_dark("plat_02.png", _P(0.415, 0.585), 0.52, Color(0.17, 0.15, 0.135), 1)
	_lit(SLICES, "combo_05.png", _P(0.635, 0.655), 0.26, 0.90, 0.5, 0)
	_dark("plat_02.png", _P(0.655, 0.715), 0.55, Color(0.155, 0.135, 0.125), 1, true)


func _left_wall() -> void:
	# solid black backing first — the wall can never leak fog through gaps
	var back := ColorRect.new()
	back.position = Vector2(-960, -540)
	back.size = Vector2(95, 1080)
	back.color = Color(0.02, 0.019, 0.017)
	back.z_index = 19
	add_child(back)
	var y := 620.0
	var i := 0
	while y > -700.0:
		var tex_name := "floor_0%d.png" % (7 if i % 2 == 0 else 8)
		var tex: Texture2D = load(SLICES + tex_name)
		var sc := 1.05
		var h := tex.get_height() * sc
		_dark(tex_name, Vector2(-905.0 + (12.0 if i % 2 else -8.0), y - h * 0.5),
				sc, Color(0.10, 0.088, 0.08), 20, i % 2 == 1)
		y -= h * 0.8
		i += 1
	# the jutting ledge — ONE assembly rooted into the wall: slab overlapping
	# the column, pebble mass under its root, teeth beneath the lip
	_dark_region(SHEET_PLATFORMS, R_LEDGE, Vector2(-720.0, -95.0), 0.75,
			Color(0.19, 0.165, 0.15), 21)
	_dark("floor_07.png", Vector2(-810.0, 30.0), 0.85, Color(0.09, 0.08, 0.072), 21)
	_dark("rock_13.png", Vector2(-690.0, 25.0), 0.30, DARK_DEEP, 22)
	_dark("rock_14.png", Vector2(-590.0, -5.0), 0.22, DARK_DEEP, 22)
	_dark_region(SHEET_PLATFORMS, R_LEDGE_SMALL, Vector2(-838.0, 90.0), 0.8,
			DARK_DEEP, 21)


func _right_wall() -> void:
	var back := ColorRect.new()
	back.position = Vector2(880, -170)
	back.size = Vector2(80, 710)
	back.color = Color(0.02, 0.019, 0.017)
	back.z_index = 19
	add_child(back)
	var y := 620.0
	var i := 0
	while y > -180.0:
		var tex_name := "floor_0%d.png" % (8 if i % 2 == 0 else 7)
		var tex: Texture2D = load(SLICES + tex_name)
		var sc := 1.15
		var h := tex.get_height() * sc
		_dark(tex_name, Vector2(910.0 + (-10.0 if i % 2 else 10.0), y - h * 0.5),
				sc, Color(0.10, 0.088, 0.08), 20, i % 2 == 0)
		y -= h * 0.8
		i += 1
	_dark_region(SHEET_PLATFORMS, R_LEDGE, _P(0.905, 0.60), 0.7, Color(0.17, 0.148, 0.135), 21, true)


func _ceiling() -> void:
	# ONE solid black mass with an undulating lip traced from the ref —
	# deep in both corners, lifting over the glow, plunging right of center
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-960, -560), Vector2(960, -560),
		Vector2(960, -197), Vector2(820, -225), Vector2(700, -320),
		Vector2(620, -400), Vector2(560, -455), Vector2(430, -478),
		Vector2(300, -462), Vector2(150, -476), Vector2(0, -468),
		Vector2(-150, -452), Vector2(-300, -470), Vector2(-450, -458),
		Vector2(-560, -428), Vector2(-680, -378), Vector2(-780, -328),
		Vector2(-860, -248), Vector2(-960, -216)])
	poly.color = Color(0.022, 0.021, 0.018)
	poly.z_index = 30
	add_child(poly)
	# dark teeth rooted in the mass (tops tucked well inside the lip)
	for t: Array in [
			[0.575, 0.155, 0.55, false], [0.605, 0.21, 0.75, false],
			[0.645, 0.15, 0.50, true], [0.31, 0.075, 0.30, false],
			[0.36, 0.09, 0.35, true], [0.13, 0.10, 0.30, false],
			[0.185, 0.085, 0.24, true], [0.80, 0.19, 0.55, false],
			[0.87, 0.24, 0.70, true], [0.945, 0.20, 0.50, false]]:
		var piece: String = ["rock_20.png", "rock_21.png", "rock_22.png"][int(t[0] * 30.0) % 3]
		_dark(piece, _P(t[0], t[1]), t[2], Color(0.03, 0.028, 0.024), 31, t[3])
	# pale BACKLIT teeth peeking from BEHIND the black lip
	for p: Array in [
			[0.44, 0.095, 0.40, false], [0.48, 0.12, 0.50, true],
			[0.52, 0.085, 0.35, false], [0.70, 0.115, 0.38, false],
			[0.75, 0.15, 0.45, true], [0.10, 0.14, 0.30, false]]:
		_lit(SLICES, ["rock_13.png", "rock_14.png"][int(p[0] * 100.0) % 2],
				_P(p[0], p[1]), p[2], 0.85, 0.55, 29, p[3])


func _ground() -> void:
	# black floor band with a pebble lip
	_dark_region(SHEET_FLOOR, R_GROUND_XW, Vector2(-450.0, 585.0), 1.1, DARK_DEEP, 40)
	_dark_region(SHEET_FLOOR, R_GROUND_XW, Vector2(700.0, 592.0), 1.0, DARK_DEEP, 40, true)
	var px := -960.0
	var i := 0
	while px < 980.0:
		var tex_name: String = ["floor_22.png", "floor_23.png"][i % 2]
		var tex: Texture2D = load(SLICES + tex_name)
		var sc := 0.45
		_dark(tex_name, Vector2(px, 512.0 - tex.get_height() * sc * 0.5 + 14.0),
				sc, Color(0.16, 0.14, 0.13), 41, i % 3 == 1)
		px += tex.get_width() * sc * 0.85
		i += 1
	# black floor spikes
	for s: Array in [[0.44, 0.86, 0.28], [0.76, 0.88, 0.34], [0.815, 0.90, 0.24]]:
		_dark(["rock_29.png", "rock_33.png", "rock_31.png"][int(s[0] * 100.0) % 3],
				_P(s[0], s[1]), s[2], DARK_DEEP, 42)


func _plants() -> void:
	# dark plant silhouettes (PlantsAnimated frame 0) — the ref's curls and
	# leaf sprays along the ground and on the left ledge
	for p: Array in [
			["GroupPlants_00000.png", 0.285, 0.735, 0.45, false, 0.20],
			["Grass2_00000.png", 0.52, 0.90, 0.40, false, 0.14],
			["PlantSmall_00000.png", 0.665, 0.635, 0.28, false, 0.22],
			["Grass2_00000.png", 0.31, 0.90, 0.35, true, 0.12]]:
		var s := Sprite2D.new()
		s.texture = _rt_tex(PLANTS, p[0])
		s.position = _P(p[1], p[2])
		var sc: float = p[3]
		s.scale = Vector2(-sc if p[4] else sc, sc)
		var b: float = p[5]
		s.modulate = Color(b, b * 1.05, b * 0.8)
		s.z_index = 43
		add_child(s)


func _mist() -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = 0.006
	var ntex := NoiseTexture2D.new()
	ntex.noise = n
	ntex.seamless = true
	ntex.width = 512
	ntex.height = 512
	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	for m: Array in [[0.010, 0.08, 0.1], [-0.016, 0.05, 0.55]]:
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/cave_mist.gdshader")
		mat.set_shader_parameter("noise_tex", ntex)
		mat.set_shader_parameter("speed", m[0])
		mat.set_shader_parameter("strength", m[1])
		mat.set_shader_parameter("y_shift", m[2])
		r.material = mat
		cl.add_child(r)


func _shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	var ref := Image.load_from_file(ProjectSettings.globalize_path(REF_IMG))
	for a: Array in [["core", 0.17, 0.22], ["mid", 0.5, 0.45],
			["low", 0.5, 0.78], ["billow", 0.2, 0.33], ["spikes", 0.62, 0.68],
			["dark_ur", 0.85, 0.12], ["wall_l", 0.045, 0.5], ["ground", 0.4, 0.95]]:
		var p := img.get_pixel(int(img.get_width() * a[1]),
				int(img.get_height() * a[2]))
		var q := ref.get_pixel(int(ref.get_width() * a[1]),
				int(ref.get_height() * a[2]))
		print("%-8s render(%3d,%3d,%3d) ref(%3d,%3d,%3d)" % [a[0],
				int(p.r * 255.0), int(p.g * 255.0), int(p.b * 255.0),
				int(q.r * 255.0), int(q.g * 255.0), int(q.b * 255.0)])
	get_tree().quit()
