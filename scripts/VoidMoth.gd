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
# arrives) -> STALK (hover + bob near its anchor, riding the climb) ->
# DIVE at her on a whim (contact damage) -> RECOVER -> STALK...
# exit_flyaway() sends it off upward (the wizard fell; it loses interest).

signal died_to_light()

const FRAME_DIR := "res://assets/enemies/void_moth/"
const FLY_FRAMES := 12
const ATTACK_FRAMES := 5
const DEATH_FRAMES := 3
const FLY_FPS := 12.0
const ATTACK_FPS := 12.0
const DEATH_FPS := 5.0
const STING_RADIUS := 95.0     # pre-scale contact reach during a dive

@export var burn_time := 5.0         # sustained light needed to unmake it
@export var burn_leak := 0.5         # burn decays at this rate when unlit (forgiving, not a reset)
@export var bob_amplitude := 16.0
@export var bob_period := 2.1
@export var dive_wait_min := 2.6     # beat between dives
@export var dive_wait_max := 4.6
@export var dive_damage := 10
@export var dive_knockback := Vector2(300.0, -140.0)
@export var dive_overshoot := 150.0  # px past her position the swoop carries

enum State { ENTER, STALK, DIVE, RECOVER, BURNED, EXIT }

var state := State.ENTER
var _visual: AnimatedSprite2D
var _sting: Area2D
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
var _recover_from := Vector2.ZERO


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

	# The sting: senses her body only while diving.
	_sting = Area2D.new()
	_sting.collision_layer = 0
	_sting.collision_mask = 1
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = STING_RADIUS
	cs.shape = circle
	_sting.add_child(cs)
	add_child(_sting)


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
	global_position = a.lerp(b, t)


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
			# ride the anchor with a living bob + sideways breath
			if _anchor != null and is_instance_valid(_anchor):
				var bob := sin(_ht * TAU / bob_period) * bob_amplitude
				var sway := sin(_ht * TAU / (bob_period * 2.3) + 0.9) * bob_amplitude * 0.7
				global_position = _anchor.global_position + _anchor_offset + Vector2(sway, bob)
			_dive_timer -= delta
			if _dive_timer <= 0.0 and _target != null and is_instance_valid(_target):
				_begin_dive()
		State.DIVE:
			_check_sting()
		_:
			pass
	_tick_burn(delta)


# --- the dive ---

func _arm_dive() -> void:
	_dive_timer = randf_range(dive_wait_min, dive_wait_max)


func _begin_dive() -> void:
	state = State.DIVE
	_dive_hit = false
	_visual.play(&"attack")
	# swoop THROUGH her: aim at her current spot plus an overshoot along the
	# approach line — a strafe, not a landing
	var her: Vector2 = _target.global_position
	var dir := (her - global_position).normalized()
	var through := her + dir * dive_overshoot
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "global_position", through, 0.62)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.finished.connect(func() -> void:
		if state != State.DIVE:
			return
		state = State.RECOVER
		_visual.play(&"fly")
		_recover_from = global_position
		var back := create_tween()
		back.tween_method(_recover_step, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		back.finished.connect(func() -> void:
			if state == State.RECOVER:
				state = State.STALK
				_arm_dive()))


# One step of the swoop-recovery — home is sampled live (the island climbs).
func _recover_step(t: float) -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		return
	global_position = _recover_from.lerp(_anchor.global_position + _anchor_offset, t)


func _check_sting() -> void:
	if _dive_hit:
		return
	for body in _sting.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			_dive_hit = true
			var kb := Vector2(signf(body.global_position.x - global_position.x)
					* absf(dive_knockback.x), dive_knockback.y)
			body.take_damage(dive_damage, kb)
			break


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
