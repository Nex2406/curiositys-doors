extends CharacterBody2D
class_name RuneOrb

# The wizard's rune-orb hazard (Realm 2): a runed crystal ball that rolls back
# and forth along the plank, riding the moving platform exactly the way
# Curiosity does (CharacterBody2D + the same gravity), and shoving her — never
# damaging her — when she touches it. It is NOT clamped to the plank: roll past
# the edge and gravity takes it, same rules as the hero. Orbs are as much at
# the platform's mercy as she is.
#
# The sheet's ball is dead-centered in every frame (measured: center 187,142 of
# 374x282, radius ~109) with the golden sparkle trail baked in streaking away —
# so the node origin IS the ball center and no offset juggling is needed when
# flipping. Frames 4..12 are the seamless rolling loop.
#
# INVULNERABLE (Advika, 2026-07-12): the player cannot destroy, damage, or stop
# an orb — no take_damage() exists here, the node is NOT in the "enemies" group
# her swing filters on, and it lives on its own physics layer 16 (mask 17 =
# terrain + sibling orbs) that her attack hitbox (mask 4) never scans. The only
# ways an orb leaves play: it rolls off the edge and falls, or the level ends.
# Counterplay is movement — jump over it, slip past it, reposition.

const FRAME_DIR := "res://assets/hazards/runeorb/"
const ROLL_FIRST := 4
const ROLL_LAST := 12
const FPS := 14.0
const BALL_RADIUS := 105.0        # collider: the ball body, NOT the trail
const PUSH_ZONE_RADIUS := 128.0   # a shade wider so the shove lands before overlap

# Same gravity source as the hero (Curiosity.gd's drifting-traveler 460) so the
# orb falls off an edge with the same weight she does.
const GRAVITY := 460.0

# Rolling inertia (Advika, 2026-07-12: the mechanics didn't feel right — snap
# reversals read weightless). The ball accelerates toward its roll direction
# instead of teleporting to full speed: a reversal decelerates through a
# momentary stop and gathers back up, like mass.
const ROLL_ACCEL := 380.0

@export var roll_speed := 140.0
@export var reverse_time_min := 1.5   # randomized whim: how long before it changes its mind
@export var reverse_time_max := 3.5
@export var push_force := 420.0       # horizontal shove on Curiosity, in the orb's travel direction
@export var push_up_kick := 150.0     # slight upward component — a shove, not a slide
@export var push_cooldown := 0.4      # overlap doesn't machine-gun pushes
@export var airborne_lifetime := 4.0  # rolled off: free after this long falling
@export var kill_y := 100000.0        # …or below this global y, whichever first
# Orbs don't overstay (Advika, 2026-07-12): after a random spell on deck the
# orb commits to its current direction — no more reversals, no more bumps —
# and rolls off the nearest open edge, clearing room for the wizard's next one.
@export var leave_after_min := 5.0
@export var leave_after_max := 10.0

var _visual: AnimatedSprite2D
var _dir := 1.0
var _reverse_timer := 0.0
var _push_cd := 0.0
var _bump_cd := 0.0     # orb-vs-orb: brief pause so one contact = one reversal, not jitter
var _air_t := 0.0
var _leave_t := 0.0     # deck time left before it commits to rolling off
var _leaving := false
var _push_zone: Area2D


func _ready() -> void:
	_visual = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"roll")
	frames.set_animation_speed(&"roll", FPS)
	frames.set_animation_loop(&"roll", true)
	for i in range(ROLL_FIRST, ROLL_LAST + 1):
		frames.add_frame(&"roll", load(FRAME_DIR + "runeorb%d.png" % i))
	_visual.sprite_frames = frames
	add_child(_visual)
	_visual.play(&"roll")

	var col := CollisionShape2D.new()
	var ball := CircleShape2D.new()
	ball.radius = BALL_RADIUS
	col.shape = ball
	add_child(col)

	_push_zone = Area2D.new()
	_push_zone.name = "PushZone"
	# Sense-only: reports nothing (layer 0), senses layer 1 bodies — the shove
	# path filters those down to the "player" group.
	_push_zone.collision_layer = 0
	_push_zone.collision_mask = 1
	var zcol := CollisionShape2D.new()
	var zone := CircleShape2D.new()
	zone.radius = PUSH_ZONE_RADIUS
	zcol.shape = zone
	_push_zone.add_child(zcol)
	add_child(_push_zone)

	# SOLID to Curiosity (Advika, 2026-07-12: she sometimes phased straight
	# through a ball — a body she can't fight must at least be a body). The
	# orb sits on layers 16+2: her mask (3 = terrain+2) collides with it, so
	# it blocks her — and the PushZone shove throws her off it. Her attack
	# (mask 4) still can't touch it. No more ghost balls.

	_arm_reverse_timer()
	_leave_t = randf_range(leave_after_min, leave_after_max)
	_apply_facing()


# Spawner sets the opening direction; 0 = flip a coin.
func set_direction(dir: int) -> void:
	_dir = float(dir) if dir != 0 else (1.0 if randf() < 0.5 else -1.0)
	_apply_facing()


# Level tuning: replace the deck-time window. Re-rolls the remaining time —
# the _ready() roll used the scene defaults, before the level's dials landed.
func set_leave_window(min_s: float, max_s: float) -> void:
	leave_after_min = min_s
	leave_after_max = max_s
	if not _leaving:
		_leave_t = randf_range(min_s, max_s)


# Reversed by a sibling orb bumping into us (see the slide-collision scan).
func bump_reverse() -> void:
	if _bump_cd > 0.0 or _leaving:
		return
	_bump_cd = 0.25
	_dir = -_dir
	_arm_reverse_timer()
	_apply_facing()


func _physics_process(delta: float) -> void:
	# Below the kill plane = gone, floor or no floor. (The plane can be
	# dynamic — the lift level rides it 900px under the climbing island — so
	# an orb that landed on old ground below must still die when it sweeps by.)
	if global_position.y > kill_y:
		queue_free()
		return
	_push_cd = maxf(0.0, _push_cd - delta)
	_bump_cd = maxf(0.0, _bump_cd - delta)

	# The randomized whim: reverse on a timer while grounded — until its deck
	# time runs out, then it commits to one direction and rolls off the edge.
	if is_on_floor():
		_air_t = 0.0
		if not _leaving:
			_leave_t -= delta
			if _leave_t <= 0.0:
				_leaving = true
			_reverse_timer -= delta
			if _reverse_timer <= 0.0:
				_dir = -_dir
				_arm_reverse_timer()
	else:
		# Off the edge: gravity owns it now. Keep rolling in the air (it reads
		# as tumbling), despawn once clearly gone. (An orb that lands on some
		# OTHER floor far below resets this clock — the kill plane above is
		# what guarantees it still dies; see the lift level's dynamic plane.)
		_air_t += delta
		if _air_t >= airborne_lifetime:
			queue_free()
			return

	velocity.x = move_toward(velocity.x, _dir * roll_speed, ROLL_ACCEL * delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Walls turn it around; a sibling orb turns BOTH around (reads as playful).
	# A leaving orb is done negotiating — nothing turns it back.
	if not _leaving:
		for i in range(get_slide_collision_count()):
			var other := get_slide_collision(i).get_collider()
			if other is RuneOrb:
				(other as RuneOrb).bump_reverse()
				bump_reverse()
				break
		if is_on_wall() and _bump_cd <= 0.0:
			_dir = -_dir
			_arm_reverse_timer()

	_apply_facing()
	_try_push()


# Shove Curiosity in the orb's travel direction — damage-less, cooldown-gated.
func _try_push() -> void:
	if _push_cd > 0.0:
		return
	for body in _push_zone.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("shove"):
			_push_cd = push_cooldown
			var impulse := Vector2(_dir * push_force, -push_up_kick)
			body.shove(impulse)
			print("[RuneOrb] shoved player  dir=%d  impulse=%s  at=%s" %
					[int(_dir), impulse, global_position])
			break


func _arm_reverse_timer() -> void:
	_reverse_timer = randf_range(reverse_time_min, reverse_time_max)


# Trail must stream BEHIND the roll: flip when moving left.
func _apply_facing() -> void:
	_visual.flip_h = _dir < 0.0
