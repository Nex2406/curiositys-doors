extends Node

# Device haptics (Advika, 2026-07-17): the device buzzes on the big beats —
# the ground tearing loose, a hit taken. On the web build this maps to the
# browser's vibration API: Android phones buzz; iOS ignores it entirely
# (Apple doesn't expose vibration to web pages — platform limit, not a bug).
# A connected gamepad rumbles too, so desktop players feel the beats.
#
# Desktop has no motor, so every buzz also KICKS THE SCREEN (Advika played
# on desktop, felt nothing, asked again — the impact must land on every
# device). A decaying camera-offset shake rides whatever Camera2D is
# current; offset is untouched by the hand-driven cameras, which only
# write position.
#
# 2026-07-27, "I WANT STRONG haptics": the screen kick was 16px at full trauma,
# which on a 1920-wide frame is a twitch. KICK is now 44px, the decay is slower
# so a hit rings out instead of snapping back, and `rumble()` holds a level of
# shake for a duration — that is what a rising island needs, rather than a single
# impulse that has faded before the thing has even left the ground.

const KICK := 44.0            # px of camera offset at full trauma
const DECAY := 1.7            # trauma lost per second (was 2.6)
const ROLL_HZ := 34.0         # jitter rate; below this it reads as a wobble

var _trauma := 0.0
var _shaken_cam: Camera2D = null
var _hold := 0.0              # sustained level from rumble()
var _hold_t := 0.0            # seconds of sustain left
var _tick := 0.0


# One impact. `strength` shapes the gamepad rumble and the screen kick —
# the browser API has no amplitude, a phone just gets the duration.
func buzz(ms: int = 80, strength: float = 0.8) -> void:
	Input.vibrate_handheld(ms)
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, strength * 0.6, strength, ms / 1000.0)
	_trauma = maxf(_trauma, clampf(strength, 0.0, 1.0))
	# kick THIS frame, not on the next resample tick — waiting for the jitter clock
	# put a visible beat between collecting a jade and feeling it (Advika 2026-07-27:
	# "there's a haptics delay when I collect jade").
	_tick = 1.0
	_apply(_trauma)


## A SUSTAINED shake: holds `strength` for `seconds` instead of decaying from a
## single hit. For anything that goes on happening — ground tearing open, an
## island climbing — where one impulse would be over before the beat is.
func rumble(seconds: float, strength: float = 0.8) -> void:
	_hold = maxf(_hold, clampf(strength, 0.0, 1.0))
	_hold_t = maxf(_hold_t, seconds)
	Input.vibrate_handheld(int(seconds * 1000.0))
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, strength * 0.6, strength, seconds)


func stop_rumble() -> void:
	_hold = 0.0
	_hold_t = 0.0


func _process(delta: float) -> void:
	if _hold_t > 0.0:
		_hold_t -= delta
		if _hold_t <= 0.0:
			_hold = 0.0
	var level: float = maxf(_trauma, _hold)
	if level <= 0.0:
		if _shaken_cam != null and is_instance_valid(_shaken_cam):
			_shaken_cam.offset = Vector2.ZERO
		return
	var cam := get_viewport().get_camera_2d()
	if cam != _shaken_cam and _shaken_cam != null and is_instance_valid(_shaken_cam):
		_shaken_cam.offset = Vector2.ZERO   # camera changed mid-shake: clean the old one
	_shaken_cam = cam
	_trauma = maxf(0.0, _trauma - delta * DECAY)
	if cam == null:
		return
	# trauma² so small hits whisper and big ones slam, resampled at a fixed rate so
	# the shake keeps its grain instead of turning to mush at high frame rates
	_tick += delta
	if _tick >= 1.0 / ROLL_HZ:
		_tick = 0.0
		_apply(level)
	if level <= 0.0:
		cam.offset = Vector2.ZERO


func _apply(level: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or level <= 0.0:
		return
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* level * level * KICK
