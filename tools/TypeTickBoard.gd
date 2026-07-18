extends Control

# Type-tick audition board (Advika: "can u synthesise a few") — six candidate
# typewriter sounds for the tarot card. Boots straight in, types the card's
# moth verse on loop with the selected tick, exactly as TarotReading would
# play it (every 2nd char, pitch-wobbled, -15 dB).
#
#   1-6    pick a candidate (retypes the line with it)
#   SPACE  retype the line
#   ESC    quit

const DIR := "res://assets/audio/type_candidates/"
const TICKS := [
	["1  classic clack", "tick_1_clack.wav"],
	["2  deep thunk", "tick_2_thunk.wav"],
	["3  crisp tick", "tick_3_crisp.wav"],
	["4  soft felt", "tick_4_felt.wav"],
	["5  muffled key", "tick_5_muffled.wav"],
	["6  double strike", "tick_6_double.wav"],
]
const SAMPLE := "Linger too long and the void moth wakes."
const TYPE_CPS := 28.0

var _sel := 0
var _player: AudioStreamPlayer
var _line: Label
var _menu: Label
var _chars := 0.0
var _typing := true
var _pause := 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.045, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_menu = Label.new()
	_menu.position = Vector2(40, 40)
	_menu.add_theme_font_size_override("font_size", 22)
	add_child(_menu)
	_line = Label.new()
	_line.position = Vector2(40, 360)
	_line.add_theme_font_size_override("font_size", 30)
	_line.add_theme_color_override("font_color", Color("EAE6DA"))
	_line.text = SAMPLE
	_line.visible_characters = 0
	add_child(_line)
	_player = AudioStreamPlayer.new()
	_player.volume_db = -15.0
	add_child(_player)
	_select(0)


func _select(i: int) -> void:
	_sel = i
	_player.stream = load(DIR + TICKS[i][1])
	var rows := PackedStringArray(["TYPE-TICK BOARD — 1-6 pick, SPACE retype, ESC quit", ""])
	for j in TICKS.size():
		rows.append(("> " if j == _sel else "  ") + TICKS[j][0])
	_menu.text = "\n".join(rows)
	_restart()


func _restart() -> void:
	_chars = 0.0
	_line.visible_characters = 0
	_typing = true


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode >= KEY_1 and e.keycode <= KEY_6:
			_select(e.keycode - KEY_1)
		elif e.keycode == KEY_SPACE:
			_restart()
		elif e.keycode == KEY_ESCAPE:
			get_tree().quit()


func _process(delta: float) -> void:
	if not _typing:
		# a beat of silence, then the line types again on its own
		_pause += delta
		if _pause > 1.6:
			_pause = 0.0
			_restart()
		return
	_chars += TYPE_CPS * delta
	var vc := maxi(0, int(_chars))
	if vc > _line.visible_characters and vc % 2 == 0:
		_player.pitch_scale = randf_range(0.9, 1.1)
		_player.play()
	_line.visible_characters = vc
	if vc >= SAMPLE.length():
		_typing = false
