extends CanvasLayer
class_name LivesHUD

## Eyes-as-lives HUD — Curiosity's signature eye, used as the life counter.
##
## N eyes sit in the corner, all open at full health. Each life lost animates the
## next eye shut (eye_1 → eye_4, the hand-drawn closing sequence). Reusable: drop
## this scene into any realm and call `lose_eye()` / `reset()`.

## Emitted the moment the last open eye has been told to close.
signal depleted

const FRAMES: Array[Texture2D] = [
	preload("res://assets/ui/eyes/eye_1.png"),  # wide open
	preload("res://assets/ui/eyes/eye_2.png"),  # lid dropping
	preload("res://assets/ui/eyes/eye_3.png"),  # nearly shut
	preload("res://assets/ui/eyes/eye_4.png"),  # closed
]

@export var max_lives: int = 3
## Scale applied to the 426x294 source art. ~0.18 → ~76px-wide eyes.
@export var eye_scale: float = 0.18
## Distance between eye centers (keep > eye width so they don't overlap).
@export var eye_spacing: float = 92.0
## Top-left position of the first eye's center.
@export var corner_margin: Vector2 = Vector2(58, 54)
## Time for one eye to play through the close sequence.
@export var close_time: float = 0.4

@export_group("Float")
## Gentle levitation so the eyes feel alive, not a static UI bar.
@export var float_amplitude: float = 5.0
@export var float_period: float = 2.8
## Radians of phase offset between adjacent eyes (so they bob out of sync).
@export var float_phase_step: float = 0.8

@export_group("Tint")
## Multiplies the eye art — white keeps the original violet. (Modulate only
## warms/darkens; a true hue change needs the colorize shader or recoloured art.)
@export var eye_tint: Color = Color.WHITE

var _eyes: Array[Sprite2D] = []
var _base_pos: Array[Vector2] = []
var _lives: int = 0
var _t: float = 0.0


func _ready() -> void:
	for i in max_lives:
		var s := Sprite2D.new()
		s.texture = FRAMES[0]
		s.centered = true
		s.scale = Vector2(eye_scale, eye_scale)
		s.modulate = eye_tint
		var base := Vector2(corner_margin.x + i * eye_spacing, corner_margin.y)
		s.position = base
		add_child(s)
		_eyes.append(s)
		_base_pos.append(base)
	reset()


func _process(delta: float) -> void:
	_t += delta
	for i in _eyes.size():
		var bob: float = sin(_t * TAU / float_period + i * float_phase_step) * float_amplitude
		_eyes[i].position.y = _base_pos[i].y + bob


## Refill to full health (all eyes open). Pass a count to change the max.
func reset(n: int = -1) -> void:
	if n >= 0:
		max_lives = n
	_lives = max_lives
	for s in _eyes:
		s.texture = FRAMES[0]
		s.modulate = eye_tint


## Close the next open eye (from the right). Returns lives remaining.
func lose_eye() -> int:
	if _lives <= 0:
		return 0
	_lives -= 1
	_animate_close(_eyes[_lives])
	if _lives <= 0:
		depleted.emit()
	return _lives


func lives_remaining() -> int:
	return _lives


func _animate_close(s: Sprite2D) -> void:
	# Step through the closing frames, then settle a touch dimmer.
	var step: float = close_time / float(FRAMES.size() - 1)
	var tw := create_tween()
	for i in range(1, FRAMES.size()):
		tw.tween_callback(_set_frame.bind(s, i))
		tw.tween_interval(step)
	tw.tween_property(s, "modulate:a", 0.5, 0.15)


func _set_frame(s: Sprite2D, i: int) -> void:
	s.texture = FRAMES[i]
