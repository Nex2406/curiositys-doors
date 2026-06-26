extends Area2D
class_name GolemBall

# A golem's projectile: a charged ball that rises in place (launch), then flies
# straight toward a captured target (fly), and bursts on contact with Curiosity or
# after a safety timeout (hit). This is a hitbox Area2D, NOT a physics body — the
# trail and sparkles are purely visual; only the small circle at the ball's centre
# actually hits. Direction is captured once at launch-finished so it flies straight
# (homing can be added later).

signal hit_player(body: Node2D)

@export var speed: float = 330.0
@export var damage: int = 1
@export var max_lifetime: float = 3.0   # safety despawn while flying (seconds)

enum State { LAUNCH, FLY, HIT }

@onready var _visual: AnimatedSprite2D = $Visual

var _state: int = State.LAUNCH
var _direction: Vector2 = Vector2.RIGHT
var _fly_time: float = 0.0
var _target: Node2D = null


func _ready() -> void:
	_visual.animation_finished.connect(_on_anim_finished)
	body_entered.connect(_on_body_entered)
	_enter_launch()


# Public: place the ball and remember who it's aimed at. The flight direction is
# computed from this target when the launch animation finishes.
func setup(spawn_pos: Vector2, target: Node2D) -> void:
	global_position = spawn_pos
	_target = target


func _enter_launch() -> void:
	_state = State.LAUNCH
	_visual.play(&"launch")


func _enter_fly() -> void:
	_state = State.FLY
	_fly_time = 0.0
	if _target != null and is_instance_valid(_target):
		_direction = (_target.global_position - global_position).normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT
	# Trail art points left with the ball leading right; flip when flying left so
	# the trail always streams behind the ball.
	_visual.flip_h = _direction.x < 0.0
	_visual.play(&"fly")


func _enter_hit(body: Node2D) -> void:
	if _state == State.HIT:
		return
	_state = State.HIT
	# Damage hook — fires on the first frame of the burst.
	print("GolemBall hit Curiosity for ", damage)
	hit_player.emit(body)
	_visual.play(&"hit")


func _physics_process(delta: float) -> void:
	if _state != State.FLY:
		return
	position += _direction * speed * delta
	_fly_time += delta
	if _fly_time >= max_lifetime:
		_enter_hit(null)


func _on_anim_finished() -> void:
	match _state:
		State.LAUNCH:
			_enter_fly()
		State.HIT:
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _state != State.FLY:
		return
	if body.is_in_group("player") or body.name == "Curiosity":
		_enter_hit(body)
