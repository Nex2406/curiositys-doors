extends Node2D
class_name VoidMoth

# The Void Moth — an independent creature of the storm-sky (NOT the wizard's;
# it arrives on its own, drawn to the climb). One slit eye, wings of void.
# It stalks near the island, bobbing, and dive-bombs Curiosity.
#
# IT CANNOT BE STRUCK DOWN. There is no take_damage here, it lives on no
# physics layer her swing scans — the void ignores the blade. It dies ONLY
# to LIGHT (Advika, 2026-07-14): hold L and Curiosity's lantern swells;
# sustained light on the moth (burn_time, ~5s) whitens it, then a white-
# purple flash, then the death motes fade to nothing.
#
# Lifecycle: enter_from() flies it in on a curved path (inactive until it
# arrives) -> STALK: CONTINUOUS prowling flight, patch to patch of air
# around the climbing island (steered velocity — banks, never parks) ->
# DIVE: a bezier swoop with a windup breath, whipping THROUGH her, exit
# velocity blending straight back into the roam -> STALK...
# exit_flyaway() sends it off upward (the wizard fell; it loses interest).

signal died_to_light()
signal burst_on_strike()   # it spent itself on the hit — one dive, one moth

const FRAME_DIR := "res://assets/enemies/void_moth/"
const FLY_FRAMES := 12
const ATTACK_FIRST := 4     # sheet frames 1-3 are body windups — they read
                            # UNEVEN against the streak (Advika); the tremble
                            # telegraph is the windup, the clip is pure speed
const ATTACK_FRAMES := 6    # frames 4-9 of Advika's comet sheet (2026-07-17)
const DEATH_FRAMES := 3
const FLY_FPS := 12.0
const ATTACK_FPS := 14.0    # slow stepping read ROUGH (Advika) — snappy now
const DEATH_FPS := 5.0
# Advika's turn sheet (2026-07-17): the moth TUCKS into a wing-shroud (the
# eye vanishes) and bursts back out into a streaking glide. The facing swap
# happens at the fold frame — fully wrapped, no visible asymmetry — so the
# old scale.x wheel-sweep is gone. The same clip plays on darts: every
# lunge is a tuck-and-burst. (Frame count scanned, not fixed: sheet is 11
# frames until voidturn10 lands, 12 after.)
const TURN_FOLD_FRAME := 5
const STING_REACH := 130.0     # pre-scale contact reach during a dive (distance test —
                               # an Area2D missed at swoop speeds; Advika: no damage)
# The island as an OBSTACLE (Advika, round 2: it still passed through — the
# old clamp teleported under-island moths up through the deck). A soft
# repulsion field around the island's body: the moth steers AROUND it, over
# or under, like a creature avoiding a thing — never snapped, never inside.
const ISLAND_HALF := Vector2(660.0, 210.0)  # the moss body incl. fringe
const AVOID_MARGIN := 150.0                 # repulsion starts this far out
const AVOID_PUSH := 1500.0                  # steering force at deepest penetration
const DIVE_DECK_CLEAR := 140.0              # dives level off this far above the moss top

@export var burn_time := 4.0         # seconds in the light before it bursts (Advika)
@export var burn_leak := 0.25        # burn decays at this rate when unlit (forgiving, not a reset)
@export var bob_amplitude := 14.0
@export var bob_period := 2.1
@export var roam_speed := 240.0      # cruising speed while it prowls the sky
@export var roam_retarget_min := 1.6 # how often it picks a new patch of air
@export var roam_retarget_max := 3.2
@export var flutter := 40.0          # small erratic wing impulses on top of the wander
@export var max_turn := 2.6          # rad/s — every course change is a CARVED ARC; a
                                     # target behind it means a visible loop to come
                                     # about (Advika: the lerp-turns read robotic)
@export var wander_drift := 0.9      # rad/s of continuous heading wander — it never
                                     # flies straight, even when it likes its patch
@export var wingbeat_surge := 0.32   # speed pulses with the wingbeat (surge + coast)
@export var dive_wait_min := 2.6     # beat between dives
@export var dive_wait_max := 4.6
@export var dive_damage := 10
@export var dive_knockback := Vector2(300.0, -140.0)
@export var dive_overshoot := 150.0  # px past her position the swoop carries
# Round 3 (Advika: "more movey and dynamic") — the missing thing wasn't the
# curves, it was CONTRAST and REACTION: one cruise energy forever reads flat
# no matter how carved the path is. So the flight now has gears — darts,
# stalls — and a temperament: the light frightens it.
@export var dart_speed_mult := 2.3   # a sudden lunge — top gear
@export var dart_time := 0.32
@export var impulse_wait_min := 1.3  # beat between darts/stalls
@export var impulse_wait_max := 3.0
@export var stall_time := 0.34       # the hover-hesitation before it whips away
@export var panic_speed_mult := 1.15 # lit: it flees, but fear can't outrun light
@export var panic_turn_boost := 1.8  # and wheels harder while it panics
@export var turn_fps := 14.0         # turn-sheet speed (24 read as a blur — Advika)

enum State { ENTER, STALK, DIVE, BURNED, EXIT }

var state := State.ENTER
var _visual: AnimatedSprite2D
var _anchor: Node2D = null       # what it rides (the island)
var _anchor_offset := Vector2.ZERO
var _target: Node2D = null       # who it stalks (Curiosity)
var _ht := 0.0
var _dive_timer := 0.0
var _dive_hit := false
var _light_t := 0.0              # accumulated burn
var _tw: Tween
var _enter_spawn := Vector2.ZERO # bezier start of the fly-in
var _enter_arc := Vector2.ZERO   # bezier bow
var _vel := Vector2.ZERO         # steering velocity — flight is CONTINUOUS, never parked
var _heading := 0.0              # the flight IS this angle: it only ever turns, at a
                                 # limited rate — position follows the heading, so
                                 # every path is a curve (the organic read)
var _roam_offset := Vector2.ZERO # current patch of air (anchor-relative)
var _roam_timer := 0.0
var _roam_pace := 1.0            # per-patch speed personality
var _flutter_timer := 0.0        # next erratic wing impulse
var _face_target := -1.0         # which way it's wheeling to face (-1 left, +1 right)
var _facing := -1.0              # displayed facing; swaps inside the turn's fold
var _dive_prev := Vector2.ZERO   # last dive sample, for exit-velocity blending
var _dive_pts: Array[Vector2] = []   # cubic talon-arc control points
var _whip := false               # the carve is flying (pose locked to the path)
var _impulse_timer := 1.5        # next dart-or-stall
var _dart_t := 0.0               # time left in the current dart
var _stall_t := 0.0              # time left in the current stall
var _lit := false                # the lantern's kill-light is on it (with grace)
var _lit_grace := 0.0            # brief stickiness so edge flicker can't re-arm dives
var _stretch := 0.0              # velocity squash/stretch on the sprite
var _dive_shrink := 0.0          # late-dive shrink: the comet plunges INTO her
var _flare := 0.0                # dive-telegraph glow (mixed into the burn tint)
var _ghost_timer := 0.0          # afterimage shedding cadence


func _ready() -> void:
	add_to_group("moths")
	_visual = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for spec in [["fly", 1, FLY_FRAMES, FLY_FPS, true],
			["attack", ATTACK_FIRST, ATTACK_FRAMES, ATTACK_FPS, false],
			["death", 1, DEATH_FRAMES, DEATH_FPS, false]]:
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[3])
		frames.set_animation_loop(spec[0], spec[4])
		for i in range(spec[1], spec[1] + spec[2]):
			frames.add_frame(spec[0], load("%s%s_%02d.png" % [FRAME_DIR, spec[0], i]))
	frames.add_animation(&"turn")
	frames.set_animation_speed(&"turn", turn_fps)
	frames.set_animation_loop(&"turn", false)
	# PING-PONG fold (Advika, two rounds): the sheet's tail sees the moth
	# from BEHIND and then streaks — any trim ended back-facing and popped
	# into the front-view fly loop ("faces backward then suddenly forward").
	# So: front → folded → front again, unfolding in reverse. The mirror
	# swaps at the apex; both ends land on the fly silhouette.
	for f in [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]:
		frames.add_frame(&"turn", load("%sturn_%02d.png" % [FRAME_DIR, f]))
	_visual.sprite_frames = frames
	add_child(_visual)
	_visual.play(&"fly")
	_visual.animation_finished.connect(_on_anim_finished)


# Fly in from `spawn_global` to a hover post (anchor + offset) on a gentle
# arc, ~1.2s, harmless until it lands. Then the stalk begins.
func enter_from(spawn_global: Vector2, anchor: Node2D, anchor_offset: Vector2,
		target: Node2D) -> void:
	_anchor = anchor
	_anchor_offset = anchor_offset
	_target = target
	global_position = spawn_global
	state = State.ENTER
	# quadratic bezier toward the (moving) hover post; the control point
	# bows the path sideways so it sweeps in, never beelines
	_enter_spawn = spawn_global
	var side := 1.0 if randf() < 0.5 else -1.0
	_enter_arc = Vector2(side * randf_range(180.0, 320.0), randf_range(-60.0, 60.0))
	_tw = create_tween()
	_tw.tween_method(_enter_step, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	_tw.finished.connect(func() -> void:
		if state == State.ENTER:
			state = State.STALK
			_pick_roam()
			_arm_dive())


# One step of the fly-in bezier — the destination is sampled live because
# the island keeps climbing while the moth is inbound.
func _enter_step(t: float) -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		return
	var dest: Vector2 = _anchor.global_position + _anchor_offset
	var ctrl: Vector2 = _enter_spawn.lerp(dest, 0.5) + _enter_arc
	var a := _enter_spawn.lerp(ctrl, t)
	var b := ctrl.lerp(dest, t)
	var prev := global_position
	global_position = a.lerp(b, t)
	_push_out_of_island(maxf(get_physics_process_delta_time(), 0.001))
	# keep the look alive during the approach too
	var dt := maxf(get_physics_process_delta_time(), 0.001)
	_vel = (global_position - prev) / dt * 0.6


# The wizard fell — the moth loses interest and leaves, upward and gone.
func exit_flyaway() -> void:
	if state in [State.BURNED, State.EXIT]:
		return
	state = State.EXIT
	_whip = false
	if _tw != null:
		_tw.kill()
	_visual.play(&"fly")
	var up := global_position + Vector2(randf_range(-250.0, 250.0), -1400.0)
	_tw = create_tween()
	_tw.tween_property(self, "global_position", up, 1.6).set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(self, "modulate:a", 0.0, 1.6)
	_tw.finished.connect(queue_free)


func _physics_process(delta: float) -> void:
	_ht += delta
	match state:
		State.STALK:
			if _visual.animation == &"attack":
				_visual.play(&"fly")   # back from a held comet (missed dive)
			# CONTINUOUS flight (Advika: it felt stiff, parked): it prowls
			# from air-patch to air-patch around the climbing island, steering
			# smoothly — and FLUTTERS: erratic little wing impulses between
			# headings, because real moths never fly a clean line.
			_roam_timer -= delta
			if _roam_timer <= 0.0:
				_pick_roam()
			_flutter_timer -= delta
			if _flutter_timer <= 0.0:
				_flutter_timer = randf_range(0.15, 0.38)
				_vel += Vector2.from_angle(randf() * TAU) * randf_range(0.5, 1.0) * flutter
			# gears: every few beats it either DARTS (a lunge on a new bearing)
			# or STALLS (hangs fluttering — then the next dart whips it away).
			# A lit moth never stalls: fear picks the fast gear every time.
			_impulse_timer -= delta
			if _impulse_timer <= 0.0:
				_impulse_timer = randf_range(impulse_wait_min, impulse_wait_max) \
						* (0.55 if _lit else 1.0)
				if _lit or randf() < 0.65:
					_start_dart()
				else:
					_stall_t = stall_time * randf_range(0.8, 1.3)
			_dart_t = maxf(0.0, _dart_t - delta)
			_stall_t = maxf(0.0, _stall_t - delta)
			if _lit and _roam_timer > 1.0:
				_roam_timer = 1.0   # panicking: it won't sit in this patch of air
			if _anchor != null and is_instance_valid(_anchor):
				# HEADING FLIGHT: it can only TURN, never re-aim — so the path
				# toward each patch is a bank, an overshoot, a loop back. Two
				# incommensurate sines drift the heading continuously (it
				# wanders even mid-course), and speed surges with the wingbeat.
				var to_patch: Vector2 = (_anchor.global_position + _roam_offset) - global_position
				var bearing := to_patch.angle()
				var diff := wrapf(bearing - _heading, -PI, PI)
				var wander := sin(_ht * 1.7) * 0.9 + sin(_ht * 2.9 + 1.3) * 0.6
				var turn_cap := max_turn * (panic_turn_boost if _lit else 1.0)
				var drift := wander_drift * (1.6 if _lit else 1.0)
				_heading += (clampf(diff * 2.6, -turn_cap, turn_cap) \
						+ wander * drift) * delta
				var pulse := 1.0 + sin(_ht * TAU / 0.62) * wingbeat_surge
				var arrive := clampf(to_patch.length() / 140.0, 0.35, 1.0)
				var speed := roam_speed * _roam_pace * pulse * arrive
				if _lit:
					speed *= panic_speed_mult
				if _dart_t > 0.0:
					speed *= dart_speed_mult
				elif _stall_t > 0.0:
					speed *= 0.12   # wings blurring, body hanging — the hesitation
				# the light UNMAKES what it burns: a lit moth falters, losing
				# up to half its wings' strength — panic without escape.
				# (Advika: holding L never finished the kill; the panic flee
				# simply outran the lantern's 340px reach forever.)
				speed *= 1.0 - 0.55 * clampf(_light_t / burn_time, 0.0, 1.0)
				_vel = _vel.lerp(Vector2.from_angle(_heading) * speed, 1.0 - pow(0.001, delta))
				_vel += _island_repulsion() * delta
				_heading = _vel.angle()   # repulsion + flutter carve the heading too
				global_position += _vel * delta
				_push_out_of_island(delta)
			_visual.position.y = sin(_ht * TAU / bob_period) * bob_amplitude
			_dive_timer -= delta
			# dives launch only from ABOVE the deck — a belly-roamer waits
			# until its prowl brings it around (a dive from below would have
			# to tunnel the island)
			# a lit moth still TRIES — the dive breaks on the light-wall and
			# costs it burn, so defiance is how it dies fastest (a hard
			# no-dive-while-lit gate just made it circle harmlessly; Advika:
			# "now hes not attacking only")
			if _dive_timer <= 0.0 \
					and _target != null and is_instance_valid(_target) \
					and _anchor != null and is_instance_valid(_anchor) \
					and global_position.y < _anchor.global_position.y - 120.0:
				_begin_dive()
		State.DIVE:
			# the light is a WALL to it: a dive that meets the swelled glow
			# BREAKS OFF, scorched — it cannot press the attack through the
			# burn. (Advika: "when it starts attacking it doesnt detect the
			# light" — the scripted arc used to fly through regardless.)
			if _lit and not _dive_hit:
				_abort_dive()
			else:
				_check_sting()
		_:
			pass
	_apply_flight_look(delta)
	_tick_burn(delta)
	# void afterimages whenever it's truly moving fast — dive whips and darts
	if state != State.BURNED and _vel.length() > roam_speed * 1.5:
		_shed_ghost(delta)


# A lunge: the heading JUMPS (the one place a snap is right — moths dart),
# then the speed burst carries it. A frightened dart aims away from the glow.
func _start_dart() -> void:
	_dart_t = dart_time * randf_range(0.85, 1.25)
	_stall_t = 0.0
	if _visual.animation == &"fly":
		_visual.play(&"turn")   # every lunge is a tuck-and-burst
	var jink := randf_range(0.5, 1.1) * (1.0 if randf() < 0.5 else -1.0)
	if _lit and _target != null and is_instance_valid(_target) \
			and _target.has_method("light_state"):
		var away: float = (global_position - _target.light_state()[0]).angle()
		_heading = away + jink * 0.45
	else:
		_heading += jink


# Ghost sprites shed along a fast path — they hold the pose (bank, facing,
# stretch) and dissolve violet. Parented to the scene so they hang in the
# air the moth just left.
func _shed_ghost(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = 0.05
	var tex := _visual.sprite_frames.get_frame_texture(_visual.animation, _visual.frame)
	if tex == null or get_parent() == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.modulate = Color(0.62, 0.4, 0.95, 0.38)
	g.z_index = z_index
	get_parent().add_child(g)
	g.global_transform = _visual.global_transform
	g.offset = _visual.offset
	g.flip_h = _visual.flip_h   # flip lives outside the transform
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.28)
	tw.finished.connect(g.queue_free)


# Repulsion field around the island's body: grows from zero at AVOID_MARGIN
# out, to full push at the surface. The moth BANKS AROUND the island — over
# or under, whichever side it approaches — steered, never snapped.
func _island_repulsion() -> Vector2:
	if _anchor == null or not is_instance_valid(_anchor):
		return Vector2.ZERO
	var d := global_position - (_anchor.global_position + Vector2(0, -40.0))
	var span := ISLAND_HALF + Vector2(AVOID_MARGIN, AVOID_MARGIN)
	var nx := absf(d.x) / span.x
	var ny := absf(d.y) / span.y
	var closeness := 1.0 - maxf(nx, ny)   # 0 at the margin edge, 1 at the core
	if closeness <= 0.0:
		return Vector2.ZERO
	# push along the axis it's shallowest on — around the nearest face
	var n := Vector2(d.x / span.x, d.y / span.y).normalized()
	return n * AVOID_PUSH * closeness


# Last-resort correction: if a step still landed INSIDE the body, slide it
# out continuously (never a teleport — a firm shove toward the nearest face).
func _push_out_of_island(delta: float) -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		return
	var c: Vector2 = _anchor.global_position + Vector2(0, -40.0)
	var d := global_position - c
	if absf(d.x) < ISLAND_HALF.x and absf(d.y) < ISLAND_HALF.y:
		var n := Vector2(d.x / ISLAND_HALF.x, d.y / ISLAND_HALF.y)
		if n == Vector2.ZERO:
			n = Vector2(0, -1)
		global_position += n.normalized() * 700.0 * delta


# Flight is a body, not a sprite slide (Advika: it only faced one way, huh?):
# it WHEELS to face its heading — the mirror is animated through the turn so
# you see it come about, wings edge-on mid-wheel — banks into turns, and
# beats its wings faster the harder it flies.
func _apply_flight_look(delta: float) -> void:
	if state in [State.BURNED]:
		return
	# WHO to face: a stalking hunter watches HER (Advika: it never faced
	# Curiosity — it was facing its own travel direction). Darts and the
	# exit face their motion. A DIVING moth changes nothing — its pose was
	# locked to the carve at launch (mid-dive flips fed the 360 pirouette).
	if state == State.DIVE:
		pass
	elif state == State.STALK and _dart_t <= 0.0 \
			and _target != null and is_instance_valid(_target):
		var dx := _target.global_position.x - global_position.x
		if absf(dx) > 60.0:   # hysteresis: no flip-flutter straight overhead
			_face_target = signf(dx)
	elif _vel.x < -40.0:
		_face_target = -1.0
	elif _vel.x > 40.0:
		_face_target = 1.0
	# facing is ANIMATED: a stalk-flight direction change plays the tuck-and-
	# burst turn sheet, and the mirror swap hides inside the fold frame (fully
	# wrapped — no visible asymmetry to pop). Outside stalk flight (mid-dive,
	# fly-in) the flip is instant; the speed masks it.
	if _face_target != _facing:
		if state == State.STALK and _visual.animation == &"fly":
			_visual.play(&"turn")
		elif _visual.animation != &"turn":
			_facing = _face_target
			_visual.flip_h = _facing > 0.0
	if _visual.animation == &"turn" and _visual.frame >= TURN_FOLD_FRAME \
			and _facing != _face_target:
		_facing = _face_target
		_visual.flip_h = _facing > 0.0
	# stretch: the body lengthens along a burst and thins, settles plump again
	var goal := clampf((_vel.length() - roam_speed) / (roam_speed * 2.2), 0.0, 0.34)
	_stretch = lerpf(_stretch, goal, 1.0 - pow(0.01, delta))
	if state != State.DIVE:
		_dive_shrink = maxf(0.0, _dive_shrink - delta * 3.0)  # missed: swell back
	_visual.scale = Vector2(1.0 + _stretch, 1.0 - _stretch * 0.55) \
			* (1.0 - 0.62 * _dive_shrink)
	var bank := clampf(_vel.x * 0.00045, -0.22, 0.22)
	if _whip and _vel.length() > 60.0:
		# the comet aims DOWN ITS OWN PATH — but only once the carve is
		# actually flying (aligning during the telegraph chased stale
		# velocity and fed the pirouette)
		var a := _vel.angle()
		bank = a if _visual.flip_h else wrapf(a - PI, -PI, PI)
	_visual.rotation = lerp_angle(_visual.rotation, bank, 1.0 - pow(0.001, delta))
	if _visual.animation == &"fly":
		if _stall_t > 0.0:
			_visual.speed_scale = 1.9   # a stall hangs the body, not the wings
		else:
			_visual.speed_scale = clampf(0.85 + _vel.length() / 420.0, 0.85, 1.6)
	elif _visual.animation == &"turn":
		_visual.speed_scale = 1.0


# A fresh patch of air — wide, varied, alive. It ranges the WHOLE island:
# mostly the sky above, sometimes swinging wide past a side, occasionally
# dipping below the underbelly (the repulsion field walls off the body, so
# crossing sides means flying AROUND — which is exactly the good look).
func _pick_roam() -> void:
	_roam_timer = randf_range(roam_retarget_min, roam_retarget_max)
	_roam_pace = randf_range(0.7, 1.3)
	var roll := randf()
	if roll < 0.62:      # the sky over the deck
		_roam_offset = Vector2(randf_range(-450.0, 450.0), randf_range(-520.0, -200.0))
	elif roll < 0.86:    # wide past a side
		var side := 1.0 if randf() < 0.5 else -1.0
		_roam_offset = Vector2(side * randf_range(720.0, 950.0), randf_range(-350.0, 150.0))
	else:                # under the island's belly — ominous
		_roam_offset = Vector2(randf_range(-400.0, 400.0), randf_range(300.0, 480.0))


# --- the dive ---

func _arm_dive() -> void:
	_dive_timer = randf_range(dive_wait_min, dive_wait_max)


func _begin_dive() -> void:
	state = State.DIVE
	_dive_hit = false
	_whip = false
	# The turn-as-windup pairing is DEAD (Advika: the whole turn-attack
	# thing felt wrong) — the dive telegraphs with its own brief cocked
	# tremble + eye flare, then carves. Turns belong to flight only.
	if _tw != null:
		_tw.kill()
	_vel *= 0.35
	_tw = create_tween()
	_tw.tween_method(func(k: float) -> void: _flare = k, 0.0, 1.0, 0.22)
	_tw.finished.connect(_launch_dive_whip)


# The whip itself: a SWOOP, not a straight stab — a bezier that first lifts
# against the approach (the windup bow), then whips down THROUGH her and
# past. Aim is taken NOW, post-telegraph, so the hang is her dodge window.
# The exit velocity is measured off the curve, so the pull-out blends
# straight back into the roam — no snap anywhere.
func _launch_dive_whip() -> void:
	if _tw != null:
		_tw.kill()   # the flare ramp — else it keeps writing _flare
	_flare = 0.0
	if state != State.DIVE:
		return
	if _target == null or not is_instance_valid(_target):
		state = State.STALK
		_pick_roam()
		_arm_dive()
		return
	_visual.play(&"attack")
	var her: Vector2 = _target.global_position
	var sx := signf(her.x - global_position.x)
	if sx == 0.0:
		sx = 1.0
	# THE TALON ARC (cubic bezier): bow down early, sweep in LOW from the
	# approach side, carve THROUGH her, exit rising past her — a swoop, not
	# a ruler line (Advika: "it moves in a straight line... not what i want")
	_dive_pts = [
		global_position,
		global_position + (her - global_position) * 0.3 + Vector2(0.0, 160.0),
		her + Vector2(-sx * 80.0, 80.0),
		her + Vector2(sx * dive_overshoot, -120.0),
	]
	# pose locks to the carve at launch: face travel ONCE, rotation snapped
	# to the opening tangent — no more mid-air pirouette (Advika: "does a
	# 360 in air... hideous"; rotation was lerping from a stale angle while
	# the facing flipped underneath it)
	_whip = true
	_facing = sx
	_face_target = sx
	_visual.flip_h = sx > 0.0
	var tangent := (_dive_pts[1] - _dive_pts[0]).normalized()
	_visual.rotation = tangent.angle() if _visual.flip_h \
			else wrapf(tangent.angle() - PI, -PI, PI)
	_dive_prev = global_position
	_tw = create_tween()
	_tw.tween_method(_dive_step, 0.0, 1.0, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.finished.connect(func() -> void:
		if state != State.DIVE:
			return
		_whip = false
		state = State.STALK
		# carry the swoop's exit speed into the roam — the pull-out IS flight
		_pick_roam()
		_arm_dive())


# One step of the talon-arc cubic; tracks its own derivative so the roam
# can inherit the exit velocity.
func _dive_step(t: float) -> void:
	var q0 := _dive_pts[0].lerp(_dive_pts[1], t)
	var q1 := _dive_pts[1].lerp(_dive_pts[2], t)
	var q2 := _dive_pts[2].lerp(_dive_pts[3], t)
	var pos := q0.lerp(q1, t).lerp(q1.lerp(q2, t), t)
	# the last stretch of the swoop shrinks the comet — it doesn't hit her,
	# it goes INSIDE her (Advika); the burst finishes the swallow
	_dive_shrink = clampf(inverse_lerp(0.55, 1.0, t), 0.0, 1.0)
	var dt := maxf(get_physics_process_delta_time(), 0.001)
	_vel = (pos - _dive_prev) / dt * 0.6   # damped: inherit the sweep, not the spike
	_dive_prev = pos
	global_position = pos
	# a dive comes from above and levels off just over the moss — it strafes
	# HER, it doesn't tunnel the deck
	if _anchor != null and is_instance_valid(_anchor) \
			and absf(global_position.x - _anchor.global_position.x) < ISLAND_HALF.x:
		var floor_y: float = _anchor.global_position.y - 120.0 - DIVE_DECK_CLEAR
		if global_position.y > floor_y:
			global_position.y = floor_y


# A dive refused by the light: kill the arc, recoil hard away from the
# glow, and take a bite of burn for daring — aggressive light play chews
# through it dive by dive.
func _abort_dive() -> void:
	if _tw != null:
		_tw.kill()
	_whip = false
	_light_t += 0.35
	state = State.STALK
	_visual.play(&"fly")
	if _target != null and is_instance_valid(_target) \
			and _target.has_method("light_state"):
		var away: Vector2 = (global_position - _target.light_state()[0]).normalized()
		_vel = away * roam_speed * 1.6
		_heading = _vel.angle()
	_pick_roam()
	_arm_dive()


func _check_sting() -> void:
	if _dive_hit or _target == null or not is_instance_valid(_target):
		return
	# plain reach test — physics areas missed at swoop speeds
	var reach := STING_REACH * absf(global_scale.x)
	if global_position.distance_to(_target.global_position) <= reach \
			and _target.has_method("take_damage"):
		_dive_hit = true
		var kb := Vector2(signf(_target.global_position.x - global_position.x)
				* absf(dive_knockback.x), dive_knockback.y)
		_target.take_damage(dive_damage, kb)
		_burst()


# The strike consumes it (Advika: satisfying) — the moth detonates into a
# spray of tiny purple motes and is gone. One dive, one moth.
func _burst() -> void:
	if state == State.BURNED:
		return
	state = State.BURNED
	_whip = false
	if _tw != null:
		_tw.kill()
	_visual.visible = false
	_mote_burst()
	burst_on_strike.emit()
	get_tree().create_timer(1.0).timeout.connect(queue_free)


# The moth's one death look: a spray of tiny purple motes drifting upward —
# void returns to void.
func _mote_burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 44
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.texture = load("res://assets/realms/realm2_moss/spore.png")
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 34.0
	p.spread = 180.0
	p.gravity = Vector2(0, -50)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 330.0
	p.scale_amount_min = 0.22
	p.scale_amount_max = 0.55
	p.color = Color(0.66, 0.42, 1.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	add_child(p)


# --- the burn (the only death) ---

func _tick_burn(delta: float) -> void:
	if state in [State.ENTER, State.BURNED, State.EXIT]:
		return
	var in_light := false
	if _target != null and is_instance_valid(_target) and _target.has_method("light_state"):
		var ls: Array = _target.light_state()
		in_light = global_position.distance_to(ls[0]) <= float(ls[1])
	if in_light:
		_lit_grace = 0.35
		_light_t += delta
	else:
		_lit_grace = maxf(0.0, _lit_grace - delta)
		_light_t = maxf(0.0, _light_t - delta * burn_leak)
	_lit = in_light or _lit_grace > 0.0
	# the burn shows: it whitens and trembles as the light unmakes it. The
	# dive telegraph's flare shares this write (one owner for tint + shake,
	# or the two effects stomp each other frame by frame).
	var k := clampf(_light_t / burn_time, 0.0, 1.0)
	_visual.modulate = Color(1.0 + k * 1.2 + _flare * 0.45,
			1.0 + k * 0.9 + _flare * 0.15, 1.0 + k * 1.4 + _flare * 0.8)
	_visual.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* (k * 5.0 + _flare * 3.0)
	if _light_t >= burn_time:
		_burn_out()


func _burn_out() -> void:
	# no death sheet (Advika): four lit seconds and it BURSTS into motes,
	# the same death the strike buys — one death language for the moth
	if state == State.BURNED:
		return
	state = State.BURNED
	_whip = false
	if _tw != null:
		_tw.kill()
	_visual.visible = false
	_mote_burst()
	died_to_light.emit()
	get_tree().create_timer(1.0).timeout.connect(queue_free)


func _on_anim_finished() -> void:
	if state == State.BURNED and _visual.animation == &"death":
		queue_free()
		return
	# a finished turn flows back to wings; a finished attack clip HOLDS its
	# last comet frame while the dive is still flying (the wings popping
	# back mid-swoop was the old "chop") and only reverts once it's roaming
	if _visual.animation == &"turn" and state != State.BURNED:
		_visual.play(&"fly")
	elif _visual.animation == &"attack" and state not in [State.DIVE, State.BURNED]:
		_visual.play(&"fly")
