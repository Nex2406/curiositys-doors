extends Node2D
## ONE-FRAME CONCEPT MOCKS — Realm 3 acts (Descent / Underhollow / Heart).
## Companion to BloomMock.gd (Act 3 has its own). NOT gameplay, NOT
## committed until Advika approves. Env:
##   MOCK_ACT = descent | underhollow | heart
##   MOCK_SHOT = <png path>  -> screenshot + quit
## Built from the real fungal pack + hero art so the target stays honest.

const FUNGAL := "res://assets/realms/realm3_fungal/"
const HERO := "res://assets/player/curiosity/"
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
	RenderingServer.set_default_clear_color(Color(0.010, 0.020, 0.018))
	match OS.get_environment("MOCK_ACT"):
		"underhollow":
			_build_underhollow()
		"heart":
			_build_heart()
		_:
			_build_descent()
	if OS.get_environment("MOCK_SHOT") != "":
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(
				OS.get_environment("MOCK_SHOT"))
		get_tree().quit()


# ---------- shared ----------

func _glow(pos: Vector2, col: Color, px: float, alpha: float, z: int) -> void:
	if _glow_tex == null:
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


func _quad(pts: PackedVector2Array, cols: PackedColorArray, z: int,
		additive := false) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.vertex_colors = cols
	p.color = Color.WHITE
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
	p.z_index = z
	add_child(p)


func _fill(x0: float, x1: float, y0: float, y1: float, col: Color, z: int) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0),
			Vector2(x1, y1), Vector2(x0, y1)])
	p.color = col
	p.z_index = z
	add_child(p)


## a book: a small rounded-ish slab with a spine highlight — mock stand-in
## for real archive art (or stays code-built if Advika approves the read)
func _book(pos: Vector2, w: float, h: float, base: Color, z: int,
		rot := 0.0) -> void:
	var n := Node2D.new()
	n.position = pos
	n.rotation_degrees = rot
	n.z_index = z
	add_child(n)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-w / 2, -h / 2),
			Vector2(w / 2, -h / 2), Vector2(w / 2, h / 2), Vector2(-w / 2, h / 2)])
	body.color = base
	n.add_child(body)
	var spine := Polygon2D.new()
	spine.polygon = PackedVector2Array([Vector2(-w / 2, -h / 2),
			Vector2(-w / 2 + w * 0.18, -h / 2), Vector2(-w / 2 + w * 0.18, h / 2),
			Vector2(-w / 2, h / 2)])
	spine.color = Color(base.r * 1.8, base.g * 1.8, base.b * 1.7, base.a)
	n.add_child(spine)


## a pebble-rimmed shelf-island (the shipped rim-platform idiom, tilted)
func _shelf(cx: float, cy: float, half_w: float, thick: float, rot: float,
		z: int, with_books := true, fv := false) -> void:
	var n := Node2D.new()
	n.position = Vector2(cx, cy)
	n.rotation_degrees = rot
	n.z_index = z
	add_child(n)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-half_w, 0), Vector2(half_w, 0),
			Vector2(half_w, thick), Vector2(-half_w, thick)])
	body.color = MASS_FILL
	n.add_child(body)
	var x := -half_w
	while x < half_w:
		var peb := Sprite2D.new()
		peb.texture = load(FUNGAL + "fungalground22.png")
		peb.scale = Vector2(0.35, 0.35)
		peb.position = Vector2(x + 103.0, 4.0)
		peb.modulate = Color(0.4, 0.48, 0.46)
		n.add_child(peb)
		var peb2 := Sprite2D.new()
		peb2.texture = load(FUNGAL + "fungalground26.png")
		peb2.scale = Vector2(0.35, 0.35)
		peb2.position = Vector2(x + 103.0, thick - 4.0)
		peb2.modulate = Color(0.3, 0.37, 0.35)
		n.add_child(peb2)
		x += 182.0
	if with_books:
		var bx := -half_w + 40.0
		while bx < half_w - 40.0:
			var bh := _rng.randf_range(34.0, 62.0)
			var bw := _rng.randf_range(14.0, 26.0)
			var hue := _rng.randf_range(0.7, 1.3)
			var bcol := Color(0.05 * hue, 0.085 * hue, 0.08 * hue)
			var b := Polygon2D.new()
			var top := -bh if not fv else thick
			b.polygon = PackedVector2Array([Vector2(bx, top),
					Vector2(bx + bw, top), Vector2(bx + bw, top + bh),
					Vector2(bx, top + bh)])
			b.color = bcol
			n.add_child(b)
			bx += bw + _rng.randf_range(2.0, 14.0)
	# growth on the shelf lip
	var gx := -half_w + 30.0
	while gx < half_w - 20.0:
		var fr := Sprite2D.new()
		fr.texture = load(FUNGAL + "fungalfrond%d.png" % [2, 3, 16][_rng.randi() % 3])
		fr.scale = Vector2.ONE * _rng.randf_range(0.1, 0.16)
		fr.position = Vector2(gx, (-14.0) if not fv else (thick + 14.0))
		fr.flip_v = fv
		fr.modulate = Color(0.3, 0.42, 0.4)
		n.add_child(fr)
		gx += _rng.randf_range(90.0, 170.0)


## a traveler / Remembered One: hero silhouette, near-black, amber ember
func _remembered(pos: Vector2, sc: float, z: int, rot := 0.0,
		fh := false, ember := 0.85) -> void:
	_sprite(HERO + "jump/jump2.png", pos, sc, z,
			Color(0.045, 0.07, 0.068, 0.95), fh, false, rot)
	_glow(pos + Vector2(-7.0 * (1.0 if not fh else -1.0), 14.0) * (sc / 0.4),
			AMBER_DEEP, 170.0 * sc, ember, z)


func _curiosity(pos: Vector2, sc: float, z: int, rot := 0.0, fh := false) -> void:
	_sprite(HERO + "jump/jump4.png", pos, sc, z,
			Color(1.0, 0.95, 0.88), fh, false, rot)
	var side := -1.0 if fh else 1.0
	var lp := pos + Vector2(side * 150.0 * sc, 120.0 * sc)
	_glow(lp, Color(1.0, 0.8, 0.45), 480.0 * sc, 0.95, z + 1)
	_sprite("res://assets/effects/lantern_halo.png", lp, 1.7 * sc, z + 1,
			Color(1.0, 0.82, 0.5, 0.55))
	_glow(pos, AMBER, 1100.0 * sc, 0.35, z - 1)


# ---------- ACT 1: THE DESCENT ----------

func _build_descent() -> void:
	# tight vertical throat, lantern the only warmth, cold hole far above
	_quad(PackedVector2Array([Vector2(-960, -540), Vector2(960, -540),
			Vector2(960, 540), Vector2(-960, 540)]),
			PackedColorArray([Color(0.03, 0.055, 0.06), Color(0.03, 0.055, 0.06),
			Color(0.008, 0.016, 0.014), Color(0.008, 0.016, 0.014)]), -20)
	_glow(Vector2(140, -620), COLD, 900, 0.22, -19)   # the hole, far above
	# walls pinch inward — big masses with rims + roots
	for side: float in [-1.0, 1.0]:
		var top_x := side * 780.0
		var bot_x := side * 430.0
		_quad(PackedVector2Array([Vector2(top_x, -560), Vector2(side * 1000.0, -560),
				Vector2(side * 1000.0, 560), Vector2(bot_x, 560)]),
				PackedColorArray([MASS_FILL, MASS_FILL, MASS_FILL, MASS_FILL]), -8)
		for i in 5:
			var t := i / 4.0
			var x := lerpf(top_x, bot_x, t)
			var y := lerpf(-460.0, 480.0, t)
			_sprite(FUNGAL + ["fungalground20.png", "fungalground21.png"][i % 2],
					Vector2(x, y), 0.4, -7, Color(0.26, 0.33, 0.31),
					_rng.randf() < 0.5, false, side * lerpf(-8.0, -22.0, t))
			_sprite(FUNGAL + "fungalfrond%d.png" % [2, 10, 16, 3][i % 4],
					Vector2(x - side * 30.0, y + 60.0),
					_rng.randf_range(0.14, 0.22), -6,
					Color(0.12, 0.2, 0.185), side > 0, false, -side * 90.0)
	# buried shelves in the walls — pebble frames w/ book rows, half sunk
	_shelf(-560, -180, 200, 60, 14, -5)
	_shelf(590, 60, 230, 64, -11, -5)
	_shelf(-470, 250, 170, 56, 8, -5)
	# hanging roots/stalactites off ledges
	_sprite(FUNGAL + "stalagmite12.png", Vector2(-260, -420), 0.5, -4,
			Color(0.05, 0.09, 0.085), false, true, -6.0)
	_sprite(FUNGAL + "stalagmite15.png", Vector2(360, -300), 0.45, -4,
			Color(0.045, 0.08, 0.075), true, true, 8.0)
	# TRAVELERS half-swallowed in the walls, ember-lit by the passing lantern
	_remembered(Vector2(-620, 10), 0.36, -4, 12.0, false, 0.7)
	_remembered(Vector2(620, 330), 0.4, -4, -20.0, true, 0.9)
	_remembered(Vector2(-430, 470), 0.3, -4, 28.0, false, 0.5)
	# a ledge she stands on, mid-frame
	_shelf(60, 190, 190, 60, -4, 2, false)
	_curiosity(Vector2(20, 120), 0.3, 6, 0.0, false)
	# spores in the lantern pool only
	for i in 40:
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(30.0, 330.0)
		_glow(Vector2(20 + cos(a) * r * 1.2, 130 + sin(a) * r), AMBER,
				_rng.randf_range(3.0, 9.0), _rng.randf_range(0.2, 0.6) * (1.0 - r / 400.0), 5)
	# the dark below — swallowing
	_quad(PackedVector2Array([Vector2(-960, 380), Vector2(960, 380),
			Vector2(960, 540), Vector2(-960, 540)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0),
			Color(0.004, 0.008, 0.007, 0.95), Color(0.004, 0.008, 0.007, 0.95)]), 8)
	# foreground fronds
	_sprite(FUNGAL + "fungalfrond10.png", Vector2(-820, 500), 0.5, 10,
			Color(0.006, 0.014, 0.012), false, false, -14.0)
	_sprite(FUNGAL + "fungalfrond2.png", Vector2(850, -480), 0.45, 10,
			Color(0.006, 0.014, 0.012), true, true, 10.0)


# ---------- ACT 1.5: THE UNDERHOLLOW ----------

func _build_underhollow() -> void:
	# open weightless void: the ruined archive drifting. Down means nothing.
	_quad(PackedVector2Array([Vector2(-960, -540), Vector2(960, -540),
			Vector2(960, 540), Vector2(-960, 540)]),
			PackedColorArray([Color(0.014, 0.03, 0.034), Color(0.02, 0.04, 0.045),
			Color(0.012, 0.026, 0.028), Color(0.008, 0.018, 0.02)]), -20)
	# far drifting shelf silhouettes, every which way
	_shelf(-620, -350, 260, 60, 24, -14, true)
	_shelf(560, -390, 200, 56, -37, -14, true)
	_shelf(760, 210, 240, 60, 12, -14, true, true)
	_shelf(-780, 260, 190, 54, -18, -14, true)
	for s in [[-300.0, -460.0, 0.5], [140.0, 480.0, 0.6], [880.0, -120.0, 0.45]]:
		_sprite(FUNGAL + "fungalstoneb%d.png" % [2, 8, 9][_rng.randi() % 3],
				Vector2(s[0], s[1]), s[2] * 0.5, -13,
				Color(0.045, 0.075, 0.072), _rng.randf() < 0.5, false,
				_rng.randf_range(-60.0, 60.0))
	# mid shelf-islands — the platforms, tilted, one fully upside down
	# (its growth hangs UP: the gravity-flip tell)
	_shelf(-360, -60, 280, 70, 9, 0, true)
	_shelf(430, -220, 220, 64, -14, 0, true)
	_shelf(300, 300, 260, 68, 186, 0, true, true)   # flipped island
	# loose books drifting everywhere, all rotations
	for i in 34:
		var pos := Vector2(_rng.randf_range(-900.0, 900.0),
				_rng.randf_range(-500.0, 500.0))
		var hue := _rng.randf_range(0.7, 1.5)
		_book(pos, _rng.randf_range(16.0, 34.0), _rng.randf_range(26.0, 52.0),
				Color(0.055 * hue, 0.09 * hue, 0.085 * hue),
				-2 if _rng.randf() < 0.7 else 3, _rng.randf_range(0.0, 360.0))
	# torn pages like slow snow, faintly lit
	for i in 60:
		var pos := Vector2(_rng.randf_range(-940.0, 940.0),
				_rng.randf_range(-520.0, 520.0))
		var pg := Polygon2D.new()
		var w := _rng.randf_range(5.0, 12.0)
		var h := w * _rng.randf_range(1.1, 1.5)
		pg.polygon = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h),
				Vector2(w, h), Vector2(-w, h)])
		var v := _rng.randf_range(0.14, 0.34)
		pg.color = Color(v * 0.9, v, v * 0.96, 0.85)
		pg.position = pos
		pg.rotation_degrees = _rng.randf_range(0.0, 360.0)
		pg.z_index = -1 if _rng.randf() < 0.6 else 4
		add_child(pg)
	# ink-dark tendrils of the old Hollow reaching between islands
	_sprite(FUNGAL + "fungalfrond22.png", Vector2(-120, -380), 0.5, -3,
			Color(0.03, 0.05, 0.05), false, true, 40.0)
	_sprite(FUNGAL + "fungalfrond23.png", Vector2(-640, 420), 0.55, -3,
			Color(0.03, 0.05, 0.05), true, false, -30.0)
	# CURIOSITY mid-drift — tilted, weightless, cloak logic gone sideways
	_curiosity(Vector2(-60, -140), 0.34, 6, -24.0, false)
	# REMEMBERED ONES drifting in from the dark, reaching
	_remembered(Vector2(360, 40), 0.42, 5, -156.0, true)       # upside-ish
	_remembered(Vector2(-540, -300), 0.36, 5, 38.0, false)
	_remembered(Vector2(660, 420), 0.3, -1, 80.0, true, 0.6)
	# amber ledger-motes; a few cyan/moss glints
	for i in 50:
		var hue: Color = [AMBER, AMBER, MOSS, CYAN][_rng.randi() % 4]
		_glow(Vector2(_rng.randf_range(-940.0, 940.0),
				_rng.randf_range(-520.0, 520.0)), hue,
				_rng.randf_range(4.0, 14.0), _rng.randf_range(0.25, 0.7), -1)
	# vignette corners
	for c in [[-960.0, -540.0], [960.0, -540.0], [-960.0, 540.0], [960.0, 540.0]]:
		_quad(PackedVector2Array([Vector2(c[0], c[1]),
				Vector2(c[0] * 0.4, c[1]), Vector2(c[0], c[1] * 0.4)]),
				PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0),
				Color(0, 0, 0, 0)]), 12)


# ---------- ACT 2: THE HEART ----------

func _build_heart() -> void:
	# vast chamber; the Heart of the Hollow fills the right half — scale
	# contrast is the whole shot. Amber veins pulse under its skin.
	_quad(PackedVector2Array([Vector2(-960, -540), Vector2(960, -540),
			Vector2(960, 540), Vector2(-960, 540)]),
			PackedColorArray([Color(0.012, 0.024, 0.026), Color(0.02, 0.036, 0.038),
			Color(0.01, 0.02, 0.02), Color(0.014, 0.028, 0.026)]), -20)
	# floor: a dark meadow line swallowed by the chamber's dark
	_fill(-960, 960, 330, 560, Color(0.016, 0.03, 0.027), -10)
	var fx := -940.0
	while fx < 940.0:
		_sprite(FUNGAL + "fungalfrond%d.png" % [2, 3, 10, 16][_rng.randi() % 4],
				Vector2(fx, 330.0), _rng.randf_range(0.12, 0.2), -9,
				Color(0.08, 0.14, 0.13), _rng.randf() < 0.5)
		fx += _rng.randf_range(70.0, 130.0)
	# THE HEART — a mountain of fused boulders + caps, breathing amber
	var heart := Node2D.new()
	heart.position = Vector2(430, 40)
	heart.z_index = -6
	add_child(heart)
	for b in [[0.0, 260.0, "fungalstoneb10.png", 0.95, 0.0],
			[-260.0, 160.0, "fungalstoneb6.png", 0.8, -10.0],
			[240.0, 130.0, "fungalstoneb1.png", 0.9, 8.0],
			[-90.0, -60.0, "fungalstoneb11.png", 0.85, 4.0],
			[190.0, -180.0, "fungalstoneb4.png", 0.75, -6.0],
			[-230.0, -230.0, "fungalstoneb7.png", 0.7, 12.0]]:
		var sp := Sprite2D.new()
		sp.texture = load(FUNGAL + (b[2] as String))
		sp.position = Vector2(b[0], b[1])
		sp.scale = Vector2.ONE * (b[3] as float)
		sp.rotation_degrees = b[4]
		sp.modulate = Color(0.16, 0.2, 0.2)
		heart.add_child(sp)
	# the crown: a vast cap silhouette leaning over it
	_sprite(FUNGAL + "mushroomcap3.png", Vector2(470, -330), 1.3, -5,
			Color(0.09, 0.13, 0.13), false, false, -4.0)
	# amber VEINS crawling the mass — light under skin (glow chains)
	var veins := [[-320.0, 120.0, 260.0, -40.0], [-180.0, 300.0, 120.0, 80.0],
			[60.0, 380.0, 320.0, 60.0], [420.0, 340.0, 560.0, -100.0],
			[220.0, -40.0, 360.0, -260.0]]
	for v in veins:
		var steps := 9
		for i in steps:
			var t := i / float(steps - 1)
			var pos := Vector2(430 + lerpf(v[0], v[2], t),
					40 + lerpf(v[1], v[3], t) + sin(t * PI * 2.2) * 24.0)
			_glow(pos, AMBER_DEEP, _rng.randf_range(14.0, 30.0),
					0.5 + 0.3 * sin(t * PI), -4)
	_glow(Vector2(470, 120), AMBER_DEEP, 700, 0.3, -4)       # the deep pulse
	_glow(Vector2(470, 120), AMBER, 300, 0.4, -4)
	# ONE eye-seam, barely open — a thin amber slit high on the mass
	_quad(PackedVector2Array([Vector2(300, -128), Vector2(560, -142),
			Vector2(560, -130), Vector2(300, -120)]),
			PackedColorArray([Color(1, 0.8, 0.5, 0.0), Color(1, 0.85, 0.55, 0.9),
			Color(1, 0.85, 0.55, 0.9), Color(1, 0.8, 0.5, 0.0)]), -4, true)
	_glow(Vector2(480, -134), AMBER, 200, 0.6, -4)
	# roots binding the Heart into the chamber
	for r in [[-380.0, 380.0, 30.0], [-100.0, 430.0, -20.0], [700.0, 400.0, 14.0]]:
		_sprite(FUNGAL + "fungalfrond22.png", Vector2(r[0] + 430.0, r[1]),
				0.6, -5, Color(0.04, 0.065, 0.06), _rng.randf() < 0.5, false, r[2])
	# CURIOSITY — tiny, before it, lantern out. The scale IS the beat.
	_curiosity(Vector2(-560, 262), 0.26, 6, 0.0, false)
	# hush-motes drifting off the Heart
	for i in 30:
		_glow(Vector2(_rng.randf_range(-100.0, 940.0),
				_rng.randf_range(-380.0, 320.0)), AMBER,
				_rng.randf_range(3.0, 10.0), _rng.randf_range(0.15, 0.5), -3)
	# foreground silhouettes framing left
	_sprite(FUNGAL + "stalagmite5.png", Vector2(-900, 240), 0.85, 10,
			Color(0.006, 0.014, 0.012))
	_sprite(FUNGAL + "fungalfrond2.png", Vector2(-780, 520), 0.5, 10,
			Color(0.006, 0.014, 0.012), false, false, -10.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
