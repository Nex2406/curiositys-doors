extends Node2D

# Standalone animation reviewer for Curiosity.
# Boot straight into it:
#   Godot ... --path . res://tools/AnimReview.tscn

const ANIMS: Array[String] = ["idle", "walk", "run", "jump", "attack", "hurt", "celebrate"]

var _spr: AnimatedSprite2D
var _info: Label
var _help: Label
var _idx := 0
var _paused := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.06))

	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = load("res://assets/player/curiosity/curiosity_frames.tres")
	_spr.centered = true
	_spr.position = Vector2(560, 380)
	_spr.scale = Vector2(1.1, 1.1)
	add_child(_spr)

	_info = _make_label(40, 30, 30)
	_help = _make_label(40, 560, 22)
	_help.text = "1 idle   2 walk   3 run   4 jump   5 attack   6 hurt   7 celebrate\n" \
		+ "SPACE pause/play    , / .  step frame    R restart    ESC quit"

	_play(0)

func _make_label(x: int, y: int, size: int) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	add_child(l)
	return l

func _play(i: int) -> void:
	_idx = clampi(i, 0, ANIMS.size() - 1)
	_paused = false
	_spr.play(ANIMS[_idx])

func _process(_d: float) -> void:
	var sf := _spr.sprite_frames
	var a := ANIMS[_idx]
	_info.text = "%s   (%d/%d)   speed %.0f fps   loop %s   %s" % [
		a.to_upper(),
		_spr.frame + 1,
		sf.get_frame_count(a),
		sf.get_animation_speed(a),
		"yes" if sf.get_animation_loop(a) else "no",
		"PAUSED" if _paused else "playing",
	]

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_1: _play(0)
		KEY_2: _play(1)
		KEY_3: _play(2)
		KEY_4: _play(3)
		KEY_5: _play(4)
		KEY_6: _play(5)
		KEY_7: _play(6)
		KEY_SPACE:
			_paused = not _paused
			if _paused: _spr.pause()
			else: _spr.play(ANIMS[_idx])
		KEY_PERIOD:
			_paused = true
			_spr.pause()
			_spr.frame = (_spr.frame + 1) % _spr.sprite_frames.get_frame_count(ANIMS[_idx])
		KEY_COMMA:
			_paused = true
			_spr.pause()
			var n := _spr.sprite_frames.get_frame_count(ANIMS[_idx])
			_spr.frame = (_spr.frame - 1 + n) % n
		KEY_R: _play(_idx)
		KEY_ESCAPE: get_tree().quit()
