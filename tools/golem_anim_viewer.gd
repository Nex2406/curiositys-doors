extends Control
## Golem animation viewer — click any clip to watch it (all looped for review).
## Feet stay on a fixed ground line so you can judge alignment between clips too.

const BoulderGolem := preload("res://scripts/BoulderGolem.gd")
const DIR := "res://assets/enemies/golem/boulder/"

var _sprite: AnimatedSprite2D
var _label: Label
var _ground_y := 560.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.5, 0.46, 0.42)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# a ground line to judge feet alignment
	var line := ColorRect.new()
	line.color = Color(0.28, 0.24, 0.2)
	line.position = Vector2(0, _ground_y)
	line.size = Vector2(1200, 240)
	add_child(line)

	# SpriteFrames from the golem's own animation table, all looped for review
	var sf := SpriteFrames.new()
	for name in BoulderGolem.ANIMS:
		var spec: Array = BoulderGolem.ANIMS[name]
		sf.add_animation(name)
		sf.set_animation_loop(name, true)
		sf.set_animation_speed(name, spec[3])
		for i in range(spec[1], spec[2] + 1):
			sf.add_frame(name, load("%s%s%d.png" % [DIR, spec[0], i]))

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sf
	_sprite.centered = true
	_sprite.scale = Vector2(1.3, 1.3)      # enlarged for review
	_sprite.position = Vector2(600, _ground_y)
	add_child(_sprite)

	_label = Label.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "serif"])
	_label.add_theme_font_override("font", f)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.1, 0.09, 0.08))
	_label.position = Vector2(40, 30)
	add_child(_label)

	# a button per clip
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.position = Vector2(40, 80)
	add_child(hb)
	var order := ["spawn", "idle", "move", "windup", "roll", "defeat", "ceilingspawn"]
	for name in order:
		var b := Button.new()
		b.text = name
		b.add_theme_font_override("font", f)
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(_play.bind(name))
		hb.add_child(b)

	_play("idle")


func _play(name: String) -> void:
	# bottom-align every clip to the ground line via its offset (feet stay put)
	_sprite.offset = BoulderGolem.OFFSETS[name]
	_sprite.play(name)
	var spec: Array = BoulderGolem.ANIMS[name]
	_label.text = "%s   (%d frames @ %d fps)" % [name, spec[2] - spec[1] + 1, int(spec[3])]
