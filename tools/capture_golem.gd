extends Node2D

# Diagnostic: drive a dummy "player" toward the golem and snap a strip of frames so
# we can SEE patrol -> alert -> arc -> hit instead of guessing. Headless-friendly.

const GOLEM := preload("res://scenes/Golem.tscn")
const BALL := preload("res://scenes/GolemBall.tscn")
const FLOOR_Y := 320.0
const GOLEM_X := 200.0

var _golem: Node2D = null
var _dummy: CharacterBody2D = null
var _label: Label = null
var _shot: int = 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.07, 0.10))

	# Floor.
	var ground := StaticBody2D.new()
	ground.position = Vector2(0, FLOOR_Y)
	var gshape := CollisionShape2D.new()
	var grect := RectangleShape2D.new()
	grect.size = Vector2(4000, 120)
	gshape.shape = grect
	gshape.position = Vector2(0, 60)
	ground.add_child(gshape)
	var gvis := Polygon2D.new()
	gvis.color = Color(0.12, 0.13, 0.17)
	gvis.polygon = PackedVector2Array([Vector2(-2000, 0), Vector2(2000, 0), Vector2(2000, 120), Vector2(-2000, 120)])
	ground.add_child(gvis)
	add_child(ground)

	# Dummy stand-in for Curiosity: in group "player" so the golem detects it; a
	# visible block so we can see where it is; a body so the ball can hit it.
	var dummy := CharacterBody2D.new()
	dummy.add_to_group("player")
	dummy.position = Vector2(-460, FLOOR_Y - 60)
	var dshape := CollisionShape2D.new()
	var drect := RectangleShape2D.new()
	drect.size = Vector2(50, 120)
	dshape.shape = drect
	dummy.add_child(dshape)
	var dvis := Polygon2D.new()
	dvis.color = Color(0.9, 0.4, 0.5)
	dvis.polygon = PackedVector2Array([Vector2(-25, -60), Vector2(25, -60), Vector2(25, 60), Vector2(-25, 60)])
	dummy.add_child(dvis)
	add_child(dummy)
	_dummy = dummy

	# Golem.
	var golem: Node2D = GOLEM.instantiate()
	golem.ball_scene = BALL
	golem.position = Vector2(GOLEM_X, FLOOR_Y - 130)
	add_child(golem)
	_golem = golem

	var cam := Camera2D.new()
	cam.position = Vector2(-40, FLOOR_Y - 160)
	cam.zoom = Vector2(0.62, 0.62)
	add_child(cam)
	cam.make_current()

	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_label.position = Vector2(-560, FLOOR_Y - 420)
	add_child(_label)

	_run()


func _physics_process(_delta: float) -> void:
	# Walk the dummy in until it's within ~250px of the golem, then hold.
	if _dummy == null:
		return
	var gap := GOLEM_X - _dummy.global_position.x
	if gap > 250.0:
		_dummy.global_position.x += 130.0 * _physics_step()
	if _golem != null and is_instance_valid(_golem) and _label != null:
		_label.text = "golem: %s   gap=%d" % [_golem.debug_state(), int(gap)]


func _physics_step() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


func _run() -> void:
	# Snap a frame every 0.35s for ~7s — catches patrol, alert, the arc, and hits.
	for i in 20:
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://tools/shots/golem_%02d.png" % _shot)
		print("shot %02d  state=%s  dummy_x=%.0f" % [_shot, _golem.debug_state(), _dummy.global_position.x])
		_shot += 1
	print("GOLEM_CAPTURE_DONE")
	get_tree().quit()
