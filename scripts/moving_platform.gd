@tool
extends AnimatableBody2D
## Reusable moving platform (Realm 1 build spec, 2026-07-19).
## sync_to_physics = false + sine easing is what makes Curiosity's floaty
## physics feel good on these rather than sliding off. If she slides, THIS
## is the fix — do not add velocity inheritance to the player controller.

@export var travel: Vector2 = Vector2(400, 0)   # offset from start position
@export var speed: float = 60.0                 # px/sec
@export var dwell: float = 1.0                  # pause at each end, seconds
@export var start_delay: float = 0.0            # for phase-offsetting pairs
@export var start_at_end: bool = false

var _origin: Vector2
var _tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	sync_to_physics = false          # required for smooth riding
	_origin = position
	if start_at_end:
		position = _origin + travel
	await get_tree().create_timer(start_delay).timeout
	_loop()


func _loop() -> void:
	var a := _origin
	var b := _origin + travel
	if start_at_end:
		var t := a
		a = b
		b = t
	var duration := travel.length() / max(speed, 1.0)
	_tween = create_tween().set_loops()
	_tween.tween_interval(dwell)
	_tween.tween_property(self, "position", b, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(dwell)
	_tween.tween_property(self, "position", a, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
