extends Area2D

# Reusable Hub door. Detects when Curiosity overlaps, shows a floating
# "[Y] Enter" prompt above the painted door, and exposes trigger() for
# Hub.gd to call when the central "interact" dispatch fires. Real scene
# transitions land in a future PR; for now trigger() flashes the glow
# and swaps the prompt so the player can SEE that Y registered.

signal near_door(door)
signal left_door(door)

@export var target_realm: String = ""
@export var door_id: String = ""
@export_group("Prompt")
@export var prompt_offset: Vector2 = Vector2(0, -120)
@export var prompt_text: String = "[Y] Enter"

const _PROMPT_SIZE: Vector2 = Vector2(140, 30)
const _PROMPT_COLOR: Color = Color(1.0, 0.93, 0.66, 0.95)
const _PROMPT_OUTLINE: Color = Color(0, 0, 0, 0.85)
const _GLOW_FLASH_ENERGY: float = 2.6
const _GLOW_FLASH_TIME: float = 0.45
const _PROMPT_FLASH_TEXT: String = "..."
const _PROMPT_FLASH_TIME: float = 0.6

var _player_inside: bool = false
var _prompt: Label
var _glow: PointLight2D
var _glow_base_energy: float = 0.8
var _flash_tween: Tween


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


func trigger() -> void:
	# Hub.gd calls this once per "interact" press while the player is in range.
	# Print survives for editor/devtools observers; the visible flash is what
	# the live-site player actually sees.
	print("[Door] Entering ", target_realm, " via ", door_id)
	_flash_feedback()


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
