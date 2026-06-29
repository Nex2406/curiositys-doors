extends Node2D

# Headless diagnostic: stationary Curiosity placed inside the golem's detection range so
# it auto-fires without input. Logs each ball's launch + burst so we can see whether it
# actually reaches her (HIT) or falls short / long (FLOOR/TIMEOUT). Run:
#   godot --headless res://tools/DebugGolemHit.tscn
# Quits itself after RUN_SECONDS.

const GOLEM := preload("res://scenes/Golem.tscn")
const CURIOSITY := preload("res://scenes/Curiosity.tscn")
const BALL := preload("res://scenes/GolemBall.tscn")

const FLOOR_Y := 320.0
const RUN_SECONDS := 5.0

var _t := 0.0
var _hero: Node2D = null

func _ready() -> void:
	# Floor.
	var ground := StaticBody2D.new()
	ground.position = Vector2(0, FLOOR_Y)
	var gshape := CollisionShape2D.new()
	var grect := RectangleShape2D.new()
	grect.size = Vector2(4000, 120)
	gshape.shape = grect
	gshape.position = Vector2(0, 60)
	ground.add_child(gshape)
	add_child(ground)

	# Stationary Curiosity, in range to the golem's left.
	_hero = CURIOSITY.instantiate()
	_hero.scale = Vector2(0.28, 0.28)
	_hero.position = Vector2(120, FLOOR_Y - 120)
	add_child(_hero)
	var hcam: Camera2D = _hero.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false
	_hero.health_changed.connect(func(h: int, m: int) -> void:
		print("[HERO hp] ", h, "/", m, "  pos=", _hero.global_position))

	# Golem with verbose ball logging. Huge detect range so she stays engaged the whole run.
	var golem: Node2D = GOLEM.instantiate()
	golem.ball_scene = BALL
	golem.debug_balls = true
	golem.position = Vector2(420, FLOOR_Y - 130)  # default detect_range (480) — realistic
	add_child(golem)

	# Drive Curiosity to WALK toward the golem (normal approach, stays engaged).
	Input.action_press("move_right")

	print("[SETUP] hero=", _hero.position, " golem=", golem.position,
		" dist=", absf(golem.position.x - _hero.position.x), " (hero walking left)")


func _process(delta: float) -> void:
	_t += delta
	if _t >= RUN_SECONDS:
		print("[DONE] final hero hp pos=", _hero.global_position)
		get_tree().quit()
