extends CharacterBody2D

@export var speed: float = 200.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -400.0

@onready var visual: Sprite2D = $Visual
@onready var lantern: PointLight2D = $Lantern

# Lantern offset is mirrored on flip — the painted lantern in the source
# image sits to the viewer's right, so when the sprite flips to face right
# the light has to move with it. Cached on ready from the scene's own value.
var _lantern_offset_x: float


func _ready() -> void:
	_lantern_offset_x = abs(lantern.position.x)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)

	if velocity.x > 0.1:
		visual.flip_h = true
		lantern.position.x = -_lantern_offset_x
	elif velocity.x < -0.1:
		visual.flip_h = false
		lantern.position.x = _lantern_offset_x

	# TODO: cloak sway animation
	# TODO: lantern flicker
	# TODO: blinking eye shader on cloak

	move_and_slide()
