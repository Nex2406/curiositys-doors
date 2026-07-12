extends Node2D
class_name OrbConjure

# One-shot conjure effect for a rune orb (the wizard's hazard, Realm 2): smoke
# coils out of the ground, a flash, the orb materializes, the smoke clears.
# The sheet is GROUND-RING anchored — the bottom of every frame is the spawn
# point, so this node's origin sits ON the plank surface. Parent it to the
# moving plank/island and the ring rides along.
#
# At ORB_READY_FRAME (smoke clearing, orb resting) it emits `orb_ready` with
# its current global ground position — that's the RuneOrb's cue to take over —
# then frees itself when the animation ends.

signal orb_ready(ground_pos: Vector2)

const FRAME_DIR := "res://assets/hazards/runeorb/"
const FRAME_COUNT := 12
const FPS := 14.0
const FRAME_SIZE := Vector2(266.0, 375.0)
const ORB_READY_FRAME := 8   # 0-indexed: the 9th frame — flash done, orb sitting in the fading smoke

var _visual: AnimatedSprite2D
var _announced := false


func _ready() -> void:
	# A conjure-in-flight already counts as an orb: the wizard's max-2 cap
	# scans the "hazards" group, and this is an orb that just hasn't finished
	# arriving. Prevents a third orb sneaking in mid-smoke.
	add_to_group("hazards")
	_visual = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"conjure")
	frames.set_animation_speed(&"conjure", FPS)
	frames.set_animation_loop(&"conjure", false)
	for i in range(1, FRAME_COUNT + 1):
		frames.add_frame(&"conjure", load(FRAME_DIR + "runeorbspawn%d.png" % i))
	_visual.sprite_frames = frames
	# Bottom-anchored: lift the centered texture so its bottom edge = our origin.
	_visual.offset = Vector2(0.0, -FRAME_SIZE.y * 0.5)
	add_child(_visual)
	_visual.frame_changed.connect(_on_frame_changed)
	_visual.animation_finished.connect(queue_free)
	_visual.play(&"conjure")


func _on_frame_changed() -> void:
	if not _announced and _visual.frame >= ORB_READY_FRAME:
		_announced = true
		orb_ready.emit(global_position)
