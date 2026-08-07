extends StaticBody2D
class_name Sporeling

## A mushroom that SPROUTS out of the ground, opens two beady red eyes, and
## jumps at her.
##
## It is not in the level until she is near it. The ground is empty; she walks;
## it comes UP out of the meadow in front of her (Advika: fresh ones sprout out
## from the ground) and then it commits — every hop from that moment is aimed
## at whoever is closest.
##
## Uniform on purpose (Advika): every one is the same size, the same hop, the
## same rhythm — they read as a SPECIES living down the whole cavern, not as
## scattered set-dressing. Only the phase differs, so a stretch of them ripples
## instead of pulsing in lockstep.
##
## The eyes are the tell. Everything else in this forest glows teal, amber or
## moss green; these are the only red things in it, exactly like the wizard's
## eyes in Realm 2 — evil at a glance, no text required.
##
## It hops toward whichever is nearer: Curiosity, or the thing wearing her
## shape. The echo cannot swing a blade, but it CAN pull them off her.

signal popped

## the breath from Realm 1's jade pickup set — see `_sprout`
const SPROUT_SFX: AudioStream = preload("res://assets/audio/jade/jade_pickup_4_breath.wav")

const SPORE_TEX := "res://assets/realms/realm2_moss/spore.png"
const HALO := "res://assets/effects/lantern_halo.png"
## the only red in the realm
const EYE_RED := Color(1.0, 0.22, 0.18)

## one rhythm for the whole species.
## These numbers are the difference between "it is coming at me" and "it is
## sitting there": at 96px per 1.5s it closed 64px/s against her 200px/s walk,
## so it could never arrive and read as not chasing at all. 175px per 0.9s is
## ~194px/s — it runs her down at a walk, and she has to actually run or fight.
@export var hop_period: float = 0.9
## the fraction of that period actually spent in the air — mostly airborne, so
## it reads as leaping rather than pausing between little hops
@export var air_frac: float = 0.58
@export var hop_height: float = 140.0
@export var hop_dist: float = 175.0
## how close she has to get before it breaks ground
@export var sprout_dist: float = 540.0
## once it is up it never loses interest — every hop is aimed at her
@export var aggro: float = 100000.0
@export var touch_dist: float = 62.0
@export var damage: int = 14
## SMALLER THAN CURIOSITY (Advika) — she stands ~130px tall in this realm, so
## these come up to about two-thirds of her. Set as a target height in pixels
## and the scale is solved from the texture, so swapping the art keeps the size.
@export var target_height: float = 86.0
## THEIR OWN HUE (Advika) — everything else out here is teal, amber or moss
## green. These are a dusky rust: warm, sickly, off-palette on purpose, and the
## same family as the red in their eyes so the species reads as one thing.
## THEIR HUE. A flat warm wash went muddy — the realm's CanvasModulate is a
## teal multiply (0.55, 0.72, 0.68), so anything already brownish comes out
## mud. This is pale bone pushed slightly past white on red, which survives
## the grade as a warm ivory creature standing in a cold forest.
@export var hue: Color = Color(1.16, 1.0, 0.86)
## and it glows, because EVERYTHING alive in this cavern glows — the caps, the
## spires, the ghost mushrooms. A creature that did not would read as pasted on.
@export var glow_col: Color = Color(1.0, 0.85, 0.62)
@export var glow_energy: float = 0.55
## Where the face goes, per mushroom. These three are all TOP-HEAVY — cap in
## the top ~13%, long bare stem under it — so a fraction measured from the
## FEET has to be up near 0.85 or the eyes end up halfway down the stalk.
@export var eye_y_frac: float = 0.85    # up from the base, as a fraction of height
@export var eye_dx_frac: float = 0.14   # apart, as a fraction of width
@export var eye_x_off_frac: float = 0.0 # the cap is not always centred on the stem
var body_scale: float = 0.52
@export var tex_name: String = "mushroomglow20.png"
@export var base_dir: String = "res://assets/realms/realm3_fungal/"
## staggers this one against its neighbours
@export var phase: float = 0.0

## everything it reacts to — her, and the echo
var triggers: Array[Node2D] = []

var _visual: Node2D
var _spr: Sprite2D
var _eye_l: Sprite2D
var _eye_r: Sprite2D
var _eye_lamp: PointLight2D
var _aura: PointLight2D
var _t := 0.0
var _ground_x := 0.0
var _ground_y := 0.0
var _dir := 1.0
## how far this particular leap commits — clamped to the gap so it lands on
## her instead of sailing over her head
var _hop_len := 0.0
## how long a single blink takes, lid down and back up
const BLINK_DUR := 0.13
var _blink_wait := 0.0
var _blink_left := 0.0
## the eyes' resting scale, so a blink can squash and restore it exactly
var _eye_scale := Vector2.ONE
var _cycle := -1
var _dead := false
var _touch_cd := 0.0
## underground until she comes near
var _awake := false
## mid-sprout: it is coming up and cannot be hit or hop yet
var _rising := false

## --- THE CEILING DROP (Advika: mushrooms spawn upside down from the ceiling,
## fall to the ground, then attack) ---
## The same animal, arriving a different way. It is deliberately NOT a second
## species: the boss fight should feel like the forest itself joining in, and a
## brand-new creature in the last two minutes would read as a different game.
## It hangs from the roof upside down, lets go, falls, lands hard — and from
## the landing on it is an ordinary sporeling with the ordinary hop.
var _falling := false
var _fall_v := 0.0
var _land_y := 0.0
const FALL_GRAVITY := 1150.0
const FALL_MAX := 1250.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4    # the layer her swing box reads (same as the golems)
	collision_mask = 0
	_ground_x = position.x
	_ground_y = position.y

	_visual = Node2D.new()
	add_child(_visual)
	_spr = Sprite2D.new()
	_spr.texture = load(base_dir + tex_name)
	# solve the scale from the target height so the species is one size
	body_scale = target_height / maxf(float(_spr.texture.get_height()), 1.0)
	_spr.scale = Vector2(body_scale, body_scale)
	_spr.modulate = hue
	# bottom-anchored: it sits ON the meadow, it never hovers in it
	_spr.position = Vector2(0.0, -_spr.texture.get_height() * body_scale * 0.46)
	_visual.add_child(_spr)
	# its own aura, in the realm's own idiom, sized to the cap
	_aura = PointLight2D.new()
	_aura.texture = load(HALO)
	_aura.texture_scale = target_height * 0.006
	_aura.color = glow_col
	_aura.energy = glow_energy
	_aura.position = Vector2(0.0, -target_height * 0.55)
	_aura.z_index = -1
	_visual.add_child(_aura)

	# --- the eyes: BEADY (Advika) — a tight solid bead with only a small
	# bloom around it, not the soft blobs the first pass had ---
	var tw: float = _spr.texture.get_width() * body_scale
	var th: float = _spr.texture.get_height() * body_scale
	var cap_y: float = -th * eye_y_frac
	var cap_x: float = tw * eye_x_off_frac
	var eye_dx: float = tw * eye_dx_frac
	_eye_l = _make_eye(Vector2(cap_x - eye_dx, cap_y), tw)
	_eye_r = _make_eye(Vector2(cap_x + eye_dx, cap_y), tw)
	# captured before anything animates it, so a blink always returns home
	_eye_scale = _eye_l.scale
	# stagger the first blink per individual — a whole stretch blinking in
	# unison would read as one creature with many heads
	_blink_wait = randf_range(0.6, 4.4)
	_eye_lamp = PointLight2D.new()
	_eye_lamp.texture = load(HALO)
	_eye_lamp.texture_scale = 0.34
	_eye_lamp.color = EYE_RED
	_eye_lamp.energy = 0.85
	_eye_lamp.position = Vector2(cap_x, cap_y)
	_visual.add_child(_eye_lamp)

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(74.0, 92.0)
	cs.shape = rect
	cs.position = Vector2(0.0, -44.0)
	add_child(cs)
	# BEHIND the front moss row (z7), like she is (z5) — at z7 they sat on top
	# of the moss and read as pasted onto the level instead of living in it.
	# At 6 the moss takes their stems and leaves the cap and the eyes showing.
	z_index = 6
	# it is not in the level yet: nothing to see, nothing to hit
	_visual.visible = false
	_visual.scale = Vector2(0.9, 0.02)
	collision_layer = 0


## a small bloom with a hard little bead sitting in the middle of it —
## the bead is what makes it an EYE instead of a glow
func _make_eye(at: Vector2, cap_w: float) -> Sprite2D:
	var e := Sprite2D.new()
	e.texture = load(HALO)
	var es: float = cap_w * 0.00075
	e.scale = Vector2(es, es)
	e.position = at
	e.modulate = Color(EYE_RED.r, EYE_RED.g, EYE_RED.b, 0.75)
	e.z_index = 1
	_visual.add_child(e)
	var bead := Polygon2D.new()
	var r: float = maxf(cap_w * 0.022, 2.0)
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	bead.polygon = pts
	bead.color = Color(1.0, 0.42, 0.34)
	bead.z_index = 2
	_visual.add_child(bead)
	return e


func _process(delta: float) -> void:
	if _dead:
		return

	# --- still underground: wait for her, then break ground ---
	if not _awake:
		for n in triggers:
			if n != null and absf(n.global_position.x - position.x) < sprout_dist:
				_sprout()
				break
		return
	if _falling:
		_fall_v = minf(_fall_v + FALL_GRAVITY * delta, FALL_MAX)
		position.y += _fall_v * delta
		# it spins a little as it comes down, so a falling one is legible in
		# peripheral vision while she is busy with the boss
		_visual.rotation += delta * 2.4 * signf(_fall_v)
		if position.y >= _land_y:
			position.y = _land_y
			_land()
		return
	if _rising:
		return

	_t += delta
	_touch_cd = maxf(0.0, _touch_cd - delta)

	var span: float = maxf(hop_period, 0.05)
	var walked: float = _t + phase
	var cyc: int = int(floor(walked / span))
	var p: float = fmod(walked, span) / span

	# a new hop begins: plant the takeoff spot, pick a direction, and decide
	# how far to commit. Without the clamp a full 175px leap sails clean OVER
	# her when she is standing close and lands behind — it looked like it was
	# running away. Now it lands ON her.
	if cyc != _cycle:
		_cycle = cyc
		_ground_x = position.x
		_dir = _pick_dir()
		_hop_len = hop_dist
		var near: Node2D = _nearest()
		if near != null:
			var gap: float = absf(near.global_position.x - position.x)
			if gap < hop_dist:
				_hop_len = maxf(gap, 34.0)
		_spr.flip_h = _dir < 0.0

	if p < air_frac:
		# --- in the air ---
		var a: float = p / air_frac
		position.x = _ground_x + _dir * _hop_len * a
		# A BALLISTIC arc. It was sin(a*PI), which leaves the ground at zero
		# vertical speed and arrives at zero vertical speed — so it drifted up,
		# hung, and settled back down like it was on a string. A thrown thing
		# is a parabola: it LAUNCHES, and it comes down just as hard.
		var arc: float = 4.0 * a * (1.0 - a)
		position.y = _ground_y - arc * hop_height
		# Stretch follows vertical SPEED, so it is longest leaving the ground
		# and longest landing, and roundest at the top. It used to ride the
		# same sine as the height, which made it fattest at the apex — exactly
		# backwards, and half of why the hop read as wrong.
		var vy: float = absf(1.0 - 2.0 * a)   # 1 at takeoff/landing, 0 at apex
		var stretch: float = 1.0 + vy * 0.22
		_visual.scale = Vector2(1.0 / stretch, stretch)
	else:
		# --- landed: squash, settle, then GATHER for the next one ---
		position.y = _ground_y
		var s: float = (p - air_frac) / maxf(1.0 - air_frac, 0.01)
		var land: float = (1.0 - clampf(s * 3.2, 0.0, 1.0)) * 0.28
		# anticipation: it crouches before it leaps. Nothing alive launches
		# from a standing rest, and its absence is the other half of the wrong.
		var crouch: float = clampf((s - 0.62) / 0.38, 0.0, 1.0)
		var squash: float = 1.0 + land + crouch * crouch * 0.24
		_visual.scale = Vector2(squash, 1.0 / squash)

	# the eyes breathe on the species' own clock — never quite steady
	_eye_lamp.energy = 0.72 + sin(_t * 3.1 + phase) * 0.22

	# --- THE BLINK ---
	# Beads that never close are lights. Beads that close are EYES, and the
	# thing behind them is looking at her. Both lids together, on a random
	# interval so a row of them never blinks in chorus.
	_blink_wait -= delta
	if _blink_wait <= 0.0 and _blink_left <= 0.0:
		_blink_left = BLINK_DUR
		_blink_wait = randf_range(1.7, 5.2)
	if _blink_left > 0.0:
		_blink_left = maxf(0.0, _blink_left - delta)
		# shut and open again across the blink: 1 open, 0 shut
		var b: float = 1.0 - _blink_left / BLINK_DUR
		var open: float = 1.0 - sin(b * PI)
		var lid: float = maxf(open, 0.05)
		_eye_l.scale.y = _eye_scale.y * lid
		_eye_r.scale.y = _eye_scale.y * lid
		# the glow goes with them — a lid over a light dims the light
		_eye_lamp.energy *= 0.25 + 0.75 * open
	else:
		_eye_l.scale.y = _eye_scale.y
		_eye_r.scale.y = _eye_scale.y
	# the body glow breathes slower and out of step with them, the way the
	# realm's own glow caps do
	_aura.energy = glow_energy * (0.85 + sin(_t * 1.15 + phase * 1.7) * 0.15)

	# --- contact ---
	if _touch_cd <= 0.0:
		for n in triggers:
			if n != null and n.has_method("take_damage") \
					and n.global_position.distance_to(global_position) < touch_dist:
				var d: float = signf(n.global_position.x - global_position.x)
				if d == 0.0:
					d = 1.0
				n.take_damage(damage, Vector2(d * 250.0, -200.0))
				_touch_cd = 1.1
				break


## one line of truth for the hop log — awake? risen? which way is it going?
func debug_state() -> String:
	return "awake=%s rising=%s dir=%+0.0f cyc=%d" % [_awake, _rising, _dir, _cycle]


## it breaks ground: a squat nub shoves up out of the meadow, overshoots,
## settles — and only then does it have eyes, weight and a hitbox
func _sprout() -> void:
	# THE GROUND GIVES ONE UP (Advika: *"a lil sound effect when each mushroom
	# spawns, smth similar to the jade collecting thing"*). Same family as
	# Realm 1's jade chime on purpose, but the BREATH rather than its spark:
	# this realm's collectible-shaped beat is a thing waking up, not a thing
	# being taken. Well under the music, because six of these go off across the
	# walk and one loud one would turn the wood into a doorbell.
	AudioManager.play_sfx(SPROUT_SFX, -9.0)
	_awake = true
	_rising = true
	_visual.visible = true
	_visual.scale = Vector2(1.15, 0.04)
	_soil_puff()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", Vector2(0.94, 1.10), 0.30)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_visual, "scale", Vector2.ONE, 0.16)
	tw.tween_callback(func() -> void:
		_rising = false
		collision_layer = 4
		_t = 0.0
		_cycle = -1)


## HANG IT FROM THE ROOF. `ceiling_y` is where it grips, `ground_y` is the
## meadow it is going to hit. It grips, it is seen gripping, and only then does
## it let go — a thing that simply appeared and fell would be an unfair hit;
## the grip is the telegraph.
func drop_from(ceiling_y: float, ground_y: float, hang: float = 0.9) -> void:
	_awake = true
	_falling = false
	_rising = true          # keeps the hop logic off until it lands
	_land_y = ground_y
	position.y = ceiling_y
	_visual.visible = true
	_visual.scale = Vector2(1.0, -1.0)     # upside down, gripping the roof
	_visual.modulate.a = 0.0
	# it fades in gripping rather than popping into existence
	var tw := create_tween()
	tw.tween_property(_visual, "modulate:a", 1.0, 0.28)
	# a shiver before it lets go — the last warning
	tw.tween_property(_visual, "position:x", 3.0, 0.06).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_visual, "position:x", -3.0, 0.06)
	tw.tween_property(_visual, "position:x", 0.0, 0.06)
	tw.tween_interval(maxf(0.0, hang - 0.5))
	tw.tween_callback(func() -> void:
		_falling = true
		_fall_v = 0.0)


## it hits the meadow, rights itself, and is immediately dangerous
func _land() -> void:
	_falling = false
	_visual.rotation = 0.0
	_visual.scale = Vector2(1.28, 0.34)     # squashed flat by the impact
	_soil_puff()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", Vector2(0.92, 1.12), 0.22)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_visual, "scale", Vector2.ONE, 0.14)
	tw.tween_callback(func() -> void:
		_rising = false
		collision_layer = 4
		_t = 0.0
		_cycle = -1)


## the meadow spitting it out
func _soil_puff() -> void:
	var p := CPUParticles2D.new()
	p.texture = load(SPORE_TEX)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 14
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 62.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 320.0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.color = Color(0.42, 0.55, 0.44)
	p.z_index = 7
	get_parent().add_child(p)
	p.global_position = global_position
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


func _nearest() -> Node2D:
	var best: Node2D = null
	var best_d: float = aggro
	for n in triggers:
		if n == null:
			continue
		var d: float = absf(n.global_position.x - position.x)
		if d < best_d:
			best_d = d
			best = n
	return best


## it comes after whoever is closest
func _pick_dir() -> float:
	var best := _nearest()
	if best == null:
		return -_dir   # nobody near: it mills back and forth on its own patch
	var s: float = signf(best.global_position.x - position.x)
	return 1.0 if s == 0.0 else s


func take_damage(_amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	_dead = true
	popped.emit()
	_spray()
	_visual.visible = false
	collision_layer = 0
	queue_free()


## IT BURSTS INTO TINY GLOWING ORBS (Advika).
##
## Not a spore puff — the thing coming apart is made of light, and what is
## left of it hangs in the air a moment before it goes out. Small, many, and
## they SLOW rather than fall: damping holds them where they burst, so the
## death leaves a little constellation instead of a splash.
##
## Parented to the level, never to the mushroom — `take_damage` frees the
## mushroom on the same frame, and children would go with it.
func _spray() -> void:
	var host: Node = get_parent()
	var at: Vector2 = global_position + Vector2(0.0, -46.0)

	var p := CPUParticles2D.new()
	p.texture = _orb_texture()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 38
	p.lifetime = 1.7
	p.lifetime_randomness = 0.45
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 55.0
	p.initial_velocity_max = 190.0
	# barely any fall, and they brake hard — the orbs hang where it died
	p.gravity = Vector2(0, 14.0)
	p.damping_min = 90.0
	p.damping_max = 160.0
	p.scale_amount_min = 0.10
	p.scale_amount_max = 0.26
	# its own red, cooling into the forest's living green as it lets go
	var ramp := Gradient.new()
	ramp.set_color(0, EYE_RED)
	ramp.set_color(1, Color(0.62, 0.95, 0.58, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.86, 0.62, 0.95))
	p.color_ramp = ramp
	p.z_index = 6
	host.add_child(p)
	p.global_position = at

	# the pop itself: one short bloom of light, gone in a third of a second
	var flash := PointLight2D.new()
	flash.texture = load(HALO)
	flash.texture_scale = 0.9
	flash.color = Color(1.0, 0.78, 0.55)
	flash.energy = 2.4
	host.add_child(flash)
	flash.global_position = at
	var tw := flash.create_tween()
	tw.tween_property(flash, "energy", 0.0, 0.34)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)

	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


## a tiny soft orb, built in code — nothing to export, and it stays round at
## any scale because it is a radial gradient rather than a sprite
func _orb_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.42, Color(1, 1, 1, 0.85))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
