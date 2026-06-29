extends CharacterBody2D

# Combat (attack1/attack2/dash) and hurt are wired below. Still dormant in
# SpriteFrames: charged, approach, lever_pull, lever_hold, celebrate — those land
# with the systems that need them (lever with lever puzzles, etc.).
enum State { IDLE, WALK, RUN, JUMP_START, AIR, LAND, ATTACK, DASH, HURT }

# Drifting-traveler tuning: gravity is well below normal-platformer (~980)
# so falls glide rather than thud. Jump magnitude is correspondingly low,
# which keeps reachable height roughly the same while ~doubling air time.
@export var walk_speed: float = 200.0
@export var run_speed: float = 210.0
@export var gravity: float = 460.0
@export var jump_velocity: float = -356.0
@export var accel_time: float = 0.15

# Combat / dash feel. A slash locks Curiosity in place for the swing; a dash is
# a quick weighty burst in the facing direction (also the platforming gap-closer).
@export var dash_speed: float = 460.0
@export var dash_time: float = 0.32
@export var dash_cooldown: float = 0.45

# Health. Damage sources call take_damage(); a short invulnerability window after a
# hit prevents a single lingering hazard from draining several hits in a few frames,
# and Curiosity blinks while it's active.
@export var max_health: int = 100
@export var invuln_time: float = 0.9

# Dashing spends a little health as stamina; it's paid back automatically a short while
# later (unlike a golem hit, which is a permanent -10). Lets dashing have a cost without
# being lethal — the dash is skipped if it would drop health to/below zero.
@export var dash_cost: int = 5
@export var dash_regen_time: float = 2.5

signal health_changed(health: int, max_health: int)
signal died()

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
# The jump poses keep the lantern in-hand at roughly its grounded height, so the glow
# should stay put on the drawn lantern in the air rather than floating up off it.
const LANTERN_AIR_LIFT: float = 0.0
const LANTERN_LIFT_LERP: float = 10.0

# Living lantern: the glow never sits still. A slow idle sway + vertical bob give it
# breath at rest; a velocity-driven trail drags it back as Curiosity accelerates and
# lets it settle when they stop. The flame leans a touch with the horizontal swing.
const LANTERN_SWAY_AMP: float = 2.5       # px — idle side-to-side (small, stays on the lantern)
const LANTERN_SWAY_PERIOD: float = 2.6    # s
const LANTERN_BOB_AMP: float = 2.0        # px — idle up/down
const LANTERN_BOB_PERIOD: float = 1.7     # s
const LANTERN_SWING_AMP: float = 4.0      # px — gentle velocity trail (kept tight so it never detaches)
const LANTERN_SWING_LERP: float = 16.0    # snappy: the glow keeps up with the lantern
const LANTERN_FACING_LERP: float = 14.0   # how fast the held side slides on a turn
const LANTERN_LEAN_PER_PX: float = 0.006  # radians of flame lean per px of swing

# The attack art is drawn as a compact forward lunge, so it reads a touch smaller
# than the upright idle. Bump its scale slightly, anchored at the feet (which sit a
# fixed distance below the sprite centre in every clip) so the lunge keeps planted
# and only grows upward toward idle height.
const ATTACK_SCALE: float = 1.13
const FEET_FROM_CENTRE: float = 136.0   # content feet row below canvas centre (all clips)

# Source art faces RIGHT. Default unflipped = facing right; flip_h mirrors to face left.
var _state: State = State.IDLE
var _facing_right: bool = false
var _lantern_offset_x: float
var _lantern_disp_x: float = 0.0   # smoothed held-side anchor
var _lantern_swing: float = 0.0    # current velocity trail offset
var _lantern_lift_y: float = 0.0   # smoothed airborne lift
var _base_visual_scale: float = 1.0
var _was_airborne: bool = false
var _flame_time: float = 0.0
var _flame_base_alpha: float = 1.0
var _flame_air_fade: float = 1.0   # fades the discrete flame overlay out while airborne
var _lantern_base_energy: float = 1.0
var _lantern_base_y: float = 0.0

# Combat / dash runtime state.
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _attack_combo: int = 0       # 0 = first swing (attack1), 1 = combo (attack2)
var _attack_queued: bool = false # pressed attack again mid-swing → chain to attack2

# Health runtime state.
var health: int
var _invuln_timer: float = 0.0


func _ready() -> void:
	_lantern_offset_x = abs(lantern.position.x)
	visual.flip_h = not _facing_right
	var anchor_x: float = _lantern_offset_x if _facing_right else -_lantern_offset_x
	_lantern_disp_x = anchor_x
	lantern.position.x = anchor_x
	flame.position.x = anchor_x
	_flame_base_alpha = flame.modulate.a
	_lantern_base_energy = lantern.energy
	_lantern_base_y = lantern.position.y
	_base_visual_scale = visual.scale.y
	visual.animation_finished.connect(_on_animation_finished)
	visual.play(&"idle")
	health = max_health
	health_changed.emit(health, max_health)


func _process(delta: float) -> void:
	var airborne: bool = _state == State.AIR or _state == State.JUMP_START
	var anchor_x: float = _lantern_offset_x if _facing_right else -_lantern_offset_x
	_flame_time += delta
	# The discrete flame overlay only sits cleanly on the drawn lantern while Curiosity
	# is idle and the lantern is settled on its side. The moment they move, flip, or jump
	# the drawn lantern swings around and the fixed overlay reads as a detached orb — so
	# we fade it out then and let the drawn lantern carry its own painted glow.
	var lantern_settled: bool = absf(_lantern_disp_x - anchor_x) < 5.0
	var show_flame: bool = _state == State.IDLE and lantern_settled and not airborne
	_flame_air_fade = lerpf(_flame_air_fade, 1.0 if show_flame else 0.0, clampf(delta * 9.0, 0.0, 1.0))
	var flicker: float = sin(_flame_time * TAU / FLAME_FLICKER_PERIOD) * FLAME_FLICKER_AMPLITUDE
	flame.modulate.a = clampf(_flame_base_alpha + flicker, 0.0, 1.0) * _flame_air_fade
	# Cast light breathes with the flame so the warm pool feels alive.
	var energy_flicker: float = \
		sin(_flame_time * TAU / LIGHT_FLICKER_FAST) * LIGHT_FLICKER_FAST_AMP \
		+ sin(_flame_time * TAU / LIGHT_FLICKER_SLOW) * LIGHT_FLICKER_SLOW_AMP
	lantern.energy = _lantern_base_energy * (1.0 + energy_flicker)

	# Blink while invulnerable after a hit, then snap back to fully opaque.
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		visual.modulate.a = 0.35 if int(_invuln_timer * 20.0) % 2 == 0 else 1.0
		if _invuln_timer <= 0.0:
			visual.modulate.a = 1.0

	# Tie the leg-cycle speed to how fast Curiosity is actually moving so the feet
	# never slide: at walk_speed the clip runs at its drawn rate (scale 1.0), and it
	# speeds up toward a run. Other states (idle/attack/hurt/dash) play at their
	# authored rate.
	if _state == State.WALK or _state == State.RUN:
		visual.speed_scale = clampf(absf(velocity.x) / walk_speed, 0.7, 1.0)
	else:
		visual.speed_scale = 1.0

	# ── Living lantern ─────────────────────────────────────────────────────────
	# Slide the held side smoothly when Curiosity turns (replaces the old tween).
	_lantern_disp_x = lerpf(_lantern_disp_x, anchor_x, clampf(delta * LANTERN_FACING_LERP, 0.0, 1.0))

	# Velocity trail: lantern lags opposite the direction of travel, then settles.
	var trail_target: float = -clampf(velocity.x / run_speed, -1.0, 1.0) * LANTERN_SWING_AMP
	_lantern_swing = lerpf(_lantern_swing, trail_target, clampf(delta * LANTERN_SWING_LERP, 0.0, 1.0))

	# Lift the orb up with the body while airborne so it stays in the lantern.
	var lift_target: float = LANTERN_AIR_LIFT if airborne else 0.0
	_lantern_lift_y = lerpf(_lantern_lift_y, lift_target, clampf(delta * LANTERN_LIFT_LERP, 0.0, 1.0))

	# Idle breath: a slow sway and an out-of-phase bob.
	var sway_x: float = sin(_flame_time * TAU / LANTERN_SWAY_PERIOD) * LANTERN_SWAY_AMP
	var bob_y: float = sin(_flame_time * TAU / LANTERN_BOB_PERIOD) * LANTERN_BOB_AMP

	var px: float = _lantern_disp_x + sway_x + _lantern_swing
	var py: float = _lantern_base_y + _lantern_lift_y + bob_y
	lantern.position = Vector2(px, py)
	flame.position = Vector2(px, py)
	# The flame leans a touch into the swing for a hand-held, breathing feel.
	flame.rotation = (sway_x + _lantern_swing) * LANTERN_LEAN_PER_PX


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
	if _was_airborne and grounded and (_state == State.AIR or _state == State.JUMP_START):
		# Landed — no separate land animation, drop straight back into locomotion.
		_update_locomotion(direction, sprint)
	elif not grounded and _is_ground_state():
		_set_state(State.AIR)

	if grounded and _state in [State.IDLE, State.WALK, State.RUN]:
		_update_locomotion(direction, sprint)

	_was_airborne = not grounded

	if _state == State.JUMP_START or _state == State.AIR:
		_drive_jump_frame()


# Hold one clean cloak-billow pose for the whole airborne stretch: the legs stay hidden
# under the spread cloak (reads as gliding), and the feet don't shuffle. Cycling the
# jump frames put the legs in walking poses and made the footing read wrong mid-air.
const JUMP_HOLD_FRAME: int = 3   # 0-indexed wide-billow glide pose, legs hidden

func _drive_jump_frame() -> void:
	if visual.sprite_frames.get_frame_count(&"jump") > JUMP_HOLD_FRAME:
		visual.frame = JUMP_HOLD_FRAME


func _is_ground_state() -> bool:
	return _state == State.IDLE or _state == State.WALK \
		or _state == State.RUN or _state == State.LAND


# ─── combat / dash ─────────────────────────────────────────────────────────
func _start_dash() -> void:
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	_spend_dash_stamina()
	_set_state(State.DASH)


# Spend the dash's health cost, then pay it back after dash_regen_time. Skipped if it
# would be lethal, so dashing is never fatal — only golem hits are.
func _spend_dash_stamina() -> void:
	if dash_cost <= 0 or health <= dash_cost:
		return
	health -= dash_cost
	health_changed.emit(health, max_health)
	get_tree().create_timer(dash_regen_time).timeout.connect(_repay_dash_stamina)


func _repay_dash_stamina() -> void:
	if health <= 0:
		return   # don't revive the dead
	health = min(max_health, health + dash_cost)
	health_changed.emit(health, max_health)


# Refill to full (a fresh life after respawn).
func refill_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func _process_dash(delta: float) -> void:
	# Attacking out of a dash: the swing comes out immediately, cancelling the dash
	# (consistent with being able to attack on the ground and in the air).
	if Input.is_action_just_pressed("attack"):
		_start_attack()
		return
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


# Public: take a hit from a hazard/enemy. Ignored during the post-hit invulnerability
# window. Subtracts health, flinches, and announces the change; emits `died` at zero.
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if _invuln_timer > 0.0 or health <= 0:
		return
	health = max(0, health - amount)
	health_changed.emit(health, max_health)
	_invuln_timer = invuln_time
	hurt(knockback)
	if health <= 0:
		died.emit()


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
	_apply_visual_scale(new_state)
	match new_state:
		State.IDLE: visual.play(&"idle")
		State.WALK, State.RUN:
			# Both use the smooth walk cycle (the dedicated run clip squashes low in its
			# back half and snaps on loop, which reads as a glitchy limp). The velocity
			# link (see _process) speeds the cycle up for a run. Guard against replaying
			# so toggling between walk/run doesn't restart the cycle mid-stride.
			if visual.animation != &"walk":
				visual.play(&"walk")
		State.JUMP_START, State.AIR:
			# The jump clip is driven by physics (see _drive_jump_frame), not a timer, so
			# its frames track the real arc. Stop autoplay; the frame is set each tick.
			if visual.animation != &"jump":
				visual.animation = &"jump"
			visual.stop()
		State.ATTACK: visual.play(&"attack")
		State.DASH: visual.play(&"run")   # no dash art — reuse the run cycle for the burst
		State.HURT: visual.play(&"hurt")


func _on_animation_finished() -> void:
	match _state:
		State.ATTACK:
			# Single swing now (no attack1→attack2 combo); return to locomotion.
			_exit_action_state()
		State.DASH:
			# Dash ends on its timer; if the clip finishes first, hold until then.
			pass
		State.HURT:
			_exit_action_state()


# Bump the visual scale for the attack lunge, keeping the feet planted. Feet sit
# FEET_FROM_CENTRE below the sprite centre at any scale, so shifting the sprite up by
# the growth in that distance holds them on the ground while the body grows upward.
func _apply_visual_scale(state: State) -> void:
	var k: float = ATTACK_SCALE if state == State.ATTACK else 1.0
	visual.scale = Vector2(_base_visual_scale * k, _base_visual_scale * k)
	visual.position.y = FEET_FROM_CENTRE * _base_visual_scale * (1.0 - k)


func _apply_facing() -> void:
	# Source art faces RIGHT, lantern is in front of the body. Just flip the sprite;
	# _process slides the lantern toward the new held side (LANTERN_FACING_LERP).
	visual.flip_h = not _facing_right
