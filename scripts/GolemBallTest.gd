extends Node2D

# Isolation harness for GolemBall. Spawns a ball on the left aimed at a dummy
# "player" body on the right; the ball pops (launch) -> flies with its trail
# behind it -> bursts on the dummy (hit) -> frees itself, then respawns on a loop.
# Boots straight into this scene — not wired to any golem yet.

const GOLEM_BALL := preload("res://scenes/GolemBall.tscn")

const SPAWN_POS := Vector2(0, 0)
const TARGET_POS := Vector2(620, 0)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.07, 0.10))

	var cam := Camera2D.new()
	cam.position = Vector2(300, -20)
	cam.zoom = Vector2(1.4, 1.4)
	add_child(cam)
	cam.make_current()

	# Dummy target: a static body in the "player" group so the ball's hitbox
	# bursts on contact (stands in for Curiosity).
	var target := StaticBody2D.new()
	target.name = "DummyTarget"
	target.add_to_group("player")
	target.position = TARGET_POS
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 220)
	cs.shape = rect
	target.add_child(cs)
	add_child(target)

	# A faint marker so the target is visible.
	var marker := Polygon2D.new()
	marker.color = Color(0.4, 0.5, 0.6, 0.35)
	marker.polygon = PackedVector2Array([Vector2(-30, -110), Vector2(30, -110), Vector2(30, 110), Vector2(-30, 110)])
	target.add_child(marker)

	var label := Label.new()
	label.text = "GolemBall isolation test — launch → fly → hit → free (loops)"
	label.position = Vector2(-260, -180)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	add_child(label)

	_spawn_ball()


func _spawn_ball() -> void:
	var ball: Area2D = GOLEM_BALL.instantiate()
	add_child(ball)
	ball.setup(SPAWN_POS, $DummyTarget)
	ball.tree_exited.connect(_on_ball_gone)


func _on_ball_gone() -> void:
	# Pause a beat, then send another so the cycle is easy to watch.
	await get_tree().create_timer(0.8).timeout
	if is_inside_tree():
		_spawn_ball()
