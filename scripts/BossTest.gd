extends Node2D

## THE VILLAIN, ON ITS OWN — nothing else in the scene.
##
## Advika: isolate it. So this is a bare stage: a flat floor, a dead-neutral
## backdrop, Curiosity standing beside it for scale, and the creature. No
## meadow, no parallax, no fog, no clock, nothing to argue with it.
##
## It is assembled from `mushroomcap9` — the flat-cap she picked — and NOTHING
## is redrawn. The layered brim is a HOOD, the black band beneath it is the
## shadow inside that hood, and the pale lit stem sitting in that shadow is a
## FACE. Red eyes go in the shadow.
##
## Every part is its own node, so a fight can move them independently later:
## layers, not frames. The layers already exist.
##
## LIVE DIALS (this rig exists to be argued with):
##   [ ]   body scale            , .   eye spacing
##   - =   eye height            ; '   eye size
##   S     shoulders on/off      H     hood shadow on/off
##   B     backdrop black / grey / realm teal
##   P     print every value so the numbers can be baked in
##   R     reload

const BASE := "res://assets/realms/realm3_fungal/"
const CAP := "mushroomcap9.png"
const HALO := "res://assets/effects/lantern_halo.png"
const EYE_RED := Color(1.0, 0.22, 0.18)

const FLOOR_Y := 640.0

# --- the dials ---
var body_scale := 1.35
var eye_spacing := 0.085      # as a fraction of body width
var eye_height := 0.58        # as a fraction of body height, up from the base
var eye_size := 0.13
var shoulders := true
var hood := true
var backdrop := 0

var _root: Node2D
var _lbl: Label
var _bg: ColorRect
var _curi: Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.06))
	_bg = ColorRect.new()
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	cl.add_child(_bg)

	var cam := Camera2D.new()
	cam.position = Vector2(0.0, 210.0)
	cam.zoom = Vector2(0.82, 0.82)   # room to breathe around it
	add_child(cam)
	cam.make_current()

	_build_floor()
	_build_scale_reference()
	_rebuild()

	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	_lbl = Label.new()
	_lbl.position = Vector2(16, 12)
	_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.86, 0.75))
	ui.add_child(_lbl)
	_apply_backdrop()
	_refresh_label()

	if OS.get_environment("BOSS_SHOT") != "":
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(
				OS.get_environment("BOSS_SHOT"))
		get_tree().quit()


## a plain dark slab — just enough for it to be standing ON something
func _build_floor() -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
			Vector2(-4000.0, FLOOR_Y), Vector2(4000.0, FLOOR_Y),
			Vector2(4000.0, FLOOR_Y + 600.0), Vector2(-4000.0, FLOOR_Y + 600.0)])
	p.color = Color(0.055, 0.085, 0.08)
	p.z_index = 10
	add_child(p)
	# something for her to actually stand on — without it she falls out of
	# frame and the scale reference is useless
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8000.0, 600.0)
	cs.shape = rect
	cs.position = Vector2(0.0, FLOOR_Y + 300.0)
	body.add_child(cs)
	add_child(body)


## she stands beside it so the size is a fact, not a guess
func _build_scale_reference() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.scale = Vector2(0.24, 0.24)
	_curi.position = Vector2(-620.0, FLOOR_Y - 60.0)
	_curi.z_index = 11
	add_child(_curi)


func _rebuild() -> void:
	if _root != null:
		_root.queue_free()
	_root = Node2D.new()
	_root.name = "Villain"
	add_child(_root)

	var tex: Texture2D = load(BASE + CAP)
	var w := tex.get_width() * body_scale
	var h := tex.get_height() * body_scale
	var base_y := FLOOR_Y

	if shoulders:
		for sgn in [-1.0, 1.0]:
			var sh := Sprite2D.new()
			sh.name = "Shoulder%s" % ("L" if sgn < 0.0 else "R")
			sh.texture = tex
			sh.scale = Vector2(0.82, 0.82)
			sh.flip_h = sgn > 0.0
			sh.modulate = Color(0.42, 0.52, 0.52)
			sh.position = Vector2(sgn * w * 0.40,
					base_y - tex.get_height() * 0.82 * 0.5 + 30.0)
			sh.z_index = 2
			_root.add_child(sh)

	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = tex
	body.scale = Vector2(body_scale, body_scale)
	body.position = Vector2(0.0, base_y - h * 0.5)
	body.z_index = 3
	_root.add_child(body)

	if hood:
		# a soft radial, NEVER a polygon — a hard-edged quad reads as a grey
		# box pasted over the face (the first mock looked exactly like that)
		var shade := Sprite2D.new()
		shade.name = "HoodShadow"
		shade.texture = load(HALO)
		shade.modulate = Color(0.0, 0.0, 0.0, 0.72)
		shade.scale = Vector2(w * 0.0016, h * 0.0011)
		shade.position = Vector2(0.0, base_y - h * 0.60)
		shade.z_index = 4
		_root.add_child(shade)

	var eye_y := base_y - h * eye_height
	for sgn2 in [-1.0, 1.0]:
		var e := Sprite2D.new()
		e.name = "Eye%s" % ("L" if sgn2 < 0.0 else "R")
		e.texture = load(HALO)
		e.scale = Vector2(eye_size, eye_size)
		e.position = Vector2(sgn2 * w * eye_spacing, eye_y)
		e.modulate = EYE_RED
		e.z_index = 5
		_root.add_child(e)
	var lamp := PointLight2D.new()
	lamp.name = "EyeGlow"
	lamp.texture = load(HALO)
	lamp.texture_scale = 1.5
	lamp.color = EYE_RED
	lamp.energy = 1.25
	lamp.position = Vector2(0.0, eye_y)
	_root.add_child(lamp)


func _apply_backdrop() -> void:
	_bg.color = [Color(0.03, 0.035, 0.035), Color(0.16, 0.17, 0.17),
			Color(0.071, 0.169, 0.157)][backdrop]


func _refresh_label() -> void:
	var tex: Texture2D = load(BASE + CAP)
	_lbl.text = "THE VILLAIN — isolated.  [ ] scale %.2f (%.0fpx tall, %.1fx her)   , . eye spacing %.3f   - = eye height %.2f   ; ' eye size %.3f\nS shoulders %s   H hood %s   B backdrop   P print   R reload" % [
			body_scale, tex.get_height() * body_scale,
			tex.get_height() * body_scale / 130.0,
			eye_spacing, eye_height, eye_size,
			"on" if shoulders else "OFF", "on" if hood else "OFF"]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	var k: int = (e as InputEventKey).keycode
	match k:
		KEY_BRACKETLEFT: body_scale = maxf(0.3, body_scale - 0.05)
		KEY_BRACKETRIGHT: body_scale += 0.05
		KEY_COMMA: eye_spacing = maxf(0.0, eye_spacing - 0.005)
		KEY_PERIOD: eye_spacing += 0.005
		KEY_MINUS: eye_height = maxf(0.0, eye_height - 0.01)
		KEY_EQUAL: eye_height += 0.01
		KEY_SEMICOLON: eye_size = maxf(0.01, eye_size - 0.005)
		KEY_APOSTROPHE: eye_size += 0.005
		KEY_S: shoulders = not shoulders
		KEY_H: hood = not hood
		KEY_B:
			backdrop = (backdrop + 1) % 3
			_apply_backdrop()
		KEY_P:
			print("body_scale=%.3f eye_spacing=%.4f eye_height=%.3f eye_size=%.4f shoulders=%s hood=%s" % [
					body_scale, eye_spacing, eye_height, eye_size, shoulders, hood])
			return
		KEY_R:
			get_tree().reload_current_scene()
			return
		_:
			return
	_rebuild()
	_refresh_label()
