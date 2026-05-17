extends CanvasLayer

# Reusable lore-moment overlay. Spawn one of these as a child of the
# current scene, call `play_line(text)`, await — it fades in, holds,
# fades out, and frees itself. Use it whenever a single short line of
# environmental narration should land before a scene transition. Every
# realm uses this; Door.gd is the primary caller.
#
# Per docs/VIBE.md the line should be short, sparse, melancholic, and
# never didactic. Per docs/MECHANICS.md "Dialogue / Lore Overlay" the
# presentation rules are: no boxes, no portraits, no ticking crawl —
# just text that fades in slowly, holds, fades out.

@export var fade_in_time: float = 1.0
@export var hold_time: float = 3.0
@export var fade_out_time: float = 1.0

@onready var _label: Label = $Container/Line


func _ready() -> void:
	_label.modulate.a = 0.0


# Plays one line. Awaitable — callers can `await lore.play_line(text)`
# and continue once the fade-out completes and this node is freed.
func play_line(text: String) -> void:
	_label.text = text
	var tween: Tween = create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, fade_in_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold_time)
	tween.tween_property(_label, "modulate:a", 0.0, fade_out_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()
