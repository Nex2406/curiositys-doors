class_name LevitatingIsland
extends AnimatableBody2D
## A chunk of land that tears free and levitates skyward, carrying the player.
## Self-contained per spec: shake → seam debris burst → smooth ascent with a
## gentle levitation hover (sine sway + bob), camera locked to the island's
## base X and following Y. All motion in _physics_process (sync_to_physics
## carries riders; no tweens). If the player falls off, nothing here cares —
## normal fall logic owns them.
##
## Use: attach to an AnimatableBody2D with its visuals + top collision, then
## either call start_levitation() or point trigger_area_path at an Area2D.

signal levitation_started
signal arrived

@export var rise_height := 2820.0        ## px the island climbs
@export var rise_duration := 24.0        ## seconds for the full climb
@export var sway_amplitude := 22.0       ## px of horizontal levitation sway
@export var sway_period := 3.4           ## seconds per sway cycle (2-4s feels alive)
@export var bob_amplitude := 8.0         ## px of vertical hover bob
@export var shake_duration := 0.8        ## rumble before the tear
@export var camera_path: NodePath        ## optional Camera2D to lock X / follow Y
@export var trigger_area_path: NodePath  ## optional Area2D; player body entering starts it

enum State { IDLE, SHAKING, RISING, HOVERING }

var state := State.IDLE
var _base := Vector2.ZERO      # anchor: where the island rests / current rise origin
var _t := 0.0                  # time in current state
var _ht := 0.0                 # hover clock (never resets — keeps sway continuous)
var _debris: CPUParticles2D
var _cam: Camera2D


func _ready() -> void:
	sync_to_physics = true
	_base = position
	if camera_path != NodePath():
		_cam = get_node_or_null(camera_path) as Camera2D
	if trigger_area_path != NodePath():
		var area := get_node_or_null(trigger_area_path) as Area2D
		if area:
			area.body_entered.connect(_on_trigger_body)
	_build_debris()


func _build_debris() -> void:
	_debris = CPUParticles2D.new()
	_debris.texture = load("res://assets/realms/realm2_moss/spore.png")
	_debris.emitting = false
	_debris.one_shot = true
	_debris.explosiveness = 0.9
	_debris.amount = 60
	_debris.lifetime = 1.6
	_debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_debris.emission_rect_extents = Vector2(330, 18)
	_debris.direction = Vector2(0, 1)
	_debris.spread = 40.0
	_debris.gravity = Vector2(0, 700)
	_debris.initial_velocity_min = 60.0
	_debris.initial_velocity_max = 240.0
	_debris.scale_amount_min = 1.0
	_debris.scale_amount_max = 2.6
	_debris.modulate = Color(0.45, 0.38, 0.62)
	_debris.position = Vector2(0, 40)  # the seam: just under the grass line
	add_child(_debris)


func _on_trigger_body(body: Node2D) -> void:
	if state == State.IDLE and body is CharacterBody2D:
		start_levitation()


func start_levitation() -> void:
	if state != State.IDLE:
		return
	state = State.SHAKING
	_t = 0.0
	levitation_started.emit()


## Debug/screenshot helper: jump partway up the climb (0..1).
func debug_jump(fraction: float) -> void:
	state = State.RISING
	_t = clampf(fraction, 0.0, 1.0) * rise_duration
	position = _base + Vector2(0, -rise_height * _ease(clampf(fraction, 0.0, 1.0)))


func _ease(k: float) -> float:
	# smooth start AND smooth arrival (no elevator jolt)
	return k * k * (3.0 - 2.0 * k)


func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	_t += delta
	_ht += delta
	var sway := sin(_ht * TAU / sway_period) * sway_amplitude
	var bob := sin(_ht * TAU / (sway_period * 0.63) + 1.1) * bob_amplitude

	match state:
		State.SHAKING:
			position = _base + Vector2(
					randf_range(-1.0, 1.0) * 3.0, randf_range(-1.0, 1.0) * 2.2)
			if _t >= shake_duration:
				position = _base
				_debris.emitting = true  # the seam gives way
				state = State.RISING
				_t = 0.0
		State.RISING:
			var k := _ease(clampf(_t / rise_duration, 0.0, 1.0))
			# hover fades in over the first 15% so the tear reads heavy, not floaty
			var hover := clampf(_t / (rise_duration * 0.15), 0.0, 1.0)
			position = _base + Vector2(sway * hover, -rise_height * k + bob * hover)
			if _t >= rise_duration:
				_base = _base + Vector2(0, -rise_height)
				state = State.HOVERING
				arrived.emit()
		State.HOVERING:
			position = _base + Vector2(sway, bob)


func _process(delta: float) -> void:
	# camera: X locked to the island's base X, Y follows the journey
	if _cam == null and camera_path != NodePath():
		_cam = get_node_or_null(camera_path) as Camera2D  # path may be set post-_ready
	if _cam == null or state == State.IDLE:
		return
	var target := Vector2(_base.x, position.y - 130.0)
	var w := 1.0 - pow(0.002, delta)
	_cam.global_position.x = lerpf(_cam.global_position.x, target.x, w)
	_cam.global_position.y = lerpf(_cam.global_position.y, target.y, w)
	if state == State.SHAKING:
		_cam.offset = Vector2(randf_range(-1.0, 1.0) * 14.0, randf_range(-1.0, 1.0) * 10.0)
	else:
		_cam.offset = _cam.offset.lerp(Vector2.ZERO, w)
