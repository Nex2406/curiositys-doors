extends Node2D
## ONE-FRAME CONCEPT MOCK — Realm 3 finale "The Bloom" (Act 3 moment).
## Not gameplay. Composes the pitch image with the real pack + hero art:
## the warm bloom rising from below, Consciousness's white correction
## raining from above, Curiosity mid-bounce between the two lights, a
## Remembered One dissolving inside the light. BLOOM_SHOT=<path>
## screenshots + quits. Advika judges the frame before the finale is built.

const FUNGAL := "res://assets/realms/realm3_fungal/"
const MASS_FILL := Color(0.014, 0.028, 0.025)
const AMBER := Color(1.0, 0.78, 0.42)
const AMBER_DEEP := Color(0.95, 0.55, 0.2)
const COLD := Color(0.82, 0.92, 1.0)
const MOSS := Color(0.62, 0.95, 0.58)
const CYAN := Color(0.68, 0.95, 0.90)

var _rng := RandomNumberGenerator.new()
var _glow_tex: GradientTexture2D


func _ready() -> void:
	_rng.seed = 20260716
	RenderingServer.set_default_clear_color(Color(0.012, 0.024, 0.022))
	($Camera as Camera2D).zoom = Vector2(1.25, 1.25)
	_build_sky()
	_build_walls()
	_build_bloom()
	_build_correction()
	_build_actors()
	_build_foreground()
	if OS.get_environment("BLOOM_SHOT") != "":
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(
				OS.get_environment("BLOOM_SHOT"))
		get_tree().quit()


func _make_glow_tex() -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = grad
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(0.5, 0.0)
	_glow_tex.width = 256
	_glow_tex.height = 256


func _glow(pos: Vector2, col: Color, px: float, alpha: float, z: int) -> void:
	if _glow_tex == null:
		_make_glow_tex()
	var s := Sprite2D.new()
	s.texture = _glow_tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	s.modulate = Color(col.r, col.g, col.b, alpha)
	s.scale = Vector2.ONE * (px / 256.0)
	s.position = pos
	s.z_index = z
	add_child(s)


func _sprite(tex_path: String, pos: Vector2, sc: float, z: int,
		tint := Color.WHITE, fh := false, fv := false, rot := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.position = pos
	s.scale = Vector2(sc, sc)
	s.z_index = z
	s.modulate = tint
	s.flip_h = fh
	s.flip_v = fv
	s.rotation_degrees = rot
	add_child(s)
	return s


## vertical gradient quad, col fading to transparent toward fade_y
func _grad_rect(x0: float, x1: float, y_solid: float, y_fade: float,
		col: Color, z: int, additive := false) -> void:
	var p := Polygon2D.new()
	var c1 := Color(col.r, col.g, col.b, col.a)
	var c0 := Color(col.r, col.g, col.b, 0.0)
	p.polygon = PackedVector2Array([Vector2(x0, y_fade), Vector2(x1, y_fade),
			Vector2(x1, y_solid), Vector2(x0, y_solid)])
	p.vertex_colors = PackedColorArray([c0, c0, c1, c1])
	p.color = Color.WHITE
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
	p.z_index = z
	add_child(p)


# ---------- layers ----------

func _build_sky() -> void:
	# deep teal cavern air: cold-dark up top, near-black mid — the realm's
	# own palette holds; only the two LIGHTS break it
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-960, -540), Vector2(960, -540),
			Vector2(960, 540), Vector2(-960, 540)])
	p.vertex_colors = PackedColorArray([
			Color(0.045, 0.075, 0.095), Color(0.045, 0.075, 0.095),
			Color(0.028, 0.05, 0.045), Color(0.028, 0.05, 0.045)])
	p.color = Color.WHITE
	p.z_index = -20
	add_child(p)
	# giant sleeping caps as far silhouettes, barely off the dark
	_sprite(FUNGAL + "mushroomcap3.png", Vector2(-560, -20), 1.0, -18,
			Color(0.055, 0.095, 0.09), false)
	_sprite(FUNGAL + "mushroomcap6.png", Vector2(640, -130), 0.8, -18,
			Color(0.05, 0.085, 0.082), true)
	_sprite(FUNGAL + "stalagmite5.png", Vector2(-280, 200), 0.9, -17,
			Color(0.04, 0.07, 0.066), false, false, 180.0)
	_sprite(FUNGAL + "stalagmite13.png", Vector2(330, 260), 0.8, -17,
			Color(0.045, 0.075, 0.07), true, false, 180.0)


func _build_walls() -> void:
	# rimmed near-black masses closing both sides — the shipped R3 idiom
	for side: float in [-1.0, 1.0]:
		var xin := side * 620.0
		var xout := side * 1000.0
		var wall := Polygon2D.new()
		wall.polygon = PackedVector2Array([Vector2(xin, -560), Vector2(xout, -560),
				Vector2(xout, 560), Vector2(xin, 560)])
		wall.color = MASS_FILL
		wall.z_index = -8
		add_child(wall)
		var y := -500.0
		while y < 540.0:
			_sprite(FUNGAL + ["fungalground20.png", "fungalground21.png"][_rng.randi() % 2],
					Vector2(xin, y), 0.42, -7,
					Color(0.3, 0.38, 0.36), _rng.randf() < 0.5)
			y += 210.0
		# sparse growth off the rim, warming as it nears the bloom
		var fy := -380.0
		while fy < 460.0:
			var warm: float = clampf((fy - 40.0) / 420.0, 0.0, 1.0)
			var tint := Color(0.14, 0.23, 0.21).lerp(Color(0.8, 0.5, 0.25), warm * 0.6)
			_sprite(FUNGAL + "fungalfrond%d.png" % [2, 3, 10, 16][_rng.randi() % 4],
					Vector2(xin - side * _rng.randf_range(6.0, 44.0), fy),
					_rng.randf_range(0.17, 0.27), -6, tint,
					side > 0, false, -side * 90.0)
			fy += _rng.randf_range(150.0, 230.0)
		# a buried SHELF: half-swallowed pebble frame sunk in the wall
		_sprite(FUNGAL + "fungalground3.png", Vector2(side * 830.0, -160.0),
				0.4, -7, Color(0.16, 0.22, 0.21), side > 0, false, side * 7.0)


func _build_bloom() -> void:
	# THE RISING MEMORY — a soft wall of warm light climbing from below.
	# No hard bands: gradient quad + stacked additive glows.
	_grad_rect(-960, 960, 560, 240, Color(0.9, 0.6, 0.25, 0.9), -4)
	_grad_rect(-960, 960, 560, 380, Color(1.0, 0.85, 0.55, 0.85), -4, true)
	for g in [[-620.0, 560.0, 1300.0, 0.55], [-90.0, 600.0, 1600.0, 0.6],
			[470.0, 570.0, 1200.0, 0.5], [820.0, 620.0, 900.0, 0.45],
			[-900.0, 640.0, 900.0, 0.45]]:
		_glow(Vector2(g[0], g[1]), AMBER, g[2], g[3], -4)
	_glow(Vector2(-60, 500), Color(1.0, 0.93, 0.75), 700, 0.7, -3)
	# erupting cap silhouettes riding the wave-front, backlit
	_sprite(FUNGAL + "mushroomcap9.png", Vector2(-430, 440), 0.5, -3,
			Color(0.22, 0.11, 0.04), false, false, -8.0)
	_sprite(FUNGAL + "mushroomcap4.png", Vector2(190, 490), 0.46, -3,
			Color(0.24, 0.12, 0.05), true, false, 6.0)
	_sprite(FUNGAL + "mushroomcap1.png", Vector2(600, 450), 0.38, -3,
			Color(0.26, 0.13, 0.05), false, false, -12.0)
	# remembered lives: motes streaming UP out of the light
	for i in 110:
		var x := _rng.randf_range(-940.0, 940.0)
		var y := 430.0 - absf(_rng.randfn(0.0, 140.0)) - _rng.randf_range(0.0, 330.0)
		var hue: Color = [AMBER, AMBER, AMBER, AMBER, MOSS, CYAN][_rng.randi() % 6]
		_glow(Vector2(x, y), hue, _rng.randf_range(6.0, 26.0),
				_rng.randf_range(0.45, 0.95), -2)


func _build_correction() -> void:
	# CONSCIOUSNESS NOTICES — a narrow torn seam, white flame in straight
	# lines. Cold, thin, deliberate. Never a sun.
	_glow(Vector2(60, -600), COLD, 1100, 0.35, -5)
	var tear := Polygon2D.new()
	tear.polygon = PackedVector2Array([Vector2(-260, -540), Vector2(300, -540),
			Vector2(120, -512), Vector2(180, -496), Vector2(30, -474),
			Vector2(60, -502), Vector2(-120, -488), Vector2(-80, -516)])
	tear.color = Color(0.95, 0.99, 1.0, 0.9)
	var tmat := CanvasItemMaterial.new()
	tmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tear.material = tmat
	tear.z_index = -4
	add_child(tear)
	_glow(Vector2(20, -520), Color.WHITE, 420, 0.75, -4)
	# straight falling lines with bright heads — a few reach deep, almost
	# touching the bloom's air (the two forces closing on each other)
	for i in 12:
		var x := _rng.randf_range(-860.0, 860.0)
		var fall := _rng.randf_range(180.0, 460.0) if i % 4 != 0 \
				else _rng.randf_range(520.0, 700.0)
		var y0 := -540.0 + _rng.randf_range(0.0, 140.0)
		var w := _rng.randf_range(1.6, 3.4)
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(x - w, y0), Vector2(x + w, y0),
				Vector2(x + w * 0.5, y0 + fall), Vector2(x - w * 0.5, y0 + fall)])
		p.vertex_colors = PackedColorArray([
				Color(0.92, 0.97, 1.0, 0.9), Color(0.92, 0.97, 1.0, 0.9),
				Color(0.92, 0.97, 1.0, 0.0), Color(0.92, 0.97, 1.0, 0.0)])
		p.color = Color.WHITE
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
		p.z_index = -4
		add_child(p)
		_glow(Vector2(x, y0 + fall), COLD, _rng.randf_range(14.0, 30.0), 0.85, -4)


func _build_actors() -> void:
	# the cap she just BOUNCED — intact, under-lit, spores arcing off it
	var cap := _sprite(FUNGAL + "mushroomcap9.png", Vector2(-360, 330), 0.42, 2,
			Color(0.85, 0.6, 0.38), false, false, -7.0)
	cap.scale.y = 0.34   # mid-squash from the bounce
	_glow(Vector2(-360, 300), AMBER, 340, 0.8, 1)
	for i in 20:
		var a := _rng.randf_range(-PI * 0.85, -PI * 0.15)
		var r := _rng.randf_range(40.0, 200.0)
		_glow(Vector2(-360 + cos(a) * r * 1.2, 310 + sin(a) * r), AMBER,
				_rng.randf_range(4.0, 13.0), _rng.randf_range(0.55, 0.95), 3)
	# the NEXT cap, growing up to meet her — the teal one (it read well)
	_sprite(FUNGAL + "mushroomcap4.png", Vector2(410, -170), 0.4, 1,
			Color(0.42, 0.56, 0.56), true, false, 8.0)
	_glow(Vector2(410, -195), CYAN, 170, 0.35, 1)
	# CURIOSITY — mid-leap between the two lights, big enough to READ
	_sprite("res://assets/player/curiosity/jump/jump4.png",
			Vector2(-10, -105), 0.36, 6, Color(1.0, 0.95, 0.88), false, false, -7.0)
	_glow(Vector2(-10, -30), AMBER, 420, 0.5, 5)             # underlight
	_glow(Vector2(44, -62), Color(1.0, 0.8, 0.45), 170, 0.95, 7)   # lantern
	_sprite("res://assets/effects/lantern_halo.png", Vector2(44, -62), 0.6, 7,
			Color(1.0, 0.82, 0.5, 0.55))
	# THE REMEMBERED ONE — a consumed traveler: a hooded silhouette
	# standing INSIDE the light, reaching up as it dissolves
	_sprite("res://assets/player/curiosity/jump/jump2.png",
			Vector2(-520, 280), 0.4, 4, Color(0.05, 0.075, 0.075, 0.95),
			true, false, -18.0)
	_glow(Vector2(-527, 294), AMBER_DEEP, 70, 0.9, 4)        # buried joy
	for i in 14:   # edges unwriting into motes
		_glow(Vector2(-520 + _rng.randf_range(-64.0, 64.0),
				280 - absf(_rng.randfn(0.0, 80.0))), AMBER,
				_rng.randf_range(3.0, 9.0), 0.8, 4)


func _build_foreground() -> void:
	# near-black silhouettes anchoring the frame
	_sprite(FUNGAL + "fungalfrond2.png", Vector2(-700, 470), 0.5, 10,
			Color(0.008, 0.018, 0.016), false, false, -10.0)
	_sprite(FUNGAL + "fungalfrond10.png", Vector2(730, 490), 0.46, 10,
			Color(0.008, 0.018, 0.016), true, false, 12.0)
	_sprite(FUNGAL + "mushroomglow13.png", Vector2(660, 430), 0.5, 10,
			Color(0.01, 0.02, 0.018), false, false, -6.0)
	_sprite(FUNGAL + "stalagmite14.png", Vector2(-760, -420), 0.7, 10,
			Color(0.01, 0.02, 0.018), false, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
