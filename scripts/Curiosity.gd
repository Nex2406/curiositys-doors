extends CharacterBody2D

# TODO: combat and lever animations (attack1, attack2, charged, dash, hurt,
# approach, lever_pull, lever_hold, celebrate) are loaded in SpriteFrames
# but not yet wired to states — wiring lands in future PRs once enemies
# and lever puzzles exist.
enum State { IDLE, WALK, RUN, JUMP_START, AIR, LAND }

# Drifting-traveler tuning: gravity is well below normal-platformer (~980)
# so falls glide rather than thud. Jump magnitude is correspondingly low,
# which keeps reachable height roughly the same while ~doubling air time.
@export var walk_speed: float = 200.0
@export var run_speed: float = 320.0
@export var gravity: float = 350.0
@export var jump_velocity: float = -240.0
@export var accel_time: float = 0.15
@export var lantern_sway_time: float = 0.2

const MOVE_EPSILON: float = 8.0

@onready var visual: AnimatedSprite2D = $Visual
@onready var lantern: PointLight2D = $Lantern
@onready var flame: Sprite2D = $LanternFlame
@onready var eye_left: Sprite2D = $EyeLeft
@onready var eye_right: Sprite2D = $EyeRight

const FLAME_FLICKER_AMPLITUDE: float = 0.05
const FLAME_FLICKER_PERIOD: float = 0.4
# Eye orbs breathe at a slower, calmer rhythm than the lantern flame.
# Left/right run π/3 out of phase so the pair feels alive but not jittery.
const EYE_FLICKER_AMPLITUDE: float = 0.05
const EYE_FLICKER_PERIOD: float = 1.2
const EYE_PHASE_OFFSET: float = PI / 3.0

# Source art faces LEFT. Default unflipped = facing left.
var _state: State = State.IDLE
var _facing_right: bool = false
var _lantern_offset_x: float
var _eye_left_offset_x: float
var _eye_right_offset_x: float
var _lantern_tween: Tween
var _was_airborne: bool = false
var _flame_time: float = 0.0
var _flame_base_alpha: float = 1.0
var _eye_time: float = 0.0
var _eye_left_base_alpha: float = 1.0
var _eye_right_base_alpha: float = 1.0


func _ready() -> void:
	_lantern_offset_x = abs(lantern.position.x)
	_eye_left_offset_x = abs(eye_left.position.x)
	_eye_right_offset_x = abs(eye_right.position.x)
	visual.flip_h = _facing_right
	var sign_x: float = 1.0 if _facing_right else -1.0
	lantern.position.x = sign_x * _lantern_offset_x
	flame.position.x = sign_x * _lantern_offset_x
	eye_left.position.x = sign_x * _eye_left_offset_x
	eye_right.position.x = sign_x * _eye_right_offset_x
	_flame_base_alpha = flame.modulate.a
	_eye_left_base_alpha = eye_left.modulate.a
	_eye_right_base_alpha = eye_right.modulate.a
	visual.animation_finished.connect(_on_animation_finished)
	visual.play(&"idle")


func _process(delta: float) -> void:
	_flame_time += delta
	var flicker: float = sin(_flame_time * TAU / FLAME_FLICKER_PERIOD) * FLAME_FLICKER_AMPLITUDE
	flame.modulate.a = clampf(_flame_base_alpha + flicker, 0.0, 1.0)
	_eye_time += delta
	var eye_phase: float = _eye_time * TAU / EYE_FLICKER_PERIOD
	var l_flicker: float = sin(eye_phase) * EYE_FLICKER_AMPLITUDE
	var r_flicker: float = sin(eye_phase + EYE_PHASE_OFFSET) * EYE_FLICKER_AMPLITUDE
	eye_left.modulate.a = clampf(_eye_left_base_alpha + l_flicker, 0.0, 1.0)
	eye_right.modulate.a = clampf(_eye_right_base_alpha + r_flicker, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction: float = Input.get_axis("move_left", "move_right")
	var sprint: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float = run_speed if sprint else walk_speed
	var target_x: float = direction * speed
	var accel: float = speed / accel_time
	velocity.x = move_toward(velocity.x, target_x, accel * delta)

	if direction != 0.0:
		var want_right: bool = direction > 0.0
		if want_right != _facing_right:
			_facing_right = want_right
			_apply_facing()

	if Input.is_action_just_pressed("jump") and is_on_floor() and _is_ground_state():
		velocity.y = jump_velocity
		_set_state(State.JUMP_START)

	move_and_slide()

	var grounded: bool = is_on_floor()
	if _was_airborne and grounded and _state == State.AIR:
		_set_state(State.LAND)
	elif not grounded and _is_ground_state():
		_set_state(State.AIR)

	if grounded and _state in [State.IDLE, State.WALK, State.RUN]:
		_update_locomotion(direction, sprint)

	_was_airborne = not grounded


func _is_ground_state() -> bool:
	return _state == State.IDLE or _state == State.WALK \
		or _state == State.RUN or _state == State.LAND


func _update_locomotion(direction: float, sprint: bool) -> void:
	var moving: bool = absf(velocity.x) > MOVE_EPSILON and direction != 0.0
	if not moving:
		_set_state(State.IDLE)
	elif sprint:
		_set_state(State.RUN)
	else:
		_set_state(State.WALK)


func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	match new_state:
		State.IDLE: visual.play(&"idle")
		State.WALK: visual.play(&"walk")
		State.RUN: visual.play(&"run")
		State.JUMP_START: visual.play(&"jump_start")
		State.AIR: visual.play(&"air")
		State.LAND: visual.play(&"land")


func _on_animation_finished() -> void:
	match _state:
		State.JUMP_START:
			_set_state(State.AIR)
		State.LAND:
			var direction: float = Input.get_axis("move_left", "move_right")
			var sprint: bool = Input.is_key_pressed(KEY_SHIFT)
			if direction != 0.0 and absf(velocity.x) > MOVE_EPSILON:
				_set_state(State.RUN if sprint else State.WALK)
			else:
				_set_state(State.IDLE)


func _apply_facing() -> void:
	# Source art faces LEFT, lantern + eye orbs sit on the screen-left side
	# of the body by default. Pressing RIGHT mirrors the visual AND flips the
	# x-offset of every sibling sprite that needs to follow the head/cloak —
	# the lantern body, its flame, and both eye orbs.
	visual.flip_h = _facing_right
	var sign_x: float = 1.0 if _facing_right else -1.0
	var lantern_target_x: float = sign_x * _lantern_offset_x
	var eye_left_target_x: float = sign_x * _eye_left_offset_x
	var eye_right_target_x: float = sign_x * _eye_right_offset_x
	if _lantern_tween and _lantern_tween.is_running():
		_lantern_tween.kill()
	_lantern_tween = create_tween().set_parallel(true)
	_lantern_tween.tween_property(lantern, "position:x", lantern_target_x, lantern_sway_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lantern_tween.tween_property(flame, "position:x", lantern_target_x, lantern_sway_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lantern_tween.tween_property(eye_left, "position:x", eye_left_target_x, lantern_sway_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lantern_tween.tween_property(eye_right, "position:x", eye_right_target_x, lantern_sway_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
