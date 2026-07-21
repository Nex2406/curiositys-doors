extends RefCounted
## Consumers: `const Realm1Bg := preload("res://scripts/Realm1Bg.gd")` —
## no class_name, so fresh headless runs never hit a stale class cache.
## Shared builder for the Realm 1 cave background — the fused-strip
## parallax stack + diagonal fog spill + drifting mist that passed Advika's
## eye (2026-07-22). Any Realm 1 scene calls `Realm1Bg.build(host)` and
## gets the identical background; tuning lives HERE, in one place.

const CUT := "res://assets/realms/realm1_cut/"
const SOFT := "res://assets/realms/realm1_soft/"
const SPAN := 5200.0

## every fog-driven material registers here so the wandering light can
## move them all in lockstep (backdrop, bands, platforms)
static var fog_mats: Array = []
static var mist_mats: Array = []
static var accents: Array = []   # shafts/motes/drips/pulse — hue follows palette

## palette presets — muted, never loud (VIBE). Each: fog core/edge, a hue
## shift for the rock art, and the mist tint.
const PALETTES: Array = [
	{"name": "GLOOM OLIVE", "core": Vector3(0.545, 0.553, 0.338),
		"edge": Vector3(0.020, 0.024, 0.016), "tint": Vector3(1, 1, 1),
		"mist": Vector3(0.40, 0.41, 0.21)},
	{"name": "VIOLET HOLLOW", "core": Vector3(0.44, 0.36, 0.58),
		"edge": Vector3(0.016, 0.012, 0.028), "tint": Vector3(0.95, 0.85, 1.15),
		"mist": Vector3(0.33, 0.27, 0.44)},
	{"name": "CRIMSON EMBER", "core": Vector3(0.60, 0.33, 0.22),
		"edge": Vector3(0.030, 0.012, 0.010), "tint": Vector3(1.15, 0.90, 0.75),
		"mist": Vector3(0.45, 0.25, 0.17)},
	{"name": "COLD DEPTHS", "core": Vector3(0.36, 0.46, 0.55),
		"edge": Vector3(0.012, 0.018, 0.026), "tint": Vector3(0.85, 0.95, 1.10),
		"mist": Vector3(0.27, 0.34, 0.42)},
	{"name": "PALE MOON", "core": Vector3(0.50, 0.52, 0.58),
		"edge": Vector3(0.018, 0.019, 0.023), "tint": Vector3(0.92, 0.95, 1.05),
		"mist": Vector3(0.37, 0.38, 0.43)},
]


static func apply_palette(idx: int) -> String:
	var p: Dictionary = PALETTES[clampi(idx, 0, PALETTES.size() - 1)]
	for m: ShaderMaterial in fog_mats:
		m.set_shader_parameter("core", p["core"])
		m.set_shader_parameter("edge", p["edge"])
		m.set_shader_parameter("palette_tint", p["tint"])
	for m: ShaderMaterial in mist_mats:
		m.set_shader_parameter("tint", p["mist"])
	var core: Vector3 = p["core"]
	var mx: float = maxf(core.x, maxf(core.y, core.z))
	var hue := core / maxf(mx, 0.001)
	for n: CanvasItem in accents:
		n.modulate = Color(hue.x, hue.y, hue.z, n.modulate.a)
	return p["name"]


static func build(host: Node2D) -> void:
	var cache := {}
	fog_mats.clear()
	mist_mats.clear()
	accents.clear()
	RenderingServer.set_default_clear_color(Color(0.020, 0.024, 0.016))
	# fog spill backdrop
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = -100
	host.add_child(fog_layer)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fmat := ShaderMaterial.new()
	fmat.shader = load("res://shaders/cave_fog_spill.gdshader")
	fog.material = fmat
	fog_layer.add_child(fog)
	fog_mats.append(fmat)
	# band strips
	var pb := ParallaxBackground.new()
	pb.layer = -50
	host.add_child(pb)
	_backdrop(pb)
	_strip(pb, cache, 0.15, "band_far.png", 1.03, 0.12, Vector3(1.0, 1.2, 0.75))
	_strip(pb, cache, 0.35, "band_spires.png", 0.85, 0.65, Vector3(1.10, 0.95, 0.80))
	_shafts(host, pb)
	var noise := _noise()
	_mist(pb, noise, 0.020, 0.14, 0.0)
	_strip(pb, cache, 0.60, "band_mid.png", 0.55, 0.60, Vector3(1.05, 0.90, 0.80))
	_mist(pb, noise, -0.034, 0.10, 0.45)
	_mist(pb, noise, 0.048, 0.07, 0.8)
	# floor fog river: dense low mist rolling along the bottom
	var river := _mist(pb, noise, 0.06, 0.17, 1.3)
	river.material.set_shader_parameter("band_zone", Vector4(0.55, 0.82, 1.2, 1.0))
	_motes(pb)
	_glow_pulse(host, pb)
	_drips(pb)
	# ROCK NEVER MOVES (lesson of 2026-07-22: heaving bands look silly).
	# Motion belongs to fog, particles, plants — and the light, which
	# wanders only a whisper so shadows creep without reading as a spotlight
	var wander := host.create_tween().set_loops()
	wander.tween_method(_set_fog_center, Vector2(0.20, 0.28),
			Vector2(0.218, 0.295), 14.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wander.tween_method(_set_fog_center, Vector2(0.218, 0.295),
			Vector2(0.20, 0.28), 12.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## STEP 1/7 (Advika's spec 2026-07-22): the painted gold backdrop —
## Tunnel 11 raw, her grade shader does all colour work. Furthest layer,
## NO tiling/mirroring (baked vanishing point; a repeat seam would show).
## Position: the painting's lower third sits on the level's horizon line.
## NOTE for the real level: clamp this layer at both level ends (the spec's
## ~2900px of covered camera travel) — the gallery has no ends yet.
static func _backdrop(pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.name = "bg_backdrop"
	pl.motion_scale = Vector2(0.08, 0.04)
	pb.add_child(pl)
	var s := Sprite2D.new()
	s.texture = load("res://assets/realms/realm1_backdrop/tunnel_11.png")
	s.centered = false
	s.position = Vector2(-1344, -546)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/backdrop_gold.gdshader")
	s.material = mat
	pl.add_child(s)


static func _set_fog_center(v: Vector2) -> void:
	for m: ShaderMaterial in fog_mats:
		m.set_shader_parameter("center", v)


static func mass_mat(lift: float, detail: float,
		brighten := Vector3(1.0, 1.2, 0.75)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog_mass_screen.gdshader")
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("detail", detail)
	mat.set_shader_parameter("brighten", brighten)
	fog_mats.append(mat)
	return mat


static func _strip(pb: ParallaxBackground, cache: Dictionary, motion: float,
		tex_name: String, lift: float, detail: float, brighten: Vector3) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2(motion, 1.0)
	pl.motion_mirroring = Vector2(SPAN, 0.0)
	pb.add_child(pl)
	var s := Sprite2D.new()
	if not cache.has(tex_name):
		var img := Image.load_from_file(
				ProjectSettings.globalize_path(SOFT + tex_name))
		cache[tex_name] = ImageTexture.create_from_image(img)
	s.texture = cache[tex_name]
	s.centered = false
	s.position = Vector2(-SPAN * 0.5, -900.0)
	s.material = mass_mat(lift, detail, brighten)
	s.z_index = 1
	pl.add_child(s)


static func _glow_tex() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = grad
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


## faint light shafts leaking down the spill diagonal, slowly breathing —
## the mysterious aura's heartbeat
static func _shafts(host: Node2D, pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var beams: Array[Polygon2D] = []
	for b: Array in [
			[Vector2(-780, -560), Vector2(-600, -560), 1500.0, 0.13],
			[Vector2(-420, -560), Vector2(-330, -560), 1250.0, 0.085]]:
		var dirv := Vector2(cos(0.5), sin(0.5))
		var poly := Polygon2D.new()
		var a: Vector2 = b[0]
		var c: Vector2 = b[1]
		poly.polygon = PackedVector2Array([a, c,
				c + dirv * (b[2] as float) + Vector2(90, 0),
				a + dirv * (b[2] as float) - Vector2(30, 0)])
		poly.color = Color(0.62, 0.62, 0.62, b[3])
		poly.material = add_mat
		pl.add_child(poly)
		beams.append(poly)
		accents.append(poly)
	# slow asynchronous breathing
	var tw := host.create_tween().set_loops()
	tw.tween_property(beams[0], "modulate:a", 0.45, 4.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(beams[0], "modulate:a", 1.0, 5.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tw2 := host.create_tween().set_loops()
	tw2.tween_property(beams[1], "modulate:a", 0.35, 7.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(beams[1], "modulate:a", 1.0, 6.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## sparse dust motes drifting through the lit air — additive glints, slow
## as snowfall, alive even when the camera is still
static func _motes(pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var p := GPUParticles2D.new()
	p.amount = 34
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.texture = _glow_tex()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add_mat
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1000, 520, 1)
	m.direction = Vector3(0.7, -0.3, 0)
	m.spread = 180.0
	m.initial_velocity_min = 4.0
	m.initial_velocity_max = 16.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.10
	m.scale_max = 0.38
	m.color = Color(0.85, 0.85, 0.55, 1.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.30),
			Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	pl.add_child(p)


## the glow pocket itself breathes — a soft additive pulse over the core
static func _glow_pulse(host: Node2D, pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var s := Sprite2D.new()
	s.texture = _glow_tex()
	s.position = Vector2(-576, -238)
	s.scale = Vector2(16, 13)
	s.modulate = Color(0.75, 0.75, 0.45, 0.05)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = add_mat
	pl.add_child(s)
	accents.append(s)
	var tw := host.create_tween().set_loops()
	tw.tween_property(s, "modulate:a", 0.10, 4.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(s, "modulate:a", 0.025, 3.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## occasional glinting drips falling from the lit stretch of ceiling
static func _drips(pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var p := GPUParticles2D.new()
	p.amount = 5
	p.lifetime = 1.5
	p.preprocess = 3.0
	p.texture = _glow_tex()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add_mat
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(550, 8, 1)
	m.gravity = Vector3(0, 900, 0)
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.0
	m.scale_min = 0.05
	m.scale_max = 0.09
	m.color = Color(0.85, 0.9, 0.6, 1.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55),
			Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	p.position = Vector2(-250, -430)
	pl.add_child(p)
	# hero motes: a few bigger, slower, brighter drifters in the light pocket
	var hero := GPUParticles2D.new()
	hero.amount = 8
	hero.lifetime = 20.0
	hero.preprocess = 20.0
	hero.texture = _glow_tex()
	hero.material = add_mat
	var hm := ParticleProcessMaterial.new()
	hm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	hm.emission_box_extents = Vector3(450, 300, 1)
	hm.gravity = Vector3.ZERO
	hm.initial_velocity_min = 2.0
	hm.initial_velocity_max = 8.0
	hm.spread = 180.0
	hm.direction = Vector3(0.7, -0.3, 0)
	hm.scale_min = 0.40
	hm.scale_max = 0.80
	hm.color = Color(0.85, 0.85, 0.55, 1.0)
	var hramp := Gradient.new()
	hramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	hramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.5),
			Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
	var hramp_tex := GradientTexture1D.new()
	hramp_tex.gradient = hramp
	hm.color_ramp = hramp_tex
	hero.process_material = hm
	hero.position = Vector2(-450, -150)
	pl.add_child(hero)
	accents.append(p)
	accents.append(hero)


static func _noise() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = 0.006
	var ntex := NoiseTexture2D.new()
	ntex.noise = n
	ntex.seamless = true
	ntex.width = 512
	ntex.height = 512
	return ntex


static func _mist(pb: ParallaxBackground, noise: NoiseTexture2D, speed: float,
		strength: float, y_shift: float) -> ColorRect:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var r := ColorRect.new()
	r.position = Vector2(-960, -540)
	r.size = Vector2(1920, 1080)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cave_mist.gdshader")
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("y_shift", y_shift)
	r.material = mat
	pl.add_child(r)
	mist_mats.append(mat)
	return r
