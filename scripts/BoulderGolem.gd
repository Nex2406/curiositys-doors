extends CharacterBody2D
class_name BoulderGolem

## Realm 1 boulder golem — a rock that lurks camouflaged, erupts when Curiosity
## nears, then curls up and ROLL-CHARGES. Armored (invulnerable) mid-roll; only
## killable (2 hits) while waking or recovering. Ground variant here; ceiling
## variant (ceiling_spawner) drops from the roof, then charges.
##
## Animations are built in code from assets/enemies/golem/boulder/ with a per-
## animation offset so the body stays put between states (cells differ in size).

signal died
## It has stopped being part of the rock — see `_enter()`.
signal woke

const DIR := "res://assets/enemies/golem/boulder/"
const SCALE := 0.35   # Advika: smaller golem, then smaller again (2026-07-26)

# per-animation [first, last, fps, loop]; frame ranges are 1-based into each set
const ANIMS := {
	# the eruption itself was half the delay before he could charge — 7fps (1.7s)
	# -> 14fps (0.86s). He bursts out of the ground, he doesn't grow out of it.
	"spawn":       ["golemspawn", 1, 12, 14.0, false],
	"idle":        ["golemidle", 1, 12, 6.0, true],
	"move":        ["golemmove", 1, 12, 10.0, true],
	# Advika 2026-07-26: the wind-up dragged — 10fps (0.60s) -> 17 -> 24fps (0.25s),
	# so the charge reads as a snap decision instead of a long tell.
	"windup":      ["golemrollattack", 1, 6, 24.0, false],
	"roll":        ["golemrollattack", 7, 12, 14.0, true],
	"defeat":      ["golemdefeat", 1, 5, 6.0, false],
	"ceilingspawn":["golemceilingspawn", 1, 12, 6.0, false],
	# the buried CLING pose: the drop sheet's first frame with its loose rubble
	# removed (tools/clean_cling_frame.py) — that debris has already broken free in
	# the art, so while he hangs in the rock it floated in open air under him.
	"cling":       ["golemceilingcling", 1, 1, 1.0, false],
}
# offset (centered sprite): y bottom-aligns the art's REAL ground-contact row to
# the body's collider bottom (local +2 = -44 + r46); x centres the rock body in
# the cell (hand-tuned per pose so the body doesn't jump between states).
# 2026-07-26 — y re-measured from the art, not assumed: the sets do NOT all have
# a 4px bottom margin (idle has 10px, move/spawn ~13), so the golem hovered 2-3px
# over the ground. Contact rows come from `tools/measure_golem_contact.py`
# (deepest ink row across every frame of the set).
const OFFSETS := {
	"spawn": Vector2(4, -116),
	"idle": Vector2(0, -112),
	"move": Vector2(-21, -76),
	"windup": Vector2(17, -74),
	"roll": Vector2(17, -72),
	"defeat": Vector2(0, -122),
	# the ceiling-drop cell has ~111px of empty pad below the body (feet at row 210 of
	# a 322 cell), so align the FEET, not the cell bottom, or it floats.
	# NOTE: y here is only the fallback — this set gets a PER-FRAME offset, below.
	"ceilingspawn": Vector2(0, -50),
	# same canvas + same y as the drop's first frame, so detaching never jumps
	"cling": Vector2(0, 78),
}
## The ceiling-drop sheet animates its OWN fall inside the cell: across frames 1-6
## the body slides from the top of the cell to the bottom (body bottom row 84 →
## 314), then frames 7-12 are the landing burst with the body back at row ~210.
## With the node ALSO falling under gravity that art travel doubled up, so by
## impact the body was drawn ~40px below the physics body and he sank through the
## platform he landed on. These offsets pin every frame's body to the collider
## bottom (local +2), so only physics moves him. Indexed by 0-based frame; derived
## the same way as OFFSETS (deepest ink row that is part of the body, not debris).
const CEIL_FRAME_OFF := [78.0, 42.0, -18.0, -48.0, -112.0, -152.0,
		-52.0, -50.0, -50.0, -46.0, -46.0, -46.0]

@export var ceiling_spawner := false
@export var body_tint: Color = Color(1, 1, 1)   # recolour to the realm's rock
@export var gravity := 1400.0
@export var detect_range := 580.0     # he notices her from further off now
# Advika 2026-07-26: "the player can easily evade the golem by dashing" — the
# charge is faster and runs further now, and it TURNS: if she slips behind him
# mid-roll he swings back around (up to ROLL_TURNS times, after a short beat so
# the turn still reads). A dash is now an escape you have to keep making, not a
# one-press answer.
@export var roll_speed := 470.0
@export var roll_distance := 1100.0
## A charge is COMMITTED. The previous version let him re-aim five times a second,
## which made him vibrate on the spot instead of attacking (Advika 2026-07-26:
## "what's this whole fast rolling back and forth, that's so odd — just make it
## attack"). Now: he picks a direction, runs it, and if he blows past her he rolls
## OVERSHOOT further, stops, gathers himself for RECOVERY_IDLE and comes again.
const OVERSHOOT := 150.0               # px he carries past her before pulling up
const MIN_CHARGE := 260.0              # a charge always covers at least this
@export var contact_damage := 22
@export var body_faces_left := true    # move/roll art faces left

## How long a golem stays up once it has charged (Advika: 5s, then 7s). After this
## it burrows back into the ground and is gone — "after it rolls back and forth /
## chases Curiosity the golem just vanishes or retreats back into the ground".
## The clock starts on its FIRST roll, so waking up is free; only the hunt is timed.
const AWAKE_LIFE := 7.0

## There is no wind-up STATE any more (Advika 2026-07-26: "get rid of winding up,
## it makes the golem take too much time"). The transform frames still play — but
## they play while he is ALREADY charging, so he never stands still telegraphing.
enum S { DORMANT, WAKING, ROLLING, RECOVERY, DYING, CLING, FALLING, LANDING, RETREAT }
var _state: int = S.DORMANT
var _visual: AnimatedSprite2D
var _shape: CollisionShape2D
var _hit_area: Area2D
var _player: Node2D
var _face := -1                 # -1 left, +1 right
var _hits := 0
var _t := 0.0                   # generic state timer
var _shudder_at := 0.0
var _roll_from := 0.0
var _drop_from_y := 0.0         # world y he detached from (arms the collider mid-fall)
var _awake_t := -1.0            # seconds since his first roll; -1 = hasn't charged yet
## GOLEM_LOG=1 prints every state change with its time and place — the only way to
## tell a bad chase from a bad animation without guessing.
var _log := false
var _life := 0.0
var _cur_anim := ""


func _ready() -> void:
	_log = OS.get_environment("GOLEM_LOG") != ""
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 3 if ceiling_spawner else 1   # ceiling golems also land on platforms
	floor_snap_length = 24.0        # stick to the surface (no landing bounce)
	scale = Vector2(SCALE, SCALE)   # node scale; children inherit
	_build_visual()
	_build_shape()
	_build_hit_area()
	_player = get_tree().get_first_node_in_group("player")
	_ignore_player_body()
	if ceiling_spawner:
		_enter(S.CLING)
	else:
		_enter(S.DORMANT)


# ── construction ─────────────────────────────────────────────────────────────
func _build_visual() -> void:
	var sf := SpriteFrames.new()
	for name in ANIMS:
		var spec: Array = ANIMS[name]
		sf.add_animation(name)
		sf.set_animation_loop(name, spec[4])
		sf.set_animation_speed(name, spec[3])
		for i in range(spec[1], spec[2] + 1):
			sf.add_frame(name, load("%s%s%d.png" % [DIR, spec[0], i]))
	_visual = AnimatedSprite2D.new()
	_visual.sprite_frames = sf
	_visual.frame_changed.connect(_on_frame_changed)
	_visual.centered = true
	_visual.z_index = 1
	_visual.modulate = body_tint          # recolour to the realm's rock
	add_child(_visual)


func _build_shape() -> void:
	_shape = CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 46.0
	_shape.shape = c
	_shape.position = Vector2(0, -44)
	_shape.disabled = true          # off until the body forms
	add_child(_shape)


# Area that deals contact damage — live only while ROLLING / landing.
func _build_hit_area() -> void:
	_hit_area = Area2D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 1    # the player's layer
	_hit_area.monitoring = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 52.0
	cs.shape = c
	cs.position = Vector2(0, -44)
	_hit_area.add_child(cs)
	add_child(_hit_area)


# ── animation helper ─────────────────────────────────────────────────────────
func _play(anim: String) -> void:
	if _cur_anim == anim:
		return
	_cur_anim = anim
	_visual.offset = OFFSETS[anim]
	# art faces left; flip when the golem faces right
	_visual.flip_h = (_face > 0)
	if _visual.flip_h:
		_visual.offset.x = -OFFSETS[anim].x
	_visual.play(anim)
	_on_frame_changed()


## The ceiling-drop set carries its own in-cell travel — re-pin the body to the
## node on every frame so gravity is the only thing that moves him.
func _on_frame_changed() -> void:
	if _cur_anim != "ceilingspawn":
		return
	var f: int = clampi(_visual.frame, 0, CEIL_FRAME_OFF.size() - 1)
	_visual.offset.y = CEIL_FRAME_OFF[f]


# ── state machine ────────────────────────────────────────────────────────────
func _enter(s: int) -> void:
	var was_dormant := _state == S.DORMANT
	_state = s
	_t = 0.0
	_enter_body(s)
	# THE MOMENT IT STOPS BEING SCENERY. A DORMANT golem runs no physics at all (see
	# `_physics_process`), which is what lets a level PARENT one to a moving platform
	# and have it ride perfectly — but the instant it erupts it needs to be back in
	# world space, moving under its own gravity, or it would charge along inside a
	# parent that is still sliding around underneath it. Realm 1 listens for this and
	# reparents. Nothing else needs to care.
	if was_dormant and s != S.DORMANT:
		woke.emit()
	# logged AFTER the state's own setup, so `face` is the direction he actually
	# committed to and not the one he had a frame ago
	if _log or OS.get_environment("GOLEM_DEBUG") != "":
		const NAMES := ["DORMANT", "WAKING", "ROLLING", "RECOVERY", "DYING",
				"CLING", "FALLING", "LANDING", "RETREAT"]
		print("[golem %d] t=%5.2f  %-8s  x=%5.0f y=%5.0f  face=%+d  dist=%4d  awake=%.1f"
				% [int(get_instance_id()) % 1000, _life, NAMES[s], global_position.x,
					global_position.y, _face, int(_player_dist()), _awake_t])


func _enter_body(s: int) -> void:
	match s:
		S.DORMANT:
			_shape.disabled = true
			_hit_area.monitoring = false
			_visual.modulate = _camo()     # dimmer, so it blends into the rock
			_play("spawn")
			_visual.stop()
			_visual.frame = 0            # hold frame 1: flat rubble pile
			_shudder_at = randf_range(4.0, 7.0)
		S.WAKING:
			_shape.disabled = false      # it erupts in place on the ground (don't let it fall)
			_visual.modulate = body_tint # revealed — full colour
			# force the eruption to play from the start (bypass the same-anim guard)
			_visual.offset = OFFSETS["spawn"]
			_visual.flip_h = false
			_cur_anim = "spawn"
			_visual.play("spawn")
			_visual.frame = 0
		S.ROLLING:
			_shape.disabled = false
			_hit_area.monitoring = true
			_visual.speed_scale = 1.0    # reset (the ceiling drop retimed it)
			_roll_from = global_position.x
			_face_player()      # commit the charge at HER, wherever she is right now
			if _awake_t < 0.0:
				_awake_t = 0.0  # his life as a hunter starts here
			# the curl-up frames play while he is already moving; _do_rolling swaps
			# to the looping ball the moment they finish
			_play("windup")
		S.RETREAT:
			# out of time: sink back into the rock. The eruption played backwards IS
			# the burrow — same frames, same silhouette, no new art.
			_shape.disabled = true
			_hit_area.monitoring = false
			velocity = Vector2.ZERO
			_cur_anim = "spawn"
			_visual.offset = OFFSETS["spawn"]
			_visual.speed_scale = 1.0
			_visual.play_backwards("spawn")
		S.RECOVERY:
			_shape.disabled = false
			_hit_area.monitoring = false
			_play("move")                # decelerate on the roll-out frames
		S.DYING:
			_shape.disabled = true
			_hit_area.monitoring = false
			velocity = Vector2.ZERO
			_play("defeat")
		S.CLING:
			_shape.disabled = true
			_visual.modulate = _camo()   # dimmer, blends into the ceiling rock
			_play("cling")               # body only — no rubble hanging in the air
			_visual.stop()
			_visual.frame = 0            # hold: clinging, camouflaged in the ceiling
		S.LANDING:
			velocity = Vector2.ZERO      # kill all residual fall velocity — no bounce
			apply_floor_snap()           # stick to the surface it touched
			_shape.disabled = false
			_hit_area.monitoring = true  # impact damages briefly
			_visual.offset = OFFSETS["ceilingspawn"]
			_cur_anim = "ceilingspawn"
			_visual.speed_scale = 1.0
			_visual.play("ceilingspawn")
			_visual.frame = 5            # debris burst frames 6-12 on the ground
			_on_frame_changed()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		_ignore_player_body()
	_t += delta
	_life += delta
	# DORMANT/CLING are placed, collider-less (no gravity/movement). Everything else —
	# including the ceiling FALL and the roll-off-a-ledge arc — is a real physics body.
	if _state == S.DORMANT or _state == S.CLING:
		velocity = Vector2.ZERO
	elif not is_on_floor():
		# clamp fall speed so a fast ceiling drop can't punch through the ground and
		# get bounced back up before it lands (Advika: it bounced then rolled)
		velocity.y = minf(velocity.y + gravity * delta, 700.0)

	# A woken golem gets AWAKE_LIFE seconds of hunting and then burrows away — BUT NOT
	# WHILE SHE IS STILL HERE (Advika 2026-08-02: level 1 is too easy and "it feels
	# boring"). He used to give up on a timer no matter what, so the whole encounter
	# could be solved by standing on a ledge and counting to seven. Now the clock runs
	# the moment he is awake, and expiring only sends him home once she has actually
	# left his range. You leave, or you kill him; you cannot outwait him.
	if _awake_t >= 0.0 and _state != S.RETREAT and _state != S.DYING:
		_awake_t += delta
		if _awake_t >= AWAKE_LIFE and _player_dist() > detect_range \
				and (_state == S.ROLLING or _state == S.RECOVERY):
			_enter(S.RETREAT)

	match _state:
		S.DORMANT: _do_dormant(delta)
		S.WAKING: _do_waking()
		S.ROLLING: _do_rolling(delta)
		S.RECOVERY: _do_recovery(delta)
		S.CLING: _do_cling()
		S.FALLING: _do_falling()
		S.LANDING: _do_landing()
		S.RETREAT: _do_retreat()
		_: pass

	if _state == S.CLING or _state == S.RETREAT:
		return
	if _state != S.ROLLING and _state != S.FALLING:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	move_and_slide()


func _do_dormant(_delta: float) -> void:
	# a subtle shudder every few seconds so a watching player catches the tell
	if _t >= _shudder_at:
		_t = 0.0
		_shudder_at = randf_range(4.0, 7.0)
		var tw := create_tween()
		tw.tween_property(_visual, "position:x", 1.5, 0.1)
		tw.tween_property(_visual, "position:x", 0.0, 0.1)
	# HE WAKES FOR HER BEING NEAR, not for her being on his floor (Advika 2026-08-02:
	# level 1 is too easy, "platforms are a safe zone" — and they were absolute. This
	# used to also require _player_on_my_ground(), so a player who stayed on the
	# platforms never woke a single ground golem in the whole level and could walk the
	# cave end to end without meeting one).
	if _player_dist() <= detect_range:
		_enter(S.WAKING)


func _do_waking() -> void:
	var spawn_dur: float = 12.0 / ANIMS["spawn"][3]     # eruption length
	if _t >= spawn_dur and _cur_anim != "idle":
		_play("idle")                                    # settle, react window
	if _t >= spawn_dur + 0.1:                            # 0.8 -> 0.25 -> 0.1
		# he is up — but he only LAUNCHES if she is down here with him. Otherwise he
		# stands and waits (RECOVERY is the waiting pose) until her feet land.
		_enter(S.ROLLING if _player_on_my_ground() else S.RECOVERY)


func _do_rolling(delta: float) -> void:
	velocity.x = _face * roll_speed
	if _cur_anim == "windup" and not _visual.is_playing():
		_play("roll")            # curled up — now the endless ball
	var run: float = absf(global_position.x - _roll_from)
	# blown past her: carry OVERSHOOT further, then pull up and come again
	var past := false
	if run >= MIN_CHARGE and _player != null and is_instance_valid(_player):
		var dx: float = _player.global_position.x - global_position.x
		past = (_face > 0 and dx < -OVERSHOOT) or (_face < 0 and dx > OVERSHOOT)
	var stop: bool = past or is_on_wall() or run >= roll_distance
	# ground golems never roll off a ledge; the ceiling golem DOES — it rolls off the
	# platform it landed on and gravity carries it down to the ground (Advika).
	if not ceiling_spawner and _no_ground_ahead():
		stop = true
	if stop:
		_enter(S.RECOVERY)


func _do_cling() -> void:
	# Hangs camouflaged in the ceiling; drops when Curiosity is under it. The window
	# was 200px, which on a level this wide meant most passes went by untouched — and
	# the ceiling golem is the ONLY thing in the cave that can reach her up on the
	# platforms, so it is the answer to "platforms are a safe zone". Widened, and it
	# leads her: it drops where she is GOING, not where she was, so simply running
	# through no longer beats it.
	if _player == null or not is_instance_valid(_player):
		return
	if _player.global_position.y <= global_position.y:
		return                                   # she is above it; nothing to drop onto
	var dx: float = _player.global_position.x - global_position.x
	var lead: float = 0.0
	if _player is CharacterBody2D:
		lead = (_player as CharacterBody2D).velocity.x * 0.35
	if absf(dx + lead) < 320.0:
		_start_ceiling_drop()


# detach and FALL with real physics — gravity carries it to whatever's below
# (floor OR a moving platform), playing every drop frame the whole way down.
func _start_ceiling_drop() -> void:
	_state = S.FALLING
	# He clings BURIED in the roof, so his body collider starts inside the ceiling's
	# collider — switching it on here would depenetrate him with a visible jolt.
	# It arms itself a few frames into the fall instead (see _do_falling), once he
	# has cleared the rock. Nothing to collide with up there in the meantime.
	_drop_from_y = global_position.y
	_shape.disabled = true
	_hit_area.monitoring = true
	_visual.modulate = body_tint      # revealed as it detaches
	velocity = Vector2.ZERO
	# play only the FALL/transform frames (1..CEIL_FALL_END) during the drop; the
	# landing-debris frames wait for impact (they were firing mid-air before).
	_visual.offset = OFFSETS["ceilingspawn"]
	_visual.flip_h = false
	_cur_anim = "ceilingspawn"
	_visual.speed_scale = 1.6
	_visual.play("ceilingspawn")
	_visual.frame = 0
	_on_frame_changed()


const CEIL_FALL_END := 5     # last fall/transform frame; 6-12 are the landing burst
const CEIL_CLEAR_DROP := 80.0   # px of fall after which the body collider arms
                                # (he clings well up inside the roof collider)

func _do_falling() -> void:
	# out of the roof rock: the body collider can arm now, in time to land
	if _shape.disabled and global_position.y - _drop_from_y >= CEIL_CLEAR_DROP:
		_shape.disabled = false
	# hold the near-landing fall pose — don't let the debris frames play in the air
	if _visual.frame >= CEIL_FALL_END and _visual.is_playing():
		_visual.pause()
	# She is not ground: a drop that reaches her bounces off and takes off rolling
	# the way she was heading (Advika 2026-07-26 — he used to just sit on her head).
	if _touching_player():
		_bounce_off_player()
		return
	if is_on_floor():                 # impact — NOW play the landing debris
		_enter(S.LANDING)


## Curiosity shares collision layer 1 with the world floor, so his BODY cannot tell
## her from ground — which let him stand on her head and let her shove him around
## like a crate (Advika 2026-07-26: "I can legit just push the golem"). His body now
## ignores her entirely (see _ready) and every interaction with her goes through the
## hit area instead: damage on contact, and the bounce when a drop reaches her.
func _ignore_player_body() -> void:
	if _player != null and is_instance_valid(_player) and _player is PhysicsBody2D:
		add_collision_exception_with(_player)


func _touching_player() -> bool:
	if _player == null or not is_instance_valid(_player) or _hit_area == null:
		return false
	return _hit_area.get_overlapping_bodies().has(_player)


func _bounce_off_player() -> void:
	var dir: int = _face
	if _player != null and is_instance_valid(_player):
		if absf(_player.velocity.x) > 8.0:
			dir = 1 if _player.velocity.x > 0.0 else -1       # the way she is going
		else:
			dir = 1 if _player.global_position.x >= global_position.x else -1
	_set_face(dir)
	_enter(S.ROLLING)
	velocity = Vector2(float(dir) * roll_speed, -240.0)       # kicked off her


func _do_landing() -> void:
	if _touching_player():             # she walked under him mid-impact — same rule
		_bounce_off_player()
		return
	if _visual.frame >= 11 or not _visual.is_playing():
		_enter(S.ROLLING)             # then charge along whatever it landed on


## Burrowing away: when the eruption has finished playing backwards he is gone.
func _do_retreat() -> void:
	if not _visual.is_playing() or _visual.frame <= 0:
		queue_free()


## The gap between charges — Advika 2026-07-26: "reduce the idle to roll timing,
## that's what makes it easier to evade them". 0.4s decel + 2.0s idle is now
## 0.2s + 0.55s, so getting away means keeping moving, not waiting him out.
func _do_recovery(_delta: float) -> void:
	if _t < 0.2:
		return                                   # decelerate on move frames
	if _cur_anim != "idle":
		_play("idle")
		_visual.speed_scale = 1.0
	if _t >= 0.75:
		# THE LAUNCH RULE. He charges when she is in range and roughly over his lane —
		# NOT only when she is standing on his floor. A charge that passes under her
		# platform still costs her the landing: she cannot drop where he is, and he is
		# already moving when she does. Waiting on a ledge is no longer free.
		var dx: float = 1e9
		if _player != null and is_instance_valid(_player):
			dx = absf(_player.global_position.x - global_position.x)
		if _player_dist() <= detect_range and dx <= roll_distance:
			_enter(S.ROLLING)
		elif _player_dist() > detect_range * 1.7:
			_enter(S.DORMANT)                    # clearly gone: re-burrow
		else:
			_t = 0.3                             # in-between: keep idling, don't re-erupt


# ── combat ───────────────────────────────────────────────────────────────────
# Curiosity's swing calls this. Only bites while vulnerable (waking/recovery);
# mid-roll it just sparks. 2 clean hits kill.
func take_damage(_amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
	if _state == S.DYING:
		return
	if _state == S.ROLLING or _state == S.FALLING:
		_spark()
		return
	if _state in [S.WAKING, S.RECOVERY]:
		_hits += 1
		_flash()
		if _hits >= 2:
			_die()


## Killed. He does NOT slump to the floor (Advika 2026-07-26: "they just fall to
## the floor which shouldn't be the case") — the body comes apart where it stands
## and scatters as little brown stones that arc out, bounce once and fade.
func _die() -> void:
	_enter(S.DYING)
	died.emit()
	_burst()
	_visual.visible = false
	await get_tree().create_timer(1.4).timeout       # let the rubble live a moment
	queue_free()


## The body coming apart: a handful of small rock-coloured lumps thrown outward,
## each falling under its own gravity and fading. Drawn as circles in code, tinted
## from the golem's own body colour so they read as HIS stone, not generic dust.
func _burst() -> void:
	var host := get_parent()
	if host == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x) * 7 + int(global_position.y)
	var origin := global_position + Vector2(0.0, -24.0 * SCALE)
	# Advika 2026-07-26: "tiny tiny brown hues, not those thick ugly ass circles" —
	# many small irregular grit specks, not a handful of fat pebbles.
	for i in range(34):
		var lump := Polygon2D.new()
		var r := rng.randf_range(1.1, 3.4)
		var pts := PackedVector2Array()
		for a in range(5):                      # a chip of grit, not a disc
			var ang := TAU * float(a) / 5.0 + rng.randf_range(-0.3, 0.3)
			var rr := r * rng.randf_range(0.55, 1.3)
			pts.append(Vector2(cos(ang), sin(ang)) * rr)
		lump.polygon = pts
		lump.color = body_tint * rng.randf_range(0.30, 0.66)
		lump.color.a = rng.randf_range(0.75, 1.0)
		lump.position = origin + Vector2(rng.randf_range(-18.0, 18.0),
				rng.randf_range(-16.0, 14.0))
		lump.z_index = z_index + 1
		host.add_child(lump)
		# thrown out and up, then gravity takes it
		var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, -0.35)).normalized()
		var speed := rng.randf_range(90.0, 240.0)
		var life := rng.randf_range(0.55, 1.1)
		var to := lump.position + dir * speed * life + Vector2(0.0, 260.0 * life * life)
		var tw := lump.create_tween()
		tw.set_parallel(true)
		tw.tween_property(lump, "position", to, life).set_trans(Tween.TRANS_QUAD)\
				.set_ease(Tween.EASE_IN)
		tw.tween_property(lump, "rotation", rng.randf_range(-4.0, 4.0), life)
		tw.tween_property(lump, "modulate:a", 0.0, life * 0.9)\
				.set_delay(life * 0.15)
		tw.chain().tween_callback(lump.queue_free)


func _flash() -> void:
	_visual.modulate = Color(2.4, 2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", body_tint, 0.18)


func _spark() -> void:
	_visual.modulate = Color(1.8, 1.8, 2.0)
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", body_tint, 0.1)


func _process(_d: float) -> void:
	# contact damage while rolling / landing
	if _hit_area != null and _hit_area.monitoring:
		for b in _hit_area.get_overlapping_bodies():
			if b.is_in_group("player") and b.has_method("take_damage"):
				var kb := Vector2(_face * 260.0, -160.0)
				b.take_damage(contact_damage, kb)


# ── helpers ──────────────────────────────────────────────────────────────────
func _camo() -> Color:
	return Color(body_tint.r * 0.5, body_tint.g * 0.5, body_tint.b * 0.5)


func _player_dist() -> float:
	if _player == null or not is_instance_valid(_player):
		return 1e9
	return global_position.distance_to(_player.global_position)


## Is she standing on HIS ground — not floating past, not up on a platform?
## Advika 2026-07-27: "make the golem in idle wait, and the second her feet hit the
## ground LAUNCH it". A golem erupting under a player who is safely up on a platform
## looked silly and cost nothing; now the threat is tied to being down there with it.
func _player_on_my_ground() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if not _player.is_on_floor():
		return false
	return absf(_player.global_position.y - global_position.y) < 150.0


func _face_player() -> void:
	if _player != null and is_instance_valid(_player):
		_set_face(1 if _player.global_position.x > global_position.x else -1)


## Turn to face `f` and mirror the CURRENT pose immediately. Facing used to be
## applied only when the animation changed, so a golem that turned mid-pose kept
## the old art (Advika 2026-07-26: "he only rolls when he faces left — it should
## depend on which way Curiosity is").
func _set_face(f: int) -> void:
	if f == _face:
		return
	_face = f
	if _visual == null or _cur_anim == "":
		return
	_visual.flip_h = (_face > 0)
	var off: Vector2 = OFFSETS[_cur_anim]
	_visual.offset.x = -off.x if _visual.flip_h else off.x


# raycast just ahead + down; no floor there → a ledge
func _no_ground_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(_face * 55.0, -10.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 90.0), 1)
	q.exclude = [self]
	return space.intersect_ray(q).is_empty()
