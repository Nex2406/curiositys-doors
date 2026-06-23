extends CharacterBody2D

# Combat (attack1/attack2/dash) and hurt are wired below. Still dormant in
# SpriteFrames: charged, approach, lever_pull, lever_hold, celebrate — those land
# with the systems that need them (lever with lever puzzles, etc.).
enum State { IDLE, WALK, RUN, JUMP_START, AIR, LAND, ATTACK, DASH, HURT }

# Drifting-traveler tuning: gravity is well below normal-platformer (~980)
# so falls glide rather than thud. Jump magnitude is correspondingly low,
# which keeps reachable height roughly the same while ~doubling air time.
@export var walk_speed: float = 265.0
@export var run_speed: float = 420.0
@export var gravity: float = 350.0
@export var jump_velocity: float = -320.0
@export var accel_time: float = 0.15
@export var lantern_sway_time: float = 0.2

# Combat / dash feel. A slash locks Curiosity in place for the swing; a dash is
# a quick weighty burst in the facing direction (also the platforming gap-closer).
@export var dash_speed: float = 760.0
@export var dash_time: float = 0.22
@export var dash_cooldown: float = 0.45

const MOVE_EPSILON: float = 8.0

@onready var visual: AnimatedSprite2D = $Visual
@onready var lantern: PointLight2D = $Lantern
@onready var flame: Sprite2D = $LanternFlame

const FLAME_FLICKER_AMPLITUDE: float = 0.05
const FLAME_FLICKER_PERIOD: float = 0.4

# The cast light breathes too — two out-of-phase sines give an organic,
# non-mechanical flicker instead of a steady pulse.
const LIGHT_FLICKER_FAST: float = 0.4
const LIGHT_FLICKER_SLOW: float = 0.17
const LIGHT_FLICKER_FAST_AMP: float = 0.12
const LIGHT_FLICKER_SLOW_AMP: float = 0.06

# The grounded poses hold the lantern low at the hand, but the jump/air poses
# lift Curiosity into a horizontal leap — leaving the orb dangling below the
# drawn lantern. Raise the orb while airborne so it rides up with the body,
# eased so the windup and landing read smoothly rather than snapping.
const LANTERN_AIR_LIFT: float = -90.0
const LANTERN_LIFT_LERP: float = 10.0

# Source art faces LEFT. Default unflipped = facing left.
var _state: State = State.IDLE
var _facing_right: bool = false
var _lantern_offset_x: float
var _lantern_tween: Tween
var _was_airborne: bool = false
var _flame_time: float = 0.0
var _flame_base_alpha: float = 1.0
var _lantern_base_energy: float = 1.0
var _lantern_base_y: float = 0.0

# Combat / dash runtime state.
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _attack_combo: int = 0       # 0 = first swing (attack1), 1 = combo (attack2)
var _attack_queued: bool = false # pressed attack again mid-swing → chain to attack2


func _ready() -> void:
	_lantern_offset_x = abs(lantern.position.x)
	visual.flip_h = _facing_right
	var anchor_x: float = _lantern_offset_x if _facing_right else -_lantern_offset_x
	lantern.position.x = anchor_x
	flame.position.x = anchor_x
	_flame_base_alpha = flame.modulate.a
	_lantern_base_energy = lantern.energy
	_lantern_base_y = lantern.position.y
	visual.animation_finished.connect(_on_animation_finished)
	visual.play(&"idle")


func _process(delta: float) -> void:
	_flame_time += delta
	var flicker: float = sin(_flame_time * TAU / FLAME_FLICKER_PERIOD) * FLAME_FLICKER_AMPLITUDE
	flame.modulate.a = clampf(_flame_base_alpha + flicker, 0.0, 1.0)
	# Cast light breathes with the flame so the warm pool feels alive.
	var energy_flicker: float = \
		sin(_flame_time * TAU / LIGHT_FLICKER_FAST) * LIGHT_FLICKER_FAST_AMP \
		+ sin(_flame_time * TAU / LIGHT_FLICKER_SLOW) * LIGHT_FLICKER_SLOW_AMP
	lantern.energy = _lantern_base_energy * (1.0 + energy_flicker)

	# Lift the orb up with the body while airborne so it stays in the lantern.
	var airborne: bool = _state == State.AIR or _state == State.JUMP_START
	var target_y: float = _lantern_base_y + (LANTERN_AIR_LIFT if airborne else 0.0)
	var lift_t: float = clampf(delta * LANTERN_LIFT_LERP, 0.0, 1.0)
	var new_y: float = lerpf(lantern.position.y, target_y, lift_t)
	lantern.position.y = new_y
	flame.position.y = new_y


func _physics_process(delta: float) -> void:
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)

	# Action states drive their own movement and consume the frame.
	if _state == State.DASH:
		_process_dash(delta)
		return
	if _state == State.ATTACK:
		_process_attack(delta)
		return
	if _state == State.HURT:
		_process_hurt(delta)
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	# Dash / slash interrupt locomotion from any ground or air state.
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_start_dash()
		return
	if Input.is_action_just_pressed("attack"):
		_start_attack()
		return

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


# ─── combat / dash ─────────────────────────────────────────────────────────
func _start_dash() -> void:
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	_set_state(State.DASH)


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	# Flat horizontal burst in the facing direction; gravity paused so the dash
	# reads as a clean lunge (and reliably clears platforming gaps).
	velocity.x = (1.0 if _facing_right else -1.0) * dash_speed
	velocity.y = 0.0
	move_and_slide()
	if _dash_timer <= 0.0:
		_exit_action_state()


func _start_attack() -> void:
	_attack_combo = 0
	_attack_queued = false
	_set_state(State.ATTACK)


func _process_attack(delta: float) -> void:
	# Hold position for the swing: bleed off horizontal speed, keep falling if
	# airborne. A second press during the swing chains into attack2.
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, (run_speed / accel_time) * delta)
	if Input.is_action_just_pressed("attack"):
		_attack_queued = true
	move_and_slide()


# Public: play the hurt flinch (called by the realm when a life is lost). An
# optional knockback nudges Curiosity opposite the hit direction.
func hurt(knockback: Vector2 = Vector2.ZERO) -> void:
	velocity = knockback
	_set_state(State.HURT)


func _process_hurt(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, (run_speed / accel_time) * delta)
	move_and_slide()


# Leave a dash/attack: re-evaluate into the right locomotion or air state.
func _exit_action_state() -> void:
	if not is_on_floor():
		_set_state(State.AIR)
		return
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0 and absf(velocity.x) > MOVE_EPSILON:
		_set_state(State.RUN if Input.is_key_pressed(KEY_SHIFT) else State.WALK)
	else:
		_set_state(State.IDLE)


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
		State.ATTACK: visual.play(&"attack1")
		State.DASH: visual.play(&"dash")
		State.HURT: visual.play(&"hurt")


func _on_animation_finished() -> void:
	match _state:
		State.ATTACK:
			# Chain attack1 → attack2 if the player tapped again mid-swing.
			if _attack_combo == 0 and _attack_queued:
				_attack_combo = 1
				_attack_queued = false
				visual.play(&"attack2")
			else:
				_exit_action_state()
		State.DASH:
			# Dash usually ends on its timer, but if the (shorter) clip finishes
			# first just hold the last frame until the burst completes.
			pass
		State.HURT:
			_exit_action_state()
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
