extends Node2D
## REALM 3 — FUNGAL ENVIRONMENT SHELL (Advika's spec, 2026-07-14).
## Environment ONLY: no enemies, no puzzle logic, no dialogue. A composed
## test area Curiosity can walk through — spawn ledge, jump-feasible
## platforms, a rock column, a hollow ring she passes through.
## Built from the Fungal pack (assets/realms/realm3_fungal/, sliced by
## tools/prep_fungal_pack.py — sheets downscaled to <=2048 for web).
## Layers back to front: near-black blue-purple gradient backdrop ->
## HillsFungal mounds on two parallax bands -> terrain sprites with
## bitmap-traced CollisionPolygon2Ds -> stalagmite/mushroom/frond dressing
## (glow mushrooms carry soft teal PointLight2Ds, <=12 total) -> Curiosity.
## CanvasModulate pulls it all toward the deep blue-purple palette; her
## lantern stays the one warm thing.
## Controls: Curiosity's own. R restarts. ESC returns to the Hub.
## R3_SHOT env: screenshot at 1s + quit. R3_SHOT_X: park the hero first.

const BASE := "res://assets/realms/realm3_fungal/"
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const HUB_SCENE := "res://scenes/Hub.tscn"
const STARTING_LIVES: int = 3

const FLOOR_Y := 420.0          # the base ground line
const SPAWN := Vector2(-40.0, FLOOR_Y - 140.0)
const AMBIENT := Color(0.62, 0.58, 0.82)  # the grade: deep blue-purple
const GLOW_TEAL := Color(0.45, 0.95, 0.85)
const MAX_GLOW_LIGHTS := 12

var _curi: CharacterBody2D
var _cam: Camera2D
var _lives: LivesHUD
var _lbl: Label
var _dying := false
var _leaving := false
var _glow_lights := 0
var _hills_far: Node2D
var _hills_mid: Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.015, 0.012, 0.04))
	_build_backdrop()
	_build_hills()
	_build_terrain()
	_build_dressing()
	_build_player()
	_build_camera()
	_build_ui()
	var grade := CanvasModulate.new()
	grade.color = AMBIENT
	add_child(grade)
	if OS.get_environment("R3_SHOT") != "":
		_self_screenshot(OS.get_environment("R3_SHOT"))


# ---------- layers ----------

func _build_backdrop() -> void:
	# screen-anchored vertical gradient: near-black up top, a breath of deep
	# blue-purple low — the cavern's own darkness (Hub Sky manners)
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.012, 0.010, 0.035), Color(0.055, 0.05, 0.115), Color(0.09, 0.085, 0.16)])
	grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)


func _build_hills() -> void:
	# HillsFungal mounds as midground silhouettes on two hand-driven parallax
	# bands (far crawls, mid drifts — Realm2Background's approach)
	_hills_far = Node2D.new()
	_hills_far.z_index = -8
	add_child(_hills_far)
	_hills_mid = Node2D.new()
	_hills_mid.z_index = -6
	add_child(_hills_mid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260714
	var hx := -900.0
	while hx < 3600.0:
		var h := Sprite2D.new()
		h.texture = load(BASE + "fungalhill%d.png" % (1 + rng.randi() % 5))
		var hs := rng.randf_range(0.55, 0.85)
		h.scale = Vector2(hs, hs)
		h.flip_h = rng.randf() < 0.5
		h.position = Vector2(hx, FLOOR_Y - 20.0 - h.texture.get_height() * hs * 0.28)
		h.modulate = Color(0.20, 0.19, 0.30)   # far: darkest silhouette
		_hills_far.add_child(h)
		hx += rng.randf_range(520.0, 780.0)
	hx = -700.0
	while hx < 3600.0:
		var h := Sprite2D.new()
		h.texture = load(BASE + "fungalhill%d.png" % (1 + rng.randi() % 5))
		var hs := rng.randf_range(0.7, 1.0)
		h.scale = Vector2(hs, hs)
		h.flip_h = rng.randf() < 0.5
		h.position = Vector2(hx, FLOOR_Y + 10.0 - h.texture.get_height() * hs * 0.22)
		h.modulate = Color(0.33, 0.31, 0.46)   # mid: a shade lighter
		_hills_mid.add_child(h)
		hx += rng.randf_range(640.0, 920.0)


# One rock: sprite + StaticBody2D + CollisionPolygon2D traced from its own
# alpha (coarse — epsilon keeps it 8-14ish points). mask: 0 = whole
# silhouette, 1 = bottom arc only, 2 = top arc only (the hollow ring uses
# arcs so Curiosity walks THROUGH its mouth, sides passing behind her).
func _add_rock(pos: Vector2, tex_name: String, sc: float, mask_mode := 0,
		z := 0) -> void:
	var tex: Texture2D = load(BASE + tex_name)
	var body := StaticBody2D.new()
	body.position = pos
	add_child(body)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(sc, sc)
	spr.z_index = z
	body.add_child(spr)
	var img := tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.35)
	if mask_mode == 1:
		bm.set_bit_rect(Rect2i(0, 0, w, int(h * 0.62)), false)
	elif mask_mode == 2:
		bm.set_bit_rect(Rect2i(0, int(h * 0.38), w, h - int(h * 0.38)), false)
	var polys := bm.opaque_to_polygons(Rect2i(0, 0, w, h), 26.0)
	# keep the LARGEST polygon — coarse hull of the visible rock
	var best: PackedVector2Array = PackedVector2Array()
	var best_area := 0.0
	for p in polys:
		var area := 0.0
		for i in p.size():
			var q := p[(i + 1) % p.size()]
			area += p[i].x * q.y - q.x * p[i].y
		area = absf(area) * 0.5
		if area > best_area:
			best_area = area
			best = p
	if best.size() >= 3:
		var scaled := PackedVector2Array()
		for pt in best:
			scaled.append((pt - Vector2(w, h) * 0.5) * sc)
		var cp := CollisionPolygon2D.new()
		cp.polygon = scaled
		body.add_child(cp)


func _build_terrain() -> void:
	# the base floor: an invisible strip under the whole walk, dressed with
	# rock clusters so the line reads as cavern ground
	var floor_body := StaticBody2D.new()
	var fcol := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(4400.0, 80.0)
	fcol.shape = frect
	fcol.position = Vector2(1250.0, FLOOR_Y + 40.0)
	floor_body.add_child(fcol)
	add_child(floor_body)
	# ground dressing: long rock strips shoulder to shoulder along the line
	for g in [[-350.0, "fungalstone28.png", 0.72], [280.0, "fungalstone3.png", 0.7],
			[900.0, "fungalstone10.png", 0.72], [1520.0, "fungalstone28.png", 0.72],
			[2150.0, "fungalstone3.png", 0.7], [2780.0, "fungalstone10.png", 0.72],
			[3320.0, "fungalstone28.png", 0.6]]:
		var s := Sprite2D.new()
		s.texture = load(BASE + (g[1] as String))
		s.scale = Vector2(g[2], g[2])
		s.position = Vector2(g[0], FLOOR_Y + 42.0)
		s.z_index = 1
		add_child(s)

	# SPAWN LEDGE: the wide rock-rimmed platform frame, flat and safe
	_add_rock(Vector2(0.0, FLOOR_Y - 160.0), "fungalground14.png", 0.8)
	# THE CLIMB: three clusters at rising heights, jump-feasible gaps
	# (apex ~138px, air reach ~300px at her -356/460 physics — R1's limits)
	_add_rock(Vector2(640.0, FLOOR_Y - 120.0), "fungalstone19.png", 0.55)
	_add_rock(Vector2(1040.0, FLOOR_Y - 210.0), "fungalstone18.png", 0.5)
	_add_rock(Vector2(1440.0, FLOOR_Y - 130.0), "fungalstone20.png", 0.5)
	# THE COLUMN: vertical rock tower — walk past it, or top it from the climb
	_add_rock(Vector2(1900.0, FLOOR_Y - 290.0), "fungalstone17.png", 0.8)
	# THE RING: hollow rock mouth, big enough to walk through — only its
	# bottom arc is floor and its top arc is ceiling; the sides pass behind
	_add_rock(Vector2(2500.0, FLOOR_Y - 240.0), "fungalground15.png", 2.2, 1)
	_add_rock(Vector2(2500.0, FLOOR_Y - 240.0), "fungalground15.png", 2.2, 2)


func _build_dressing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260715
	# stalagmites along the floor line, leaning clusters (never flip_v)
	for p in [[-550.0, 3, 0.5], [420.0, 7, 0.42], [1230.0, 11, 0.55],
			[1700.0, 5, 0.38], [2900.0, 9, 0.5], [3250.0, 2, 0.44]]:
		var st := Sprite2D.new()
		st.texture = load(BASE + "stalagmite%d.png" % p[1])
		st.scale = Vector2(p[2], p[2])
		st.flip_h = rng.randf() < 0.5
		st.position = Vector2(p[0], FLOOR_Y + 6.0 - st.texture.get_height() * p[2] * 0.5)
		st.z_index = 2
		add_child(st)
	# glow mushrooms near the platform edges — each carries one soft teal
	# light (cheap ambience; hard cap below)
	for m in [[-260.0, FLOOR_Y - 250.0, 3, 0.5], [220.0, FLOOR_Y - 250.0, 7, 0.42],
			[560.0, FLOOR_Y - 195.0, 12, 0.45], [1120.0, FLOOR_Y - 300.0, 3, 0.4],
			[1360.0, FLOOR_Y - 195.0, 18, 0.42], [1975.0, FLOOR_Y - 15.0, 7, 0.5],
			[2500.0, FLOOR_Y - 30.0, 12, 0.5], [3050.0, FLOOR_Y - 20.0, 3, 0.48],
			[790.0, FLOOR_Y - 15.0, 22, 0.45]]:
		var mu := Sprite2D.new()
		mu.texture = load(BASE + "mushroomglow%d.png" % m[2])
		mu.scale = Vector2(m[3], m[3])
		mu.position = Vector2(m[0], m[1] - mu.texture.get_height() * m[3] * 0.42)
		mu.z_index = 3
		add_child(mu)
		if _glow_lights < MAX_GLOW_LIGHTS:
			_glow_lights += 1
			var l := PointLight2D.new()
			l.texture = _soft_glow_texture()
			l.color = GLOW_TEAL
			l.energy = 0.4
			l.texture_scale = 1.3
			mu.add_child(l)
	# big blue caps + amber spore stalks, sparse
	for c in [[-620.0, 1, 0.55], [1700.0, 4, 0.42], [2260.0, 8, 0.6], [3400.0, 4, 0.55]]:
		var cap := Sprite2D.new()
		cap.texture = load(BASE + "mushroomcap%d.png" % c[1])
		cap.scale = Vector2(c[2], c[2])
		cap.flip_h = rng.randf() < 0.5
		cap.position = Vector2(c[0], FLOOR_Y + 4.0 - cap.texture.get_height() * c[2] * 0.5)
		cap.z_index = 2
		add_child(cap)
	# fronds in the corners and against the platforms
	for f in [[-700.0, 2, 0.5], [-120.0, 9, 0.45], [500.0, 15, 0.5], [960.0, 22, 0.45],
			[1620.0, 5, 0.5], [2080.0, 12, 0.45], [2720.0, 27, 0.5], [3180.0, 18, 0.45]]:
		var fr := Sprite2D.new()
		fr.texture = load(BASE + "fungalfrond%d.png" % f[1])
		fr.scale = Vector2(f[2], f[2])
		fr.flip_h = rng.randf() < 0.5
		fr.position = Vector2(f[0], FLOOR_Y + 8.0 - fr.texture.get_height() * f[2] * 0.5)
		fr.z_index = 1
		fr.modulate = Color(0.8, 0.78, 0.9)
		add_child(fr)


var _glow_tex: GradientTexture2D = null
func _soft_glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
		_glow_tex.width = 256
		_glow_tex.height = 256
	return _glow_tex


func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = SPAWN
	_curi.scale = Vector2(0.24, 0.24)   # the realm scale (Realm 2's convention)
	add_child(_curi)
	_lives = LIVES_HUD.instantiate() as LivesHUD
	_lives.eye_scale = 0.22
	_lives.eye_spacing = 112.0
	add_child(_lives)
	_lives.reset(STARTING_LIVES)
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


func _build_camera() -> void:
	_cam = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := 0.9 * vp.y / 1080.0
	_cam.zoom = Vector2(z, z)
	_cam.position = SPAWN + Vector2(0, -80)
	add_child(_cam)
	_cam.make_current()
	var hcam: Camera2D = _curi.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	_lbl = Label.new()
	_lbl.text = "R3 FUNGAL SHELL — walk right →   (R restart · ESC hub)"
	_lbl.position = Vector2(16, 12)
	_lbl.add_theme_color_override("font_color", Color(0.73, 0.78, 0.92, 0.6))
	cl.add_child(_lbl)


# ---------- running ----------

func _process(delta: float) -> void:
	# hand-driven parallax: far crawls, mid drifts (Realm 2's manners)
	if _cam != null:
		_hills_far.position.x = _cam.global_position.x * 0.82
		_hills_mid.position.x = _cam.global_position.x * 0.6
		# camera: follow X always, ease; hold a gentle floor-line framing
		var target := Vector2(clampf(_curi.global_position.x, -300.0, 3300.0),
				clampf(_curi.global_position.y - 110.0, -400.0, FLOOR_Y - 190.0))
		_cam.position = _cam.position.lerp(target, 1.0 - pow(0.001, delta))
	# fell somewhere impossible (no pits in the shell, but belt + suspenders)
	if not _dying and _curi.global_position.y > FLOOR_Y + 700.0:
		_die()


func _die() -> void:
	if _dying or _leaving:
		return
	_dying = true
	if _curi.has_method("hurt"):
		_curi.hurt()
	var remaining: int = _lives.lose_eye()
	await get_tree().create_timer(0.45).timeout
	if remaining <= 0:
		get_tree().reload_current_scene()
		return
	_curi.global_position = SPAWN
	_curi.velocity = Vector2.ZERO
	if _curi.has_method("refill_health"):
		_curi.refill_health()
	if _curi.has_method("grant_invuln"):
		_curi.grant_invuln(1.6)
	_dying = false


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_leaving = true
		Transition.transition_to(HUB_SCENE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _self_screenshot(path: String) -> void:
	if OS.get_environment("R3_SHOT_X") != "":
		_curi.position = Vector2(float(OS.get_environment("R3_SHOT_X")), FLOOR_Y - 160.0)
		_curi.velocity = Vector2.ZERO
		_cam.position = Vector2(_curi.position.x, FLOOR_Y - 190.0)
	await get_tree().create_timer(1.0).timeout
	print("SHOT curi=", _curi.global_position)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
