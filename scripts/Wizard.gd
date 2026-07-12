extends Node2D
class_name Wizard

# The Wizard — Realm 2's boss, the storm's author, a dark mirror of Curiosity
# (docs/realms/realm2.md R2-M7). Purple-shifted, red-eyed BlueWizard pack art
# (tools/tint_wizard_pack.gd). For now he is a PRESENCE, not a fight: he
# flickers into existence over the rising island a few seconds into the
# ascent, hovers with it, and watches. Combat (BossBase, storm bolts,
# teleport-blinks, stop_levitation() on defeat) lands with R2-M7 proper.

signal materialized()

const FRAME_DIR := "res://assets/enemies/wizard/"
const IDLE_FRAMES := 20
const IDLE_FPS := 16.0

# Spawn flicker: the apparition blinks in — sprite toggling on/off while its
# alpha climbs, same visual language as the Golem's hit flicker / Curiosity's
# respawn blink, so "flicker = threshold between being and not" stays one idea.
const FLICKER_INTERVAL := 0.045

@export var hover_amplitude := 14.0   # px of his own levitation bob
@export var hover_period := 2.6       # seconds per bob cycle (out of phase with the island)

var _visual: AnimatedSprite2D
var _follow: Node2D = null      # what he rides (the island)
var _follow_offset := Vector2.ZERO
var _watch: Node2D = null       # who he faces (Curiosity)
var _ht := 0.0                  # hover clock
var _mat_t := -1.0              # >=0 → materialize flicker running
var _mat_dur := 0.9


func _ready() -> void:
	_visual = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", IDLE_FPS)
	frames.set_animation_loop(&"idle", true)
	for i in range(IDLE_FRAMES):
		frames.add_frame(&"idle", load(FRAME_DIR + "idle/idle_%02d.png" % i))
	_visual.sprite_frames = frames
	add_child(_visual)
	_visual.play(&"idle")
	visible = false   # nothing until materialize() (or appear_instant())


# Ride a node (the island) at a fixed offset; his own bob rides on top.
func follow(target: Node2D, offset: Vector2) -> void:
	_follow = target
	_follow_offset = offset


# Keep facing a node (Curiosity). Pack art faces RIGHT natively (confirmed
# live 2026-07-12 — he spawned looking away from her); flip when she's left.
func watch(target: Node2D) -> void:
	_watch = target


# Flicker into existence over `duration` seconds.
func materialize(duration := 0.9) -> void:
	_mat_dur = maxf(duration, 0.1)
	_mat_t = 0.0
	modulate.a = 0.0
	visible = true


# Fully there at once — screenshot/debug path, no flicker.
func appear_instant() -> void:
	_mat_t = -1.0
	modulate.a = 1.0
	visible = true


func _physics_process(delta: float) -> void:
	_ht += delta
	if _follow != null and is_instance_valid(_follow):
		var bob := sin(_ht * TAU / hover_period) * hover_amplitude
		var drift := sin(_ht * TAU / (hover_period * 2.7) + 0.7) * hover_amplitude * 0.6
		global_position = _follow.global_position + _follow_offset + Vector2(drift, bob)
	if _watch != null and is_instance_valid(_watch):
		_visual.flip_h = _watch.global_position.x < global_position.x

	if _mat_t >= 0.0:
		_mat_t += delta
		var k := clampf(_mat_t / _mat_dur, 0.0, 1.0)
		_visual.visible = int(_mat_t / FLICKER_INTERVAL) % 2 == 0 or k >= 1.0
		modulate.a = k
		if k >= 1.0:
			_mat_t = -1.0
			_visual.visible = true
			materialized.emit()
