extends Node2D
## R3 PROTOTYPE RIG — THE MAP WRITES ITSELF (Underhollow stage 1).
## The descent has no level: platforms ASSEMBLE from flying pebble-pieces
## just below Curiosity as they descend, and CRUMBLE away behind them.
## DRESSED LIKE THE SURFACE (Advika: "overcrowded, chaotic, every asset"):
## the shipped realm's full grammar — giant loud-hue caps + auras, spire
## clusters, glowers w/ bloom, wall fringe, cups, boulders, spores, the
## teal grade — all generated endlessly with depth.
##   Controls: Curiosity's own (walk/jump). R restart. ESC quit.
##   REARR_SHOT=<path> env: screenshot at 2.6s + quit (self-verify).
## Stage 2 (later): gravity loosens with depth; stage 3: Remembered Ones.
## NOT COMMITTED until Advika approves the feel.

const FUNGAL := "res://assets/realms/realm3_fungal/"
const SHAFT_HALF_W := 520.0
const STEP_Y_MIN := 150.0
const STEP_Y_MAX := 205.0
const PLAT_W_MIN := 200.0
const PLAT_W_MAX := 310.0
const FORM_AHEAD := 1000.0
const CRUMBLE_DELAY := 1.1
const FORM_TIME := 0.55
const CHUNK_IDS := [1, 2, 6, 8, 13, 16, 31]

# the shipped realm's palette (Realm3FungalTest.gd)
const FILL_DARK := Color(0.085, 0.145, 0.132)
const BG_TOP := Color(0.071, 0.169, 0.157)
const BG_BOTTOM := Color(0.039, 0.086, 0.078)
const SIL_FAR := Color(0.045, 0.085, 0.078)
const SIL_MID := Color(0.07, 0.125, 0.115)
const CAP_HUES: Array[Color] = [Color(0.16, 0.33, 0.31),
		Color(0.19, 0.30, 0.16), Color(0.14, 0.26, 0.36)]
const GLOW_WARM := Color(1.0, 0.85, 0.62)
const GLOW_COOL := Color(0.68, 0.95, 0.90)
const GLOW_MOSS := Color(0.62, 0.95, 0.58)
const FRINGE_LIT := Color(0.95, 1.0, 0.97)
const FRINGE_NEAR := Color(0.55, 0.68, 0.63)
const AMBIENT := Color(0.55, 0.72, 0.68)

var _curi: CharacterBody2D
var _cam: Camera2D
var _rng := RandomNumberGenerator.new()
var _platforms: Array = []
var _decor: Array = []               # [{node, y}] culled far above her
var _next_y := 260.0
var _wall_y := -500.0
var _bg_y := -400.0
var _last_x := 0.0
var _depth_label: Label
var _glow_tex: GradientTexture2D
var _spores: Array = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.09, 0.08))
	_rng.seed = 20260716
	_build_backdrop()
	_build_wall_bodies()
	_spawn_platform(0.0, 140.0, 360.0, false)
	_write_world_until(FORM_AHEAD)
	_build_player()
	_build_spores()
	_build_ui()
	var grade := CanvasModulate.new()
	grade.color = AMBIENT
	add_child(grade)
	if OS.get_environment("REARR_SHOT") != "":
		_self_shot(OS.get_environment("REARR_SHOT"))


# ---------- shared ----------

func _soft_glow() -> GradientTexture2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex


func _spr(tex_name: String, pos: Vector2, sc: float, z: int,
		tint := Color.WHITE, fh := false, fv := false, rot := 0.0,
		parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(FUNGAL + tex_name)
	s.position = pos
	s.scale = Vector2(sc, sc)
	s.z_index = z
	s.modulate = tint
	s.flip_h = fh
	s.flip_v = fv
	s.rotation_degrees = rot
	(parent if parent != null else self).add_child(s)
	if parent == null:
		_decor.append({"node": s, "y": pos.y})
	return s


func _bloom_at(pos: Vector2, col: Color, px: float, alpha: float, z: int,
		parent: Node = null) -> void:
	var g := Sprite2D.new()
	g.texture = _soft_glow()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	g.modulate = Color(col.r, col.g, col.b, alpha)
	g.scale = Vector2.ONE * (px / 128.0)
	g.position = pos
	g.z_index = z
	(parent if parent != null else self).add_child(g)
	if parent == null:
		_decor.append({"node": g, "y": pos.y})


func _build_backdrop() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([BG_TOP, BG_TOP.lerp(BG_BOTTOM, 0.5), BG_BOTTOM])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)


func _build_wall_bodies() -> void:
	for side: float in [-1.0, 1.0]:
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(400, 60000)
		cs.shape = rect
		cs.position = Vector2(side * (SHAFT_HALF_W + 200.0), 20000)
		body.add_child(cs)
		add_child(body)
		var fill := Polygon2D.new()
		var x0 := side * SHAFT_HALF_W
		var x1 := side * (SHAFT_HALF_W + 800.0)
		fill.polygon = PackedVector2Array([Vector2(x0, -900), Vector2(x1, -900),
				Vector2(x1, 60900), Vector2(x0, 60900)])
		fill.color = FILL_DARK
		fill.z_index = -6
		add_child(fill)


# ---------- the endless dressing (the surface grammar, vertical) ----------

func _write_world_until(y_to: float) -> void:
	while _next_y < y_to:
		_spawn_next_row()
	while _wall_y < y_to + 400.0:
		_write_wall_band(_wall_y)
		_wall_y += 130.0
	while _bg_y < y_to + 400.0:
		_write_bg_vignette(_bg_y)
		_bg_y += _rng.randf_range(210.0, 300.0)


func _write_wall_band(y: float) -> void:
	# DENSE growth crawling both wall faces + rims + life in the crevices
	for side: float in [-1.0, 1.0]:
		var x0 := side * SHAFT_HALF_W
		_spr(["fungalground20.png", "fungalground21.png"][_rng.randi() % 2],
				Vector2(x0, y), 0.45, -5, Color.WHITE, _rng.randf() < 0.5)
		# fringe bursts every band — overcrowded, like the surface fringe
		for k in 2:
			_spr("fungalfrond%d.png" % [2, 3, 4, 10, 11, 16][_rng.randi() % 6],
					Vector2(x0 - side * _rng.randf_range(14.0, 66.0),
					y + _rng.randf_range(-58.0, 58.0)),
					_rng.randf_range(0.2, 0.34), -4,
					(FRINGE_LIT if _rng.randf() < 0.5 else FRINGE_NEAR),
					side > 0, false, -side * 90.0 + _rng.randf_range(-16.0, 16.0))
		# life in the crevices, cycling the glow hues
		var roll := _rng.randf()
		if roll < 0.4:
			var gid: int = [17, 23, 24, 5, 12, 4][_rng.randi() % 6]
			var gx := x0 - side * _rng.randf_range(26.0, 60.0)
			var g := _spr("mushroomglow%d.png" % gid, Vector2(gx, y + 40.0),
					_rng.randf_range(0.2, 0.3), -3, Color.WHITE, side > 0)
			var hue: Color = [GLOW_WARM, GLOW_COOL, GLOW_MOSS][_rng.randi() % 3]
			_bloom_at(Vector2(0, -g.texture.get_height() * 0.28), hue, 300.0, 0.30, 0, g)
		elif roll < 0.6:
			_spr("fungalfrond%d.png" % (24 + _rng.randi() % 7),
					Vector2(x0 - side * _rng.randf_range(20.0, 50.0), y + 50.0),
					_rng.randf_range(0.14, 0.2), -3, Color.WHITE, side > 0)
		elif roll < 0.78:
			_spr("fungalstoneb%d.png" % [1, 4, 6, 7][_rng.randi() % 4],
					Vector2(x0 + side * _rng.randf_range(20.0, 90.0), y),
					_rng.randf_range(0.3, 0.42), -5,
					Color(0.72, 0.8, 0.76), _rng.randf() < 0.5)
		# hanging spires off the walls on a slower rhythm
		if _rng.randf() < 0.3:
			_spr("stalagmite%d.png" % (12 + _rng.randi() % 5),
					Vector2(x0 - side * _rng.randf_range(30.0, 90.0), y),
					_rng.randf_range(0.3, 0.5), -4,
					Color(0.66, 0.76, 0.72), _rng.randf() < 0.5,
					side < 0, -side * _rng.randf_range(60.0, 100.0))


func _write_bg_vignette(y: float) -> void:
	# the surface's composed-vignette move, stacked down the shaft:
	# rotating set-pieces, every 3rd a GIANT loud-hue cap w/ aura
	var motif := _rng.randi() % 4
	var x := _rng.randf_range(-SHAFT_HALF_W + 140.0, SHAFT_HALF_W - 140.0)
	match motif:
		0:   # giant cap wearing a LOUD hue + glow aura (the skyline move)
			var hue_i := _rng.randi() % 3
			var cap := _spr("mushroomcap%d.png" % [3, 6, 9, 10][_rng.randi() % 4],
					Vector2(x, y), _rng.randf_range(0.55, 0.95), -8,
					CAP_HUES[hue_i], _rng.randf() < 0.5)
			var aura: Color = [GLOW_COOL, GLOW_MOSS, Color(0.5, 0.7, 1.0)][hue_i]
			_bloom_at(Vector2(0, -cap.texture.get_height() * 0.2), aura,
					cap.texture.get_width() * 1.1, 0.16, -1, cap)
		1:   # spire grove grown together
			for k in 3:
				_spr("stalagmite%d.png" % (1 + _rng.randi() % 11),
						Vector2(x + (k - 1) * _rng.randf_range(60.0, 110.0),
						y + _rng.randf_range(-30.0, 30.0)),
						_rng.randf_range(0.4, 0.7), -9,
						SIL_FAR if k == 1 else SIL_MID,
						_rng.randf() < 0.5, false, _rng.randf_range(-6.0, 6.0))
		2:   # ghost glowers w/ alternating glints
			for k in 2:
				var gg := _spr("mushroomglow%d.png" % [17, 23, 24, 9][_rng.randi() % 4],
						Vector2(x + k * _rng.randf_range(70.0, 130.0), y + k * 40.0),
						_rng.randf_range(0.3, 0.5), -8, SIL_MID, _rng.randf() < 0.5)
				if k == 0:
					_bloom_at(Vector2(0, -gg.texture.get_height() * 0.25),
							GLOW_COOL if _rng.randf() < 0.5 else GLOW_MOSS,
							260.0, 0.22, -1, gg)
		3:   # cap family huddle (thin talls threading the gap)
			_spr("mushroomcap%d.png" % [4, 6][_rng.randi() % 2],
					Vector2(x, y), _rng.randf_range(0.4, 0.6), -8,
					SIL_MID, _rng.randf() < 0.5)
			for k in 2:
				_spr("mushroomglow%d.png" % [1, 2, 5, 7, 8][_rng.randi() % 5],
						Vector2(x + (k * 2 - 1) * _rng.randf_range(80.0, 140.0),
						y + _rng.randf_range(-20.0, 60.0)),
						_rng.randf_range(0.25, 0.4), -9, SIL_FAR,
						_rng.randf() < 0.5)


# ---------- the writing ----------

func _spawn_next_row() -> void:
	var x := clampf(_last_x + _rng.randf_range(-330.0, 330.0),
			-SHAFT_HALF_W + 190.0, SHAFT_HALF_W - 190.0)
	if absf(x - _last_x) < 120.0:
		x = clampf(_last_x + (330.0 if _rng.randf() < 0.5 else -330.0),
				-SHAFT_HALF_W + 190.0, SHAFT_HALF_W - 190.0)
	_spawn_platform(x, _next_y, _rng.randf_range(PLAT_W_MIN, PLAT_W_MAX), true)
	_last_x = x
	_next_y += _rng.randf_range(STEP_Y_MIN, STEP_Y_MAX)


func _spawn_platform(cx: float, cy: float, w: float, crumbles: bool) -> void:
	var plat := Node2D.new()
	plat.position = Vector2(cx, cy)
	add_child(plat)
	var half := w * 0.5
	var thick := 50.0
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([Vector2(-half + 8, 12),
			Vector2(half - 8, 12), Vector2(half - 16, thick), Vector2(-half + 16, thick)])
	fill.color = Color(FILL_DARK.r, FILL_DARK.g, FILL_DARK.b, 0.0)
	fill.z_index = 0
	plat.add_child(fill)
	# pieces: chunk pebbles along the lip — WHITE like the surface rims
	var pieces: Array = []
	var px := -half + 26.0
	while px < half - 10.0:
		var p := Sprite2D.new()
		p.texture = load(FUNGAL + "fungalground%d.png" % CHUNK_IDS[_rng.randi() % CHUNK_IDS.size()])
		p.scale = Vector2.ONE * _rng.randf_range(0.30, 0.42)
		p.z_index = 1
		p.flip_h = _rng.randf() < 0.5
		var slot := Vector2(px, _rng.randf_range(-2.0, 8.0))
		var a := _rng.randf_range(0.0, TAU)
		p.position = slot + Vector2(cos(a), sin(a)) * _rng.randf_range(260.0, 520.0)
		p.rotation_degrees = _rng.randf_range(-160.0, 160.0)
		p.modulate = Color(1, 1, 1, 0.0)
		plat.add_child(p)
		pieces.append({"node": p, "slot": slot})
		px += _rng.randf_range(36.0, 56.0)
	# LIFE assembles with the ground (Advika: overcrowded) — a mini-meadow:
	# fronds + a glower or cup or perched mini-caps, all growing in on form
	var growth: Array = []
	var gx := -half + 30.0
	while gx < half - 26.0:
		var fr := Sprite2D.new()
		fr.texture = load(FUNGAL + "fungalfrond%d.png" % [2, 3, 4, 10, 11, 16][_rng.randi() % 6])
		fr.scale = Vector2.ONE * 0.001
		fr.position = Vector2(gx, -6.0)
		fr.flip_h = _rng.randf() < 0.5
		fr.modulate = FRINGE_LIT.lerp(FRINGE_NEAR, _rng.randf_range(0.0, 0.6))
		fr.z_index = 2
		plat.add_child(fr)
		growth.append({"node": fr, "sc": _rng.randf_range(0.16, 0.26)})
		gx += _rng.randf_range(40.0, 74.0)
	var roll := _rng.randf()
	if roll < 0.45:
		var gid: int = [17, 23, 24, 5, 4, 12, 16, 20, 25][_rng.randi() % 9]
		var gm := Sprite2D.new()
		gm.texture = load(FUNGAL + "mushroomglow%d.png" % gid)
		gm.scale = Vector2.ONE * 0.001
		gm.position = Vector2(_rng.randf_range(-half * 0.5, half * 0.5), 2.0)
		gm.flip_h = _rng.randf() < 0.5
		gm.z_index = 3
		plat.add_child(gm)
		growth.append({"node": gm, "sc": _rng.randf_range(0.2, 0.3)})
		var hue: Color = [GLOW_WARM, GLOW_COOL, GLOW_MOSS][_rng.randi() % 3]
		_bloom_at(Vector2(gm.position.x, -26.0), hue, 320.0, 0.34, 3, plat)
	elif roll < 0.7:
		var cup := Sprite2D.new()
		cup.texture = load(FUNGAL + "fungalfrond%d.png" % (24 + _rng.randi() % 7))
		cup.scale = Vector2.ONE * 0.001
		cup.position = Vector2(_rng.randf_range(-half * 0.4, half * 0.4), 4.0)
		cup.flip_h = _rng.randf() < 0.5
		cup.z_index = 2
		plat.add_child(cup)
		growth.append({"node": cup, "sc": _rng.randf_range(0.13, 0.18)})
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w - 24.0, 20.0)
	cs.shape = rect
	cs.position = Vector2(0, 18)
	cs.disabled = true
	body.add_child(cs)
	plat.add_child(body)
	var sh := Sprite2D.new()
	sh.texture = _soft_glow()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sh.material = mat
	sh.modulate = Color(GLOW_WARM.r, GLOW_WARM.g, GLOW_WARM.b, 0.0)
	sh.scale = Vector2.ONE * (w * 1.4 / 128.0)
	sh.position = Vector2(0, 14)
	sh.z_index = -1
	plat.add_child(sh)
	var entry := {"node": plat, "fill": fill, "pieces": pieces, "body": cs,
			"growth": growth, "shimmer": sh, "y": cy, "crumbles": crumbles,
			"state": "forming", "stood": 0.0}
	_platforms.append(entry)
	_animate_form(entry)


func _animate_form(e: Dictionary) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	var i := 0
	for pc in e.pieces:
		var p: Sprite2D = pc.node
		var delay := 0.03 * i + _rng.randf_range(0.0, 0.08)
		tw.tween_property(p, "position", pc.slot, FORM_TIME)\
				.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation_degrees", _rng.randf_range(-14.0, 14.0),
				FORM_TIME).set_delay(delay).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(p, "modulate:a", 1.0, FORM_TIME * 0.6).set_delay(delay)
		i += 1
	tw.tween_property(e.fill, "color:a", 1.0, FORM_TIME * 0.9)\
			.set_delay(FORM_TIME * 0.4)
	tw.tween_property(e.shimmer, "modulate:a", 0.5, FORM_TIME * 0.5)
	tw.chain().tween_property(e.shimmer, "modulate:a", 0.0, 0.5)
	# the meadow grows in just after the ground exists
	var gi := 0
	for g in e.growth:
		tw.tween_property(g.node, "scale", Vector2.ONE * g.sc, 0.4)\
				.set_delay(FORM_TIME * 0.7 + 0.05 * gi)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		gi += 1
	get_tree().create_timer(FORM_TIME * 0.7).timeout.connect(func() -> void:
		if is_instance_valid(e.body):
			e.body.disabled = false
		e.state = "solid")


func _crumble(e: Dictionary) -> void:
	if e.state != "solid":
		return
	e.state = "crumbling"
	e.body.disabled = true
	var tw := create_tween()
	tw.set_parallel(true)
	for pc in e.pieces:
		var p: Sprite2D = pc.node
		var v := Vector2(_rng.randf_range(-140.0, 140.0), _rng.randf_range(60.0, 320.0))
		tw.tween_property(p, "position", p.position + v, 0.9)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "rotation_degrees",
				p.rotation_degrees + _rng.randf_range(-220.0, 220.0), 0.9)
		tw.tween_property(p, "modulate:a", 0.0, 0.9).set_delay(0.15)
	for g in e.growth:
		tw.tween_property(g.node, "scale", Vector2.ONE * 0.001, 0.3)
	tw.tween_property(e.fill, "color:a", 0.0, 0.5)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(e.node):
			e.node.queue_free()
		_platforms.erase(e))


func _process(delta: float) -> void:
	if _curi == null:
		return
	var cy := _curi.global_position.y
	_write_world_until(cy + FORM_AHEAD)
	for e in _platforms.duplicate():
		if not e.crumbles or e.state != "solid":
			continue
		var on_it: bool = _curi.is_on_floor() \
				and absf(_curi.global_position.y + 34.0 - e.y) < 46.0 \
				and absf(_curi.global_position.x - e.node.position.x) < 190.0
		if on_it:
			e.stood += delta
			e.node.position.x += sin(e.stood * 46.0) * minf(e.stood, 1.0) * 0.9
			if e.stood > CRUMBLE_DELAY:
				_crumble(e)
		if e.y < cy - 620.0:
			_crumble(e)
	# cull dressing far above — it un-writes too
	for d in _decor.duplicate():
		if d.y < cy - 1500.0:
			if is_instance_valid(d.node):
				d.node.queue_free()
			_decor.erase(d)
	# drifting spores wrap around the camera
	for sp in _spores:
		var n: Sprite2D = sp.node
		n.position += sp.vel * delta
		var rel := n.position - _cam.position
		if absf(rel.x) > 1050.0:
			n.position.x -= signf(rel.x) * 2100.0
		if absf(rel.y) > 640.0:
			n.position.y -= signf(rel.y) * 1280.0
	_cam.position = _cam.position.lerp(
			_curi.global_position + Vector2(0, -60), 8.0 * delta)
	_depth_label.text = "R3 REARRANGE RIG — the map writes itself\ndepth %dpx   (R restart · ESC quit)" \
			% int(maxf(0.0, _curi.global_position.y - 106.0))
	if cy > _next_y + 400.0:
		get_tree().reload_current_scene()


# ---------- player / air / ui / harness ----------

func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = Vector2(0, 40)
	_curi.scale = Vector2(0.24, 0.24)
	_curi.z_index = 5
	add_child(_curi)
	var hcam: Camera2D = _curi.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false
	_cam = Camera2D.new()
	_cam.position = _curi.position
	add_child(_cam)
	_cam.make_current()


func _build_spores() -> void:
	for i in 46:
		var s := Sprite2D.new()
		s.texture = _soft_glow()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = mat
		var hue: Color = [GLOW_WARM, GLOW_COOL, GLOW_MOSS][_rng.randi() % 3]
		s.modulate = Color(hue.r, hue.g, hue.b, _rng.randf_range(0.15, 0.5))
		s.scale = Vector2.ONE * (_rng.randf_range(4.0, 12.0) / 128.0)
		s.position = Vector2(_rng.randf_range(-1000.0, 1000.0),
				_rng.randf_range(-600.0, 600.0))
		s.z_index = 4
		add_child(s)
		_spores.append({"node": s,
				"vel": Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-22.0, -6.0))})


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	_depth_label = Label.new()
	_depth_label.position = Vector2(24, 18)
	_depth_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.82, 0.85))
	cl.add_child(_depth_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _self_shot(path: String) -> void:
	await get_tree().create_timer(2.6).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
