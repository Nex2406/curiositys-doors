extends AnimatableBody2D
class_name BouncePlank

# A vertically travelling plank that carries riders up and down — but the instant its
# DESCENT would meet Curiosity below it, it stops and heads back UP instead of pushing her
# down. It oscillates symmetrically around its painted home (±up/down amp) at the ORIGINAL
# per-plank speed, so the timings match the pre-shift feel (planks drift out of phase via
# their different periods). A thin sensor under the plank spots the player only, so the
# golem riding ON the plank never trips it.

var up_amp: float = 48.0     # travel above home (px)
var down_amp: float = 48.0   # travel below home (px)
var speed: float = 30.0      # px/s
var _base_y: float = 0.0
var _dir: float = -1.0       # -1 rising, +1 descending; start rising (original 0→up)
var _sensor: Area2D


func setup(p_up: float, p_down: float, p_speed: float, sensor_center: Vector2, sensor_size: Vector2) -> void:
	up_amp = p_up
	down_amp = p_down
	speed = p_speed
	_base_y = position.y
	_sensor = Area2D.new()
	_sensor.collision_mask = 1      # player is on layer 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = sensor_size
	cs.shape = r
	cs.position = sensor_center
	_sensor.add_child(cs)
	add_child(_sensor)


func _physics_process(delta: float) -> void:
	if _dir < 0.0:
		position.y -= speed * delta
		if position.y <= _base_y - up_amp:
			position.y = _base_y - up_amp
			_dir = 1.0
	else:
		if _player_below():
			_dir = -1.0            # about to land on Curiosity → go back up
		else:
			position.y += speed * delta
			if position.y >= _base_y + down_amp:
				position.y = _base_y + down_amp
				_dir = -1.0


func _player_below() -> bool:
	if _sensor == null:
		return false
	for b in _sensor.get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false
