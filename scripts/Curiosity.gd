extends CharacterBody2D

@export var speed: float = 200.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -400.0

@onready var visual: Sprite2D = $Visual
@onready var lantern: PointLight2D = $Lantern

# Source art (curiosity.png) faces LEFT by default. We track facing as a
# state bool so idle holds the last input direction (no snap-back to default).
var _facing_right: bool = false
# Cached on ready from the scene's lantern position so the script doesn't
# hardcode the offset — retune in the .tscn and the script keeps following.
var _lantern_offset_x: float


func _ready() -> void:
	_lantern_offset_x = abs(lantern.position.x)
	_apply_facing()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * speed
		# Update facing only on real input; idle holds the last direction.
		var want_right: bool = direction > 0.0
		if want_right != _facing_right:
			_facing_right = want_right
			_apply_facing()
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)

	# TODO: cloak sway animation
	# TODO: lantern flicker
	# TODO: blinking eye shader on cloak

	move_and_slide()


func _apply_facing() -> void:
	# Press LEFT  -> faces left  -> flip_h = false (source unflipped),  lantern at +offset
	# Press RIGHT -> faces right -> flip_h = true  (source mirrored),   lantern at -offset
	visual.flip_h = _facing_right
	lantern.position.x = -_lantern_offset_x if _facing_right else _lantern_offset_x
