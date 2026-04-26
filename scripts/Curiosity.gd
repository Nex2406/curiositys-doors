extends CharacterBody2D

@export var speed: float = 200.0
# Drifting-traveler tuning: gravity is well below normal-platformer (~980)
# so falls glide rather than thud. Jump magnitude is correspondingly low,
# which keeps reachable height roughly the same while ~doubling air time.
@export var gravity: float = 350.0
@export var jump_velocity: float = -240.0
# Time to ramp horizontal velocity to/from full speed. Used as
# acceleration = speed / accel_time.
@export var accel_time: float = 0.15
@export var lantern_sway_time: float = 0.2
@export var bob_amplitude: float = 4.0
@export var bob_period: float = 1.5

@onready var visual: Sprite2D = $Visual
@onready var lantern: PointLight2D = $Lantern

# Source art faces LEFT. Default unflipped = facing left.
var _facing_right: bool = false
var _lantern_offset_x: float
var _lantern_tween: Tween
var _bob_time: float = 0.0


func _ready() -> void:
	_lantern_offset_x = abs(lantern.position.x)
	# Apply facing without tween on first frame so the lantern isn't mid-glide
	# at scene start.
	visual.flip_h = _facing_right
	lantern.position.x = _lantern_offset_x if not _facing_right else -_lantern_offset_x


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction: float = Input.get_axis("move_left", "move_right")
	var target_x: float = direction * speed
	var accel: float = speed / accel_time
	velocity.x = move_toward(velocity.x, target_x, accel * delta)

	if direction != 0.0:
		var want_right: bool = direction > 0.0
		if want_right != _facing_right:
			_facing_right = want_right
			_apply_facing()

	move_and_slide()


func _process(delta: float) -> void:
	# Idle/walking sprite bob. Eases back to zero in the air so jumps don't
	# fight the bob curve.
	if is_on_floor():
		_bob_time += delta
		visual.position.y = sin(_bob_time * TAU / bob_period) * bob_amplitude
	else:
		visual.position.y = lerp(visual.position.y, 0.0, 1.0 - exp(-delta * 5.0))


func _apply_facing() -> void:
	# Press LEFT  -> faces left  -> flip_h = false (source unflipped),  lantern at +offset
	# Press RIGHT -> faces right -> flip_h = true  (source mirrored),   lantern at -offset
	visual.flip_h = _facing_right
	var target_x: float = -_lantern_offset_x if _facing_right else _lantern_offset_x
	if _lantern_tween and _lantern_tween.is_running():
		_lantern_tween.kill()
	_lantern_tween = create_tween()
	_lantern_tween.tween_property(lantern, "position:x", target_x, lantern_sway_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
