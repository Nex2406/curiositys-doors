extends Node2D
class_name EndDoorSpirit

# The prologue's smoke-spirit — the half-seen hooded figure that circled the cauldron in
# the very first scene — reused here as a still apparition hovering by a realm's exit
# door. Built in code from the same painted sprite + soft-additive eye glows + rising
# wisps as IntroEffects, but instead of orbiting it just floats: a slow bob & sway, a
# gentle tilt, a breathing alpha so it fades toward transparent and back like it's barely
# holding its shape, and a gate-keeping eye-glow pulse.

const BODY_TEX := "res://assets/effects/spirit_body.png"
const EYE_TEX := "res://assets/effects/spirit_eye.png"
const HALO_TEX := "res://assets/effects/lantern_halo.png"
const EYE_OFFSET: Vector2 = Vector2(21.0, -94.0)   # eye sockets in the 512px texture
const EYE_TINT: Color = Color(0.82, 1.0, 0.97)

@export var body_scale: float = 0.35
# Slow levitating orbit around the node's origin (place the node at the door centre).
@export var orbit_rx: float = 68.0       # ellipse half-width (px)
@export var orbit_ry: float = 48.0       # ellipse half-height (px) — flattened
@export var orbit_period: float = 9.0    # s per full circle
@export var bob_amp: float = 6.0         # px extra levitation flutter on top of the orbit
@export var bob_period: float = 3.1      # s per flutter
@export var tilt_amp: float = 0.06       # radians of lean into the drift
@export var body_alpha_min: float = 0.28 # ghostly trough
@export var body_alpha_max: float = 0.72 # most-present peak
@export var breath_period: float = 5.4   # s per fade in/out
@export var eye_alpha_min: float = 0.2
@export var eye_alpha_max: float = 0.75

var _root: Node2D
var _body: Sprite2D
var _eyes: Array[Sprite2D] = []
var _t: float = 0.0


func _ready() -> void:
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# A container that holds the whole figure so it can bob / sway / tilt as one.
	_root = Node2D.new()
	add_child(_root)

	# The painted hooded figure. Normal/alpha blend so it reads as a shape; only alpha
	# is driven. The sprite is already the right cold white-teal.
	_body = Sprite2D.new()
	_body.texture = load(BODY_TEX)
	_body.scale = Vector2(body_scale, body_scale)
	_body.modulate = Color(1.0, 1.0, 1.0, body_alpha_min)
	_root.add_child(_body)

	# Two soft-additive eye glows locked to the painted sockets.
	for sgn: float in [-1.0, 1.0]:
		var e := Sprite2D.new()
		e.texture = load(EYE_TEX)
		e.material = add_mat
		e.scale = Vector2(0.10, 0.10) * (body_scale / 0.6)
		e.position = Vector2(sgn * EYE_OFFSET.x, EYE_OFFSET.y) * body_scale
		e.modulate = Color(EYE_TINT.r, EYE_TINT.g, EYE_TINT.b, 0.0)
		_root.add_child(e)
		_eyes.append(e)

	# A few soft tendril wisps rising off the head.
	var wisp := CPUParticles2D.new()
	wisp.texture = load(HALO_TEX)
	wisp.material = add_mat
	wisp.position = Vector2(0, -90.0 * body_scale)
	wisp.amount = 7
	wisp.lifetime = 4.5
	wisp.lifetime_randomness = 0.4
	wisp.preprocess = 3.0
	wisp.direction = Vector2(0, -1)
	wisp.spread = 16.0
	wisp.gravity = Vector2(0, -8)
	wisp.initial_velocity_min = 7.0
	wisp.initial_velocity_max = 16.0
	wisp.scale_amount_min = 0.35 * (body_scale / 0.6)
	wisp.scale_amount_max = 0.8 * (body_scale / 0.6)
	wisp.color = Color(0.7, 0.95, 0.92, 0.28)
	wisp.emitting = true
	_root.add_child(wisp)

	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	# Levitate in a slow ellipse around the door, with a little extra bob flutter.
	var ang: float = _t / orbit_period * TAU
	_root.position = Vector2(cos(ang) * orbit_rx,
		sin(ang) * orbit_ry + sin(_t / bob_period * TAU) * bob_amp)
	# Lean gently in the direction it's drifting (derivative of the horizontal orbit).
	_root.rotation = -sin(ang) * tilt_amp
	# Breathing: fade the whole figure in and out; eyes pulse with it.
	var breath: float = 0.5 - 0.5 * cos(_t / breath_period * TAU)   # 0..1
	_body.modulate.a = lerpf(body_alpha_min, body_alpha_max, breath)
	var ea: float = lerpf(eye_alpha_min, eye_alpha_max, breath)
	for e in _eyes:
		e.modulate.a = ea
