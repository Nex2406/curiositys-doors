extends CanvasLayer

# Reusable typewriter dialogue box. Bottom panel, a named speaker, body text
# typed out character-by-character. [Y] (the `interact` action) advances; a
# press mid-type completes the current line instantly. A soft blinking
# indicator appears once a line has finished typing.
#
# The box drives nothing on its own: an owner feeds it `start(lines)` and
# listens to `line_changed(index)` to sync visuals (e.g. cross-fading a
# background) and to `finished` to move on (e.g. enter the hub).

signal line_changed(index: int)   # emitted the frame line `index` begins typing
signal finished                    # emitted after the final line is advanced past

@export var chars_per_second: float = 38.0
@export var speaker_name: String = "Curiosity"

var _lines: Array = []
var _index: int = -1
var _typing: bool = false
var _char_progress: float = 0.0
var _blink_t: float = 0.0

@onready var _speaker: Label = $Panel/Margin/VBox/Speaker
@onready var _body: Label = $Panel/Margin/VBox/Body
@onready var _indicator: Label = $Panel/Indicator


func _ready() -> void:
	_speaker.text = speaker_name
	_indicator.visible = false


# Begin playing a sequence of lines. Emits `line_changed(0)` immediately.
func start(lines: Array) -> void:
	_lines = lines
	_index = -1
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		emit_signal("finished")
		set_process(false)
		return
	_body.text = _lines[_index]
	_body.visible_characters = 0
	_char_progress = 0.0
	_typing = true
	_indicator.visible = false
	emit_signal("line_changed", _index)


func _process(delta: float) -> void:
	if _typing:
		_char_progress += delta * chars_per_second
		_body.visible_characters = int(_char_progress)
		if _body.visible_characters >= _body.text.length():
			_finish_typing()
	elif _indicator.visible:
		# Gentle pulse on the continue indicator while we wait for input.
		_blink_t += delta
		_indicator.modulate.a = 0.35 + 0.45 * (0.5 + 0.5 * sin(_blink_t * 4.0))

	# [Y] is the canonical advance (matches door entry), but accept the usual
	# Space / Enter as well so the prompt isn't a dead end for new players.
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_on_advance_pressed()


# Left-click / tap also advances, for touch and mouse players.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_advance_pressed()


func _on_advance_pressed() -> void:
	if _typing:
		_finish_typing()        # first press: snap the whole line in
	else:
		_advance()              # second press: next line


func _finish_typing() -> void:
	_body.visible_characters = -1   # -1 = show all glyphs
	_typing = false
	_blink_t = 0.0
	_indicator.visible = true
