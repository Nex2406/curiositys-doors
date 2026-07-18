extends Node2D
class_name Wizard

# The Wizard — Realm 2's boss, the storm's author, a dark mirror of Curiosity
# (docs/realms/realm2.md R2-M7). Purple-shifted, red-eyed BlueWizard pack art
# (tools/tint_wizard_pack.gd). Two lives so far:
#
# 1. APPARITION (Realm2LiftTest): materialize() / follow() / watch() — he
#    flickers in on the rising island and rides it, watching. Presence only.
# 2. TRIAL CONJURER (the rune-orb level): parent him to the plank, call
#    configure_trial() then start_trial() — he idles a beat, teleport-blinks
#    to a random spot ON the plank (local space, so the moving plank carries
#    the landing), reappears, casts, and emits cast_committed at the gesture
#    peak. The OrbSpawner connects to that later. stop_trial() halts it.
#
# Anim mapping (the pack has no cast/teleport sheets — verified 2026-07-12):
#   tp_disappear = "blink" played FORWARD while he fades out
#   tp_appear    = "blink" played BACKWARDS while he fades in
#   cast         = the jump flourish + an eye-glow modulate pulse
# Blink variant: blink_a (full smear — reads as dematerializing). Advika can
# re-pick via tools/WizardAnimReview.tscn; it's the one BLINK_SET constant.

signal materialized()
signal intro_finished()
signal cast_committed(pos: Vector2)
signal died()

const FRAME_DIR := "res://assets/enemies/wizard/"
const IDLE_FRAMES := 20
const IDLE_FPS := 16.0
const BLINK_SET := "blink_a"
const BLINK_FRAMES := 16
const BLINK_FPS := 24.0          # 16 frames -> ~0.67s vanish/appear
const CAST_FRAMES := 8           # the jump set doubling as the conjure flourish
const CAST_FPS := 12.0           # was 10 — refills must not dawdle (Advika)
const CAST_COMMIT_FRAME := 4     # gesture peak: the orb is committed here
const FEET_Y := 134.0            # feet row below the 512-frame center (pre-scale)
const CONJURE_AHEAD := 160.0     # the orb is born slightly IN FRONT of him (pre-scale px)
const TRIAL_EDGE_MARGIN := 110.0 # never lands closer than this to the plank lip
const TELEPORT_MIN_HOP := 240.0  # each landing is a genuinely NEW place, not a shuffle

# Spawn flicker: the apparition blinks in — same visual language as the
# Golem's hit flicker / Curiosity's respawn blink.
const FLICKER_INTERVAL := 0.045

# The intro beat (dialogue through the UI card) is wired by the level; these
# are his canonical opening lines, editable per scene.
@export var dialogue_lines: Array[String] = [
	"Another little wanderer, come to test the doors?",
	"My orbs are ever so fond of pushing things. Do try to keep your footing.",
	"Dodge well, little light. They cannot be broken — and neither, I suspect, can you.",
]
@export var trial_idle_min := 2.0   # beat between teleports (calmer — he lingers, Advika)
@export var trial_idle_max := 3.5
@export var max_orbs := 2           # he conjures at most this many onto the deck
@export var strikes_to_fell := 5    # blows it takes to bring him down (Advika, 2026-07-12: settled at five)
@export var escape_range := 280.0   # global px: Curiosity this close while he idles -> he blinks away
@export var escape_grace := 0.9     # seconds after landing before the escape reflex arms —
                                    # he stands his ground a beat even with her bearing down
@export var edge_lure_chance := 0.3 # some landings sit right at the platform's lip — the
                                    # chase becomes the risk (Advika, 2026-07-12)
@export var hover_amplitude := 14.0 # apparition mode: px of levitation bob
@export var hover_period := 2.6

enum Trial { OFF, IDLE, VANISH, APPEAR, CAST }

# The trial's win rule (Advika, 2026-07-12): reach him and strike (her normal
# J/Z swing) — FIVE blows fell him, and every non-fatal hit sends him
# panic-teleporting away, so each strike must be earned fresh. Reaching him
# is the hard part: while he idles he escape-teleports when she closes in —
# but the reflex arms only after a grace beat each landing, so the windows
# are appear + cast + that beat. A floating EnemyHealthBar tracks strikes.
# The hurtbox is what her attack scans: layer 4 ("enemies" group + take_damage,
# exactly like the Golem), forwarding the blow to the wizard.
class Hurtbox extends StaticBody2D:
	var wizard: Wizard
	func take_damage(_amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
		if wizard != null:
			wizard._on_struck()

var _visual: AnimatedSprite2D
var _conjure_point: Marker2D
var _follow: Node2D = null      # apparition mode: what he rides (the island)
var _follow_offset := Vector2.ZERO
var _watch: Node2D = null       # who he faces (Curiosity)
var _ht := 0.0                  # hover clock
var _mat_t := -1.0              # >=0 → materialize flicker running
var _mat_dur := 0.9

var _trial := Trial.OFF
var _idle_timer := 0.0
var _escape_lock := 0.0   # >0 → the escape reflex hasn't armed yet this landing
var _cast_emitted := false
var _half_extent_x := 0.0       # trial: plank half-width (local space)
var _surface_local_y := 0.0     # trial: his standing y on the plank (local)
var _fade_tween: Tween
var _hurtbox: Hurtbox
var _hurt_shape: CollisionShape2D
var _hpbar: EnemyHealthBar
var _strikes_left := 0
var _dead := false


func _ready() -> void:
	_visual = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", IDLE_FPS)
	frames.set_animation_loop(&"idle", true)
	for i in range(IDLE_FRAMES):
		frames.add_frame(&"idle", load(FRAME_DIR + "idle/idle_%02d.png" % i))
	frames.add_animation(&"blink")
	frames.set_animation_speed(&"blink", BLINK_FPS)
	frames.set_animation_loop(&"blink", false)
	for i in range(BLINK_FRAMES):
		frames.add_frame(&"blink", load(FRAME_DIR + "%s/%s_%02d.png" % [BLINK_SET, BLINK_SET, i]))
	frames.add_animation(&"cast")
	frames.set_animation_speed(&"cast", CAST_FPS)
	frames.set_animation_loop(&"cast", false)
	for i in range(CAST_FRAMES):
		frames.add_frame(&"cast", load(FRAME_DIR + "jump/jump_%02d.png" % i))
	_visual.sprite_frames = frames
	add_child(_visual)
	_visual.animation_finished.connect(_on_anim_finished)
	_visual.frame_changed.connect(_on_frame_changed)
	_visual.play(&"idle")
	visible = false   # nothing until materialize() / appear_instant()

	_conjure_point = Marker2D.new()
	_conjure_point.name = "ConjurePoint"
	# Ahead of his feet, not under them — _face_watch_now() flips the side.
	_conjure_point.position = Vector2(CONJURE_AHEAD, FEET_Y)
	add_child(_conjure_point)

	# Disabled until the trial starts — the lift-scene apparition can't be hit.
	_hurtbox = Hurtbox.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.wizard = self
	_hurtbox.collision_layer = 4   # the layer her attack hitbox scans
	_hurtbox.collision_mask = 0
	_hurtbox.add_to_group("enemies")
	_hurt_shape = CollisionShape2D.new()
	var hrect := RectangleShape2D.new()
	hrect.size = Vector2(160.0, 250.0)   # his figure, pre-scale
	_hurt_shape.shape = hrect
	_hurt_shape.position = Vector2(0.0, 10.0)
	_hurt_shape.disabled = true
	_hurtbox.add_child(_hurt_shape)
	add_child(_hurtbox)

	# Floating strike counter — hidden until the first blow lands (house style).
	_hpbar = EnemyHealthBar.new()
	_hpbar.y_offset = -120.0
	add_child(_hpbar)


# ---------- apparition mode (Realm2LiftTest) ----------

# Ride a node (the island) at a fixed offset; his own bob rides on top.
func follow(target: Node2D, offset: Vector2) -> void:
	_follow = target
	_follow_offset = offset


# Keep facing a node (Curiosity). Pack art faces RIGHT natively (confirmed
# live 2026-07-12 — he spawned looking away from her); flip when she's left.
func watch(target: Node2D) -> void:
	_watch = target


# Flicker into existence over `duration` seconds.
func materialize(duration := 0.9) -> void:
	_mat_dur = maxf(duration, 0.1)
	_mat_t = 0.0
	modulate.a = 0.0
	visible = true


# Fully there at once — screenshot/debug path, no flicker.
func appear_instant() -> void:
	_mat_t = -1.0
	modulate.a = 1.0
	visible = true


# ---------- trial mode (the rune-orb level) ----------

# Call before start_trial(). He must already be a CHILD of the plank: teleport
# targets are picked in the plank's local space so a moving plank carries the
# landing spot with it.
func configure_trial(half_extent_x: float, surface_local_y: float) -> void:
	_half_extent_x = half_extent_x
	_surface_local_y = surface_local_y


# Begin the loop. He opens by conjuring on the spot — when the wizard comes,
# a ball comes with him (Advika) — then: idle -> escape/whim teleport ->
# reappear elsewhere -> cast (if under the cap) -> idle. Level calls this
# after the instructions window closes — never auto-started.
func start_trial() -> void:
	if _trial != Trial.OFF or _dead or _half_extent_x <= 0.0:
		if _half_extent_x <= 0.0:
			push_warning("Wizard.start_trial() before configure_trial()")
		return
	appear_instant()
	_strikes_left = strikes_to_fell
	_hpbar.set_ratio(1.0)
	_hurt_shape.set_deferred("disabled", false)
	_begin_cast()


# Public: a fall reset — drop any mid-cycle momentum (vanish fades included)
# and stand a fresh idle beat. Cast pacing restarts kindly; strikes are NOT
# reset — her progress on him survives her fall.
func reset_pacing() -> void:
	if _trial == Trial.OFF or _dead:
		return
	if _fade_tween != null:
		_fade_tween.kill()
	modulate.a = 1.0
	_hurt_shape.set_deferred("disabled", false)
	_enter_trial_idle()


func stop_trial() -> void:
	if _trial == Trial.OFF:
		return
	_trial = Trial.OFF
	_hurt_shape.set_deferred("disabled", true)
	if _fade_tween != null:
		_fade_tween.kill()
	modulate.a = 1.0
	_visual.play(&"idle")


func _enter_trial_idle() -> void:
	_trial = Trial.IDLE
	_idle_timer = randf_range(trial_idle_min, trial_idle_max)
	_escape_lock = escape_grace
	_visual.play(&"idle")


func _begin_vanish() -> void:
	_trial = Trial.VANISH
	_hurt_shape.set_deferred("disabled", true)   # mid-smear he's nowhere to hit
	_visual.play(&"blink")
	_fade_to(0.0, BLINK_FRAMES / BLINK_FPS)


func _begin_appear() -> void:
	_trial = Trial.APPEAR
	# New spot in the PLANK's local space — the plank has moved; so has this.
	# Re-roll until it's a real hop from where he vanished AND clear of
	# Curiosity (Advika: half the time he landed right on her — an evasive
	# caster does not blink into the blade). If the deck is too crowded to
	# satisfy both, the last roll stands — he's arrogant, not stuck.
	var old_x := position.x
	var new_x := old_x
	var her_x := INF
	var parent := get_parent() as Node2D
	if _watch != null and is_instance_valid(_watch) and parent != null:
		her_x = parent.to_local(_watch.global_position).x
		# She's mid-death-fall (far below the deck)? Her body is meaningless —
		# she's about to blink back in at the RESPAWN POST (deck center).
		# Avoid THAT, or he camps her respawn (Advika, 2026-07-12).
		if parent.to_local(_watch.global_position).y > 500.0:
			her_x = 0.0
	if randf() < edge_lure_chance:
		# THE EDGE LURE (Advika, 2026-07-12): sometimes he lands right at the
		# platform's lip — chasing him there is the risk. Prefers the edge
		# away from her, so the hunt crosses the whole swaying deck.
		var side := (1.0 if her_x < 0.0 else -1.0) if her_x != INF \
				else (1.0 if randf() < 0.5 else -1.0)
		new_x = side * (_half_extent_x - randf_range(15.0, 55.0))
	else:
		for _i in range(12):
			new_x = randf_range(-_half_extent_x + TRIAL_EDGE_MARGIN, _half_extent_x - TRIAL_EDGE_MARGIN)
			if absf(new_x - old_x) >= TELEPORT_MIN_HOP \
					and (her_x == INF or absf(new_x - her_x) >= 380.0):
				break
	position = Vector2(new_x, _surface_local_y)
	_face_watch_now()
	_hurt_shape.set_deferred("disabled", false)  # materializing = catchable
	_visual.play_backwards(&"blink")
	_fade_to(1.0, BLINK_FRAMES / BLINK_FPS)


func _begin_cast() -> void:
	_trial = Trial.CAST
	_cast_emitted = false
	_visual.play(&"cast")
	# The conjuring glow: eyes and cloak flare toward violet-white across the
	# gesture, peaking at the commit frame, then settle.
	var dur := CAST_FRAMES / CAST_FPS
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_visual, "modulate", Color(1.7, 1.45, 2.3), dur * 0.5)
	_fade_tween.tween_property(_visual, "modulate", Color(1, 1, 1), dur * 0.5)


func _fade_to(alpha: float, dur: float) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, dur)


func _on_anim_finished() -> void:
	if _dead:
		queue_free()
		return
	match _trial:
		Trial.VANISH:
			_begin_appear()
		Trial.APPEAR:
			# Conjure only under the cap (in-flight smoke counts as an orb);
			# at the cap he just prowls — teleporting is its own menace.
			if get_tree().get_nodes_in_group("hazards").size() < max_orbs:
				_begin_cast()
			else:
				_enter_trial_idle()
		Trial.CAST:
			_enter_trial_idle()


func _on_frame_changed() -> void:
	if _trial == Trial.CAST and not _cast_emitted \
			and _visual.animation == &"cast" and _visual.frame >= CAST_COMMIT_FRAME:
		_cast_emitted = true
		cast_committed.emit(_conjure_point.global_position)


func _face_watch_now() -> void:
	if _watch != null and is_instance_valid(_watch):
		_visual.flip_h = _watch.global_position.x < global_position.x
		# The conjure point rides his facing: the orb is born in FRONT of him.
		_conjure_point.position.x = -CONJURE_AHEAD if _visual.flip_h else CONJURE_AHEAD


# A blow lands. Non-fatal: flash, panic-teleport — the next strike must be
# earned fresh. The fifth: bright flash, then he dissolves out through his
# own blink smear — and this time nothing reappears.
func _on_struck() -> void:
	if _dead or _trial == Trial.OFF:
		return
	_strikes_left -= 1
	_hpbar.set_ratio(float(_strikes_left) / float(strikes_to_fell))
	if _strikes_left > 0:
		_visual.modulate = Color(2.4, 2.0, 2.6)   # the strike registers
		var flash := create_tween()
		flash.tween_property(_visual, "modulate", Color(1, 1, 1), 0.25)
		print("[Wizard] struck — %d/%d blows remain" % [_strikes_left, strikes_to_fell])
		if _trial != Trial.VANISH:
			_begin_vanish()   # struck = gone; catch him again
		return
	_dead = true
	_trial = Trial.OFF
	_hurt_shape.set_deferred("disabled", true)
	_hpbar.hide()
	if _fade_tween != null:
		_fade_tween.kill()
	_visual.modulate = Color(2.4, 2.0, 2.6)
	_visual.play(&"blink")
	_fade_tween = create_tween()
	_fade_tween.tween_property(_visual, "modulate", Color(1, 1, 1), 0.2)
	_fade_tween.parallel().tween_property(self, "modulate:a", 0.0, BLINK_FRAMES / BLINK_FPS)
	died.emit()
	print("[Wizard] struck down")


# Which way he's looking (art faces right): +1 right, -1 left. Orbs are
# conjured in front of him and must ROLL that way too.
func facing_dir() -> int:
	return -1 if _visual.flip_h else 1


# ---------- shared ----------

func _physics_process(delta: float) -> void:
	_ht += delta
	if _follow != null and is_instance_valid(_follow):
		var bob := sin(_ht * TAU / hover_period) * hover_amplitude
		var drift := sin(_ht * TAU / (hover_period * 2.7) + 0.7) * hover_amplitude * 0.6
		global_position = _follow.global_position + _follow_offset + Vector2(drift, bob)
	_face_watch_now()

	if _trial == Trial.IDLE:
		_idle_timer -= delta
		_escape_lock = maxf(0.0, _escape_lock - delta)
		# A ball rolled off? He refills IMMEDIATELY, casting from where he
		# stands — the deck never sits quiet waiting out his idle ritual
		# (Advika, 2026-07-12: re-conjuring took too long). In-flight smoke
		# counts in the group, so this can't double-cast.
		if get_tree().get_nodes_in_group("hazards").size() < max_orbs:
			_begin_cast()
			return
		# She's closing in — he blinks away, but only once the reflex has
		# armed: the grace beat after each landing is her honest window.
		var threatened: bool = _escape_lock <= 0.0 \
				and _watch != null and is_instance_valid(_watch) \
				and global_position.distance_to(_watch.global_position) < escape_range
		if _idle_timer <= 0.0 or threatened:
			_begin_vanish()

	if _mat_t >= 0.0:
		_mat_t += delta
		var k := clampf(_mat_t / _mat_dur, 0.0, 1.0)
		_visual.visible = int(_mat_t / FLICKER_INTERVAL) % 2 == 0 or k >= 1.0
		modulate.a = k
		if k >= 1.0:
			_mat_t = -1.0
			_visual.visible = true
			materialized.emit()
