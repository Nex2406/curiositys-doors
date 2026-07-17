class_name Realm2Background
extends Node2D
## The living Realm 2 backdrop, reusable by any Realm 2 scene.
## A/B target: assets/_reference/realm2_bg_target_2026-07-04.png
## Owns: sky, moon, stars, storm wisps, 3 parallax spire bands, mid-depth
## vines, foreground canopy, fog, spores, fireflies, (optional) deco chunk.
## Storm API: set_storm(0..1) ramps wind sway, cloud speed, sky darkness —
## the storm is this realm's engine.

const BASE := "res://assets/realms/realm2_moss/"

@export var include_chunk := true  # decorative floating chunk (Realm2BgTest)

var _t := 0.0
var _storm := 0.0
var _chunk: Node2D
var _chunk_base_y := 170.0
var _glow: Sprite2D
var _moon: Sprite2D
var _sky_rect: TextureRect
var _fogs: Array[Sprite2D] = []
var _stars: Array[Sprite2D] = []
var _star_phase: Array[float] = []
var _clouds: Array[Sprite2D] = []
var _sway_mats: Array[ShaderMaterial] = []
var _plants: Array[AnimatedSprite2D] = []
var _pendulums: Array[Dictionary] = []

const SWAY_SHADER := "
shader_type canvas_item;
uniform float amp = 14.0;
uniform float speed = 1.2;
uniform float phase = 0.0;
uniform float storm = 0.0;
void vertex() {
	float a = amp * (1.0 + 2.2 * storm);
	float s = speed * (1.0 + 1.6 * storm);
	VERTEX.x += sin(TIME * s + phase) * a * UV.y;
}
"


func _ready() -> void:
	_build_sky()
	_build_parallax()
	if include_chunk:
		_build_deco_chunk()
	_build_foreground()
	_build_particles()
	_build_fog()


## Storm intensity 0..1 — wind, clouds, sky darkness. The one dial.
func set_storm(intensity: float) -> void:
	_storm = clampf(intensity, 0.0, 1.0)
	for m in _sway_mats:
		m.set_shader_parameter("storm", _storm)
	for p in _plants:
		p.speed_scale = 1.0 + 1.8 * _storm
	if _sky_rect:
		_sky_rect.modulate = Color(1, 1, 1).lerp(Color(0.62, 0.58, 0.72), _storm)
	for c in _clouds:
		c.modulate.a = 0.5 + 0.35 * _storm


func get_storm() -> float:
	return _storm


func _build_sky() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -20
	add_child(cl)
	_sky_rect = TextureRect.new()
	_sky_rect.texture = load(BASE + "sky.png")
	_sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_sky_rect)


func _add_band(pb: ParallaxBackground, tex: String, motion: float, y_motion: float) -> ParallaxLayer:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(motion, y_motion)
	pb.add_child(layer)
	var s := Sprite2D.new()
	s.texture = load(BASE + tex)
	s.centered = false
	s.position = Vector2(-960, 0)  # layer space: origin = screen top-left
	layer.add_child(s)
	return layer


func _build_parallax() -> void:
	var pb := ParallaxBackground.new()
	pb.layer = -15
	add_child(pb)

	var ml := ParallaxLayer.new()
	ml.motion_scale = Vector2(0.02, 0.0)
	pb.add_child(ml)
	_moon = Sprite2D.new()
	_moon.texture = load(BASE + "moon.png")
	_moon.position = Vector2(310, 215)
	ml.add_child(_moon)

	var sl := ParallaxLayer.new()
	sl.motion_scale = Vector2(0.04, 0.0)
	pb.add_child(sl)
	var srng := RandomNumberGenerator.new()
	srng.seed = 7
	for i in 16:
		var st := Sprite2D.new()
		st.texture = load(BASE + "star.png")
		st.position = Vector2(srng.randf_range(80, 1840), srng.randf_range(50, 430))
		st.scale = Vector2.ONE * srng.randf_range(0.5, 1.1)
		st.modulate.a = srng.randf_range(0.2, 0.5)
		sl.add_child(st)
		_stars.append(st)
		_star_phase.append(srng.randf_range(0.0, TAU))

	var cl2 := ParallaxLayer.new()
	cl2.motion_scale = Vector2(0.08, 0.0)
	pb.add_child(cl2)
	for i in 3:
		var c := Sprite2D.new()
		c.texture = load(BASE + "cloud.png")
		c.position = Vector2(200 + i * 700, 180 + i * 90)
		c.scale = Vector2(1.3 + 0.3 * i, 1.1)
		c.modulate.a = 0.5
		cl2.add_child(c)
		_clouds.append(c)

	# y motions tuned for the ascent: near canopy falls away fast, far spires
	# sink slowly — high altitude reads as open sky + moon + stars
	var far := _add_band(pb, "band_far.png", 0.12, 0.25)
	_flora_band(far, true)
	var mid := _add_band(pb, "band_mid.png", 0.3, 0.55)
	_flora_band(mid, false)
	_add_band(pb, "band_ground.png", 0.75, 0.9)


# Advika 2026-07-17: "can we make the bg denser" → round 2 "MAXIMISE THE
# BACKGROUND DONT BE SHY". Two silhouette forests grown into the painted
# bands' own layers (they parallax and sink identically during the ascent):
# a dense one in the mid band, a fainter, smaller one in the far band.
# Every trunk wears a TUFT CROWN over its sliced top — the naked cut end
# read as an unfinished tree (Advika caught one floating mid-sky). Rooted
# into the bands' shrub masses; dressing law: nothing floats, no naked ends.
func _flora_band(layer: ParallaxLayer, far: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260718 if far else 20260717
	var trunks: Array[Texture2D] = []
	for n in ["vine_trunk_0", "vine_trunk_1", "vine_trunk_2", "vine_trunk_3"]:
		trunks.append(load(BASE + n + ".png"))
	var tufts: Array[Texture2D] = []
	for n in ["tuft_0", "tuft_1", "tuft_2"]:
		tufts.append(load(BASE + n + ".png"))
	var x := -1250.0
	var x_max := 2200.0 if far else 2700.0
	while x < x_max:
		var b := rng.randf_range(0.14, 0.30) * (0.55 if far else 1.0)
		if rng.randf() < 0.72:
			_flora_tree(layer, rng, trunks, tufts, x, b, far)
		if rng.randf() < 0.9:
			_flora_mound(layer, rng, tufts, x + rng.randf_range(-90.0, 90.0), b, far)
		# round 3 (Advika: "add more density") — a second, farther mound row
		# fills the last violet slivers between the trees
		if rng.randf() < 0.6:
			_flora_mound(layer, rng, tufts, x + rng.randf_range(-60.0, 60.0),
					b * 0.7, far)
		x += rng.randf_range(70.0, 150.0) if not far else rng.randf_range(120.0, 220.0)


# A finished tree: trunk column + overlapping tuft crown hiding the slice.
func _flora_tree(layer: ParallaxLayer, rng: RandomNumberGenerator,
		trunks: Array[Texture2D], tufts: Array[Texture2D],
		x: float, b: float, far: bool) -> void:
	var t: Texture2D = trunks[rng.randi() % trunks.size()]
	var sc := rng.randf_range(0.5, 0.95) * (0.55 if far else 1.0)
	var trunk := Sprite2D.new()
	trunk.texture = t
	trunk.centered = false
	trunk.flip_h = rng.randf() < 0.5
	trunk.scale = Vector2(sc, sc)
	var base_y := rng.randf_range(660.0, 750.0) + (40.0 if far else 0.0)
	var top_y := base_y - t.get_height() * sc
	trunk.position = Vector2(x, top_y)
	trunk.modulate = Color(b, b * 0.92, b * 1.35)
	layer.add_child(trunk)
	# the crown: 2 tufts straddling the trunk axis, swallowing the cut end
	var axis_x := x + t.get_width() * sc * 0.5
	for i in 2:
		var ct: Texture2D = tufts[rng.randi() % tufts.size()]
		var cs := sc * rng.randf_range(0.85, 1.25)
		var crown := Sprite2D.new()
		crown.texture = ct
		crown.flip_h = rng.randf() < 0.5
		crown.scale = Vector2(cs, cs)
		crown.position = Vector2(axis_x + (i * 2 - 1) * rng.randf_range(0.0, 60.0) * sc,
				top_y + rng.randf_range(-10.0, 25.0))
		crown.modulate = trunk.modulate
		layer.add_child(crown)


# A moss mound swelling out of the band's shrub line.
func _flora_mound(layer: ParallaxLayer, rng: RandomNumberGenerator,
		tufts: Array[Texture2D], x: float, b: float, far: bool) -> void:
	var t: Texture2D = tufts[rng.randi() % tufts.size()]
	var sc := rng.randf_range(0.5, 1.0) * (0.55 if far else 1.0)
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.flip_h = rng.randf() < 0.5
	s.scale = Vector2(sc, sc)
	s.position = Vector2(x,
			rng.randf_range(700.0, 780.0) + (40.0 if far else 0.0) - t.get_height() * sc)
	s.modulate = Color(b * 1.3, b * 1.2, b * 1.65)
	layer.add_child(s)


func _sway_material(amp: float, speed: float, phase: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SWAY_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("storm", _storm)
	_sway_mats.append(m)
	return m


func _hanging(tex: String, amp: float, speed: float, phase: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(BASE + tex)
	s.centered = false
	s.offset = Vector2(-s.texture.get_width() / 2.0, 0)
	s.material = _sway_material(amp, speed, phase)
	return s


func _animated(dir: String, fps: float, sc: float) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("sway")
	frames.set_animation_loop("sway", true)
	frames.set_animation_speed("sway", fps)
	var i := 0
	while ResourceLoader.exists(BASE + dir + "/frame_%03d.png" % i):
		frames.add_frame("sway", load(BASE + dir + "/frame_%03d.png" % i))
		i += 1
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.scale = Vector2(sc, sc)
	a.play("sway")
	_plants.append(a)
	return a


## Dress any node as "the chunk": cascades below, glow, body, animated plants.
## Returns the glow sprite so the owner can breathe it.
func build_chunk_visuals(parent: Node2D) -> Sprite2D:
	for p in [[-210.0, 78.0, 12.0, 1.0, 0.0], [-20.0, 110.0, 16.0, 0.85, 1.7],
			[170.0, 70.0, 11.0, 1.15, 3.1]]:
		var c := _hanging("cascade.png", p[2], p[3], p[4])
		c.position = Vector2(p[0], p[1])
		c.scale = Vector2(0.6, 0.6)
		parent.add_child(c)
	var glow := Sprite2D.new()
	glow.texture = load(BASE + "glow_gold.png")
	glow.position = Vector2(0, -110)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add_mat
	parent.add_child(glow)
	var body := Sprite2D.new()
	body.texture = load(BASE + "chunk.png")
	parent.add_child(body)

	# ---- design pass: break up the flat dark core ----
	# boulders grown into the top line (roots hidden by the fringe overlay)
	for p in [[-330.0, -122.0, 0.34, 0, 0.85], [255.0, -116.0, 0.24, 1, 0.75]]:
		var b := Sprite2D.new()
		b.texture = load(BASE + "boulder_%d.png" % [0 if p[3] == 0 else 1])
		b.scale = Vector2(p[2], p[2])
		if p[3] == 1:
			b.flip_h = true
		b.position = Vector2(p[0], p[1])
		b.modulate = Color(p[4], p[4], p[4])
		parent.add_child(b)
	# tuft clusters varying the fringe silhouette — bases rooted INSIDE the
	# fringe (bottom sits at -85 local, covered by the z12 fringe overlay)
	# (-140 / +350 plug the bare-rock notches between the fringe clumps —
	# they read as black holes while the island is embedded)
	for p in [[-460.0, 0.5], [-140.0, 0.55], [-70.0, 0.62], [350.0, 0.5], [420.0, 0.45]]:
		var tf := Sprite2D.new()
		tf.texture = load(BASE + "tuft_%d.png" % (randi() % 3))
		tf.scale = Vector2(p[1], p[1])
		tf.position = Vector2(p[0], -85.0 - tf.texture.get_height() * p[1] * 0.5)
		parent.add_child(tf)
	# half-sunk rocks texturing the dark core
	for p in [[-180.0, -20.0, 0.2, 0.5], [120.0, -8.0, 0.16, 0.42]]:
		var r := Sprite2D.new()
		r.texture = load(BASE + "boulder_2.png")
		r.scale = Vector2(p[2], p[2])
		r.position = Vector2(p[0], p[1])
		r.modulate = Color(p[3], p[3], p[3] * 1.15)
		parent.add_child(r)
	# faint gold ember-veins in the rock (kin to the lantern)
	for p in [[-280.0, -36.0, 0.13], [40.0, -18.0, 0.1], [340.0, -42.0, 0.15]]:
		var em := Sprite2D.new()
		em.texture = load(BASE + "glow_gold.png")
		em.scale = Vector2(p[2], p[2])
		em.position = Vector2(p[0], p[1])
		em.modulate.a = 0.5
		var add_m := CanvasItemMaterial.new()
		add_m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		em.material = add_m
		parent.add_child(em)

	# front fringe overlay: the island's own top grass drawn OVER the rider,
	# so anyone standing on it stands IN the moss, not on a shelf above it.
	# The region crop ends mid-texture, so its bottom quarter dissolves —
	# otherwise the crop edge draws a razor-straight line across everything
	# beneath it (it was THE ground-band line while the island sat embedded).
	var fringe := Sprite2D.new()
	fringe.texture = body.texture
	fringe.region_enabled = true
	fringe.region_rect = Rect2(0, 0, body.texture.get_width(), 95)
	fringe.position = Vector2(0, -body.texture.get_height() / 2.0 + 47.5)
	fringe.z_index = 12
	var fade := Shader.new()
	# NB: modify COLOR (texture * modulate), don't resample — the island's
	# camouflage/wake tint must keep applying to the fringe
	fade.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR.a *= 1.0 - smoothstep(0.52, 1.0, UV.y);\n}"
	var fade_mat := ShaderMaterial.new()
	fade_mat.shader = fade
	fringe.material = fade_mat
	parent.add_child(fringe)
	var flower := _animated("flower", 8.0, 0.26)
	flower.position = Vector2(60, -138)
	parent.add_child(flower)
	var plant1 := _animated("plant1", 9.0, 0.28)
	plant1.position = Vector2(210, -132)
	parent.add_child(plant1)
	return glow


func _build_deco_chunk() -> void:
	_chunk = Node2D.new()
	_chunk.position = Vector2(0, _chunk_base_y)
	add_child(_chunk)
	_glow = build_chunk_visuals(_chunk)


func _leaf(parent: Node2D, tex: String, x: float, y: float, sc: float,
		bright: float, shear_amp: float, speed: float, phase: float,
		base_rot: float, rot_amp: float) -> void:
	var v := _hanging(tex, shear_amp, speed, phase)
	v.position = Vector2(x, y)
	v.scale = Vector2(sc, sc)
	v.modulate = Color(bright, bright, bright)
	v.rotation_degrees = base_rot
	parent.add_child(v)
	_pendulums.append({"node": v, "base": base_rot, "amp": rot_amp,
			"speed": speed * 0.55, "phase": phase + 0.8})


func _build_foreground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()  # fresh canopy every launch

	var mv := Node2D.new()
	mv.name = "MidVines"
	add_child(mv)
	move_child(mv, 0)
	# (range: the container parallax-shifts by +0.55*cam.x, so 2200 local is
	# what the frame's right edge needs at the island)
	var mx := rng.randf_range(-1700.0, -1300.0)
	while mx < 2200.0:
		_leaf(mv, "cascade.png", mx, rng.randf_range(-660.0, -595.0),
				rng.randf_range(0.55, 0.95), rng.randf_range(0.38, 0.58),
				rng.randf_range(6.0, 10.0), rng.randf_range(0.5, 0.75),
				rng.randf_range(0.0, TAU), rng.randf_range(-6.0, 6.0),
				rng.randf_range(1.5, 2.8))
		mx += rng.randf_range(250.0, 430.0)  # tightened twice (Advika: denser bg)

	# canopy moss clumps — the ground's own tufts hanging among the leaf
	# strands, so ceiling and floor share one vocabulary (they ride MidVines:
	# same parallax, same fade-out at liftoff)
	var tx := rng.randf_range(-1650.0, -1250.0)
	while tx < 2200.0:
		var ct := Sprite2D.new()
		ct.texture = load(BASE + "tuft_%d.png" % (rng.randi() % 3))
		var cs := rng.randf_range(0.30, 0.52)
		ct.scale = Vector2(cs, cs)
		ct.flip_h = rng.randf() < 0.5
		ct.position = Vector2(tx, rng.randf_range(-650.0, -545.0))
		var cb := rng.randf_range(0.36, 0.52)
		ct.modulate = Color(cb, cb * 0.95, cb * 1.2)
		mv.add_child(ct)
		tx += rng.randf_range(130.0, 250.0)  # tightened twice (Advika: denser bg)

	var fg := Node2D.new()
	fg.name = "Foreground"
	fg.z_index = 50
	add_child(fg)
	# (range: this container parallax-shifts by -0.22*cam.x, so the frame's
	# right edge at the island needs strands out to ~3300 local — stopping at
	# 2000 left the right half of the level bald)
	var fx := rng.randf_range(-1800.0, -1500.0)
	while fx < 3300.0:
		var tex := "vine_dark.png" if rng.randf() < 0.6 else "cascade_dark.png"
		_leaf(fg, tex, fx, rng.randf_range(-620.0, -535.0),
				rng.randf_range(0.55, 1.2), rng.randf_range(0.72, 1.0),
				rng.randf_range(8.0, 15.0), rng.randf_range(0.55, 0.95),
				rng.randf_range(0.0, TAU), rng.randf_range(-7.0, 7.0),
				rng.randf_range(2.0, 3.6))
		fx += rng.randf_range(300.0, 560.0)


func _build_particles() -> void:
	var spores := CPUParticles2D.new()
	spores.texture = load(BASE + "spore.png")
	spores.amount = 22
	spores.lifetime = 16.0
	spores.preprocess = 16.0
	spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spores.emission_rect_extents = Vector2(1400, 520)
	spores.direction = Vector2(1, 0.22)
	spores.spread = 12.0
	spores.gravity = Vector2.ZERO
	spores.initial_velocity_min = 14.0
	spores.initial_velocity_max = 34.0
	spores.scale_amount_min = 0.6
	spores.scale_amount_max = 1.2
	spores.position = Vector2(0, -80)
	add_child(spores)

	var ff := CPUParticles2D.new()
	ff.texture = load(BASE + "firefly.png")
	ff.amount = 12
	ff.lifetime = 9.0
	ff.preprocess = 9.0
	ff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ff.emission_rect_extents = Vector2(900, 380)
	ff.gravity = Vector2.ZERO
	ff.initial_velocity_min = 6.0
	ff.initial_velocity_max = 18.0
	ff.spread = 180.0
	ff.scale_amount_min = 0.35
	ff.scale_amount_max = 0.8
	ff.position = Vector2(0, 120)
	ff.z_index = 40
	add_child(ff)


func _build_fog() -> void:
	for i in 3:
		var f := Sprite2D.new()
		f.texture = load(BASE + "fog.png")
		f.position = Vector2(-1400 + i * 1300, 260 - i * 140)
		f.scale = Vector2(3.4, 2.6)
		f.modulate.a = 0.5
		f.z_index = 30
		add_child(f)
		_fogs.append(f)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	if cam:
		$Foreground.position.x = cam.global_position.x * -0.22
		$MidVines.position.x = cam.global_position.x * 0.55
		# the hanging canopy belongs to the forest floor: it must be FULLY gone
		# before the highest strand anchor (y ≈ -535) can cross the frame top
		# (cam.y ≈ 33 at ground zoom) — otherwise cut-off leaf tops float in
		# mid-air during the climb. Ground cam sits at y = 80; the liftoff
		# shake/storm masks this quick fade.
		var alt := clampf(inverse_lerp(75.0, 20.0, cam.global_position.y), 0.0, 1.0)
		$Foreground.modulate.a = 1.0 - alt
		$MidVines.modulate.a = 1.0 - alt
	if _chunk:
		_chunk.position.y = _chunk_base_y + sin(_t * 0.5) * 10.0
	if _glow:
		_glow.modulate.a = 0.82 + sin(_t * 1.1) * 0.1 + sin(_t * 1.7 + 1.3) * 0.06
	if _moon:
		_moon.modulate.a = 0.92 + sin(_t * 0.23) * 0.08
	for i in _fogs.size():
		var f := _fogs[i]
		f.position.x += (6.0 + i * 3.0 + 26.0 * _storm) * delta
		if f.position.x > 2400.0:
			f.position.x = -2400.0
	for i in _stars.size():
		_stars[i].modulate.a = 0.32 + sin(_t * 0.6 + _star_phase[i]) * 0.18
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += (4.0 + i * 2.5 + 60.0 * _storm) * delta
		if c.position.x > 2600.0:
			c.position.x = -700.0
	var storm_rot := 1.0 + 2.0 * _storm
	for pd in _pendulums:
		pd["node"].rotation_degrees = pd["base"] + \
				sin(_t * pd["speed"] * storm_rot + pd["phase"]) * pd["amp"] * (1.0 + 1.2 * _storm)
