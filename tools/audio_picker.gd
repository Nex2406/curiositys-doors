extends Node2D

## Audition rig for EVERY piece of audio we have — what is already in the game AND the
## unused music packs still sitting in Downloads (Advika 2026-07-29: "give me a sample
## window of all audios we have ... the ones we haven't used in the game").
##
## The library packs are read STRAIGHT OFF DISK at runtime, not imported into the project:
## 66 tracks is 266MB, and none of it belongs in git until a track is actually chosen. So
## this is a dev tool that only works from a local run — that is the point, not a bug.
##
##   up / down     move          (page up / page down jumps a screen)
##   enter, space  play / stop
##   left, right   seek 5s       (shift: 15s)
##   L             loop on / off
##   esc           quit
##
## Picking one: tell me the name and I copy it into assets/audio and wire it up.

const CREAM := Color(0.90, 0.87, 0.79)
const DIM := Color(0.50, 0.48, 0.46)
const ACCENT := Color(0.93, 0.78, 0.45)
const COOL := Color(0.55, 0.78, 0.88)
const IN_GAME := Color(0.62, 0.85, 0.66)

const EXTS := ["ogg", "wav", "mp3"]
const LIBRARY := "C:/Users/advik/Downloads/_audio_library"

var _clips: Array = []          # {path, label, group, in_game, stream, length}
var _rows: Array[Label] = []
var _sel := 0
var _playing := -1
var _loop := false

var _player: AudioStreamPlayer
var _now: Label
var _bar: ProgressBar
var _scroll: ScrollContainer


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.043, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var under := CanvasLayer.new()
	under.layer = -10
	under.add_child(bg)
	add_child(under)

	_player = AudioStreamPlayer.new()
	_player.finished.connect(_on_finished)
	add_child(_player)

	_scan_res("res://assets/audio", "IN GAME", true)
	_scan_disk(LIBRARY + "/fairytale", "FAIRYTALE PACK  (12 tracks, unused)")
	_scan_disk(LIBRARY + "/jrpg", "JRPG PACK  (12 tracks, unused)")
	_build_ui()
	_paint()


func _scan_res(dir: String, group: String, in_game: bool) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_scan_res(dir + "/" + sub, group, in_game)
	for f in d.get_files():
		var name := f.trim_suffix(".import")
		if not EXTS.has(name.get_extension().to_lower()):
			continue
		var path := dir + "/" + name
		if _clips.any(func(c): return c.path == path):
			continue
		_add(path, name.get_basename(), group, in_game)


func _scan_disk(dir: String, group: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		push_warning("no library at %s" % dir)
		return
	var files := d.get_files()
	files.sort()
	for f in files:
		if EXTS.has(f.get_extension().to_lower()):
			_add(dir + "/" + f, _tidy(f.get_basename()), group, false)


## "1. Moonlight (Abmient, Intense) - 1. Moonlight (Full Loop)" -> "1. Moonlight (Full Loop)"
## The packs repeat the track name in the folder AND the file; keep the variant, drop the echo.
func _tidy(name: String) -> String:
	var dash := name.find(" - ")
	return name.substr(dash + 3) if dash >= 0 else name


func _add(path: String, label: String, group: String, in_game: bool) -> void:
	_clips.append({
		"path": path, "label": label, "group": group,
		"in_game": in_game, "stream": null, "length": 0.0,
	})


## Streams load on first play. Loading all 66 up front is 266MB and a long stare at a blank
## window; this way the list is instant and only what you listen to costs anything.
func _stream_for(i: int) -> AudioStream:
	var c: Dictionary = _clips[i]
	if c.stream != null:
		return c.stream
	var stream: AudioStream = null
	if String(c.path).begins_with("res://"):
		stream = load(c.path)
	else:
		match String(c.path).get_extension().to_lower():
			"ogg": stream = AudioStreamOggVorbis.load_from_file(c.path)
			"mp3": stream = AudioStreamMP3.load_from_file(c.path)
			"wav": stream = AudioStreamWAV.load_from_file(c.path)
	if stream != null:
		c.stream = stream
		c.length = stream.get_length()
	return stream


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 54)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	ui.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	margin.add_child(col)

	col.add_child(_label("AUDIO LIBRARY — %d clips" % _clips.size(), 24, CREAM))
	_now = _label("nothing playing", 19, ACCENT)
	col.add_child(_now)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 5)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	col.add_child(_bar)
	col.add_child(_spacer(8))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)

	var group := ""
	for i in _clips.size():
		var c: Dictionary = _clips[i]
		if c.group != group:
			group = c.group
			list.add_child(_spacer(10))
			list.add_child(_label(String(group).to_upper(), 15, COOL))
		var row := _label("", 18, DIM)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_row_input.bind(i))
		list.add_child(row)
		_rows.append(row)

	col.add_child(_spacer(8))
	col.add_child(_label(
			"↑↓ move · enter/space play-stop · ←→ seek 5s (shift 15s) · L loop · esc quit",
			15, DIM))


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _fmt(seconds: float) -> String:
	if seconds <= 0.0:
		return " -- "
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _paint() -> void:
	for i in _rows.size():
		var c: Dictionary = _clips[i]
		var mark := "▶" if i == _playing else ("›" if i == _sel else " ")
		var tag := "  ·in game" if c.in_game else ""
		_rows[i].text = "%s  %-46s %s%s" % [mark, c.label, _fmt(c.length), tag]
		if i == _playing:
			_rows[i].add_theme_color_override("font_color", ACCENT)
		elif i == _sel:
			_rows[i].add_theme_color_override("font_color", CREAM)
		elif c.in_game:
			_rows[i].add_theme_color_override("font_color", IN_GAME)
		else:
			_rows[i].add_theme_color_override("font_color", DIM)


func _process(_delta: float) -> void:
	if _playing < 0 or not _player.playing:
		_bar.value = 0.0
		return
	var length: float = float(_clips[_playing].length)
	var at: float = _player.get_playback_position()
	_bar.value = clampf(at / maxf(0.01, length), 0.0, 1.0)
	_now.text = "▶  %s   %s / %s%s" % [_clips[_playing].label, _fmt(at), _fmt(length),
			"   [loop]" if _loop else ""]


func _play(i: int) -> void:
	if i < 0 or i >= _clips.size():
		return
	var stream := _stream_for(i)
	if stream == null:
		_now.text = "could not load %s" % _clips[i].path
		return
	_playing = i
	_apply_loop(stream)
	_player.stream = stream
	_player.play()
	_paint()


## Looping lives on the stream resource and each type spells it differently.
func _apply_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = _loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = _loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = \
				AudioStreamWAV.LOOP_FORWARD if _loop else AudioStreamWAV.LOOP_DISABLED


func _stop() -> void:
	_player.stop()
	_playing = -1
	_now.text = "nothing playing"
	_paint()


func _on_finished() -> void:
	if not _loop:
		_playing = -1
		_now.text = "nothing playing"
		_paint()


func _seek(delta: float) -> void:
	if _playing < 0 or not _player.playing:
		return
	var length: float = float(_clips[_playing].length)
	_player.seek(clampf(_player.get_playback_position() + delta, 0.0, maxf(0.0, length - 0.1)))


func _move(step: int) -> void:
	if _clips.is_empty():
		return
	_sel = clampi(_sel + step, 0, _clips.size() - 1)
	_paint()
	if _scroll != null and _sel < _rows.size():
		_scroll.ensure_control_visible(_rows[_sel])


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_sel = i
		if _playing == i:
			_stop()
		else:
			_play(i)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var step: float = 15.0 if key.shift_pressed else 5.0
	match key.keycode:
		KEY_DOWN, KEY_S: _move(1)
		KEY_UP, KEY_W: _move(-1)
		KEY_PAGEDOWN: _move(12)
		KEY_PAGEUP: _move(-12)
		KEY_HOME: _move(-_clips.size())
		KEY_END: _move(_clips.size())
		KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
			if _playing == _sel:
				_stop()
			else:
				_play(_sel)
		KEY_RIGHT: _seek(step)
		KEY_LEFT: _seek(-step)
		KEY_L:
			_loop = not _loop
			if _playing >= 0:
				_apply_loop(_clips[_playing].stream)
			_paint()
		KEY_ESCAPE:
			get_tree().quit()
