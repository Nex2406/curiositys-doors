extends Node2D

# Frame-by-frame review of the void moth's animations (Advika 2026-07-18:
# "tell u which ones feel choppy"). Same manners as WizardAnimReview.
# Shows the EXACT sequences VoidMoth.gd plays (turn ping-pong, attack 4-9)
# and names each frame's SOURCE FILE so feedback can point at a png.
#
#   1 / 2 / 3   fly · turn · attack
#   SPACE       play / pause
#   LEFT/RIGHT  step one frame (pauses)
#   UP/DOWN     fps +2 / -2 for the current animation
#   ESC         quit

const DIR := "res://assets/enemies/void_moth/"

# [anim, fps, loop, frame files (pack), source sheet labels (hers)]
var _sets := {
	"fly": [12.0, true, [], []],
	"turn": [14.0, false, [], []],
	"attack": [14.0, false, [], []],
	"death": [5.0, false, [], []],
}

var _sprite: AnimatedSprite2D
var _label: Label
var _anim := "turn"
var _paused := false


func _ready() -> void:
	for i in range(1, 13):
		_sets["fly"][2].append("fly_%02d" % i)
		_sets["fly"][3].append("voidmothfly%d" % i)
	for n in [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]:   # VoidMoth's ping-pong fold
		_sets["turn"][2].append("turn_%02d" % n)
		_sets["turn"][3].append("voidturn%d" % n)
	for n in range(4, 10):                        # VoidMoth trims the windups
		_sets["attack"][2].append("attack_%02d" % n)
		_sets["attack"][3].append("voidattack%d" % n)
	for n in range(1, 4):
		_sets["death"][2].append("death_%02d" % n)
		_sets["death"][3].append("voidmothdeath%d" % n)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.10)
	bg.size = Vector2(4000, 3000)
	bg.position = Vector2(-1000, -1000)
	add_child(bg)

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in _sets:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, _sets[anim][0])
		frames.set_animation_loop(anim, _sets[anim][1])
		for f in _sets[anim][2]:
			frames.add_frame(anim, load("%s%s.png" % [DIR, f]))
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.position = Vector2(960, 560)
	_sprite.scale = Vector2(1.7, 1.7)
	add_child(_sprite)
	_sprite.frame_changed.connect(_refresh)

	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 22)
	add_child(_label)

	_play(_anim)


func _play(anim: String) -> void:
	_anim = anim
	_paused = false
	_sprite.play(anim)
	_refresh()


func _refresh() -> void:
	var total: int = _sets[_anim][2].size()
	var idx: int = _sprite.frame
	var src: String = _sets[_anim][3][idx] if idx < total else "?"
	_label.text = "%s   frame %d/%d   source: %s.png   fps %.0f   %s\n1 fly · 2 turn · 3 attack · 4 death   SPACE play/pause   ←/→ step   ↑/↓ fps" \
			% [_anim.to_upper(), idx + 1, total, src,
			_sprite.sprite_frames.get_animation_speed(_anim),
			"⏸ PAUSED" if _paused else "▶ playing"]


func _step(d: int) -> void:
	_paused = true
	_sprite.pause()
	var total: int = _sets[_anim][2].size()
	_sprite.frame = wrapi(_sprite.frame + d, 0, total)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1: _play("fly")
		KEY_2: _play("turn")
		KEY_3: _play("attack")
		KEY_4: _play("death")
		KEY_SPACE:
			_paused = not _paused
			if _paused:
				_sprite.pause()
			else:
				_sprite.play(_anim)
			_refresh()
		KEY_LEFT: _step(-1)
		KEY_RIGHT: _step(1)
		KEY_UP, KEY_DOWN:
			var d := 2.0 if event.keycode == KEY_UP else -2.0
			var fps: float = clampf(_sprite.sprite_frames.get_animation_speed(_anim) + d, 2.0, 40.0)
			_sprite.sprite_frames.set_animation_speed(_anim, fps)
			_refresh()
		KEY_ESCAPE: get_tree().quit()
