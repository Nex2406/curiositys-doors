extends CharacterBody2D
class_name Mirror

## PHASE C — IT HAS BEEN WATCHING YOU PLAY, AND NOW IT PLAYS YOU.
##
## The boss wears her: the `evil_curiosity` frames are derived from Curiosity's
## own sheets, and it takes her scale, her collider and her movement constants
## off the live hero at spawn. But it is NOT a mirror (Advika: "it needs to be
## based off the player, not like a simple mirror"). It does not copy her moves
## and it does not replay a recording. It has a fighter's own kit — four moves,
## its own footwork — and `PlayerProfile`'s read of how this person plays
## decides WHICH of them it reaches for, how far out it does it, and how often.
##
##   THE MOVES
##     SWING   the plain blow. Announced by the eyes, punishable if it misses.
##     COMBO   two in a row, the second one faster than the first.
##     LUNGE   a committed dash the whole width of a screen, blade first. This
##             is what a player who likes to keep their distance is answered
##             with; there is nowhere far enough away.
##     LEAP    over her head and down, landing hard enough to hit either side.
##             A player who lives in the air gets fought in the air.
##
##   WHAT THE PROFILE DECIDES
##     they live in the air        -> it leaps
##     they fight from range       -> it lunges
##     they swing constantly       -> it combos
##     they break the same way     -> it steps that way first (DECIDE)
##     they back off after a hit   -> it follows them off (DECIDE)
##     their cadence               -> the clock every move of its own runs on
##
##   THE THREE STAGES are how much of that kit it is allowed to use, and they
##   are a sentence: MIMIC — it fights at their range, on their rhythm, with
##   the plain blow only. TIME — it reads the swing they are throwing RIGHT NOW,
##   gives ground through it, and comes back into the recovery; the lunge opens
##   up. DECIDE — the whole kit, faster than their own cadence, aimed at the
##   habits they cannot stop having.
##
## It carries no lantern. She is the only warm thing left on the screen.

signal died()
signal stage_changed(stage: int)
signal struck_player()

enum Stage { MIMIC, TIME, DECIDE }
enum Act { WAIT, CLOSE, BACK, SWING, LUNGE, LEAP, HURT, DEAD }

## IT IS HER FRAMES. NOT A COPY OF THEM, NOT A MATCHING SET — HERS.
##
## Advika: *"the animations arent smooth at all, i just want it to take an exact
## frame copy of the player's animation and just put that in a separate colour
## to get evil curiosity"* — and *"even the jump animation is wrong."*
##
## The `assets/player/evil_curiosity/` art is out of the fight entirely. It was
## a separately drawn set that happened to have the same folder names, and
## "same folder names" is not the same thing as the same animation: its jump
## read wrong because it IS a different jump, drawn separately, and no amount
## of matching the frame counts and the fps was ever going to fix a different
## drawing. Two attempts went into syncing the metadata when the frames
## themselves were the problem.
##
## So the boss now plays `curiosity_frames.tres` — the hero's own resource,
## untouched, every frame, every speed, every loop flag — and a shader recolours
## it as it draws. Identical animation by construction, because it is literally
## the same animation. Advika can redraw her walk tomorrow and the mirror walks
## the new way the same afternoon.
const HER_FRAMES := "res://assets/player/curiosity/curiosity_frames.tres"

## THE RECOLOUR. Luminance is read off her art and remapped through a two-point
## ramp: her darks become the boss's shadow, her lights become its cold rim.
## Nothing is hue-rotated (that keeps the gold of her lantern as a gold-ish
## smear); the whole figure is rebuilt out of two colours, so it reads as a
## silhouette of her rather than a tinted photo of her.
##
## `MODULATE` is captured in vertex() and applied at the end ON PURPOSE. A
## canvas shader that writes COLOR from scratch DISCARDS the node's modulate,
## and this one depends on modulate for two things: the arrival fade, and the
## white-hot flash on every hit it takes.
## THE RECOLOUR, AND THE EYES.
##
## Luminance is read off her art and remapped through a two-point ramp: her
## darks become the boss's shadow, her lights become its cold rim. Nothing is
## hue-rotated — the whole figure is rebuilt out of two colours, so it reads as
## a silhouette of her rather than a tinted photo of her.
##
## THE EYES ARE FOUND, NOT PAINTED. Her sprite has exactly two things brighter
## than 0.85 luminance: her white eyes, and her lantern flame. A brightness
## test alone would set the lantern on fire too — so the test is brightness AND
## LOW SATURATION. Her eyes are near-white (saturation ~0); the flame is a
## saturated orange and fails the second half of the test, which is what keeps
## the boss carrying a dead lamp instead of a lit one.
##
## The red is pushed above 1.0 on purpose. Canvas colour is not clamped on the
## way out, so an over-bright value blooms against the PointLight2D sitting
## behind it and the eyes read as lit rather than painted.
##
## `MODULATE` is captured in vertex() and applied at the end ON PURPOSE. A
## canvas shader that writes COLOR from scratch DISCARDS the node's modulate,
## and this one depends on modulate for two things: the arrival fade, and the
## white-hot flash on every hit it takes.
const EVIL_SHADER := "shader_type canvas_item;
uniform vec3 shadow : source_color = vec3(0.038, 0.052, 0.120);
uniform vec3 rim : source_color = vec3(0.460, 0.500, 0.580);
uniform vec3 eye : source_color = vec3(1.0, 0.045, 0.045);
uniform float contrast = 1.40;
uniform float eye_cut = 0.62;
uniform float eye_sat = 0.09;
uniform float eye_gain = 1.0;
varying vec4 mod_c;

// is this texel part of the lantern? Its flame keeps a white-hot core that is
// as neutral as her eyes, so no per-pixel brightness test can tell them apart —
// measured across all 94 frames, every cut that kept the eyes also kept ~1500
// pixels of flame. What DOES separate them is the neighbourhood: the flame core
// is surrounded by warm glass and her eyes are surrounded by black hood. Eight
// taps is enough to ask that question.
float lantern(vec2 uv, sampler2D tex, vec2 px) {
	float warm = 0.0;
	vec2 r = px * 5.0;
	for (int i = 0; i < 8; i++) {
		float t = float(i) * 0.7853982;
		vec4 n = texture(tex, uv + vec2(cos(t), sin(t)) * r);
		warm = max(warm, (n.r - n.b) * n.a);
	}
	return smoothstep(0.10, 0.20, warm);
}

void vertex() { mod_c = COLOR; }

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float sat = max(max(t.r, t.g), t.b) - min(min(t.r, t.g), t.b);
	float body_l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 body = mix(shadow, rim, body_l);
	// THE LANTERN IS DEAD. Warm regions are crushed to the darkest value in the
	// palette, so the boss carries a spent lamp — she stays the only warm thing
	// on screen, which is the realm's rule, and the flame can never be mistaken
	// for an eye.
	float lan = max(smoothstep(0.10, 0.20, t.r - t.b), lantern(UV, TEXTURE, TEXTURE_PIXEL_SIZE));
	body = mix(body, shadow * 0.7, lan);
	// bright AND desaturated AND not lantern = her eyes, and nothing else
	float is_eye = smoothstep(eye_cut, eye_cut + 0.12, l)
			* (1.0 - smoothstep(eye_sat, eye_sat + 0.06, sat))
			* (1.0 - lan);
	// BRIGHTER, AND PURER RED (Advika). Canvas colour is not clamped on the way
	// out, so pushing well past 1.0 makes them burn rather than merely be red —
	// which is what lets them carry the whole silhouette on a black screen now
	// that the outline is gone.
	vec3 col = mix(body, eye * (2.9 + 2.4 * eye_gain), is_eye);
	// NO OUTLINE. A cold edge light was tried to keep it legible on black and
	// Advika's verdict was immediate — it read as a sticker cut out of the
	// scene rather than a figure standing in it. The eyes are the read.
	COLOR = vec4(col, t.a) * mod_c;
}"

# ---- the fight's numbers (all of these are meant to be argued with) ----
## TEN OF HER SWINGS. It was 900 — twenty-three — and Advika played it and
## said it was anticlimactic, which is the correct verdict on any boss whose
## difficulty lives in its health bar: hitting something twenty-three times is
## not a climax, it is a chore, and nothing about it feels like winning.
##
## The fight stays long and hard the way it should be — because it is
## DANGEROUS and hard to land a blow on, not because it is a wall. Ten clean
## swings, and it spends the whole time making clean swings expensive.
@export var max_health: int = 400
## what a plain blow costs her. She carries 100 and three eyes, so four clean
## ones is an eye. The heavier moves cost more, below.
@export var damage: int = 22
## how far in front of itself the blade actually reaches, in world px. Measured
## against hers: a 460px box pushed 240px forward at 0.24 scale reaches ~112px.
@export var reach: float = 118.0
## it has to be roughly on her level to connect — no hitting her off a mushroom
@export var reach_y: float = 150.0

## the swing, in seconds: eyes flare -> the blow lands -> it is open
@export var windup := 0.30
@export var strike_recover := 0.42
## it cannot open a new move inside this no matter what the profile says
@export var attack_floor := 0.52

## HOW IT MOVES. Nothing is assigned to `velocity.x` any more — everything
## steers a TARGET and the body accelerates onto it (Advika: "you need to make
## the clone move smoother"). Snapping straight to full speed and straight back
## to zero every time it re-thought was the whole of the jerkiness, and it also
## made the walk/run animation flicker between states four times a second.
@export var accel_time := 0.16
## how long it must commit to closing or giving ground before it may re-think.
## Without this it flips direction inside a single footstep.
@export var commit_time := 0.34
## how long it keeps backing off after a swing lands or misses. Long enough to
## read, short enough that the pressure never really lifts.
@export var disengage_time := 0.42

var walk_speed := 200.0
var run_speed := 210.0
var gravity := 460.0
var jump_velocity := -356.0

var health: int
var stage: int = Stage.MIMIC
var target: CharacterBody2D = null
## dead until the arrival beat finishes — it stands there and is looked at
## first, and only then does it get to move
var live := false
## its opening move has been spent — see `_pick_move`
var _opened := false

var _act: int = Act.WAIT
var _act_t := 0.0
var _think := 0.0
var _swing_cd := 0.0
var _hit_landed := false
var _t := 0.0
var _dying := false
var _facing_right := false
## how far she has to be past its centre line before it turns, and how long it
## must then keep facing that way
const FACE_DEADZONE := 26.0
const FACE_MIN_HOLD := 0.22
var _face_hold := 0.0
## the speed it is steering toward; `velocity.x` chases this
var _target_vx := 0.0
## how many blows are left in the move it is in the middle of (COMBO = 2)
var _blows_left := 0
## per-move cooldowns, so it never plays the same trick twice running
var _cd := {"lunge": 0.0, "leap": 0.0, "combo": 0.0}

var _visual: AnimatedSprite2D
var _her_visual: AnimatedSprite2D
var _eyes: PointLight2D
var _rim: PointLight2D
var _bar: EnemyHealthBar

## how long ago she started her current swing, so TIME can give ground during
## it and come back into the recovery. -1 = she is not swinging.
var _her_swing_t := -1.0
## it only reacts to a swing once
var _read_swing := false


func _ready() -> void:
	add_to_group("enemies")
	# layer 4 is the one her swing box scans (the golems and the sporelings
	# live here). Mask 1 is the terrain — deliberately NOT her body layer, so
	# the two never shove each other around; they only ever meet through a
	# hitbox.
	collision_layer = 4
	collision_mask = 1
	health = max_health
	_build_body()


## It is built FROM her — scale, collider and animation timing are all read off
## the live hero rather than written down, so it is exactly her size in any
## realm that spawns it at any zoom.
func build_from(hero: CharacterBody2D) -> void:
	target = hero
	if hero == null:
		return
	scale = hero.scale
	for k in ["walk_speed", "run_speed", "gravity", "jump_velocity"]:
		if k in hero:
			set(k, hero.get(k))
	var vis: Node2D = hero.get_node_or_null("Visual")
	if vis != null and _visual != null:
		_visual.scale = vis.scale
		_visual.position = vis.position
	# WATCHING HER HANDS. The one thing the profile cannot tell it is what she
	# is doing RIGHT NOW, and the stage that hits recoveries has to know a
	# swing when it sees one. Her animation is public and her state enum is
	# not, so it reads the picture rather than the variable.
	_her_visual = vis as AnimatedSprite2D
	var cs: CollisionShape2D = hero.get_node_or_null("CollisionShape2D")
	if cs != null and cs.shape is RectangleShape2D:
		var mine: CollisionShape2D = get_node_or_null("CollisionShape2D")
		if mine != null and mine.shape is RectangleShape2D:
			(mine.shape as RectangleShape2D).size = (cs.shape as RectangleShape2D).size


func _build_body() -> void:
	# HER resource, verbatim. Nothing is swapped, nothing is rebuilt.
	var frames: SpriteFrames = load(HER_FRAMES)

	_visual = AnimatedSprite2D.new()
	_visual.name = "Visual"
	_visual.sprite_frames = frames
	_visual.centered = true
	_visual.scale = Vector2(1.62, 1.62)
	_visual.flip_h = true          # her art faces right; this one faces her
	# the colour is a shader, so her art is never modified and the two bodies
	# can never fall out of step
	var sh := Shader.new()
	sh.code = EVIL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_visual.material = mat
	_visual.animation_finished.connect(_on_anim_done)
	add_child(_visual)
	_visual.play(&"idle")

	var cs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(88, 432)
	cs.shape = box
	cs.name = "CollisionShape2D"
	add_child(cs)

	# A BLACK FIGURE IN A DEAD FOREST IS BLACK. The sprite is charcoal by
	# design and the drained world is charcoal by design, so the silhouette
	# has to be cut OUT of the dark rather than left to carry itself.
	_rim = PointLight2D.new()
	_rim.texture = load("res://assets/effects/lantern_halo.png")
	_rim.texture_scale = 2.1
	_rim.color = Color(0.44, 0.62, 0.78)
	_rim.energy = 0.0
	_rim.z_index = -1
	_rim.position = Vector2(0, -30)
	add_child(_rim)

	# the eyes arrive before the shape does, and they are the tell: they flare
	# through every windup, so the blow is always announced by the only red in
	# the level.
	_eyes = PointLight2D.new()
	_eyes.texture = load("res://assets/effects/lantern_halo.png")
	_eyes.texture_scale = 0.7
	_eyes.color = Color(1.0, 0.17, 0.24)
	_eyes.energy = 0.0
	_eyes.position = Vector2(0, -46)
	add_child(_eyes)

	_bar = EnemyHealthBar.new()
	_bar.y_offset = -104.0
	_bar.fill_color = Color(0.92, 0.22, 0.26)
	add_child(_bar)


## THE ARRIVAL. It does not walk in — the colour finishes leaving and it is
## simply there, already looking at her. Only when this finishes is it allowed
## to move, so the player gets a beat to understand what they are looking at.
func arrive(hold: float = 2.6) -> void:
	_visual.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_visual, "modulate:a", 1.0, hold)
	tw.parallel().tween_property(_eyes, "energy", 2.3, hold)
	tw.parallel().tween_property(_rim, "energy", 1.05, hold * 1.15)
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void: live = true)


# ---------- the brain ----------

func _physics_process(delta: float) -> void:
	_t += delta
	if _dying:
		return
	# the eyes never sit still, and they SPIKE through a windup — the tell
	var flare: float = 1.0
	if _in_move() and _act_t < windup:
		flare = 1.0 + 1.6 * (_act_t / maxf(windup, 0.01))
	_eyes.energy = (2.3 + sin(_t * 2.7) * 0.28) * flare
	# the same pulse drives the eyes IN the sprite, so the tell is on its face
	# rather than only in the glow behind it
	var em: ShaderMaterial = _visual.material as ShaderMaterial
	if em != null:
		em.set_shader_parameter("eye_gain",
				(0.35 + sin(_t * 2.7) * 0.12) * flare)

	if not is_on_floor():
		velocity.y += gravity * delta
	if not live or target == null or not is_instance_valid(target):
		_target_vx = 0.0
		_steer(delta)
		move_and_slide()
		return

	_swing_cd = maxf(0.0, _swing_cd - delta)
	for k in _cd:
		_cd[k] = maxf(0.0, _cd[k] - delta)
	_act_t += delta
	_think -= delta
	_face_hold = maxf(0.0, _face_hold - delta)
	_watch_her(delta)

	match _act:
		Act.HURT:
			_target_vx = 0.0
		Act.SWING:
			_run_swing()
		Act.LUNGE:
			_run_lunge()
		Act.LEAP:
			_run_leap()
		_:
			_run_footwork(delta)

	_steer(delta)
	move_and_slide()
	_face()
	_animate()


## EVERY horizontal motion in this fight goes through here. Nothing writes
## `velocity.x`; they write `_target_vx` and the body accelerates onto it at
## her own feel, which is what makes it read as a body rather than a cursor.
func _steer(delta: float) -> void:
	var a: float = run_speed / maxf(accel_time, 0.01)
	# in the air it has much less authority — the same rule her own controller
	# follows, and the reason a leap commits to where it was aimed
	if not is_on_floor():
		a *= 0.35
	velocity.x = move_toward(velocity.x, _target_vx, a * delta)


func _in_move() -> bool:
	return _act == Act.SWING or _act == Act.LUNGE or _act == Act.LEAP


## Her swing, live. Everything the profile knows is history; this is the one
## thing it has to see happening.
func _watch_her(delta: float) -> void:
	if _her_visual == null:
		return
	if _her_visual.animation == &"attack":
		if _her_swing_t < 0.0:
			_her_swing_t = 0.0
			_read_swing = false
		else:
			_her_swing_t += delta
	else:
		_her_swing_t = -1.0


func _gap() -> float:
	return target.global_position.x - global_position.x


func _dir_to_player() -> float:
	var d: float = signf(_gap())
	return d if d != 0.0 else -1.0


# ---------- footwork ----------

func _run_footwork(delta: float) -> void:
	var gap: float = absf(_gap())
	var toward: float = _dir_to_player()

	# HER OWN SPACING. Where she likes to stand when she swings is where it
	# tries to stand, which means it is always exactly as close as she taught
	# it to be. If she never got measured, its own reach is the default.
	var want: float = PlayerProfile.engage_distance
	if want < 40.0:
		want = reach * 0.85
	if stage == Stage.TIME:
		want *= 0.85
	elif stage == Stage.DECIDE:
		# it stops respecting her spacing — it comes in past the range she is
		# comfortable fighting at and stays there
		want *= 0.55

	# it may only re-think once it has committed to what it is already doing.
	# Both gates matter: the timer keeps it from twitching, `commit_time` keeps
	# a step from being abandoned halfway through.
	if _think <= 0.0 and (_act == Act.WAIT or _act_t >= commit_time):
		_decide(gap, want)
		_think = randf_range(0.26, 0.48)

	match _act:
		Act.CLOSE:
			var sp: float = run_speed if gap > want * 2.0 else walk_speed
			# they were measured closing at a speed; it closes at theirs, so a
			# cautious player is stalked and a rusher is rushed
			if PlayerProfile.approach_speed > 30.0:
				sp = clampf(PlayerProfile.approach_speed * (1.35 if stage == Stage.DECIDE \
						else 1.0), walk_speed * 0.55, run_speed)
			_target_vx = toward * sp
		Act.BACK:
			# a disengage after a blow is a real retreat, not a shuffle — it
			# opens roughly a body-and-a-half of daylight before it re-thinks
			_target_vx = -toward * walk_speed * (1.35 if _think > 0.0 else 0.9)
		_:
			_target_vx = 0.0

	# HOW OFTEN THEY LEAVE THE GROUND, AND HOW MUCH THEY LIVE UP THERE. A
	# player who never jumps fights something that never jumps; a bunny-hopper
	# fights their own habit. Two numbers, because twenty little hops and one
	# long float give the same jumps-per-minute and are not the same person.
	if is_on_floor() and _act == Act.CLOSE:
		var appetite: float = clampf(PlayerProfile.jumps_per_minute() / 60.0
				+ PlayerProfile.air_fraction * 0.5, 0.0, 0.8)
		if appetite > 0.02 and randf() < appetite * delta * 3.0:
			velocity.y = jump_velocity


func _decide(gap: float, want: float) -> void:
	var level: bool = absf(target.global_position.y - global_position.y) < reach_y

	# --- what it does about a swing it can SEE, once it has learned to ---
	if stage != Stage.MIMIC and _her_swing_t >= 0.0 and not _read_swing:
		_read_swing = true
		if gap < reach * 1.5:
			# she has committed. It gives ground through the swing and comes
			# back into the recovery — the fight's first move that is about
			# what she is doing rather than what she usually does.
			_act = Act.BACK
			_act_t = 0.0
			_think = 0.34
			return
		if stage == Stage.DECIDE and _cd["lunge"] <= 0.0:
			# a swing thrown at nothing is a free half second, and in the last
			# third it spends every one of them arriving
			_start_lunge()
			return
	# she just finished one and it is standing in range: that is the window
	if stage != Stage.MIMIC and _her_swing_t < 0.0 and _read_swing:
		_read_swing = false
		if gap < reach * 1.25 and level and _swing_cd <= attack_floor * 0.5:
			_swing_cd = 0.0
			_start_swing(1)
			return

	# THEIR RHYTHM IS THE DRUMBEAT; their spacing only says where it waits
	# between beats. Getting this backwards produced a boss that respected a
	# cautious player's 190px so faithfully it never once came at them — it
	# stood at exactly arm's length for two thirds of its health and did
	# nothing. When the clock is up it commits to something, always.
	if _swing_cd <= 0.0:
		_pick_move(gap, level)
		return
	if gap > want * 1.15:
		_act = Act.CLOSE
		_act_t = 0.0
		return
	if gap < want * 0.62:
		# MIMIC and TIME keep to their measured spacing. DECIDE does not back
		# off from anything — it stays inside her guard on purpose.
		_act = Act.BACK if stage != Stage.DECIDE else Act.CLOSE
		_act_t = 0.0
		return
	_act = Act.WAIT
	_act_t = 0.0


## WHICH TRICK, AND WHY. Every weight here is a fact about the player: it does
## the thing their own habits leave them worst placed to answer. The stage only
## decides how much of the kit is unlocked.
func _pick_move(gap: float, level: bool) -> void:
	# ITS FIRST MOVE IS A DASH (Advika: *"instead of jumping towards the player
	# initially evil C should dash and then attack"*).
	#
	# The opening stage is MIMIC, which unlocks only the swing — so with her stood
	# anywhere but on top of it, `opts` came out empty and it fell through to CLOSE,
	# and CLOSE hops. The very first thing the boss did was bunny-hop across the
	# arena at her, which is not an entrance for a thing that has been watching her
	# fight; a dash is. The lunge's own animation is her DASH art, so this is also
	# the read: it opens by doing the move she opens with.
	#
	# Once only, and only from range — if she is already in its face when it wakes
	# it swings like it always did, and everything after this is the profile-driven
	# weighting untouched.
	if not _opened:
		_opened = true
		if gap > reach * 1.1 and level:
			_start_lunge()
			return

	var opts: Array = []          # [name, weight]

	if gap < reach * 1.05 and level:
		opts.append(["swing", 1.0])
		# THEY NEVER STOP SWINGING -> neither does it. Two blows on the rhythm
		# of a player who has thrown two hundred.
		if stage == Stage.DECIDE and _cd["combo"] <= 0.0:
			opts.append(["combo", 0.35 + clampf(
					PlayerProfile.attacks_per_minute() / 90.0, 0.0, 1.0) * 0.9])
	if stage != Stage.MIMIC and _cd["lunge"] <= 0.0 and gap > reach * 1.1 \
			and gap < 900.0 and level:
		# THEY LIKE THEIR SPACE -> there is nowhere far enough away. The
		# further out they habitually stand, the more this is its answer.
		opts.append(["lunge", 0.5 + clampf(
				PlayerProfile.engage_distance / 260.0, 0.0, 1.0) * 1.1])
	if stage == Stage.DECIDE and _cd["leap"] <= 0.0 and gap > reach * 0.9 \
			and gap < 620.0:
		# THEY LIVE IN THE AIR -> it goes up there after them.
		opts.append(["leap", 0.25 + PlayerProfile.air_fraction * 2.0])

	if opts.is_empty():
		_act = Act.CLOSE
		_act_t = 0.0
		return
	var total := 0.0
	for o in opts:
		total += float(o[1])
	var roll: float = randf() * total
	for o in opts:
		roll -= float(o[1])
		if roll <= 0.0:
			match String(o[0]):
				"swing": _start_swing(1)
				"combo": _start_swing(2)
				"lunge": _start_lunge()
				"leap": _start_leap()
			return
	_start_swing(1)


## HER RHYTHM, AS ITS CLOCK. The mean gap between her swings becomes the gap
## between its own moves — and in the last third it moves inside that gap,
## which is the first thing in the fight that is faster than the player.
func _rhythm() -> float:
	var cad: float = PlayerProfile.attack_cadence_mean
	if cad <= 0.05:
		cad = 1.1
	if stage == Stage.TIME:
		cad *= 0.88
	elif stage == Stage.DECIDE:
		cad *= 0.7
	return maxf(attack_floor, minf(cad, 2.4))


# ---------- the moves ----------

func _start_swing(blows: int) -> void:
	_act = Act.SWING
	_act_t = 0.0
	_hit_landed = false
	_blows_left = blows
	_swing_cd = _rhythm()
	if blows > 1:
		_cd["combo"] = 5.0
	_visual.speed_scale = 2.0
	_visual.play(&"attack")
	# it plants for the blow, plus the cut-off step in the last stage
	_target_vx = _cutoff() * 2.2


func _run_swing() -> void:
	_target_vx = 0.0
	if not _hit_landed and _act_t >= windup:
		_hit_landed = true
		_swing(damage)
	if _act_t >= windup + strike_recover:
		_blows_left -= 1
		if _blows_left > 0:
			# THE SECOND ONE IS FASTER. A combo that repeats at the same speed
			# is two swings; the acceleration is what makes it one move.
			_act_t = windup * 0.35
			_hit_landed = false
			_visual.speed_scale = 2.6
			_visual.play(&"attack")
			_target_vx = _dir_to_player() * walk_speed * 0.5
			return
		# IT GIVES GROUND AFTER IT SWINGS (Advika: "once he attacks there needs
		# to be distance b/w it and the player"). It used to drop straight back
		# into footwork still standing inside its own reach, so a landed blow
		# was followed by it simply being there, on top of her, with the next
		# swing already charging. There was no beat to read and no room to
		# answer in. Now the recovery IS a step back: it disengages for
		# `disengage_time`, which is the window the whole fight is legible
		# through — her punish, or her retreat, or her heal.
		_act = Act.BACK
		_act_t = 0.0
		_think = disengage_time
		_visual.speed_scale = 1.0


## THE LUNGE — a committed dash, blade out, across most of a screen. It is the
## answer to distance, so it is deliberately un-cancellable: once it goes it
## goes, and a player who reads it can punish the recovery.
const LUNGE_SPEED := 940.0
const LUNGE_WINDUP := 0.26
const LUNGE_DRIVE := 0.30
const LUNGE_RECOVER := 0.46
## the lunge is the biggest commitment it makes, so it is the biggest opening
const LUNGE_DISENGAGE := 0.55

func _start_lunge() -> void:
	_act = Act.LUNGE
	_act_t = 0.0
	_hit_landed = false
	_swing_cd = _rhythm() * 1.15
	_cd["lunge"] = 3.4
	_target_vx = 0.0
	# the run clip is her DASH art, and a lunge is exactly that — the one
	# moment it is allowed to look like it is sprinting
	_visual.speed_scale = 1.0
	_visual.play(&"run")


func _run_lunge() -> void:
	if _act_t < LUNGE_WINDUP:
		# it gathers, and the eyes give it away
		_target_vx = -_dir_to_player() * walk_speed * 0.35
		return
	if _act_t < LUNGE_WINDUP + LUNGE_DRIVE:
		_target_vx = _dir_to_player() * LUNGE_SPEED
		# the blade is live for the whole drive, but it can only land once
		if not _hit_landed:
			if _swing(damage + 4, 1.35):
				_hit_landed = true
		return
	# the recovery is a step BACK, not a stop: after crossing most of a screen
	# to reach her it does not get to stand there afterwards
	_target_vx = -_dir_to_player() * walk_speed * 0.75
	if _act_t >= LUNGE_WINDUP + LUNGE_DRIVE + LUNGE_RECOVER:
		_act = Act.BACK
		_act_t = 0.0
		_think = LUNGE_DISENGAGE


## THE LEAP — it goes over her and comes down. The landing hits BOTH sides, so
## walking under it is not the answer; moving is.
const LEAP_WINDUP := 0.30
const LEAP_DAMAGE_BONUS := 8
## HOW FAR PAST HER IT COMES DOWN. Advika: it kept landing ON TOP of Curiosity,
## which is exactly what the old aim asked for — the horizontal speed was solved
## as `gap / air_time`, i.e. "arrive precisely where she is standing". A leap
## that ends inside her is unreadable: there is no side to it, she cannot tell
## which way to turn, and the two bodies overlap.
##
## It now aims for her far side plus this clearance. 170 is chosen against the
## fight's own numbers, not by feel: her collider is ~29px wide, so it clears
## her completely, and it is inside the landing blow's reach (118 x 1.5 = 177),
## so crossing over her still threatens — it just does it from somewhere she has
## to turn around to answer.
const LEAP_CLEAR := 170.0

func _start_leap() -> void:
	_act = Act.LEAP
	_act_t = 0.0
	_hit_landed = false
	_swing_cd = _rhythm() * 1.3
	_cd["leap"] = 5.2
	_target_vx = 0.0
	_visual.speed_scale = 1.0


func _run_leap() -> void:
	if _act_t < LEAP_WINDUP:
		_target_vx = 0.0
		return
	if is_on_floor() and _act_t < LEAP_WINDUP + 0.1:
		# it goes OVER her and comes down on the far side. Time in the air is
		# fixed by her own gravity and jump, so the horizontal speed is solved
		# from the distance rather than guessed — the distance is now the gap
		# PLUS the clearance, on the side she is not on.
		velocity.y = jump_velocity * 1.12
		var air: float = 2.0 * absf(jump_velocity * 1.12) / gravity
		var g: float = _gap()
		var over: float = g + signf(g if g != 0.0 else 1.0) * LEAP_CLEAR
		_target_vx = clampf(over / maxf(air, 0.2), -run_speed * 3.2, run_speed * 3.2)
		velocity.x = _target_vx      # the one place a leap needs its speed NOW
		_visual.play(&"jump")
		return
	if not is_on_floor():
		return
	# LANDED
	if not _hit_landed:
		_hit_landed = true
		_target_vx = 0.0
		# AND IT TURNS, IMMEDIATELY. It has just crossed over her, so it is
		# standing at her back — the whole point of the move. `_face()` is
		# suppressed for the whole airborne leap and then rate-limited by
		# FACE_MIN_HOLD, which left it facing the way it jumped FROM for a
		# beat after landing: back to the player, blade pointing at nothing.
		_face_hold = 0.0
		_facing_right = _gap() > 0.0
		_visual.flip_h = not _facing_right
		_visual.speed_scale = 2.0
		_visual.play(&"attack")
		_swing(damage + LEAP_DAMAGE_BONUS, 1.5, true)
		Haptics.rumble(0.25, 0.8)
	if _act_t >= LEAP_WINDUP + 0.9:
		_act = Act.WAIT
		_act_t = 0.0
		_visual.speed_scale = 1.0


## Polled at the frame a blow lands — the same shape her own swing uses (a
## forward reach test), not an Area2D, so it cannot hit anything behind it and
## cannot hit her twice on one blow. `both_sides` is the leap's landing, which
## does not care which way it happens to be facing when it comes down.
func _swing(amount: int, span := 1.0, both_sides := false) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var dx: float = _gap()
	var facing: float = -1.0 if _visual.flip_h else 1.0
	if not both_sides and signf(dx) != facing:
		return false
	if absf(dx) > reach * span \
			or absf(target.global_position.y - global_position.y) > reach_y:
		return false
	if not target.has_method("take_damage"):
		return false
	var before: int = target.health if "health" in target else -1
	var kick: float = signf(dx) if both_sides else facing
	target.take_damage(amount, Vector2(kick * 210.0, -140.0))
	Haptics.buzz(90, 0.7)
	if before < 0 or target.health < before:
		struck_player.emit()
		# THEY BACK OFF AFTER TRADING -> it follows them off. The habit that
		# keeps them alive against everything else in the game is the habit it
		# was built to punish.
		if stage == Stage.DECIDE and PlayerProfile.retreat_tendency > 0.45:
			_swing_cd = minf(_swing_cd, attack_floor)
		# IT ENJOYS IT. The celebrate frames have been sitting unused since the
		# first import; this is what they were for.
		elif randf() < 0.3:
			_gloat()
		return true
	return false


func _gloat() -> void:
	_act = Act.WAIT
	_act_t = 0.0
	_think = 0.9
	_visual.speed_scale = 1.0
	_visual.play(&"celebrate")
	await get_tree().create_timer(0.9).timeout
	if not _dying and _visual != null and _visual.animation == &"celebrate":
		_visual.play(&"idle")


## Their dodge is a habit, and a habit is a direction. In DECIDE the boss steps
## THAT way before it swings, so the escape they have used all game runs them
## into it. Returns a world-x nudge, or 0 while it has no read on them.
func _cutoff() -> float:
	if stage != Stage.DECIDE:
		return 0.0
	var b: float = PlayerProfile.dodge_bias
	if absf(b) < 0.2:
		return 0.0
	return signf(b) * reach * 0.75


# ---------- being hit ----------

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if _dying or not live:
		return
	health = maxi(0, health - amount)
	_bar.set_ratio(float(health) / float(max_health))
	if health <= 0:
		_die()
		return
	# A LUNGE OR A LANDING IS NOT INTERRUPTIBLE. Letting a single hit cancel a
	# committed move made the whole fight a stun-lock: stand next to it and it
	# never finished anything. It still FLINCHES — it just does not stop.
	var committed: bool = (_act == Act.LUNGE and _act_t > LUNGE_WINDUP) \
			or (_act == Act.LEAP and _act_t > LEAP_WINDUP)
	_visual.modulate = Color(2.2, 1.4, 1.4, _visual.modulate.a)
	create_tween().tween_property(_visual, "modulate",
			Color(1, 1, 1, _visual.modulate.a), 0.16)
	if not committed:
		_act = Act.HURT
		_act_t = 0.0
		_hit_landed = true
		_visual.speed_scale = 1.0
		_visual.play(&"hurt")
		velocity = Vector2(knockback.x * 0.45, minf(knockback.y, -70.0))
		_target_vx = 0.0
	_check_stage()


## Two thirds and one third. Each crossing is a beat: it stands up, the eyes
## burn, and what it is allowed to do changes in a way the player can name.
func _check_stage() -> void:
	var f: float = float(health) / float(max_health)
	var want: int = Stage.MIMIC
	if f <= 0.34:
		want = Stage.DECIDE
	elif f <= 0.67:
		want = Stage.TIME
	if want == stage:
		return
	stage = want
	_read_swing = false
	for k in _cd:
		_cd[k] = 0.0

	# THE BREAK HAS TO LAND. Two thirds of its health went by with nothing to
	# show for it but a number, which is most of why the fight read flat. Now
	# each crossing is an event: it is thrown backwards off her, it holds there
	# for a beat with the eyes burning at nearly twice size, and then it comes
	# back meaner. The player gets to SEE that they broke something.
	_act = Act.HURT
	_act_t = 0.0
	_think = 0.85
	_swing_cd = maxf(_swing_cd, 0.85)
	velocity = Vector2(-_dir_to_player() * 260.0, -210.0)
	_target_vx = 0.0
	_visual.speed_scale = 1.0
	_visual.play(&"hurt")
	_visual.modulate = Color(3.0, 1.5, 1.5, _visual.modulate.a)
	create_tween().tween_property(_visual, "modulate",
			Color(1, 1, 1, _visual.modulate.a), 0.55)
	Haptics.rumble(0.55, 0.9)
	var tw := create_tween()
	tw.tween_property(_eyes, "texture_scale", 1.45, 0.18)
	tw.tween_interval(0.45)
	tw.tween_property(_eyes, "texture_scale", 0.7, 0.8)
	# and the rim goes with them, so the silhouette flares out of the dark
	var rt := create_tween()
	rt.tween_property(_rim, "energy", 2.4, 0.18)
	rt.tween_property(_rim, "energy", 1.05, 1.1)
	stage_changed.emit(stage)


func _die() -> void:
	_dying = true
	live = false
	_act = Act.DEAD
	collision_layer = 0
	_bar.set_ratio(0.0)
	_bar.visible = false
	_visual.speed_scale = 1.0
	_visual.play(&"hurt")
	velocity = Vector2.ZERO
	# THE EYES OUTLIVE THE BODY. The shape goes first and the two red lights
	# stay where it was standing, alone, in a forest with nothing else red in
	# it — then they BLINK, once, and only then go out. That blink is the whole
	# ending's argument and it costs no words: a thing that blinks was never a
	# monster, it was somebody, and somebody taught it how to be her.
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_rim, "energy", 0.0, 1.4)
	tw.parallel().tween_property(_visual, "modulate:a", 0.0, 2.2)
	# it holds, lit, with nothing under it
	tw.tween_interval(1.1)
	# the blink: shut fast, open, hold — a lid, not a fade
	tw.tween_property(_eyes, "energy", 0.0, 0.12)
	tw.tween_interval(0.14)
	tw.tween_property(_eyes, "energy", 2.6, 0.16)
	tw.tween_interval(0.9)
	# and then it is not looking at anything
	tw.tween_property(_eyes, "energy", 0.0, 1.6)
	tw.tween_callback(func() -> void: died.emit())


# ---------- presentation ----------

func _face() -> void:
	# it does not spin on the spot. A leap crosses over her and a lunge drives
	# past her, and turning to keep looking at her mid-flight is exactly the
	# twitch that made it read as a cursor rather than a body.
	if _act == Act.LUNGE and _act_t > LUNGE_WINDUP:
		return
	if _act == Act.LEAP and not is_on_floor():
		return
	# A DEADZONE, because it was flipping every frame it stood level with her.
	# Advika: her animation feels smooth and this one does not. Most of that is
	# here — `_gap() > 0.0` has no dead space, so whenever the fight closed to
	# arm's length and she drifted across its centre line the sprite snapped
	# left-right-left at sixty hertz. A body does not do that. It only turns
	# once she is properly on the other side of it, and never twice in a
	# quarter second.
	var g: float = _gap()
	if absf(g) > FACE_DEADZONE and _face_hold <= 0.0:
		var right: bool = g > 0.0
		if right != _facing_right:
			_facing_right = right
			_face_hold = FACE_MIN_HOLD
	# her art faces right, so unflipped = facing right
	_visual.flip_h = not _facing_right


func _animate() -> void:
	if _in_move() or _act == Act.HURT or _dying:
		return
	if _visual.animation == &"celebrate":
		return
	if not is_on_floor():
		if _visual.animation != &"jump":
			_visual.play(&"jump")
		return
	# IT WAS SPRINTING EVERYWHERE, AND HERE IS WHY (Advika: "why is he running
	# towards u???"). Her `walk_speed` is 200 and her `run_speed` is 210 — they
	# are almost the same number, because she does not have a jog and a sprint;
	# she has a WALK, and `run` is the clip her DASH borrows. This picked its
	# animation off an absolute threshold of `run_speed * 0.8` = 168, and since
	# every ordinary step it takes is 200-210, it was over that line the entire
	# fight. It ran at her, constantly, at walking pace.
	#
	# It follows her rule now: walk is locomotion, run belongs to the burst.
	if _act == Act.LUNGE:
		return
	var sp: float = absf(velocity.x)
	var want := &"idle"
	# hysteresis on the one threshold that is left, so accelerating away from
	# standing does not restart the clip several times a second
	var out_of_idle: float = 14.0 if _visual.animation == &"walk" else 34.0
	if sp > out_of_idle:
		want = &"walk"
	# HER anti-slide rule, copied exactly: at walk_speed the clip runs at its
	# drawn rate and below that it slows with the body, so the feet never skate.
	# This is a real part of what "smooth" means on her and it was missing here.
	_visual.speed_scale = clampf(sp / walk_speed, 0.7, 1.0) if want == &"walk" 			else 1.0
	if _visual.animation != want:
		_visual.play(want)


func _on_anim_done() -> void:
	if _visual.animation == &"hurt" and not _dying:
		_act = Act.WAIT
		_act_t = 0.0
		_visual.play(&"idle")


## one line for a debug overlay — what it is doing and why
func debug_state() -> String:
	var st: String = ["MIMIC", "TIME", "DECIDE"][stage]
	var ac: String = ["wait", "close", "back", "swing", "lunge", "leap",
			"hurt", "dead"][_act]
	return "MIRROR  %s / %s  hp %d/%d  gap %.0f  next %.2f  %s" \
			% [st, ac, health, max_health, absf(_gap()) if target != null else 0.0,
			_swing_cd, "(she is swinging)" if _her_swing_t >= 0.0 else ""]
