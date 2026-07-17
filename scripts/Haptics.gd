extends Node

# Device haptics (Advika, 2026-07-17): the device buzzes on the big beats —
# the ground tearing loose, a hit taken. On the web build this maps to the
# browser's vibration API: Android phones buzz; iOS ignores it entirely
# (Apple doesn't expose vibration to web pages — platform limit, not a bug).
# A connected gamepad rumbles too, so desktop players feel the beats.


# Desktop has no motor, so every buzz also KICKS THE SCREEN (Advika played
# on desktop, felt nothing, asked again — the impact must land on every
# device). A decaying camera-offset shake rides whatever Camera2D is
# current; offset is untouched by the hand-driven cameras, which only
# write position.

var _trauma := 0.0
var _shaken_cam: Camera2D = null


# One impact. `strength` shapes the gamepad rumble and the screen kick —
# the browser API has no amplitude, a phone just gets the duration.
func buzz(ms: int = 80, strength: float = 0.8) -> void:
	Input.vibrate_handheld(ms)
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, strength * 0.5, strength, ms / 1000.0)
	_trauma = maxf(_trauma, clampf(strength, 0.0, 1.0))


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam != _shaken_cam and _shaken_cam != null and is_instance_valid(_shaken_cam):
		_shaken_cam.offset = Vector2.ZERO   # camera changed mid-shake: clean the old one
	_shaken_cam = cam
	_trauma = maxf(0.0, _trauma - delta * 2.6)
	if cam == null:
		return
	# trauma² so small hits whisper and big ones slam
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* _trauma * _trauma * 16.0
	if _trauma <= 0.0:
		cam.offset = Vector2.ZERO
