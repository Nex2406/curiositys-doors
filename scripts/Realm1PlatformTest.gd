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
const PLANTS := "res://assets/realms/realm1_plants/"
const CAM_SPEED := 700.0

var _cache := {}
var _cam: Camera2D

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
var _rock_ramp: ShaderMaterial
var _floor_ramp: ShaderMaterial


func _ready() -> void:
	Realm1Bg.build(self)
	# each platform is ONE fused texture (tools/compose_platforms.gd) —
	# internal seams melted offline; plants ride on top as crisp accents
	_fused("wall_ledge", Vector2(-900, 0), Vector2(240, 800), 0.10, [
			["GroupPlants_00000.png", 95.0, 205.0, 0.28, false]])
	var wall_back := ColorRect.new()
	wall_back.position = Vector2(-980, -540)
	wall_back.size = Vector2(150, 1080)
	wall_back.color = Color(0.02, 0.019, 0.017)
	wall_back.z_index = 4
	add_child(wall_back)
	_fused("small_a", Vector2(-140, 40), Vector2(180, 150), 0.10, [])
	_fused("medium_a", Vector2(350, 180), Vector2(250, 170), 0.10, [
			["Grass2_00000.png", 96.0, -60.0, 0.22, false]])
	_fused("small_b", Vector2(540, -150), Vector2(170, 150), 0.10, [])
	_fused("medium_b", Vector2(40, 290), Vector2(240, 190), 0.10, [
			["Grass2_00000.png", -34.0, -66.0, 0.18, true]])
	_fused("large_b", Vector2(830, 300), Vector2(250, 220), 0.10, [
			["Grass2_00000.png", 84.0, -108.0, 0.2, true]])
	_ground()
	_cam = Camera2D.new()
	_cam.position = Vector2.ZERO
	add_child(_cam)
	_cam.make_current()
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
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
	if OS.get_environment("PLAT_SHOT") != "":
		_shot(OS.get_environment("PLAT_SHOT"))



func _process(delta: float) -> void:
	if _cam != null:
		_cam.position.x += Input.get_axis("ui_left", "ui_right") * CAM_SPEED * delta


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
		plants: Array) -> void:
	var a := _assembly(pos)
	if _plat_ramp == null:
		_plat_ramp = ShaderMaterial.new()
		_plat_ramp.shader = load("res://shaders/plat_form.gdshader")
	var s := Sprite2D.new()
	s.texture = _tex(SOFT, "plat_%s.png" % pname)
	s.centered = false
	s.position = -origin
	s.material = _plat_ramp
	a.add_child(s)
	_platform_treatment(a, pname)
	for p: Array in plants:
		_plant(a, p[0], Vector2(p[1], p[2]), p[3], p[4])
	if pname != "wall_ledge":
		var amp := randf_range(3.0, 5.5)
		var dur := randf_range(3.2, 4.8)
		var tw := create_tween().set_loops()
		tw.tween_property(a, "position:y", pos.y - amp, dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(a, "position:y", pos.y + amp, dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## STEP 5/5b: underside rocks (#040302) root the platforms (shadows and
## rim lines removed — both read as floating artifacts against the glow;
## platforms read rooted and heavy, not floating stickers
func _platform_treatment(a: Node2D, pname: String) -> void:
	var meta: Array = PLAT_META[pname]
	var rim_y: float = meta[0] + 7.0
	var rim_x0: float = meta[1] + 9.0
	var rim_x1: float = meta[2] - 9.0
	var bottom: float = meta[3]
	var width: float = meta[4]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pname)
	# STEP 5c: 3-4 OVERLAPPING under-rocks with a lit ramp — rubble, not
	# hard black triangles
	if _rock_ramp == null:
		_rock_ramp = ShaderMaterial.new()
		_rock_ramp.shader = load("res://shaders/plat_form.gdshader")
		_rock_ramp.set_shader_parameter("dark_c", Color(0.063, 0.047, 0.027))
		_rock_ramp.set_shader_parameter("cap_c", Color(0.227, 0.184, 0.122))
		_rock_ramp.set_shader_parameter("gamma_v", 1.4)
		_rock_ramp.set_shader_parameter("rim_strength", 0.0)
	var pool: Array[String] = ["rock_00.png", "rock_03.png", "rock_05.png",
			"rock_08.png", "rock_10.png"]
	var n := 3 + (int(hash(pname)) & 1)
	var cx := (rim_x0 + rim_x1) * 0.5
	var span := (rim_x1 - rim_x0) * 0.30
	for i in range(n):
		var piece: String = pool[rng.randi() % pool.size()]
		var tex := _tex(CUT, piece)
		var w := rng.randf_range(60.0, 95.0)
		var sc := w / float(tex.get_width())
		var r := Sprite2D.new()
		r.texture = tex
		r.scale = Vector2(sc, sc)
		r.flip_h = rng.randf() < 0.5
		r.position = Vector2(cx - span + 2.0 * span * float(i) / maxf(float(n - 1), 1.0)
				+ rng.randf_range(-10.0, 10.0),
				bottom - float(tex.get_height()) * sc * 0.18
				+ rng.randf_range(-8.0, 8.0))
		r.material = _rock_ramp
		r.z_index = -1
		a.add_child(r)


## a plant playing its pack animation — the wind lives in the frames
const PLANT_DIRS := {"PlantSmall_00000.png": ["plantsmall/PlantSmall_%05d.png", 30],
		"Grass2_00000.png": ["grass2/Grass2_%05d.png", 30],
		"GroupPlants_00000.png": ["groupplants/GroupPlants_%05d.png", 45]}
var _frames_cache := {}
func _plant(parent: Node2D, key: String, pos: Vector2, sc: float,
		fh: bool) -> void:
	var spec: Array = PLANT_DIRS[key]
	if not _frames_cache.has(key):
		var sf := SpriteFrames.new()
		sf.set_animation_loop("default", true)
		sf.set_animation_speed("default", 15.0)
		for i in range(spec[1]):
			var img := Image.load_from_file(ProjectSettings.globalize_path(
					PLANTS + spec[0] % i))
			sf.add_frame("default", ImageTexture.create_from_image(img))
		_frames_cache[key] = sf
	var an := AnimatedSprite2D.new()
	an.sprite_frames = _frames_cache[key]
	an.position = pos
	an.scale = Vector2(-sc if fh else sc, sc)
	an.modulate = Color(0.15, 0.16, 0.10)
	an.z_index = 1
	an.play("default")
	an.frame = randi() % int(spec[1])
	parent.add_child(an)


## the FLOOR (cave_ref_04's bottom grammar): a solid near-black ground
## band, knobbly rock lip, washed mounds sitting ON it, dark piles, sparse
## black spikes, and the plants growing FROM the line — spike forest rises
## behind it
func _ground() -> void:
	var g := _assembly(Vector2.ZERO)
	g.z_index = 6
	var base := ColorRect.new()
	base.position = Vector2(-2600, 478)
	base.size = Vector2(5200, 260)
	base.color = Color(0.016, 0.013, 0.011)
	g.add_child(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# the ref's COBBLE ROW: pebble pieces shoulder to shoulder along the
	# line, tops catching the fog light faintly
	var x := -2600.0
	var i := 0
	while x < 2600.0:
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
	# washed pale mounds — occasional clusters, the line stays mostly clean
	for m: Array in [[-1900.0, 0.30], [-420.0, 0.34], [1050.0, 0.36],
			[2400.0, 0.28]]:
		var piece2: String = ["combo_07.png", "combo_10.png", "combo_11.png"][
				int(absf(m[0])) % 3]
		var tex2 := _tex(CUT, piece2)
		var s := Sprite2D.new()
		s.texture = tex2
		s.position = Vector2(m[0], 470.0 - tex2.get_height() * (m[1] as float) * 0.34)
		s.scale = Vector2(m[1], m[1])
		s.material = _floor_mat()
		s.z_index = 0
		g.add_child(s)
	# dark rock piles breaking the lip — sparse
	for d: Array in [[-1500.0, 0.42], [120.0, 0.45], [1500.0, 0.40]]:
		var piece3: String = ["combo_08.png", "combo_10.png"][int(absf(d[0])) % 2]
		var tex3 := _tex(CUT, piece3)
		_p(g, piece3, Vector2(d[0], 486.0 - tex3.get_height() * (d[1] as float) * 0.32),
				d[1], Color(0.055, 0.050, 0.045), 2, int(d[0]) % 2 == 0)
	# black floor spikes — rare and small, like the ref
	for sp: Array in [[-2100.0, 0.26], [-80.0, 0.30], [1300.0, 0.24]]:
		var piece4: String = ["rock_29.png", "rock_31.png", "rock_33.png",
				"rock_37.png"][int(absf(sp[0])) % 4]
		var tex4 := _tex(CUT, piece4)
		_p(g, piece4, Vector2(sp[0], 492.0 - tex4.get_height() * (sp[1] as float) * 0.42),
				sp[1], Color(0.04, 0.037, 0.033), 3)
	# STEP 5: floor is the hole's bottom edge — near-black silhouette
	# plants grow FROM the line — curls at last in their rightful home
	for pl: Array in [["PlantSmall_00000.png", -1320.0, 0.26, false],
			["Grass2_00000.png", -550.0, 0.24, false],
			["PlantSmall_00000.png", 480.0, 0.22, true],
			["GroupPlants_00000.png", 960.0, 0.30, false],
			["Grass2_00000.png", 1680.0, 0.22, true],
			["PlantSmall_00000.png", 2350.0, 0.25, false]]:
		_plant(g, pl[0], Vector2(pl[1], 452.0), pl[2], pl[3])
	for c in g.get_children():
		if c is AnimatedSprite2D:
			c.modulate = Color("241c10")
	# the ref's one lit tuft — a single green-glowing grass by the light
	var lit := AnimatedSprite2D.new()
	lit.sprite_frames = _frames_cache["Grass2_00000.png"]
	lit.position = Vector2(-680, 452)
	lit.scale = Vector2(0.26, 0.26)
	lit.modulate = Color("241c10")
	lit.z_index = 4
	lit.play("default")
	g.add_child(lit)


func _floor_mat() -> ShaderMaterial:
	if _floor_ramp == null:
		_floor_ramp = ShaderMaterial.new()
		_floor_ramp.shader = load("res://shaders/plat_ramp.gdshader")
		_floor_ramp.set_shader_parameter("cap", Color(0.051, 0.035, 0.024))
		_floor_ramp.set_shader_parameter("gamma_v", 1.4)
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
