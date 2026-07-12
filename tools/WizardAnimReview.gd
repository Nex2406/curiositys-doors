extends Node2D

# Standalone animation reviewer for the Wizard (Realm 2 boss — purple-shifted
# BlueWizard pack, see tools/tint_wizard_pack.gd). Modeled on AnimReview.gd.
# Boot straight into it:
#   Godot ... --path . res://tools/WizardAnimReview.tscn
# WIZ_SHOT env: screenshot at 1s + quit (headless verification).

# set name -> [frame count, fps, loops]. blink_a/b/c are the pack's three
# dash variants — one of them becomes the teleport-blink, Advika picks.
const SETS := {
	"idle": [20, 16.0, true],
	"walk": [20, 18.0, true],
	"jump": [8, 12.0, false],
	"blink_a": [16, 24.0, false],
	"blink_b": [16, 24.0, false],
	"blink_c": [16, 24.0, false],
}
const ORDER: Array[String] = ["idle", "walk", "jump", "blink_a", "blink_b", "blink_c"]
const LABELS := {
	"idle": "IDLE", "walk": "WALK", "jump": "JUMP",
	"blink_a": "BLINK A (full smear)", "blink_b": "BLINK B (readable blur)",
	"blink_c": "BLINK C (readable blur alt)",
}

var _spr: AnimatedSprite2D
var _info: Label
var _idx := 0
var _paused := false
var _speed := 1.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.07, 0.055, 0.11))

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for set_name: String in SETS:
		var spec: Array = SETS[set_name]
		frames.add_animation(set_name)
		frames.set_animation_speed(set_name, spec[1])
		frames.set_animation_loop(set_name, spec[2])
		for i in range(spec[0]):
			frames.add_frame(set_name,
					load("res://assets/enemies/wizard/%s/%s_%02d.png" % [set_name, set_name, i]))

	var center := get_viewport_rect().size * 0.5
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = frames
	_spr.position = center + Vector2(0, 40)
	_spr.scale = Vector2(1.6, 1.6)   # 512px frames read small full-screen; blow him up for review
	add_child(_spr)

	_info = _make_label(40, 30, 26)
	var help := _make_label(40, int(get_viewport_rect().size.y) - 110, 20)
	help.text = "1 idle   2 walk   3 jump   4/5/6 blink A/B/C  (teleport-blink candidates)\n" \
		+ "SPACE pause/play    , / .  step frame    F flip    Q / E  speed -+    R restart    ESC quit"

	_play(0)
	if OS.get_environment("WIZ_SHOT") != "":
		_self_screenshot(OS.get_environment("WIZ_SHOT"))

func _make_label(x: int, y: int, size: int) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.9, 0.86, 0.95))
	add_child(l)
	return l

func _play(i: int) -> void:
	_idx = clampi(i, 0, ORDER.size() - 1)
	_paused = false
	_spr.play(ORDER[_idx], _speed)

func _process(_d: float) -> void:
	var a: String = ORDER[_idx]
	_info.text = "%s   (%d/%d)   %.0f fps x%.2f   loop %s   %s" % [
		LABELS[a],
		_spr.frame + 1,
		_spr.sprite_frames.get_frame_count(a),
		_spr.sprite_frames.get_animation_speed(a),
		_speed,
		"yes" if _spr.sprite_frames.get_animation_loop(a) else "no",
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
		KEY_SPACE:
			_paused = not _paused
			if _paused: _spr.pause()
			else: _spr.play(ORDER[_idx], _speed)
		KEY_PERIOD:
			_paused = true
			_spr.pause()
			_spr.frame = (_spr.frame + 1) % _spr.sprite_frames.get_frame_count(ORDER[_idx])
		KEY_COMMA:
			_paused = true
			_spr.pause()
			var n := _spr.sprite_frames.get_frame_count(ORDER[_idx])
			_spr.frame = (_spr.frame - 1 + n) % n
		KEY_F: _spr.flip_h = not _spr.flip_h
		KEY_Q:
			_speed = maxf(0.25, _speed - 0.25)
			if not _paused: _spr.play(ORDER[_idx], _speed)
		KEY_E:
			_speed = minf(3.0, _speed + 0.25)
			if not _paused: _spr.play(ORDER[_idx], _speed)
		KEY_R: _play(_idx)
		KEY_ESCAPE: get_tree().quit()

func _self_screenshot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
