extends Node

# Autoload "Transition". Owns a high-layer CanvasLayer + black ColorRect
# overlay used for fade-to-black scene changes. The overlay is created in
# code so this stays a single-file autoload (no .tscn needed).
#
# `last_door_id` lives here so a destination scene can read which door was
# used and respawn the player accordingly. Only set on realm-bound trips;
# Hub-bound trips leave it intact so the hub can place Curiosity back at
# the door she came out of.

const FADE_TIME: float = 0.6

var last_door_id: String = ""

var _layer: CanvasLayer
var _rect: ColorRect


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 1)
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func fade_to_black(duration: float = FADE_TIME) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_rect, "modulate:a", 1.0, duration)
	await tween.finished


func fade_from_black(duration: float = FADE_TIME) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_rect, "modulate:a", 0.0, duration)
	await tween.finished


func transition_to(scene_path: String) -> void:
	await fade_to_black()
	var err: int = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("[Transition] change_scene_to_file failed: %s (err %d)" % [scene_path, err])
	# Yield a frame so the new scene's _ready can position nodes before reveal.
	await get_tree().process_frame
	await fade_from_black()
