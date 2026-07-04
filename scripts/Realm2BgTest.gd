extends Node2D
## Realm 2 background test — the intimate moss canopy, ALIVE.
## A/B target: assets/_reference/realm2_bg_target_2026-07-04.png
## Everything moves: vines/cascades sway, plants play Maaot's wind frames,
## spores drift, fireflies wander, fog crawls, the chunk bobs, glow breathes.
## Camera auto-pans to show parallax; A/D to pan manually, ESC quits.
## Env var R2_SHOT=<path.png> captures a screenshot after 1s and quits (CI/self-check).

const BASE := "res://assets/realms/realm2_moss/"
const FLOOR_Y := 540.0  # world y of the viewport bottom when camera is at origin

var _t := 0.0
var _cam: Camera2D
var _chunk: Node2D
var _chunk_base_y := 170.0
var _glow: Sprite2D
var _moon: Sprite2D
var _fogs: Array[Sprite2D] = []
var _manual := 0.0

const SWAY_SHADER := "
shader_type canvas_item;
uniform float amp = 14.0;
uniform float speed = 1.2;
uniform float phase = 0.0;
void vertex() {
	VERTEX.x += sin(TIME * speed + phase) * amp * UV.y;
}
"

const VIGNETTE_SHADER := "
shader_type canvas_item;
void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5);
	float d = length(uv * vec2(1.2, 1.35));
	COLOR = vec4(0.02, 0.012, 0.055, smoothstep(0.45, 0.95, d) * 0.85);
}
"


func _ready() -> void:
	_build_sky()
	_build_parallax()
	_build_chunk()
	_build_foreground()
	_build_particles()
	_build_fog()
	_build_ui()
	_build_camera()
	if OS.get_environment("R2_SHOT") != "":
		_self_screenshot(OS.get_environment("R2_SHOT"))


func _build_sky() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -20  # behind the ParallaxBackground (set to -15 below)
	add_child(cl)
	var tr := TextureRect.new()
	tr.texture = load(BASE + "sky.png")
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(tr)


func _add_band(pb: ParallaxBackground, tex: String, motion: float) -> ParallaxLayer:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(motion, motion * 0.4)
	pb.add_child(layer)
	var s := Sprite2D.new()
	s.texture = load(BASE + tex)
	s.centered = false
	# ParallaxLayer space: origin = screen top-left. Center the 3840 band,
	# bottom flush with the screen bottom.
	s.position = Vector2(-960, 0)
	layer.add_child(s)
	return layer


func _build_parallax() -> void:
	var pb := ParallaxBackground.new()
	pb.layer = -15  # above the sky (-20), below the world (0)
	add_child(pb)
	# moon: barely moves, upper left, halo pulses
	var ml := ParallaxLayer.new()
	ml.motion_scale = Vector2(0.02, 0.0)
	pb.add_child(ml)
	_moon = Sprite2D.new()
	_moon.texture = load(BASE + "moon.png")
	_moon.position = Vector2(310, 215)  # screen-space: upper left, through the canopy
	ml.add_child(_moon)
	_add_band(pb, "band_far.png", 0.12)
	_add_band(pb, "band_mid.png", 0.3)
	_add_band(pb, "band_ground.png", 0.75)


func _sway_material(amp: float, speed: float, phase: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SWAY_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("phase", phase)
	return m


func _hanging(tex: String, amp: float, speed: float, phase: float) -> Sprite2D:
	# top-anchored sprite so the sway pivots from where it hangs
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
	return a


func _build_chunk() -> void:
	_chunk = Node2D.new()
	_chunk.position = Vector2(0, _chunk_base_y)
	add_child(_chunk)

	# moss cascades hanging from the underside, each swaying out of phase
	for p in [[-210.0, 78.0, 12.0, 1.0, 0.0], [-20.0, 110.0, 16.0, 0.85, 1.7],
			[170.0, 70.0, 11.0, 1.15, 3.1]]:
		var c := _hanging("cascade.png", p[2], p[3], p[4])
		c.position = Vector2(p[0], p[1])
		c.scale = Vector2(0.6, 0.6)
		_chunk.add_child(c)

	# warm lantern pocket, breathing (additive)
	_glow = Sprite2D.new()
	_glow.texture = load(BASE + "glow_gold.png")
	_glow.position = Vector2(0, -110)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add_mat
	_chunk.add_child(_glow)

	# the chunk itself
	var body := Sprite2D.new()
	body.texture = load(BASE + "chunk.png")
	_chunk.add_child(body)

	# Maaot's animated plants ON the chunk — real frame-by-frame wind
	var wind := _animated("plant_wind", 10.0, 0.30)
	wind.position = Vector2(-170, -140)
	_chunk.add_child(wind)
	var flower := _animated("flower", 8.0, 0.26)
	flower.position = Vector2(60, -138)
	_chunk.add_child(flower)
	var plant1 := _animated("plant1", 9.0, 0.28)
	plant1.position = Vector2(210, -132)
	_chunk.add_child(plant1)


func _build_foreground() -> void:
	# near-black canopy pressing in from above, swaying. Foreground parallax
	# (>1) is faked by counter-shifting this node against the camera in _process.
	var fg := Node2D.new()
	fg.name = "Foreground"
	fg.z_index = 50
	add_child(fg)
	for p in [[-880.0, -560.0, "vine_dark.png", 10.0, 0.7, 0.0],
			[-380.0, -572.0, "cascade_dark.png", 14.0, 0.9, 1.2],
			[140.0, -566.0, "cascade_dark.png", 12.0, 0.8, 2.6],
			[620.0, -558.0, "vine_dark.png", 9.0, 0.65, 4.0],
			[1250.0, -570.0, "vine_dark.png", 11.0, 0.75, 5.2],
			[-1500.0, -565.0, "cascade_dark.png", 13.0, 0.85, 0.6],
			[1800.0, -562.0, "vine_dark.png", 10.0, 0.7, 2.0]]:
		var v := _hanging(p[2], p[3], p[4], p[5])
		v.position = Vector2(p[0], p[1])
		fg.add_child(v)


func _build_particles() -> void:
	# drifting spores
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

	# amber fireflies, wandering near the warm pocket
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


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var vr := ColorRect.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	vr.material = m
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(vr)
	var lbl := Label.new()
	lbl.text = "REALM 2 BG TEST — auto-pan · A/D pan · ESC quit"
	lbl.position = Vector2(16, 12)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.9, 0.55))
	cl.add_child(lbl)


func _build_camera() -> void:
	_cam = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := vp.y / 1080.0
	_cam.zoom = Vector2(z, z)
	add_child(_cam)
	_cam.make_current()


func _self_screenshot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	# camera: gentle auto-pan, A/D overrides
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.01:
		_manual = clampf(_manual + dir * 500.0 * delta, -900.0, 900.0)
		_cam.position.x = _manual
	else:
		_cam.position.x = lerpf(_cam.position.x, sin(_t * 0.1) * 820.0, delta * 0.5)
	# foreground counter-shift (fake >1 parallax)
	$Foreground.position.x = _cam.position.x * -0.22
	# the chunk floats
	_chunk.position.y = _chunk_base_y + sin(_t * 0.5) * 10.0
	# glow breathes (two out-of-phase sines, same trick as the lantern)
	_glow.modulate.a = 0.82 + sin(_t * 1.1) * 0.1 + sin(_t * 1.7 + 1.3) * 0.06
	# moon halo pulse, very slow
	_moon.modulate.a = 0.92 + sin(_t * 0.23) * 0.08
	# fog crawls, wraps
	for i in _fogs.size():
		var f := _fogs[i]
		f.position.x += (6.0 + i * 3.0) * delta
		if f.position.x > 2400.0:
			f.position.x = -2400.0
