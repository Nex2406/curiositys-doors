extends Node2D
## Realm 2 background viewer — thin wrapper around Realm2Background.
## Auto-pan camera; A/D pan, W/S storm dial (test the wind!), ESC quit.
## R2_SHOT env var: self-screenshot after 1s, then quit.

var _t := 0.0
var _cam: Camera2D
var _bg: Realm2Background
var _manual := 0.0
var _storm_test := 0.0
var _lbl: Label


func _ready() -> void:
	_bg = Realm2Background.new()
	_bg.include_chunk = true
	add_child(_bg)

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
	_lbl.text = "REALM 2 BG TEST — auto-pan · A/D pan · W/S storm · ESC quit"
	_lbl.position = Vector2(16, 12)
	_lbl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.9, 0.55))
	cl.add_child(_lbl)

	_cam = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := vp.y / 1080.0
	_cam.zoom = Vector2(z, z)
	add_child(_cam)
	_cam.make_current()

	if OS.get_environment("R2_SHOT") != "":
		_self_screenshot(OS.get_environment("R2_SHOT"))


func _self_screenshot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.01:
		_manual = clampf(_manual + dir * 500.0 * delta, -900.0, 900.0)
		_cam.position.x = _manual
	else:
		_cam.position.x = lerpf(_cam.position.x, sin(_t * 0.1) * 820.0, delta * 0.5)
	# storm dial for testing: W up, S down
	var sd := 0.0
	if Input.is_key_pressed(KEY_W):
		sd = 1.0
	elif Input.is_key_pressed(KEY_S):
		sd = -1.0
	if sd != 0.0:
		_storm_test = clampf(_storm_test + sd * 0.5 * delta, 0.0, 1.0)
		_bg.set_storm(_storm_test)
		_lbl.text = "REALM 2 BG TEST — storm %.2f · A/D pan · ESC quit" % _storm_test
