extends Area2D
class_name GolemBall

# A golem's projectile: a ball lobbed in a true gravity parabola toward a captured
# target (fly), bursting (hit) the instant it touches Curiosity or the ground — it does
# not bounce or roll. It leaves the golem's hand already arcing — the
# "launch" charge frames play while it travels, so there's no hang at the head. This is
# a hitbox Area2D, not a physics body — we integrate the arc ourselves so we can solve
# the exact launch velocity that lands on the target.
#
# Lobbed-projectile solve: fire at a FIXED launch angle and back out the launch
# *speed* that lands the ball on the target. Holding the angle constant means the
# arc reads the same lofted shape whether Curiosity is close or far — it always
# leaves the hand already climbing on a clean parabola, instead of the old
# fixed-flight-time solve that shot nearly straight up at close range and flat-and-
# late-curving at long range.

signal hit_player(body: Node2D)

@export_range(20.0, 80.0, 1.0) var launch_angle_deg: float = 71.0  # arc loft; higher = steeper initial upward kick
@export var lob_gravity: float = 9000.0    # downward accel applied each frame; higher = ball travels the arc faster
                                           # (shape/apex set by angle+hang; this only sets speed → keep flight short
                                           #  so leading a moving target stays accurate)
                                           # (Area2D already has a `gravity` field)
# Apex hang: near the top of the arc (small vertical speed) gravity is softened so the
# ball floats sideways across the peak — a broad, rounded crown instead of a sharp point
# — then full gravity resumes for the descent.
@export var apex_hang_speed: float = 520.0   # |vy| below this counts as "near the apex"
@export_range(0.0, 1.0, 0.05) var apex_gravity_scale: float = 0.35  # gravity multiplier in the hang band
@export var damage: int = 10
@export var knockback_force: Vector2 = Vector2(0.0, 0.0)  # shove on Curiosity when it bursts on her
@export var max_lifetime: float = 4.0      # safety despawn while flying (seconds)
@export var rotate_to_velocity: bool = true

enum State { LAUNCH, FLY, HIT }

@onready var _visual: AnimatedSprite2D = $Visual

var _state: int = State.LAUNCH
var _velocity: Vector2 = Vector2.ZERO
var _fly_time: float = 0.0
var _floor_y: float = INF   # global y the ball bursts on at the ground
var _target: Node2D = null
var _dbg: bool = false      # verbose trajectory logging (set by debug harness)
var _hit_radius: float = 30.0   # ball collision radius (read from the shape)


func _ready() -> void:
	_visual.animation_finished.connect(_on_anim_finished)
	body_entered.connect(_on_body_entered)
	var cs := get_node_or_null("CollisionShape2D")
	if cs != null and cs.shape is CircleShape2D:
		_hit_radius = (cs.shape as CircleShape2D).radius
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
	_velocity = _solve_lob()
	_visual.play(&"fly")
	if _dbg and _target != null and is_instance_valid(_target):
		print("[BALL launch] from=", global_position, " target=", _target.global_position,
			" floor_y=", _floor_y, " vel=", _velocity)


# Solve the launch velocity at the fixed angle that lands on the target. Because the
# arc uses softened gravity near the apex (see _physics_process), a closed-form parabola
# no longer matches the real motion — so we simulate the actual variable-gravity arc and
# binary-search the launch speed whose path passes through the target. Higher speed →
# reaches the target's x sooner → less drop → lands higher, so y-at-target falls
# monotonically with speed, which the search exploits.
func _solve_lob() -> Vector2:
	if _target == null or not is_instance_valid(_target):
		return Vector2(200.0, -350.0)   # fall back to a generic forward lob
	# Lead a moving target: the lob hangs ~1s+ in the air, so aiming at where Curiosity
	# stands at launch always lands behind her once she's walking. Predict where she'll
	# be when the ball arrives (pos + velocity·flight_time) and aim there. flight_time
	# depends on the aim, so iterate a few times — it converges fast.
	var tvel: Vector2 = Vector2.ZERO
	if _target is CharacterBody2D:
		tvel = (_target as CharacterBody2D).velocity
	# Fixed-point lead: aim → flight time → new aim. For a fast-approaching target the
	# feedback can oscillate, so damp toward the new estimate rather than jumping to it,
	# which converges cleanly within a handful of iterations.
	# Aim at her cloak/body, not her origin (which sits high) — a downward bias so the ball
	# strikes her middle instead of sailing just over her head.
	var body_off := Vector2(0.0, 45.0)
	var aim: Vector2 = _target.global_position + body_off
	var vel: Vector2 = Vector2.ZERO
	for _iter in range(16):
		var solved: Array = _solve_to(aim)
		vel = solved[0]
		var predicted: Vector2 = _target.global_position + body_off + tvel * float(solved[1])
		aim = aim.lerp(predicted, 0.5)
	return vel


# Fixed-angle arc landing on `aim`. Returns [launch velocity, flight time]. Binary-searches
# the launch speed whose real (apex-hang) arc drops onto the aim point; flight time is exact
# (dx / vx) because horizontal velocity is constant through the flight.
func _solve_to(aim: Vector2) -> Array:
	var to: Vector2 = aim - global_position
	var dir: float = signf(to.x)
	if dir == 0.0:
		dir = 1.0
	var dx: float = maxf(absf(to.x), 1.0)
	var dy: float = to.y                       # +down: target below the launch point
	var ang: float = deg_to_rad(launch_angle_deg)
	var cos_a: float = cos(ang)
	var sin_a: float = sin(ang)
	var lo: float = 50.0
	var hi: float = 16000.0
	for _i in range(34):
		var mid: float = (lo + hi) * 0.5
		# Too much drop at the target (landed below it) → need more speed; else less.
		if _sim_drop_at(mid * cos_a, -mid * sin_a, dx) > dy:
			lo = mid
		else:
			hi = mid
	var speed: float = (lo + hi) * 0.5
	var vx: float = speed * cos_a
	return [Vector2(dir * vx, -speed * sin_a), dx / vx]


# Integrate the same variable-gravity arc the ball actually flies (apex hang included),
# starting level with the launch point, and return its y once it has travelled `target_dx`
# horizontally. Used only by the aim solve.
func _sim_drop_at(vx: float, vy0: float, target_dx: float) -> float:
	var x: float = 0.0
	var y: float = 0.0
	var vy: float = vy0
	var dt: float = 1.0 / 60.0
	var t: float = 0.0
	var px: float = 0.0
	var py: float = 0.0
	while x < target_dx and t < max_lifetime:
		px = x
		py = y
		var g: float = lob_gravity
		if absf(vy) < apex_hang_speed:
			g *= apex_gravity_scale
		vy += g * dt
		x += vx * dt
		y += vy * dt
		t += dt
	# Interpolate the drop at exactly target_dx instead of the step that overshot it.
	if x > px:
		return lerpf(py, y, clampf((target_dx - px) / (x - px), 0.0, 1.0))
	return y


func _enter_hit(body: Node2D) -> void:
	if _state == State.HIT:
		return
	_state = State.HIT
	_visual.rotation = 0.0   # burst sprite reads upright, not tilted to the arc
	# Damage Curiosity on a direct hit (body is null when it bursts on the floor).
	# Knockback shoves her away from the ball's travel direction.
	if body != null and body.has_method("take_damage"):
		var kb := Vector2(signf(_velocity.x) * absf(knockback_force.x), knockback_force.y)
		body.take_damage(damage, kb)
	hit_player.emit(body)
	_visual.play(&"hit")


func _physics_process(delta: float) -> void:
	if _state != State.FLY:
		return
	# Soften gravity near the apex so the ball hangs and curves broadly over the top.
	var g: float = lob_gravity
	if absf(_velocity.y) < apex_hang_speed:
		g *= apex_gravity_scale
	var prev: Vector2 = global_position
	_velocity.y += g * delta
	global_position += _velocity * delta
	if rotate_to_velocity:
		_visual.rotation = _velocity.angle()
	_fly_time += delta
	# Continuous hit test vs Curiosity: a fast ball can move >100px per physics frame, far
	# wider than her ~25px hitbox, so the Area2D body_entered check below can miss it between
	# frames (tunnelling). Sweeping this frame's travel segment against her box catches it
	# regardless of speed. (body_entered stays as a backup for odd cases.)
	if _target != null and is_instance_valid(_target):
		var he: Vector2 = _target_half_extents() + Vector2(_hit_radius, _hit_radius)
		if _segment_hits_box(prev, global_position, _target.global_position, he):
			if _dbg:
				print("[BALL HIT swept] at=", global_position, " t=%.2f" % _fly_time)
			_enter_hit(_target)
			return
	# Touches the ground while descending → burst on the spot. No bounce, no roll.
	if _velocity.y > 0.0 and global_position.y >= _floor_y:
		global_position.y = _floor_y
		_dbg_burst("FLOOR")
		_enter_hit(null)
		return
	# Safety timeout while flying.
	if _fly_time >= max_lifetime:
		_dbg_burst("TIMEOUT")
		_enter_hit(null)


# Half-extents of the target's body collider in world space (Curiosity's RectangleShape2D
# under her scale), so the swept test matches her real hitbox. Falls back to a sane box.
func _target_half_extents() -> Vector2:
	if _target == null or not is_instance_valid(_target):
		return Vector2(20.0, 60.0)
	var s: Vector2 = _target.global_scale.abs()
	for c in _target.get_children():
		if c is CollisionShape2D:
			var shape: Shape2D = (c as CollisionShape2D).shape
			if shape is RectangleShape2D:
				return (shape as RectangleShape2D).size * 0.5 * s
			if shape is CircleShape2D:
				var r: float = (shape as CircleShape2D).radius * maxf(s.x, s.y)
				return Vector2(r, r)
	return Vector2(20.0, 60.0)


# Does the segment a→b intersect the axis-aligned box centred at `c` with half-extents `he`?
# Slab method — true if the travel this frame crossed the (ball-expanded) target box.
func _segment_hits_box(a: Vector2, b: Vector2, c: Vector2, he: Vector2) -> bool:
	var d: Vector2 = b - a
	var tmin: float = 0.0
	var tmax: float = 1.0
	for axis in 2:
		var lo: float = c[axis] - he[axis]
		var hi: float = c[axis] + he[axis]
		if absf(d[axis]) < 0.000001:
			if a[axis] < lo or a[axis] > hi:
				return false
		else:
			var t1: float = (lo - a[axis]) / d[axis]
			var t2: float = (hi - a[axis]) / d[axis]
			if t1 > t2:
				var tmp: float = t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return false
	return true


func _dbg_burst(reason: String) -> void:
	if not _dbg:
		return
	var tpos: String = "?"
	if _target != null and is_instance_valid(_target):
		tpos = "%v dist=%.0f" % [_target.global_position, global_position.distance_to(_target.global_position)]
	print("[BALL burst ", reason, "] at=", global_position, " target=", tpos, " t=%.2f" % _fly_time)


func _on_anim_finished() -> void:
	if _state == State.HIT:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _state != State.FLY:
		return
	if body.is_in_group("player") or body.name == "Curiosity":
		if _dbg:
			print("[BALL HIT player] at=", global_position, " t=%.2f" % _fly_time)
		_enter_hit(body)
