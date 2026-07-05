extends Node2D
## R2-M1 — THE QUAKE + LIFTOFF, playable grey-box on the living background.
## Flat mossy ground → walk right onto the half-buried chunk → the storm
## builds (wind, shake, dark sky) → the ground TEARS → the chunk rises with
## Curiosity aboard → high above the canopy: sequence complete.
## Controls: Curiosity's own (move/jump/dash). R restarts. ESC quits.
## R2_SHOT env: screenshot at 1s + quit. R2_SHOT_LIFT: jump to mid-ascent first.

const BASE := "res://assets/realms/realm2_moss/"
const FLOOR_Y := 300.0
const CHUNK_X := 1500.0
const CHUNK_START_Y := 420.0
const LIFT_TOP_Y := -2400.0

enum Phase { INTRO, BUILD, TEAR, LIFT, DONE }

var phase := Phase.INTRO
var _pt := 0.0            # time in current phase
var _t := 0.0
var _bg: Realm2Background
var _chunk: AnimatableBody2D
var _chunk_glow: Sprite2D
var _curi: CharacterBody2D
var _cam: Camera2D
var _trauma := 0.0
var _lbl: Label
var _debris: CPUParticles2D


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

	# FRONT moss row — drawn OVER Curiosity, but ONLY the bottom finger strip
	# of the band (region crop), tuned so tips reach the hero's waist at most.
	for i in 3:
		var front := Sprite2D.new()
		front.texture = load(BASE + "band_ground.png")
		front.centered = false
		front.region_enabled = true
		front.region_rect = Rect2(0, 810, 3840, 270)
		front.scale = Vector2(0.7, 0.7)
		front.position = Vector2(-2200 + i * 3840 * 0.7, FLOOR_Y - 56.0)
		front.modulate = Color(0.82, 0.8, 0.9)
		front.z_index = 12
		add_child(front)


func _build_chunk() -> void:
	_chunk = AnimatableBody2D.new()
	_chunk.sync_to_physics = true
	_chunk.position = Vector2(CHUNK_X, CHUNK_START_Y)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(600, 32)
	col.shape = shape
	col.position = Vector2(0, -114)  # top surface, under the grass fringe
	_chunk.add_child(col)
	add_child(_chunk)
	_chunk_glow = _bg.build_chunk_visuals(_chunk)

	_debris = CPUParticles2D.new()
	_debris.texture = load(BASE + "spore.png")
	_debris.emitting = false
	_debris.one_shot = true
	_debris.explosiveness = 0.9
	_debris.amount = 60
	_debris.lifetime = 1.6
	_debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_debris.emission_rect_extents = Vector2(330, 20)
	_debris.direction = Vector2(0, 1)
	_debris.spread = 40.0
	_debris.gravity = Vector2(0, 700)
	_debris.initial_velocity_min = 60.0
	_debris.initial_velocity_max = 240.0
	_debris.scale_amount_min = 1.0
	_debris.scale_amount_max = 2.6
	_debris.modulate = Color(0.45, 0.38, 0.62)
	_debris.position = Vector2(0, 40)
	_chunk.add_child(_debris)


func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = Vector2(150, FLOOR_Y - 120)
	# the world is authored at 1080-scale; shrink the hero to stand ~110px tall
	_curi.scale = Vector2(0.24, 0.24)
	add_child(_curi)


func _build_camera() -> void:
	_cam = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := 1.55 * vp.y / 1080.0
	_cam.zoom = Vector2(z, z)
	_cam.position = Vector2(150, FLOOR_Y - 220)
	add_child(_cam)
	_cam.make_current()


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
		_set_phase(Phase.LIFT)
		_pt = 6.0
		_chunk.position.y = CHUNK_START_Y - 1400.0
		_curi.position = Vector2(CHUNK_X, _chunk.position.y - 150.0)
		_curi.velocity = Vector2.ZERO
		_bg.set_storm(0.75)
		_cam.position = Vector2(CHUNK_X, _chunk.position.y - 120.0)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


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
		Phase.TEAR:
			_lbl.text = ""
			_trauma = 1.0
			_debris.emitting = true
		Phase.LIFT:
			_lbl.text = ""
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
			# the ground itself judders as the storm grips it
			_chunk.position.x = CHUNK_X + sin(_pt * 31.0) * 2.4 * k
			if _pt >= 5.0:
				_set_phase(Phase.TEAR)
		Phase.TEAR:
			_trauma = 1.0
			_bg.set_storm(1.0)
			# three violent jerks upward before it breaks free
			_chunk.position.y = CHUNK_START_Y - absf(sin(_pt * 12.0)) * 26.0
			if _pt >= 1.3:
				_set_phase(Phase.LIFT)
		Phase.LIFT:
			_bg.set_storm(0.75)
			_trauma = maxf(_trauma, 0.18)
			# ease-in ascent: slow tear-away, accelerating climb
			var v := minf(30.0 + _pt * 26.0, 380.0)
			_chunk.position.y -= v * delta
			_chunk.position.x = CHUNK_X + sin(_t * 1.3) * 6.0
			if _chunk.position.y <= LIFT_TOP_Y:
				_set_phase(Phase.DONE)
		Phase.DONE:
			_bg.set_storm(0.35)
			_chunk.position.y = LIFT_TOP_Y + sin(_t * 0.5) * 10.0


func _process(delta: float) -> void:
	_t += delta
	_trauma = maxf(_trauma - delta * 0.8, 0.0)

	# chunk glow breathes
	if _chunk_glow:
		_chunk_glow.modulate.a = 0.82 + sin(_t * 1.1) * 0.1 + sin(_t * 1.7 + 1.3) * 0.06

	# camera: follow Curiosity, shake by trauma
	var target := Vector2(
		clampf(_curi.global_position.x, -450.0, CHUNK_X + 250.0),
		clampf(_curi.global_position.y - 130.0, LIFT_TOP_Y - 200.0, FLOOR_Y - 220.0))
	_cam.position = _cam.position.lerp(target, 1.0 - pow(0.001, delta))
	var sh := _trauma * _trauma
	_cam.offset = Vector2(
		randf_range(-1.0, 1.0) * 16.0 * sh,
		randf_range(-1.0, 1.0) * 12.0 * sh)
	_cam.rotation = randf_range(-1.0, 1.0) * 0.012 * sh
