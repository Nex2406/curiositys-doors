extends CharacterBody2D
class_name Golem

# Realm 1 guard enemy. Patrols slowly back and forth around its spawn, playing the
# "walk" cycle as it trudges, facing the way it walks (art faces left by default).
# When Curiosity enters its detection range it stops, turns to face her, drops to the
# idle pose, plays "attack", and lobs a GolemBall on the launch frame, then repeats on
# a cooldown. Walks again when she leaves.
# (Health/hit-reaction come later with the reusable enemy base, M2.)

@export var ball_scene: PackedScene
@export var gravity: float = 1400.0
@export var patrol_speed: float = 90.0      # px/s shove during the push frames (see STRIDE_FRAMES)
@export var patrol_range: float = 170.0     # px to each side of the spawn point
@export var detect_range: float = 480.0     # px; Curiosity within this → stop & attack
@export var shoot_interval: float = 1.4     # seconds between shots while engaged
@export var alert_delay: float = 0.15       # tiny telegraph between spotting her and the first throw

# 0-indexed frame of the "attack" animation where the ball erupts (golemr1attack5).
const ATTACK_LAUNCH_FRAME: int = 4

# Walk-cycle frames where he's sunk low, planted, and shoving forward. He only
# translates on these — between them he's gathering up for the next step and holds
# still, so the movement reads as a heavy lurching trudge instead of a smooth glide.
const STRIDE_FRAMES: Array[int] = [1, 2, 3, 4]

@onready var _visual: AnimatedSprite2D = $Visual
@onready var _launch_point: Marker2D = $LaunchPoint

var _player: Node2D = null
var _attacking: bool = false
var _fired: bool = false
var _engaged_now: bool = false    # is Curiosity in range this frame
var _shoot_timer: float = 0.0
var _origin_x: float = 0.0
var _patrol_dir: float = 1.0


func _ready() -> void:
	_origin_x = global_position.x
	_player = get_tree().get_first_node_in_group("player")
	_visual.animation_finished.connect(_on_anim_finished)
	_visual.frame_changed.connect(_on_frame_changed)
	_visual.play(&"idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	_shoot_timer += delta

	var sees: bool = _sees_player()
	if sees and not _engaged_now:
		# Just spotted her — snap to face her and throw almost immediately (short telegraph),
		# instead of waiting a full cooldown for the first lob.
		_shoot_timer = shoot_interval - alert_delay
	_engaged_now = sees

	if sees:
		_engaged()
	else:
		_patrol()

	move_and_slide()


# Curiosity within detect_range? Re-find her if the reference went stale.
func _sees_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	return global_position.distance_to(_player.global_position) <= detect_range


# Player in range: stand your ground and fire on the cooldown.
func _engaged() -> void:
	velocity.x = 0.0
	# Face Curiosity: default art faces left; flip when she's to the right.
	var dx: float = _player.global_position.x - global_position.x
	_visual.flip_h = dx > 0.0
	if _attacking:
		return
	# Hold the idle pose while planted and winding up between shots.
	if _visual.animation != &"attack" and _visual.animation != &"idle":
		_visual.play(&"idle")
	if _shoot_timer >= shoot_interval:
		_shoot_timer = 0.0
		_start_attack()


# No player: drift back and forth around the spawn point, playing the walk cycle.
func _patrol() -> void:
	if _visual.animation != &"walk":
		_visual.play(&"walk")
	# Face the way he's walking: default art faces left, flip when heading right.
	_visual.flip_h = _patrol_dir > 0.0
	# Shove forward only on the planted push frames; hold still while he gathers up.
	if _visual.frame in STRIDE_FRAMES:
		velocity.x = _patrol_dir * patrol_speed
	else:
		velocity.x = 0.0
	if global_position.x > _origin_x + patrol_range:
		_patrol_dir = -1.0
	elif global_position.x < _origin_x - patrol_range:
		_patrol_dir = 1.0


func _start_attack() -> void:
	_attacking = true
	_fired = false
	velocity.x = 0.0
	_visual.play(&"attack")


func _on_frame_changed() -> void:
	if _attacking and _visual.animation == &"attack" \
			and _visual.frame == ATTACK_LAUNCH_FRAME and not _fired:
		_fired = true
		_fire_ball()


func _fire_ball() -> void:
	if ball_scene == null or _player == null or not is_instance_valid(_player):
		return
	var b: Area2D = ball_scene.instantiate()
	get_tree().current_scene.add_child(b)
	# Pass the floor level (golem's feet) so the ball arcs down from the head and
	# then travels along the floor toward Curiosity.
	var floor_y: float = global_position.y + _feet_offset()
	b.setup(_launch_point.global_position, _player, floor_y)


# Global-space y of the golem's feet (bottom of the body collider) ≈ the floor.
func _feet_offset() -> float:
	var cs: CollisionShape2D = $CollisionShape2D
	var rect := cs.shape as RectangleShape2D
	return cs.position.y + rect.size.y * 0.5


func _on_anim_finished() -> void:
	if _visual.animation == &"attack":
		_attacking = false
		_visual.play(&"idle")


# For the test HUD: which state the golem reads as right now.
func debug_state() -> String:
	if _attacking:
		return "ATTACK"
	if _engaged_now:
		return "ALERT (facing + winding up)"
	return "PATROL"
