extends Node

# Autoload "Dialogue" — the one-call entry point for making Curiosity speak.
#
# DialogueBox.tscn already owns the look + typewriter + advance logic. This
# service wraps it so any scene can run a sequence without hand-embedding the
# box and wiring signals: just `await Dialogue.say([...])`, which resolves once
# the player has dismissed the final line.
#
#   func _on_something() -> void:
#       await Dialogue.say(["A line.", "Another line."])
#       # ...continues here after the box closes.
#
# One dialogue runs at a time (overlapping calls are ignored, not queued) — the
# foundation guarantees a single active box; sequencing/queuing can layer on top
# later if a realm needs it. Content lives with the caller; this owns plumbing.

signal started   # emitted as a sequence begins
signal closed    # emitted after the box is dismissed and freed

const BOX_SCENE: PackedScene = preload("res://scenes/UI/DialogueBox.tscn")

var _box: CanvasLayer = null


func is_active() -> bool:
	return _box != null


# Play `lines` in order. Awaitable: the coroutine resumes after the last line
# is advanced past and the box has freed itself. `speaker` labels the box;
# defaults to Curiosity, the only voice for now.
func say(lines: Array, speaker: String = "Curiosity") -> void:
	if lines.is_empty():
		return
	if _box != null:
		push_warning("[Dialogue] say() ignored — a dialogue is already active")
		return
	_box = BOX_SCENE.instantiate()
	# Export var set before add_child so the box's _ready picks up the speaker.
	_box.speaker_name = speaker
	get_tree().root.add_child(_box)
	emit_signal("started")
	_box.start(lines)
	await _box.finished
	_box.queue_free()
	_box = null
	emit_signal("closed")
