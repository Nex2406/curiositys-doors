extends CanvasLayer
class_name TarotCard

# A tarot card drawn over the world (Advika, 2026-07-14: tarot instructions).
# The trial announces itself as a trump card: gold-framed violet card, the
# wizard's own portrait as the illustration, the realm's verbs beneath in
# small gold type. It flips in (scale.x 0 -> 1), pauses the game while held,
# and start_trial() waits on its `closed` signal — the gate the trial's
# design always wanted. Deliberately spare, gold-on-dark (InstructionCard's
# manners, a card's body).

signal closed()

const GOLD := Color(1.0, 0.82, 0.42)
const GOLD_DIM := Color(0.72, 0.58, 0.30)
const INK := Color(0.88, 0.86, 0.80)
const DIM := Color(0.62, 0.60, 0.56)
const CARD_FACE := Color(0.10, 0.075, 0.16)
const CARD_SIZE := Vector2(430.0, 660.0)

@export var numeral := "II"
@export var card_title := "THE TRIAL"
@export var portrait: Texture2D = preload("res://assets/enemies/wizard/idle/idle_00.png")
@export var verses: Array[String] = [
	"strike the conjurer — J",
	"grow the light — hold L",
	"the orbs only push — move",
]

var _card: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = Control.new()
	_card.custom_minimum_size = CARD_SIZE
	_card.pivot_offset = CARD_SIZE * 0.5
	center.add_child(_card)

	# card body + double gold frame — a trump card, not a menu
	var face := ColorRect.new()
	face.color = CARD_FACE
	face.size = CARD_SIZE
	_card.add_child(face)
	for inset in [8.0, 18.0]:
		var frame := ReferenceRect.new()
		frame.border_color = GOLD if inset == 8.0 else GOLD_DIM
		frame.border_width = 2.0
		frame.editor_only = false
		frame.position = Vector2(inset, inset)
		frame.size = CARD_SIZE - Vector2(inset * 2.0, inset * 2.0)
		_card.add_child(frame)

	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])

	var num := Label.new()
	num.text = numeral
	num.add_theme_font_override("font", serif)
	num.add_theme_font_size_override("font_size", 26)
	num.add_theme_color_override("font_color", GOLD_DIM)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.position = Vector2(0, 30)
	num.size = Vector2(CARD_SIZE.x, 30)
	_card.add_child(num)

	# the illustration: the storm's author himself
	var art := TextureRect.new()
	art.texture = portrait
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(55, 80)
	art.size = Vector2(CARD_SIZE.x - 110, 320)
	_card.add_child(art)

	var title := Label.new()
	title.text = card_title
	title.add_theme_font_override("font", serif)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 415)
	title.size = Vector2(CARD_SIZE.x, 40)
	_card.add_child(title)

	var y := 480.0
	for verse in verses:
		var v := Label.new()
		v.text = verse
		v.add_theme_font_override("font", serif)
		v.add_theme_font_size_override("font_size", 21)
		v.add_theme_color_override("font_color", INK)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.position = Vector2(0, y)
		v.size = Vector2(CARD_SIZE.x, 26)
		_card.add_child(v)
		y += 38.0

	var hint := Label.new()
	hint.text = "press any key"
	hint.add_theme_font_override("font", serif)
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, CARD_SIZE.y - 52)
	hint.size = Vector2(CARD_SIZE.x, 24)
	_card.add_child(hint)

	# the flip: drawn from the deck edge-on, turned face-up
	_card.scale = Vector2(0.0, 1.0)
	var flip := create_tween()
	flip.tween_property(_card, "scale", Vector2(1.0, 1.0), 0.45)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	get_tree().paused = true
	AudioManager.set_ducked(true)  # the music dims under the card, never stops


func _unhandled_input(event: InputEvent) -> void:
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if go:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		AudioManager.set_ducked(false)
		closed.emit()
		queue_free()
