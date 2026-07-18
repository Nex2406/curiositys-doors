extends Node

# Autoload "AudioManager" — owns ambient music + SFX for the whole game.
#
# Each scene declares the ambient it wants in its _ready (by stream + a name),
# and this manager crossfades from whatever was playing. Re-requesting the same
# track is a no-op, so returning to a scene that's already sounding doesn't
# restart it. Two players ping-pong so a crossfade never cuts.
#
#   func _ready() -> void:
#       AudioManager.play_ambient(MY_TRACK, "realm1")   # real track
#       # or, until a real track exists:
#       AudioManager.play_placeholder("realm1")          # synthesized drone
#
# The placeholder is a soft, seamless-looping low drone generated in code, so
# the system is real and audible with no committed/licensed audio. Swapping in
# a real per-scene track later is a one-line change at the call site.
#
# Buses (Ambient, SFX) are created at runtime and routed to Master, so the
# project needs no checked-in bus layout.

signal ambient_changed(track_name: String)

const AMBIENT_BUS: String = "Ambient"
const SFX_BUS: String = "SFX"
const DEFAULT_FADE: float = 1.5
const SILENCE_DB: float = -80.0
# Ambient sits a touch below unity so a track has headroom and never dominates
# the mix; the placeholder drone is quiet by design on top of this.
const AMBIENT_DB: float = -6.0

const PLACEHOLDER_NAME: String = "placeholder_drone"
# How far the Ambient bus sinks while an overlay holds the stage.
# Tuned live with Advika: -12 fought the chime, -18 left it naked —
# -14 with a softened chime (-7dB) is the blend.
const DUCK_DB: float = -10.0

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current_name: String = ""
var _placeholder: AudioStreamWAV
var _fade_tween: Tween
var _duck_tween: Tween
# Web export runs the no-threads SAMPLE audio path, which does not honor
# runtime-created buses — everything routed to Ambient/SFX played SILENT
# on the live build (Advika, 2026-07-18). On web: Master bus only, and
# ducking moves the player's own volume instead of a bus.
var _web := false


func _ready() -> void:
	# Music survives a paused tree (the tarot card pauses the game; the track
	# should dim, not stop — Advika 2026-07-17). Duck/unduck does the dimming.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	if not _web:
		_ensure_bus(AMBIENT_BUS)
		_ensure_bus(SFX_BUS)
	_placeholder = _make_placeholder_drone()
	for i in 2:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master" if _web else AMBIENT_BUS
		p.volume_db = SILENCE_DB
		add_child(p)
		_players.append(p)


# ─── ambient ───────────────────────────────────────────────────────────────

func is_playing() -> bool:
	return _current_name != "" and _players[_active].playing


# Crossfade to `stream` (a null stream falls back to the placeholder drone).
# `track_name` identifies it so the same track isn't restarted on re-request.
func play_ambient(stream: AudioStream, track_name: String, fade: float = DEFAULT_FADE) -> void:
	if track_name == _current_name and _players[_active].playing:
		return
	var incoming: AudioStream = stream if stream != null else _placeholder
	_current_name = track_name

	var next_i: int = 1 - _active
	var incoming_player: AudioStreamPlayer = _players[next_i]
	var outgoing_player: AudioStreamPlayer = _players[_active]

	incoming_player.stream = incoming
	incoming_player.volume_db = SILENCE_DB
	incoming_player.play()
	_crossfade(incoming_player, outgoing_player, fade)
	_active = next_i
	emit_signal("ambient_changed", track_name)


# Convenience: play the built-in placeholder drone under `track_name`. Used
# until a scene has a real track; the crossfade still runs so transitions are
# proven end to end.
func play_placeholder(track_name: String = PLACEHOLDER_NAME, fade: float = DEFAULT_FADE) -> void:
	play_ambient(null, track_name, fade)


# Duck the whole Ambient bus under an overlay (tarot card, dialogue…) and
# swell back when it clears. Bus-level, so crossfades keep working under it.
# Quick dip, slow recovery — the return should feel like surfacing.
func duck_music(fade: float = 0.5) -> void:
	_duck_to(DUCK_DB, fade)


func unduck_music(fade: float = 1.0) -> void:
	_duck_to(0.0, fade)


func _duck_to(target: float, fade: float) -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	if _web:
		# no bus to duck on web — dim the active player itself
		var p: AudioStreamPlayer = _players[_active]
		_duck_tween.tween_property(p, "volume_db", AMBIENT_DB + target, fade)
		return
	var idx: int = AudioServer.get_bus_index(AMBIENT_BUS)
	if idx == -1:
		return
	_duck_tween.tween_method(
			func(v: float) -> void: AudioServer.set_bus_volume_db(idx, v),
			AudioServer.get_bus_volume_db(idx), target, fade)


func stop_ambient(fade: float = DEFAULT_FADE) -> void:
	_current_name = ""
	var p: AudioStreamPlayer = _players[_active]
	var t: Tween = create_tween()
	t.tween_property(p, "volume_db", SILENCE_DB, fade)
	t.tween_callback(p.stop)


func _crossfade(incoming_player: AudioStreamPlayer, outgoing_player: AudioStreamPlayer, fade: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(incoming_player, "volume_db", AMBIENT_DB, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if outgoing_player.playing:
		_fade_tween.tween_property(outgoing_player, "volume_db", SILENCE_DB, fade) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Stop the faded-out player once the parallel fades complete, but only if
		# it wasn't reclaimed as the active player by a newer crossfade.
		_fade_tween.chain().tween_callback(func() -> void:
			if outgoing_player != _players[_active]:
				outgoing_player.stop())


# ─── sfx ───────────────────────────────────────────────────────────────────

# Fire-and-forget one-shot. Spawns a short-lived player that frees itself.
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = "Master" if _web else SFX_BUS
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ─── internals ─────────────────────────────────────────────────────────────

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


# Generate a soft, seamless-looping low drone as a 16-bit mono AudioStreamWAV.
# Every partial and the breathing LFO are multiples of 1/duration, so the loop
# point is click-free. This is a placeholder voice, not the final ambience.
func _make_placeholder_drone() -> AudioStreamWAV:
	var rate: int = 22050
	var seconds: int = 4
	var frames: int = rate * seconds   # 88200 → loop length is a whole 4s
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(frames * 2)
	for i in frames:
		var t: float = float(i) / float(rate)
		# Breath: one slow swell per loop (0.25 Hz), amplitude 0.2 … 1.0.
		var breath: float = 0.6 + 0.4 * sin(TAU * 0.25 * t - PI * 0.5)
		# Low triad — all multiples of 0.25 Hz, so each completes whole cycles.
		var s: float = 0.5 * sin(TAU * 55.0 * t)
		s += 0.3 * sin(TAU * 82.5 * t)
		s += 0.2 * sin(TAU * 110.0 * t)
		s *= breath * 0.12   # keep it quiet; this is atmosphere, not melody
		var v: int = int(clampf(s, -1.0, 1.0) * 32767.0)
		buf.encode_s16(i * 2, v)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	wav.data = buf
	return wav
