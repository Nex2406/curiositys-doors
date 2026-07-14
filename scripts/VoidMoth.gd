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

const FRAME_DIR := "res://assets/enemies/void_moth/"
const FLY_FRAMES := 12
const ATTACK_FRAMES := 5
const DEATH_FRAMES := 3
const FLY_FPS := 12.0
const ATTACK_FPS := 12.0
const DEATH_FPS := 5.0
const STING_REACH := 130.0     # pre-scale contact reach during a dive (distance test —
                               # an Area2D missed at swoop speeds; Advika: no damage)
const DECK_CLEAR_Y := 150.0    # it NEVER enters the island's body: when horizontally
const DECK_HALF_X := 640.0     # over the deck it stays at least this far above it

@export var burn_time := 5.0         # sustained light needed to unmake it
@export var burn_leak := 0.5         # burn decays at this rate when unlit (forgiving, not a reset)
@export var bob_amplitude := 14.0
@export var bob_period := 2.1
@export var roam_speed := 240.0      # cruising speed while it prowls the sky
@export var roam_retarget_min := 1.6 # how often it picks a new patch of air
@export var roam_retarget_max := 3.2
@export var dive_wait_min := 2.6     # beat between dives
@export var dive_wait_max := 4.6
@export var dive_damage := 10
@export var dive_knockback := Vector2(300.0, -140.0)
@export var dive_overshoot := 150.0  # px past her position the swoop carries

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
var _roam_offset := Vector2.ZERO # current patch of air (anchor-relative)
var _roam_timer := 0.0
var _dive_prev := Vector2.ZERO   # last dive sample, for exit-velocity blending


func _ready() -> void:
	add_to_group("moths")
	_visual = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for spec in [["fly", FLY_FRAMES, FLY_FPS, true], ["attack", ATTACK_FRAMES, ATTACK_FPS, false],
			["death", DEATH_FRAMES, DEATH_FPS, false]]:
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[2])
		frames.set_animation_loop(spec[0], spec[3])
		for i in range(1, spec[1] + 1):
			frames.add_frame(spec[0], load("%s%s_%02d.png" % [FRAME_DIR, spec[0], i]))
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
	_respect_the_deck()
	# keep the look alive during the approach too
	var dt := maxf(get_physics_process_delta_time(), 0.001)
	_vel = (global_position - prev) / dt * 0.6


# The wizard fell — the moth loses interest and leaves, upward and gone.
func exit_flyaway() -> void:
	if state in [State.BURNED, State.EXIT]:
		return
	state = State.EXIT
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
			# CONTINUOUS flight (Advika: it felt stiff, parked): it prowls
			# from air-patch to air-patch around the climbing island, steering
			# smoothly — velocity eases toward each new heading, so turns are
			# banks, not snaps. The wing-bob rides on the visual only.
			_roam_timer -= delta
			if _roam_timer <= 0.0:
				_pick_roam()
			if _anchor != null and is_instance_valid(_anchor):
				var to_patch: Vector2 = (_anchor.global_position + _roam_offset) - global_position
				var desired := to_patch.normalized() * roam_speed
				# arrive: ease off inside the patch so it swings around, not through
				if to_patch.length() < 120.0:
					desired *= to_patch.length() / 120.0
				_vel = _vel.lerp(desired, 1.0 - pow(0.03, delta))
				global_position += _vel * delta
				_respect_the_deck()
			_visual.position.y = sin(_ht * TAU / bob_period) * bob_amplitude
			_dive_timer -= delta
			if _dive_timer <= 0.0 and _target != null and is_instance_valid(_target):
				_begin_dive()
		State.DIVE:
			_check_sting()
		_:
			pass
	_apply_flight_look(delta)
	_tick_burn(delta)


# The island is SOLID to it (Advika: they passed through the bloody
# platform): horizontally over the deck, the moth holds clearance above the
# moss. Applied after every movement step, whatever state moved it.
func _respect_the_deck() -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		return
	if absf(global_position.x - _anchor.global_position.x) < DECK_HALF_X:
		var ceiling_y := _anchor.global_position.y - DECK_CLEAR_Y
		if global_position.y > ceiling_y:
			global_position.y = ceiling_y
			_vel.y = minf(_vel.y, 0.0)


# Flight is a body, not a sprite slide (Advika: it only faces one direction,
# stiff): it faces the way it flies, banks into turns, and beats its wings
# faster the harder it moves.
func _apply_flight_look(delta: float) -> void:
	if state in [State.BURNED]:
		return
	if absf(_vel.x) > 30.0:
		_visual.flip_h = _vel.x < 0.0
	var bank := clampf(_vel.x * 0.00045, -0.22, 0.22)
	_visual.rotation = lerpf(_visual.rotation, bank, 1.0 - pow(0.002, delta))
	if _visual.animation == &"fly":
		_visual.speed_scale = clampf(0.85 + _vel.length() / 420.0, 0.85, 1.6)


# A fresh patch of air around the island — wide, varied, alive.
func _pick_roam() -> void:
	_roam_timer = randf_range(roam_retarget_min, roam_retarget_max)
	_roam_offset = Vector2(randf_range(-450.0, 450.0), randf_range(-480.0, -180.0))


# --- the dive ---

func _arm_dive() -> void:
	_dive_timer = randf_range(dive_wait_min, dive_wait_max)


func _begin_dive() -> void:
	state = State.DIVE
	_dive_hit = false
	_visual.play(&"attack")
	# A SWOOP, not a straight stab: a bezier that first lifts against the
	# approach (the windup breath), then whips down THROUGH her and past.
	# The exit velocity is measured off the curve, so the pull-out blends
	# straight back into the roam — no snap anywhere.
	var her: Vector2 = _target.global_position
	var dir := (her - global_position).normalized()
	var through := her + dir * dive_overshoot
	_enter_spawn = global_position
	_enter_arc = -dir * 140.0 + Vector2(0, -110.0)  # reuse the bezier fields: windup bow
	_dive_prev = global_position
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(_dive_step.bind(through), 0.0, 1.0, 0.85)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.finished.connect(func() -> void:
		if state != State.DIVE:
			return
		state = State.STALK
		# carry the swoop's exit speed into the roam — the pull-out IS flight
		_pick_roam()
		_arm_dive())


# One step of the dive bezier; tracks its own derivative so the roam can
# inherit the exit velocity.
func _dive_step(t: float, through: Vector2) -> void:
	var ctrl := _enter_spawn + _enter_arc
	var a := _enter_spawn.lerp(ctrl, t)
	var b := ctrl.lerp(through, t)
	var pos := a.lerp(b, t)
	var dt := maxf(get_physics_process_delta_time(), 0.001)
	_vel = (pos - _dive_prev) / dt * 0.6   # damped: inherit the sweep, not the spike
	_dive_prev = pos
	global_position = pos
	_respect_the_deck()


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


# --- the burn (the only death) ---

func _tick_burn(delta: float) -> void:
	if state in [State.ENTER, State.BURNED, State.EXIT]:
		return
	var lit := false
	if _target != null and is_instance_valid(_target) and _target.has_method("light_state"):
		var ls: Array = _target.light_state()
		lit = global_position.distance_to(ls[0]) <= float(ls[1])
	if lit:
		_light_t += delta
	else:
		_light_t = maxf(0.0, _light_t - delta * burn_leak)
	# the burn shows: it whitens and trembles as the light unmakes it
	var k := clampf(_light_t / burn_time, 0.0, 1.0)
	_visual.modulate = Color(1.0 + k * 1.2, 1.0 + k * 0.9, 1.0 + k * 1.4)
	_visual.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (k * 5.0)
	if _light_t >= burn_time:
		_burn_out()


func _burn_out() -> void:
	state = State.BURNED
	if _tw != null:
		_tw.kill()
	# the flash — then the death motes, fading as they scatter
	var flash := create_tween()
	flash.tween_property(_visual, "modulate", Color(2.6, 2.2, 3.0), 0.08)
	flash.finished.connect(func() -> void:
		_visual.play(&"death")
		var dur := DEATH_FRAMES / DEATH_FPS
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, dur)
		died_to_light.emit())


func _on_anim_finished() -> void:
	if state == State.BURNED and _visual.animation == &"death":
		queue_free()
		return
	# the attack clip is shorter than the swoop — flow back to wings mid-
	# flight instead of freezing on the last frame (that read as the "chop")
	if _visual.animation == &"attack" and state != State.BURNED:
		_visual.play(&"fly")
