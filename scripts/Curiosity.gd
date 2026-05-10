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

const FLAME_FLICKER_AMPLITUDE: float = 0.05
const FLAME_FLICKER_PERIOD: float = 0.4

# Source art faces LEFT. Default unflipped = facing left.
var _state: State = State.IDLE
var _facing_right: bool = false
var _lantern_offset_x: float
var _lantern_tween: Tween
var _was_airborne: bool = false
var _flame_time: float = 0.0
var _flame_base_alpha: float = 1.0


func _ready() -> void:
	_lantern_offset_x = abs(lantern.position.x)
	visual.flip_h = _facing_right
	var anchor_x: float = _lantern_offset_x if _facing_right else -_lantern_offset_x
	lantern.position.x = anchor_x
	flame.position.x = anchor_x
	_flame_base_alpha = flame.modulate.a
	visual.animation_finished.connect(_on_animation_finished)
	visual.play(&"idle")


func _process(delta: float) -> void:
	_flame_time += delta
	var flicker: float = sin(_flame_time * TAU / FLAME_FLICKER_PERIOD) * FLAME_FLICKER_AMPLITUDE
	flame.modulate.a = clampf(_flame_base_alpha + flicker, 0.0, 1.0)


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
	# Source art faces LEFT, lantern is in front of the body (screen-left).
	# Press LEFT  -> faces left  -> flip_h = false, lantern at -offset (left of body)
	# Press RIGHT -> faces right -> flip_h = true,  lantern at +offset (right of body)
	visual.flip_h = _facing_right
	var target_x: float = _lantern_offset_x if _facing_right else -_lantern_offset_x
	if _lantern_tween and _lantern_tween.is_running():
		_lantern_tween.kill()
	_lantern_tween = create_tween().set_parallel(true)
	_lantern_tween.tween_property(lantern, "position:x", target_x, lantern_sway_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lantern_tween.tween_property(flame, "position:x", target_x, lantern_sway_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
