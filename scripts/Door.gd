extends Area2D

# Reusable door. Detects when Curiosity overlaps, shows a floating
# "[Y] Enter" prompt above the painted door, and exposes trigger() for
# Hub.gd (or a realm controller) to call when the central "interact"
# dispatch fires. trigger() flashes the glow + swaps the prompt as
# immediate feedback, then routes through the Transition autoload to
# fade-and-change scene. Doors whose target_realm has no resolved scene
# (the not-yet-built realms) just print and stay open for retry.

signal near_door(door)
signal left_door(door)

@export var target_realm: String = ""
@export var door_id: String = ""
@export_group("Prompt")
@export var prompt_offset: Vector2 = Vector2(0, -120)
@export var prompt_text: String = "[Y] Enter"
@export_group("Lore")
## Optional single-line lore moment that plays before the transition fade.
## Leave empty to skip. Used by realm exits to land an environmental beat
## right before returning to the hub. See scripts/LoreMoment.gd.
@export_multiline var exit_lore_line: String = ""

const _PROMPT_SIZE: Vector2 = Vector2(140, 30)
const _PROMPT_COLOR: Color = Color(1.0, 0.93, 0.66, 0.95)
const _PROMPT_OUTLINE: Color = Color(0, 0, 0, 0.85)
const _GLOW_FLASH_ENERGY: float = 2.6
const _GLOW_FLASH_TIME: float = 0.45
const _PROMPT_FLASH_TEXT: String = "..."
const _PROMPT_FLASH_TIME: float = 0.6
const _TRIGGER_TO_FADE_DELAY: float = 0.3

var _player_inside: bool = false
var _prompt: Label
var _glow: PointLight2D
var _glow_base_energy: float = 0.8
var _flash_tween: Tween
var _triggered: bool = false


func _ready() -> void:
	add_to_group("doors")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_glow = _find_glow()
	if _glow:
		_glow_base_energy = _glow.energy
	_build_prompt()


func _find_glow() -> PointLight2D:
	# Glow lives under the sibling "Visual" node in the parent door root.
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	var visual: Node = parent_node.get_node_or_null("Visual")
	if visual == null:
		return null
	return visual.get_node_or_null("Glow") as PointLight2D


func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.text = prompt_text
	_prompt.size = _PROMPT_SIZE
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", _PROMPT_COLOR)
	_prompt.add_theme_color_override("font_outline_color", _PROMPT_OUTLINE)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.position = prompt_offset - _PROMPT_SIZE * 0.5
	_prompt.visible = false
	_prompt.modulate.a = 0.0
	add_child(_prompt)


func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D):
		return
	_player_inside = true
	_show_prompt(true)
	near_door.emit(self)


func _on_body_exited(body: Node) -> void:
	if not (body is CharacterBody2D):
		return
	_player_inside = false
	_show_prompt(false)
	left_door.emit(self)


func _show_prompt(on: bool) -> void:
	if _prompt == null:
		return
	_prompt.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_prompt, "modulate:a", 1.0 if on else 0.0, 0.25)
	if not on:
		tween.tween_callback(func() -> void: _prompt.visible = false)


# Driven by Hub.gd's X-proximity check: the doors float out of reach, so the
# player can't physically overlap the Area2D. Hub calls this when the player
# stands beneath this door (true) or moves away (false). Shows/hides the prompt
# and brightens the glow so the selectable door reads as "lit up".
func set_active(on: bool) -> void:
	_player_inside = on
	_show_prompt(on)
	_highlight(on)


func _highlight(on: bool) -> void:
	if _glow == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	var target: float = _glow_base_energy * 2.4 if on else _glow_base_energy
	_flash_tween = create_tween()
	_flash_tween.tween_property(_glow, "energy", target, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func trigger() -> void:
	# Hub.gd calls this once per "interact" press while the player is in range.
	# Print survives for editor/devtools observers; the visible flash is what
	# the live-site player actually sees.
	if _triggered:
		return
	print("[Door] Entering ", target_realm, " via ", door_id)
	_flash_feedback()
	var path: String = _resolve_scene_path(target_realm)
	if path == "":
		print("[Door] Realm not yet built: ", target_realm)
		return
	_triggered = true
	# Realm-bound trips remember which door was used so the hub can respawn
	# Curiosity at the same door on return. Hub-bound trips leave it intact.
	if target_realm.begins_with("realm_"):
		Transition.last_door_id = door_id
		# Persist that this door has been entered, so progress survives a
		# refresh. First real consumer of the SaveManager foundation.
		SaveManager.mark_door_opened(door_id)
	# Hold the flash briefly so the player sees the Y register before fade.
	await get_tree().create_timer(_TRIGGER_TO_FADE_DELAY).timeout
	if exit_lore_line.strip_edges() != "":
		await _play_lore(exit_lore_line)
	await Transition.transition_to(path)


func _play_lore(text: String) -> void:
	# Instantiate a fresh LoreMoment overlay under the current scene, await
	# its full fade-in / hold / fade-out cycle, and let it free itself.
	var lore_scene: PackedScene = load("res://scenes/UI/LoreMoment.tscn")
	if lore_scene == null:
		push_warning("[Door] LoreMoment scene missing — skipping lore line")
		return
	var lore: Node = lore_scene.instantiate()
	var host: Node = get_tree().current_scene
	if host == null:
		push_warning("[Door] No current scene to host LoreMoment — skipping")
		return
	host.add_child(lore)
	if lore.has_method("play_line"):
		await lore.play_line(text)


static func _resolve_scene_path(target: String) -> String:
	match target:
		"realm_1": return "res://assets/realms/realm1_caves/Realm1.tscn"
		"realm_2": return "res://scenes/realms/Realm2LiftTest.tscn"
		"realm_3": return "res://scenes/realms/Realm3FungalTest.tscn"
		"hub": return "res://scenes/Hub.tscn"
		_: return ""


func _flash_feedback() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	if _glow:
		_glow.energy = _GLOW_FLASH_ENERGY
		_flash_tween.tween_property(_glow, "energy", _glow_base_energy, _GLOW_FLASH_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _prompt:
		_prompt.text = _PROMPT_FLASH_TEXT
		_flash_tween.tween_callback(func() -> void: _prompt.text = prompt_text) \
			.set_delay(_PROMPT_FLASH_TIME)
