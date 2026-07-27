extends Node2D

## Audition rig for the jade-pickup candidates (Advika 2026-07-27: "make some
## audio samples for me"). Press 1-6 to hear one, SPACE to hear them all in order,
## J to hear one against the real jade chime cadence (three in quick succession,
## the way a greedy run through the cave actually sounds). ESC quits.
##
## The files are synthesised by tools/make_jade_sfx.py — no licensing, no credits.

const DIR := "res://assets/audio/jade/"

var _clips: Array = []        # [label, AudioStream]
var _player: AudioStreamPlayer
var _list: VBoxContainer
var _now: Label


func _ready() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	var rect := ColorRect.new()
	rect.color = Color(0.05, 0.05, 0.06)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(rect)
	add_child(bg)

	_player = AudioStreamPlayer.new()
	add_child(_player)

	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".wav"):
			var st: AudioStream = load(DIR + f)
			if st != null:
				_clips.append([f.get_basename(), st])
	_clips.sort_custom(func(a, b): return String(a[0]) < String(b[0]))

	var ui := CanvasLayer.new()
	add_child(ui)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_top", 50)
	ui.add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	margin.add_child(_list)

	_head("JADE PICKUP — press a number to hear it", 26, Color(0.92, 0.88, 0.78))
	_head("SPACE plays all six · J plays three in a row · ESC quits", 17,
			Color(0.45, 0.75, 0.85))
	_list.add_child(Control.new())
	for i in _clips.size():
		_head("%d.  %s" % [i + 1, String(_clips[i][0]).replace("jade_pickup_", "")],
				22, Color(0.86, 0.82, 0.72))
	_list.add_child(Control.new())
	_now = Label.new()
	_now.add_theme_font_size_override("font_size", 20)
	_now.add_theme_color_override("font_color", Color(0.55, 0.85, 0.65))
	_list.add_child(_now)


func _head(text: String, size: int, colour: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	_list.add_child(l)


func _play(i: int) -> void:
	if i < 0 or i >= _clips.size():
		return
	_player.stream = _clips[i][1]
	_player.play()
	_now.text = "▶  %s" % String(_clips[i][0]).replace("jade_pickup_", "")


func _play_all() -> void:
	for i in _clips.size():
		_play(i)
		await get_tree().create_timer(1.5).timeout


## Three pickups in quick succession — how it sounds when she sweeps a platform.
func _play_run(i: int) -> void:
	for _k in range(3):
		_play(i)
		await get_tree().create_timer(0.42).timeout


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_9:
		_play(k - KEY_1)
	elif k == KEY_SPACE:
		_play_all()
	elif k == KEY_J:
		_play_run(0 if _player.stream == null else _clips.find(
				_clips.filter(func(c): return c[1] == _player.stream)[0]))
	elif k == KEY_ESCAPE:
		get_tree().quit()
