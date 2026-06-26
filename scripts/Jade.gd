extends Area2D
class_name Jade

# A jade collectible: a slowly-spinning shard that bobs as if floating. Curiosity
# walks/jumps into it to collect. Reusable — drop instances onto platforms and
# size each via `piece_scale`. Scoring is wired by whoever places it, via the
# `collected` signal (the jade just frees itself).

signal collected

# Source frames are 164×274; 0.4 reads as a small pickup. Tweak per-platform.
@export var piece_scale: float = 0.4
@export var spin_fps: float = 3.5          # rotation speed (frames/sec)
@export var bob_amplitude: float = 6.0     # px up/down around rest (±)
@export var bob_period: float = 2.0        # seconds for a full up-down cycle

@onready var _visual: AnimatedSprite2D = $Visual
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _collected: bool = false


func _ready() -> void:
	_visual.scale = Vector2(piece_scale, piece_scale)
	_shape.scale = Vector2(piece_scale, piece_scale)
	_visual.sprite_frames.set_animation_speed(&"spin", spin_fps)
	_visual.play(&"spin")
	_start_float()
	# Arm pickup only after spawn settles. If Curiosity drops into the level already
	# overlapping a jade (e.g. the one on the spawn platform), connecting late means
	# that initial overlap doesn't fire body_entered — the jade sits there visibly
	# and is only collected on a fresh walk/jump into it.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	body_entered.connect(_on_body_entered)


# Gentle sine float layered on top of the spin. Oscillates the visual ±amplitude
# around its rest position, looping forever; the spin runs independently.
func _start_float() -> void:
	var rest_y: float = _visual.position.y
	var half: float = bob_period * 0.5
	var t: Tween = create_tween().set_loops()
	t.tween_property(_visual, "position:y", rest_y - bob_amplitude, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_visual, "position:y", rest_y + bob_amplitude, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	# Only Curiosity collects (golems/other bodies pass through).
	if body.is_in_group("player") or body.name == "Curiosity":
		_collected = true
		collected.emit()
		queue_free()
