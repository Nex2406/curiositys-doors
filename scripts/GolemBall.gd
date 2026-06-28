extends Area2D
class_name GolemBall

# A golem's projectile: a ball lobbed in a true gravity parabola toward a captured
# target (fly), bouncing off the floor if it lands short, and bursting on contact with
# Curiosity or once it rolls out (hit). It leaves the golem's hand already arcing — the
# "launch" charge frames play while it travels, so there's no hang at the head. This is
# a hitbox Area2D, not a physics body — we integrate the arc ourselves so we can solve
# the exact launch velocity that lands on the target.
#
# Lobbed-projectile solve: pick a fixed flight time T, then back out the launch
# velocity that puts the ball on the target at t = T. Gravity does the rest, so it
# rises, peaks, and falls in a smooth parabola. Longer T / lower gravity = a higher,
# gentler, floatier lob.

signal hit_player(body: Node2D)

@export var flight_time: float = 1.25      # T — longer = higher, gentler lob
@export var lob_gravity: float = 900.0     # downward accel applied each frame
                                           # (Area2D already has a `gravity` field)
@export var damage: int = 1
@export var max_lifetime: float = 4.0      # safety despawn while flying (seconds)
@export var rotate_to_velocity: bool = true

# Floor bounce: instead of bursting the instant it lands, the ball ricochets off the
# ground and keeps traveling, losing a little energy each hop until it rolls out.
@export var bounce_restitution: float = 0.55  # vertical speed kept per floor bounce
@export var bounce_friction: float = 0.84     # horizontal speed kept per bounce
@export var max_bounces: int = 3              # bursts after this many floor bounces
@export var min_bounce_speed: float = 140.0   # slower downward hit than this → burst, don't bounce

enum State { LAUNCH, FLY, HIT }

@onready var _visual: AnimatedSprite2D = $Visual

var _state: int = State.LAUNCH
var _velocity: Vector2 = Vector2.ZERO
var _fly_time: float = 0.0
var _floor_y: float = INF   # global y the ball bounces on / bursts on at the ground
var _target: Node2D = null
var _bounces: int = 0


func _ready() -> void:
	_visual.animation_finished.connect(_on_anim_finished)
	body_entered.connect(_on_body_entered)
	_enter_fly()


# Public: place the ball at the launch point and remember who it's aimed at.
# `floor_y` (global) is the ground height the ball bursts on if it misses.
func setup(spawn_pos: Vector2, target: Node2D, floor_y: float = INF) -> void:
	global_position = spawn_pos
	_target = target
	_floor_y = floor_y


# The ball leaves the golem's hand already arcing: it solves its trajectory and starts
# moving on the very first frame with the rolling "fly" sprite — no stationary charge-up
# hang and no choppy charge frames spinning through the air.
func _enter_fly() -> void:
	_state = State.FLY
	_fly_time = 0.0
	_bounces = 0
	_velocity = _solve_lob()
	_visual.play(&"fly")


# Back out the launch velocity for a parabola that lands on the target at t = T.
#   vx = to.x / T
#   vy = (to.y - 0.5 * g * T^2) / T   (the upward kick that gravity cancels by T)
func _solve_lob() -> Vector2:
	if _target == null or not is_instance_valid(_target):
		return Vector2(200.0, -350.0)   # fall back to a generic forward lob
	var to: Vector2 = _target.global_position - global_position
	var t: float = maxf(flight_time, 0.05)
	var vx: float = to.x / t
	var vy: float = (to.y - 0.5 * lob_gravity * t * t) / t
	return Vector2(vx, vy)


func _enter_hit(body: Node2D) -> void:
	if _state == State.HIT:
		return
	_state = State.HIT
	_visual.rotation = 0.0   # burst sprite reads upright, not tilted to the arc
	# Damage hook — fires on the first frame of the burst.
	print("GolemBall hit for ", damage)
	hit_player.emit(body)
	_visual.play(&"hit")


func _physics_process(delta: float) -> void:
	if _state != State.FLY:
		return
	_velocity.y += lob_gravity * delta
	global_position += _velocity * delta
	if rotate_to_velocity:
		_visual.rotation = _velocity.angle()
	_fly_time += delta
	# Hit the ground while descending: bounce and keep traveling, until it has either
	# bounced too many times or landed too softly to hop again — then it bursts.
	if _velocity.y > 0.0 and global_position.y >= _floor_y:
		global_position.y = _floor_y
		_bounces += 1
		if _bounces > max_bounces or _velocity.y < min_bounce_speed:
			_enter_hit(null)
			return
		_velocity.y = -_velocity.y * bounce_restitution
		_velocity.x *= bounce_friction
	# Safety timeout while flying.
	if _fly_time >= max_lifetime:
		_enter_hit(null)


func _on_anim_finished() -> void:
	if _state == State.HIT:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _state != State.FLY:
		return
	if body.is_in_group("player") or body.name == "Curiosity":
		_enter_hit(body)
