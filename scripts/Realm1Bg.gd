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


static func build(host: Node2D) -> void:
	var cache := {}
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
	# band strips
	var pb := ParallaxBackground.new()
	pb.layer = -50
	host.add_child(pb)
	_strip(pb, cache, 0.15, "band_far.png", 1.03, 0.12, Vector3(1.0, 1.2, 0.75))
	_strip(pb, cache, 0.35, "band_spires.png", 0.85, 0.65, Vector3(1.10, 0.95, 0.80))
	_shafts(host, pb)
	var noise := _noise()
	_mist(pb, noise, 0.012, 0.14, 0.0)
	_strip(pb, cache, 0.60, "band_mid.png", 0.55, 0.60, Vector3(1.05, 0.90, 0.80))
	_mist(pb, noise, -0.02, 0.10, 0.45)
	_strip(pb, cache, 0.85, "band_near.png", 0.06, 0.25, Vector3(0.95, 0.85, 0.80))
	_mist(pb, noise, 0.028, 0.07, 0.8)
	_motes(pb)


static func mass_mat(lift: float, detail: float,
		brighten := Vector3(1.0, 1.2, 0.75)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog_mass_screen.gdshader")
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("detail", detail)
	mat.set_shader_parameter("brighten", brighten)
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
		poly.color = Color(0.55, 0.55, 0.33, b[3])
		poly.material = add_mat
		pl.add_child(poly)
		beams.append(poly)
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
		strength: float, y_shift: float) -> void:
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
