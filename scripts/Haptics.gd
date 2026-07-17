extends Node

# Device haptics (Advika, 2026-07-17): the device buzzes on the big beats —
# the ground tearing loose, a hit taken. On the web build this maps to the
# browser's vibration API: Android phones buzz; iOS ignores it entirely
# (Apple doesn't expose vibration to web pages — platform limit, not a bug).
# A connected gamepad rumbles too, so desktop players feel the beats.


# One buzz. `strength` only shapes the gamepad rumble — the browser API has
# no amplitude, a phone just gets the duration.
func buzz(ms: int = 80, strength: float = 0.8) -> void:
	Input.vibrate_handheld(ms)
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, strength * 0.5, strength, ms / 1000.0)
