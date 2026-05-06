extends Area2D

# Reusable Hub door. Detects when Curiosity overlaps, shows a floating
# "↑ Enter" prompt above the painted door, and on jump/up logs the
# realm we'd transition to. Real scene transitions land in PR2.

signal near_door(door)

@export var target_realm: String = ""
@export var door_id: String = ""
@export_group("Prompt")
@export var prompt_offset: Vector2 = Vector2(0, -120)
@export var prompt_text: String = "[Y] Enter"

const _PROMPT_SIZE: Vector2 = Vector2(140, 30)
const _PROMPT_COLOR: Color = Color(1.0, 0.93, 0.66, 0.95)
const _PROMPT_OUTLINE: Color = Color(0, 0, 0, 0.85)

var _player_inside: bool = false
var _prompt: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_prompt()


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


func _show_prompt(on: bool) -> void:
	if _prompt == null:
		return
	_prompt.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_prompt, "modulate:a", 1.0 if on else 0.0, 0.25)
	if not on:
		tween.tween_callback(func() -> void: _prompt.visible = false)


func _process(_delta: float) -> void:
	if not _player_inside:
		return
	if Input.is_action_just_pressed("interact"):
		print("[Door] Entering ", target_realm, " via ", door_id)
