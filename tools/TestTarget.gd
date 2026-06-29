extends CharacterBody2D

# Scriptable stand-in for Curiosity used by the golem system tests: sits in the "player"
# group, moves at a fixed velocity (so leading can be tested with exact, repeatable
# motion), exposes take_damage() and counts hits. Collision is a circle roughly matching
# Curiosity's body so the ball's body_entered fires like it does in game.

var move_vel: Vector2 = Vector2.ZERO
var hits: int = 0
# Faithful to Curiosity's real body: RectangleShape2D 88x432 under a 0.28 scale ≈ 25x121.
var body_size: Vector2 = Vector2(88.0 * 0.28, 432.0 * 0.28)

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = body_size
	cs.shape = r
	add_child(cs)

func _physics_process(_delta: float) -> void:
	velocity = move_vel
	move_and_slide()

func take_damage(_amount: int, _kb: Vector2 = Vector2.ZERO) -> void:
	hits += 1
