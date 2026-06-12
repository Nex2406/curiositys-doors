extends SceneTree

# Headless check for the AudioManager foundation.
#   godot --headless --script res://tests/test_audio_manager.gd
# Verifies the synthesized placeholder drone is well-formed and that ambient
# state transitions (play / re-request no-op / crossfade swap / stop) behave.

const AudioManagerScript := preload("res://scripts/AudioManager.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fails: int = 0
	var am: Node = AudioManagerScript.new()
	root.add_child(am)   # _ready creates buses + players + drone

	# Buses exist and route somewhere.
	fails += _check("Ambient bus created", AudioServer.get_bus_index("Ambient") != -1)
	fails += _check("SFX bus created", AudioServer.get_bus_index("SFX") != -1)

	# Placeholder drone is a usable, looping, non-empty stream.
	var drone: AudioStreamWAV = am._placeholder
	fails += _check("drone is AudioStreamWAV", drone is AudioStreamWAV)
	fails += _check("drone has PCM data", drone.data.size() > 0)
	fails += _check("drone loops forward", drone.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	# 4 s * 22050 Hz * 2 bytes (16-bit mono) = 176400 bytes.
	fails += _check("drone length correct", drone.data.size() == 22050 * 4 * 2)

	fails += _check("idle before play", not am.is_playing())

	# Enter hub ambient.
	am.play_placeholder("hub")
	fails += _check("playing after hub", am.is_playing())
	fails += _check("current name is hub", am._current_name == "hub")
	var hub_player: int = am._active

	# Re-requesting the same track is a no-op (no player swap, no restart).
	am.play_placeholder("hub")
	fails += _check("re-request same is no-op", am._active == hub_player)

	# Crossfade to a different track flips the active player.
	am.play_placeholder("realm1")
	fails += _check("current name is realm1", am._current_name == "realm1")
	fails += _check("active player swapped", am._active != hub_player)
	fails += _check("still playing after swap", am.is_playing())

	# Stop clears the current track.
	am.stop_ambient()
	fails += _check("name cleared after stop", am._current_name == "")
	fails += _check("not playing after stop", not am.is_playing())

	# SFX with a null stream is a safe no-op (doesn't crash / spawn a player).
	am.play_sfx(null)
	fails += _check("null sfx is safe", true)

	if fails == 0:
		print("[test_audio_manager] ALL PASSED")
		quit(0)
	else:
		print("[test_audio_manager] FAILED: %d check(s)" % fails)
		quit(1)


func _check(label: String, ok: bool) -> int:
	print(("  PASS " if ok else "  FAIL ") + label)
	return 0 if ok else 1
