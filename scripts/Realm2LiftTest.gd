extends Node2D
## R2-M1 — THE QUAKE + LIFTOFF, playable grey-box on the living background.
## Flat mossy ground → walk right onto the half-buried chunk → the storm
## builds (wind, shake, dark sky) → the ground TEARS → the chunk rises with
## Curiosity aboard → high above the canopy: sequence complete.
## Controls: Curiosity's own (move/jump/dash). R restarts. ESC quits.
## R2_SHOT env: screenshot at 1s + quit. R2_SHOT_LIFT: jump to mid-ascent first.

const BASE := "res://assets/realms/realm2_moss/"
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const STARTING_LIVES: int = 3  # same rules as Realm 1
const FLOOR_Y := 300.0
const CHUNK_X := 1500.0
const CHUNK_START_Y := 420.0
const LIFT_TOP_Y := -2400.0

enum Phase { INTRO, BUILD, RIDE, DONE }

var phase := Phase.INTRO
var _pt := 0.0            # time in current phase
var _t := 0.0
var _bg: Realm2Background
var _chunk: LevitatingIsland
var _chunk_glow: Sprite2D
var _curi: CharacterBody2D
var _cam: Camera2D
var _trauma := 0.0
var _lbl: Label
var _lives: LivesHUD
var _dying := false


func _ready() -> void:
	_bg = Realm2Background.new()
	_bg.include_chunk = false  # OUR chunk is a physics body, not decor
	add_child(_bg)
	_build_ground()
	_build_chunk()
	_build_player()
	_build_camera()
	_build_ui()
	if OS.get_environment("R2_SHOT") != "":
		_self_screenshot(OS.get_environment("R2_SHOT"))


func _build_ground() -> void:
	# collision floor
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12000, 120)
	col.shape = shape
	col.position = Vector2(400, FLOOR_Y + 60)
	body.add_child(col)
	# side walls so the only way forward is the chunk
	for wx in [-750.0, 2250.0]:
		var w := CollisionShape2D.new()
		var ws := RectangleShape2D.new()
		ws.size = Vector2(60, 1600)
		w.shape = ws
		w.position = Vector2(wx, FLOOR_Y - 700)
		body.add_child(w)
	add_child(body)

	# visual: dark earth + the mossy hedge band along the floor line
	var earth := Polygon2D.new()
	earth.polygon = PackedVector2Array([Vector2(-6000, FLOOR_Y + 6), Vector2(6400, FLOOR_Y + 6),
			Vector2(6400, FLOOR_Y + 1400), Vector2(-6000, FLOOR_Y + 1400)])
	earth.color = Color(7.0 / 255.0, 5.0 / 255.0, 16.0 / 255.0)  # near-black soil, not a purple band
	add_child(earth)
	var hedge := Sprite2D.new()
	hedge.texture = load(BASE + "band_ground.png")
	hedge.centered = false
	hedge.scale = Vector2(0.7, 0.7)
	hedge.position = Vector2(-1900, FLOOR_Y - 1080 * 0.7 + 26)
	add_child(hedge)
	var hedge2 := Sprite2D.new()
	hedge2.texture = load(BASE + "band_ground.png")
	hedge2.centered = false
	hedge2.scale = Vector2(0.7, 0.7)
	hedge2.position = Vector2(-1900 + 3840 * 0.7, FLOOR_Y - 1080 * 0.7 + 26)
	add_child(hedge2)

	# continuous moss MAT behind the hero — grass always under the feet,
	# no floating over visual dips (tileable, no seams)
	for i in 3:
		var mat := Sprite2D.new()
		mat.texture = load(BASE + "moss_mat.png")
		mat.centered = false
		mat.scale = Vector2(0.7, 0.7)
		mat.position = Vector2(-2200 + i * 3840 * 0.7, 210.0)
		add_child(mat)

	# FRONT moss row — dedicated tileable strip drawn OVER Curiosity
	# (organic tips to the waist; no crop slices, no seams)
	for i in 3:
		var front := Sprite2D.new()
		front.texture = load(BASE + "moss_front.png")
		front.centered = false
		front.scale = Vector2(0.7, 0.7)
		front.position = Vector2(-2200 + i * 3840 * 0.7, 236.0)
		front.modulate = Color(0.86, 0.84, 0.94)
		front.z_index = 12
		add_child(front)


func _build_chunk() -> void:
	# the chunk IS a LevitatingIsland — self-contained shake/debris/ascent/hover
	_chunk = LevitatingIsland.new()
	_chunk.position = Vector2(CHUNK_X, CHUNK_START_Y)
	_chunk.rise_height = CHUNK_START_Y - LIFT_TOP_Y
	_chunk.rise_duration = 24.0
	_chunk.sway_amplitude = 22.0
	_chunk.sway_period = 3.4
	_chunk.bob_amplitude = 8.0
	_chunk.shake_duration = 0.8
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1100, 32)  # match the wide island art, not just its center
	col.shape = shape
	col.position = Vector2(0, -114)  # top surface, under the grass fringe
	_chunk.add_child(col)
	add_child(_chunk)
	_chunk_glow = _bg.build_chunk_visuals(_chunk)
	_chunk.levitation_started.connect(func() -> void: _lbl.text = "")
	_chunk.arrived.connect(func() -> void: _set_phase(Phase.DONE))


func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = Vector2(150, FLOOR_Y - 120)
	# the world is authored at 1080-scale; shrink the hero to stand ~110px tall
	_curi.scale = Vector2(0.24, 0.24)
	add_child(_curi)

	# the SAME eye lifeline counter as Realm 1 — shared scene, same rules
	_lives = LIVES_HUD.instantiate() as LivesHUD
	add_child(_lives)
	_lives.reset(STARTING_LIVES)
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


func _build_camera() -> void:
	_cam = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := 1.12 * vp.y / 1080.0  # zoomed out: context around the island
	_cam.zoom = Vector2(z, z)
	_cam.position = Vector2(150, FLOOR_Y - 220)
	add_child(_cam)
	_cam.make_current()
	_chunk.camera_path = _chunk.get_path_to(_cam)  # island drives it once active


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var vr := ColorRect.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = SCREEN_UV - vec2(0.5);\n\tfloat d = length(uv * vec2(1.2, 1.35));\n\tCOLOR = vec4(0.02, 0.012, 0.055, smoothstep(0.45, 0.95, d) * 0.85);\n}"
	var m := ShaderMaterial.new()
	m.shader = sh
	vr.material = m
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(vr)
	_lbl = Label.new()
	_lbl.text = "R2-M1 LIFT TEST — walk right →   (R restart · ESC quit)"
	_lbl.position = Vector2(16, 12)
	_lbl.add_theme_color_override("font_color", Color(0.78, 0.73, 0.92, 0.6))
	cl.add_child(_lbl)


func _self_screenshot(path: String) -> void:
	if OS.get_environment("R2_SHOT_LIFT") != "":
		# jump straight to mid-ascent for the screenshot
		_set_phase(Phase.RIDE)
		_chunk.debug_jump(0.5)
		_curi.position = Vector2(CHUNK_X, _chunk.position.y - 150.0)
		_curi.velocity = Vector2.ZERO
		_bg.set_storm(0.75)
		_cam.position = Vector2(CHUNK_X, _chunk.position.y - 120.0)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


# Realm 1's death beat, verbatim rules: eye closes, respawn with full health;
# last eye → whole scene restarts.
func _die() -> void:
	if _dying:
		return
	_dying = true
	if _curi.has_method("hurt"):
		_curi.hurt()
	var remaining: int = _lives.lose_eye()
	await get_tree().create_timer(0.45).timeout
	if remaining <= 0:
		get_tree().reload_current_scene()
		return
	# respawn: on the island if it's flying, else back on solid ground
	if _chunk.state != LevitatingIsland.State.IDLE:
		_curi.global_position = _chunk.global_position + Vector2(0, -170)
	else:
		_curi.position = Vector2(clampf(_curi.position.x, -600.0, 2100.0), FLOOR_Y - 140.0)
	_curi.velocity = Vector2.ZERO
	if _curi.has_method("refill_health"):
		_curi.refill_health()
	_dying = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _set_phase(p: Phase) -> void:
	phase = p
	_pt = 0.0
	match p:
		Phase.BUILD:
			_lbl.text = "the wind is changing…"
		Phase.RIDE:
			_trauma = 1.0
		Phase.DONE:
			_lbl.text = "above the canopy — R2-M1 complete   (R restart · ESC quit)"


func _physics_process(delta: float) -> void:
	# AnimatableBody2D with sync_to_physics MUST be moved here, not _process.
	_pt += delta
	match phase:
		Phase.INTRO:
			# trigger: Curiosity steps onto the chunk region
			if _curi.global_position.x > CHUNK_X - 260.0:
				_set_phase(Phase.BUILD)
		Phase.BUILD:
			var k := clampf(_pt / 5.0, 0.0, 1.0)
			_bg.set_storm(k * 0.85)
			_trauma = maxf(_trauma, k * 0.55)
			if _pt >= 5.0:
				_chunk.start_levitation()  # island owns shake/debris/ascent now
				_set_phase(Phase.RIDE)
		Phase.RIDE:
			_bg.set_storm(0.8)
			_trauma = maxf(_trauma, 0.15)
			# fell off mid-ascent: same death beat as any other (eye closes, respawn).
			# _pt guard: never fire in the ride's first moments (spawn/settle race).
			if _pt > 1.0 and _curi.global_position.y > _chunk.global_position.y + 900.0:
				_die()
		Phase.DONE:
			_bg.set_storm(0.35)


func _process(delta: float) -> void:
	_t += delta
	_trauma = maxf(_trauma - delta * 0.8, 0.0)

	# chunk glow breathes
	if _chunk_glow:
		_chunk_glow.modulate.a = 0.82 + sin(_t * 1.1) * 0.1 + sin(_t * 1.7 + 1.3) * 0.06

	# camera: ours until the island wakes, then the island drives it
	if _chunk.state == LevitatingIsland.State.IDLE:
		var target := Vector2(
			clampf(_curi.global_position.x, -450.0, CHUNK_X + 250.0),
			clampf(_curi.global_position.y - 130.0, LIFT_TOP_Y - 200.0, FLOOR_Y - 220.0))
		_cam.position = _cam.position.lerp(target, 1.0 - pow(0.001, delta))
		var sh := _trauma * _trauma
		_cam.offset = Vector2(
			randf_range(-1.0, 1.0) * 16.0 * sh,
			randf_range(-1.0, 1.0) * 12.0 * sh)
		_cam.rotation = randf_range(-1.0, 1.0) * 0.012 * sh
