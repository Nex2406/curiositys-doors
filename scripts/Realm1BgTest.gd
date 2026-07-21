extends Node2D
## Realm 1 PARALLAX BACKGROUND RIG — Advika's spec (2026-07-21): parallax,
## depth, CHAOS, and nothing floating. Four dense bands, back to front,
## each a continuous belt: a solid fill strip with masses ROOTED in it,
## heavily overlapped (seeded rng), wrapped in ParallaxLayers.
## Hold LEFT/RIGHT to pan the camera and watch the bands slide.
## BG_SHOT=<path> screenshots and quits; BG_CAM_X=<px> pans first.

const SLICES := "res://assets/realms/realm1_cavern/"
const SOFT := "res://assets/realms/realm1_soft/"
const SPAN := 5200.0                       # band width; mirrors for infinity
const CAM_SPEED := 700.0

# [belt line y, fill bottom, motion scale, lift, detail]
const FAR_SOFT: Array[String] = ["bigrock_00_soft.png", "bigrock_01_soft.png",
	"bigrock_02_soft.png", "bigrock_03_soft.png", "bigrock_04_soft.png",
	"bigrock_06_soft.png", "bigrock_07_soft.png", "bigrock_08_soft.png"]
const SPIRE_SOFT: Array[String] = ["combo_12_soft.png", "combo_13_soft.png",
	"combo_14_soft.png", "combo_15_soft.png", "bigrock_05_soft.png",
	"bigrock_03_soft.png"]
const MID_RAW: Array[String] = ["combo_00.png", "combo_01.png", "combo_03.png",
	"combo_04.png", "combo_05.png", "combo_06.png", "combo_07.png",
	"combo_08.png", "combo_09.png", "combo_10.png", "combo_11.png",
	"bigrock_02.png", "bigrock_06.png", "bigrock_08.png"]
const NEAR_RAW: Array[String] = ["combo_07.png", "combo_10.png", "combo_11.png",
	"rock_29.png", "rock_31.png", "rock_33.png", "rock_35.png", "rock_37.png"]
const TEETH_RAW: Array[String] = ["rock_13.png", "rock_14.png", "rock_20.png",
	"rock_21.png", "rock_22.png"]

var _soft_cache := {}
var _white_tex: ImageTexture
var _cam: Camera2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.020, 0.024, 0.016))
	_build_fog()
	var pb := ParallaxBackground.new()
	pb.layer = -50
	add_child(pb)
	# each ground band is ONE pre-composed strip (tools/compose_band_strips
	# .gd): silhouettes fused + blurred so no per-asset boundary survives
	# lifts/details CALIBRATED against cave_ref_04 samples (2026-07-22):
	# billows ride ±4 RGB of local fog; rock bands match fog VALUE and
	# differ only in warm hue; near band is true silhouette
	# recut solid pieces: bands are PRESENT rock, stepping darker toward
	# the viewer — no washes (Advika: don't fade the outline away)
	var far := _band(pb, 0.15)
	_strip(far, "band_far.png", 1.03, 0.12)
	var spires := _band(pb, 0.35)
	_strip(spires, "band_spires.png", 0.85, 0.65, Vector3(1.10, 0.95, 0.80))
	_mist(pb, 0.012, 0.14, 0.0)     # slow drift right, between spires and mid
	var mid := _band(pb, 0.60)
	_strip(mid, "band_mid.png", 0.55, 0.60, Vector3(1.05, 0.90, 0.80))
	_mist(pb, -0.02, 0.10, 0.45)    # counter-drift left, in front of mid
	var near := _band(pb, 0.85)
	_strip(near, "band_near.png", 0.06, 0.25, Vector3(0.95, 0.85, 0.80))
	_mist(pb, 0.028, 0.07, 0.8)     # nearest wisps, faster and faint
	_cam = Camera2D.new()
	_cam.position = Vector2.ZERO
	add_child(_cam)
	_cam.make_current()
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var l := Label.new()
	l.text = "REALM 1 BG — parallax rig      hold LEFT / RIGHT to pan"
	l.position = Vector2(24, 18)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	cl.add_child(l)
	if OS.get_environment("BG_CAM_X") != "":
		_cam.position.x = float(OS.get_environment("BG_CAM_X"))
	if OS.get_environment("BG_SHOT") != "":
		_shot(OS.get_environment("BG_SHOT"))


func _process(delta: float) -> void:
	if _cam == null:
		return
	var dir := Input.get_axis("ui_left", "ui_right")
	_cam.position.x += dir * CAM_SPEED * delta


func _build_fog() -> void:
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


func _band(pb: ParallaxBackground, motion: float) -> ParallaxLayer:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2(motion, 1.0)
	pl.motion_mirroring = Vector2(SPAN, 0.0)
	pb.add_child(pl)
	return pl


## one fused band strip (composed offline), spanning world y -900..900
func _strip(pl: ParallaxLayer, tex_name: String, lift: float,
		detail: float, brighten := Vector3(1.0, 1.2, 0.75)) -> void:
	var s := Sprite2D.new()
	s.texture = _tex(tex_name, true)
	s.centered = false
	s.position = Vector2(-SPAN * 0.5, -900.0)
	var mat := _mass_mat(lift, detail)
	mat.set_shader_parameter("brighten", brighten)
	s.material = mat
	s.z_index = 1
	pl.add_child(s)


## a screen-anchored drifting mist sheet (motion_scale 0) — our own fog,
## moving on its own so the cave feels alive even with a still camera
var _noise_tex: NoiseTexture2D
func _mist(pb: ParallaxBackground, speed: float, strength: float,
		y_shift: float) -> void:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_PERLIN
		n.frequency = 0.006
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.noise = n
		_noise_tex.seamless = true
		_noise_tex.width = 512
		_noise_tex.height = 512
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var r := ColorRect.new()
	r.position = Vector2(-960, -540)
	r.size = Vector2(1920, 1080)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cave_mist.gdshader")
	mat.set_shader_parameter("noise_tex", _noise_tex)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("y_shift", y_shift)
	r.material = mat
	pl.add_child(r)


func _mass_mat(lift: float, detail: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog_mass_screen.gdshader")
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("detail", detail)
	return mat


func _tex(tex_name: String, soft: bool) -> Texture2D:
	if not soft:
		return load(SLICES + tex_name)
	if not _soft_cache.has(tex_name):
		var img := Image.load_from_file(ProjectSettings.globalize_path(SOFT + tex_name))
		_soft_cache[tex_name] = ImageTexture.create_from_image(img)
	return _soft_cache[tex_name]


func _white() -> ImageTexture:
	if _white_tex == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


func _shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	# calibration readout: render vs cave_ref_04 at the anchor points
	var ref := Image.load_from_file(ProjectSettings.globalize_path(
			"res://docs/reference/cave_ref_04.png"))
	for a: Array in [["core", 0.17, 0.22], ["mid", 0.5, 0.45],
			["low", 0.5, 0.78], ["billow", 0.2, 0.33], ["spikes", 0.62, 0.68],
			["dark_ur", 0.85, 0.12]]:
		var p := img.get_pixel(int(img.get_width() * a[1]),
				int(img.get_height() * a[2]))
		var q := ref.get_pixel(int(ref.get_width() * a[1]),
				int(ref.get_height() * a[2]))
		print("%-8s render(%3d,%3d,%3d) ref(%3d,%3d,%3d)" % [a[0],
				int(p.r * 255.0), int(p.g * 255.0), int(p.b * 255.0),
				int(q.r * 255.0), int(q.g * 255.0), int(q.b * 255.0)])
	get_tree().quit()
