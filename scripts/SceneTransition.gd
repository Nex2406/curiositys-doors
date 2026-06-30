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
const EYE_CLOSE_TIME: float = 0.55   # lids sweep shut (death blink)
const EYE_OPEN_TIME: float = 0.45    # and open on the restarted level

var last_door_id: String = ""

var _layer: CanvasLayer
var _rect: ColorRect
# Two black "eyelids" that sweep from top and bottom to a shut slit — Curiosity's eye
# closing on death, echoing the blinking-eye cloak motif.
var _lid_top: ColorRect
var _lid_bottom: ColorRect


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

	# Eyelids live above the fade rect. Each spans the full width; we animate the inner
	# anchor toward 0.5 so they meet in the middle. Start fully open (off-screen).
	_lid_top = _make_lid()
	_lid_top.anchor_top = 0.0
	_lid_top.anchor_bottom = 0.0
	_lid_bottom = _make_lid()
	_lid_bottom.anchor_top = 1.0
	_lid_bottom.anchor_bottom = 1.0


func _make_lid() -> ColorRect:
	var lid := ColorRect.new()
	lid.color = Color(0, 0, 0, 1)
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lid.anchor_left = 0.0
	lid.anchor_right = 1.0
	lid.offset_left = 0.0
	lid.offset_right = 0.0
	lid.offset_top = 0.0
	lid.offset_bottom = 0.0
	_layer.add_child(lid)
	return lid


# Death blink: the eye sweeps shut. Eased so it snaps closed like a real blink.
func eye_close(duration: float = EYE_CLOSE_TIME) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_lid_top, "anchor_bottom", 0.5, duration)
	tween.tween_property(_lid_bottom, "anchor_top", 0.5, duration)
	await tween.finished


# The eye opens again on the restarted level.
func eye_open(duration: float = EYE_OPEN_TIME) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_lid_top, "anchor_bottom", 0.0, duration)
	tween.tween_property(_lid_bottom, "anchor_top", 1.0, duration)
	await tween.finished


# Curiosity's death beat: the eye closes, the level restarts from the top, the eye opens.
func death_restart() -> void:
	await eye_close()
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await eye_open()


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
