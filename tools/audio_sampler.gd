extends Control
## Audio sampler — auditions the 12 fairytale tracks so Advika can pick Level 1's
## background music. Scans the extracted tracks folder, one button per track; click
## to play (stops the current one). Track 1 "Moonlight" is what Realm 2 uses.

const TRACKS_DIR := "C:/Users/advik/AppData/Local/Temp/claude/C--Users-advik-Curiosity-s-Doors/74d97699-4ba4-4bc2-a420-181865206542/scratchpad/tracks"

var _player: AudioStreamPlayer
var _now: Label
var _buttons: Array = []
var _playing := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "serif"])

	var title := Label.new()
	title.text = "LEVEL 1  —  pick a track"
	title.add_theme_font_override("font", serif)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7))
	title.position = Vector2(40, 26)
	add_child(title)

	_now = Label.new()
	_now.add_theme_font_override("font", serif)
	_now.add_theme_font_size_override("font_size", 20)
	_now.add_theme_color_override("font_color", Color(0.75, 0.85, 0.7))
	_now.position = Vector2(40, 66)
	_now.size = Vector2(760, 26)
	_now.text = "click a track to play"
	add_child(_now)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 110)
	scroll.size = Vector2(760, 560)
	add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(740, 0)
	scroll.add_child(vb)

	var files := _track_files()
	for path in files:
		var nm := _display_name(path.get_file())
		var b := Button.new()
		b.text = ("♪  " + nm) + ("   —  (Realm 2's track)" if nm.begins_with("Moonlight") else "")
		b.add_theme_font_override("font", serif)
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(720, 46)
		b.pressed.connect(_on_track.bind(path, nm))
		vb.add_child(b)
		_buttons.append(b)

	var stop := Button.new()
	stop.text = "■  Stop"
	stop.add_theme_font_override("font", serif)
	stop.add_theme_font_size_override("font_size", 20)
	stop.position = Vector2(40, 686)
	stop.size = Vector2(160, 44)
	stop.pressed.connect(_stop)
	add_child(stop)


func _track_files() -> Array:
	var out: Array = []
	var d := DirAccess.open(TRACKS_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.to_lower().ends_with(".mp3"):
			out.append(TRACKS_DIR + "/" + f)
		f = d.get_next()
	out.sort()
	return out


func _display_name(fname: String) -> String:
	var s := fname.replace("(Full).mp3", "").strip_edges()
	# strip a leading "N. "
	var dot := s.find(". ")
	if dot >= 0 and dot <= 2:
		s = s.substr(dot + 2)
	return s.strip_edges()


func _on_track(path: String, nm: String) -> void:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		_now.text = "could not open: " + nm
		return
	var stream := AudioStreamMP3.new()
	stream.data = fa.get_buffer(fa.get_length())
	stream.loop = true
	_player.stream = stream
	_player.play()
	_playing = nm
	_now.text = "▶  " + nm


func _stop() -> void:
	_player.stop()
	_now.text = "stopped"
