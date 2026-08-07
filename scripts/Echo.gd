extends Node2D
class_name Echo

## Realm 3's whole concept, in one object: THE THING BEHIND YOU IS YOU.
##
## It does not chase and it has no AI. It replays the player's own recorded
## path, a fixed number of seconds late — every step, every jump, every place
## they stopped. Which makes it two things at once:
##
##   THREAT — it walks exactly where you walked, so you can never be safe
##            anywhere you have already been, and it arrives on YOUR schedule.
##   TOOL   — you can leave your past self somewhere useful. Stand on a plate,
##            walk away, and in ten seconds someone is standing on that plate
##            holding a door open for you.
##
## The dread has no speed-up in it. `delay` SHRINKS as she goes deeper —
## twelve seconds at the mouth of the forest, three at the far end — so it is
## never faster, it is only ever closer to being now.

signal caught

## the anti-lantern: pale, bloodless, no gold anywhere in it
const COLD := Color(0.62, 0.86, 0.92)
## what it is up close — a hole cut in the forest
const BODY_DARK := Color(0.02, 0.03, 0.03)

const ANIM := ["idle", "walk", "jump"]

## how far behind it starts, in seconds — a whole rumour away
@export var delay_start: float = 12.0
## and what it has closed to when the clock runs out: standing where she stands
@export var delay_end: float = 0.4

## 0 at the start of the level, 1 when the time is gone. THE CLOCK AND THE
## SHADOW ARE THE SAME PRESSURE — the realm gives her fifteen minutes, and
## what "fifteen minutes" MEANS is that in fifteen minutes her own past is
## standing on top of her. There is no separate fail rule to explain.
var pressure: float = 0.0
## close enough to be taken
@export var catch_dist: float = 70.0
## it is shaped like Curiosity and it is not the right size
@export var body_scale: float = 0.29
## the frames are centred on the body, so the origin rides above her feet
@export var body_lift: float = 52.0
## distance at which it is fully swallowed by haze
@export var fade_dist: float = 1250.0
## what the far haze stains it (the realm's fog tint)
@export var haze: Color = Color(0.20, 0.38, 0.34)

var target: CharacterBody2D = null

var _body: AnimatedSprite2D
var _lamp: PointLight2D
## ring buffer of everything she has done — 20s of it at the physics rate
var _cap: int = 1200
var _px: PackedFloat32Array
var _py: PackedFloat32Array
var _pflip: PackedByteArray
var _panim: PackedByteArray
var _head: int = 0
var _count: int = 0
## it cannot take her until she has genuinely got away from it once — without
## this it would "catch" her on frame one, standing where she is standing
var _armed := false
var _delay := 0.0


func _ready() -> void:
	_px.resize(_cap)
	_py.resize(_cap)
	_pflip.resize(_cap)
	_panim.resize(_cap)
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = load("res://assets/player/curiosity/curiosity_frames.tres")
	_body.animation = "idle"
	_body.scale = Vector2(body_scale, body_scale)
	_body.play()
	add_child(_body)
	# Her lantern is the only warm thing in the game. This is the cold one — it
	# is how you FIND the shape in a dark forest, and the palette does the
	# telling: gold is you, this is not.
	_lamp = PointLight2D.new()
	_lamp.color = COLD
	_lamp.texture = load("res://assets/effects/lantern_halo.png")
	_lamp.texture_scale = 1.35
	_lamp.energy = 0.0
	add_child(_lamp)
	z_index = 5
	_delay = delay_start


## how late it currently is, in seconds — the realm's actual difficulty curve
func delay_now() -> float:
	return _delay


## whether it is currently allowed to take her (see the arming rule below)
func is_armed() -> bool:
	return _armed


func clear_history() -> void:
	_count = 0
	_head = 0
	_armed = false


func _physics_process(delta: float) -> void:
	if target == null or delta <= 0.0:
		return

	# ---- record what she just did ----
	var state := 0
	if not target.is_on_floor():
		state = 2
	elif absf(target.velocity.x) > 25.0:
		state = 1
	_px[_head] = target.global_position.x
	_py[_head] = target.global_position.y
	_pflip[_head] = 1 if target.velocity.x < -25.0 else (0 if target.velocity.x > 25.0 else _pflip[(_head - 1 + _cap) % _cap])
	_panim[_head] = state
	_head = (_head + 1) % _cap
	_count = mini(_count + 1, _cap)

	# ---- it is never faster, only ever closer to being now ----
	_delay = lerpf(delay_start, delay_end, clampf(pressure, 0.0, 1.0))

	# ---- replay ----
	var want: int = int(round(_delay / delta))
	# before there is that much history it waits at the oldest thing she did,
	# which is the spot she started from: it comes out of where she came in
	var back: int = mini(want, _count - 1)
	if back < 0:
		return
	var i: int = (_head - 1 - back + _cap * 2) % _cap
	# where she actually WAS. The node sits `body_lift` above this, because the
	# frames are centred on the body rather than the feet — so every distance
	# test below has to use the path point, not the node, or it carries a
	# constant 52px of error and `catch_dist` never means what it says.
	var was := Vector2(_px[i], _py[i])
	global_position = Vector2(was.x, was.y - body_lift)
	_body.flip_h = _pflip[i] == 1
	var a: String = ANIM[_panim[i]]
	if _body.animation != a:
		_body.animation = a
		_body.play()
	# it walks its own path at her pace, but it is never in a hurry about it
	_body.speed_scale = 0.85

	# ---- far off a stain in the haze; up close a hole in the world ----
	var d: float = target.global_position.distance_to(was)
	var near: float = 1.0 - clampf(d / maxf(fade_dist, 1.0), 0.0, 1.0)
	_body.modulate = haze.lerp(BODY_DARK, near)
	_body.modulate.a = lerpf(0.55, 1.0, near)
	# the cold pool comes up as it closes — you see the light before the shape
	_lamp.energy = lerpf(0.30, 0.95, near)

	# It may only take her once she has genuinely got away from it — but "away"
	# cannot be a fixed number. Late in the level it is two seconds behind, and
	# two seconds of walking is ~400px: a flat 500 would mean the echo becomes
	# HARMLESS exactly when it is closest. So the bar is what its own delay is
	# worth on foot, and never less than a body's width of clearance.
	if not _armed and d > maxf(catch_dist * 2.5, _delay * 120.0):
		_armed = true
	if _armed and d < catch_dist:
		_armed = false
		caught.emit()
