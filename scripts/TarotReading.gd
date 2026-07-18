extends CanvasLayer
class_name TarotReading

# The trial announces itself as a READING (Advika, 2026-07-17): her card art
# front (door-arch with the eye) floats in, flips to the ornamental reveal
# frame, and the trial's verses type themselves line by line between the
# frame's flanking eyes. Replaces nothing yet — the trial level still uses
# TarotCard; this scene carries the same contract (pauses the game, ducks
# the music, emits `closed`) so the swap is one line whenever she says so.
#
# Both faces are 1000x1720 renders of a 500x860 card; every label position
# below is that source mapped through CARD_H/1720.

signal closed()

const CREAM := Color("EAE6DA")
const CREAM_DIM := Color("EAE6DA", 0.55)
const CARD_H := 560.0                      # bigger (Advika round 2) — it owns the frame
const CARD_W := CARD_H * 1000.0 / 1720.0   # ≈ 326
const TYPE_CPS := 28.0                     # typewriter chars/sec

# This card REPLACES the code-drawn TarotCard as the wizard's trial gate
# (Advika) — same numeral, portrait, and verses, her painted faces. The moth
# verse is hers ("Linger too long and the void moth wakes", styled to match).
@export var numeral := "II"
@export var card_title := "THE TRIAL"
@export var portrait: Texture2D = preload("res://assets/enemies/wizard/idle/idle_00.png")
# One uniform voice: threat — answer (Advika: fit the text, make it uniform,
# say how the moths are expelled).
@export var verses: Array[String] = [
	"Strike the conjurer — J",
	"Grow the light — hold L",
	"The orbs only push — keep moving",
	"The void moth dies only to light — hold L",
	"Kill the conjurer to secure victory",
]

var _wrapper: Control
var _card: Control
var _face: TextureRect
var _glow: TextureRect
var _reveal_ui: Control
var _verse_labels: Array[Label] = []
var _prompt: Label
var _root: Control
var _rise := 26.0   # enter/exit vertical drift, blended into the bob
var _t := 0.0
var _flipped := false
var _typing := false
var _type_line := 0
var _type_chars := 0.0
var _done := false
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE, or the overlay eats every mouse click before _unhandled_input
	# sees it (Advika: clicking didn't flip the card)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# the wrapper is positioned EVERY FRAME from the live screen center —
	# anchor presets + a positional bob fight each other (the first pass
	# lerped the card to the screen top; Advika: "why is the card in air")
	_wrapper = Control.new()
	_root.add_child(_wrapper)

	# faint warm breath behind the card — lantern-kin, not a spotlight
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(1, 1, 1, 1))
	g.gradient.set_color(1, Color(1, 1, 1, 0))
	g.width = 64
	g.height = 64
	_glow = TextureRect.new()
	_glow.texture = g
	_glow.size = Vector2(CARD_W, CARD_H) * 2.1
	_glow.position = -_glow.size * 0.5
	# moon-cream, the card's own scheme — the lantern gold clashed against
	# the ink-and-cream faces (Advika: match its colorscheme)
	_glow.modulate = Color(0.92, 0.89, 0.82, 0.34)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add_mat
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrapper.add_child(_glow)

	_card = Control.new()
	_card.size = Vector2(CARD_W, CARD_H)
	_card.position = -_card.size * 0.5
	_card.pivot_offset = _card.size * 0.5
	_card.clip_contents = true
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrapper.add_child(_card)

	_face = TextureRect.new()
	_face.texture = load("res://assets/ui/tarot/tarot_front.png")
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	# TextureRects default to STOP — the face swallowed every click ON the
	# card, the one place a player clicks (Advika, twice). Never again:
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_face)

	_build_reveal_ui()

	_prompt = Label.new()
	_prompt.text = "click — or any key — to begin"
	_prompt.add_theme_font_override("font", _serif(["EB Garamond", "Georgia", "serif"]))
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", CREAM_DIM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-140, CARD_H * 0.5 + 26)
	_prompt.size = Vector2(280, 24)
	_prompt.modulate.a = 0.0
	_wrapper.add_child(_prompt)   # rides the centered wrapper, not the layout

	# drawn from the deck: rises in from a shade below, glow swelling with it
	_wrapper.modulate.a = 0.0
	var enter := create_tween().set_parallel(true)
	enter.tween_property(_wrapper, "modulate:a", 1.0, 0.5)
	enter.tween_method(func(v: float) -> void: _rise = v, 26.0, 0.0, 0.6)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	get_tree().paused = true
	AudioManager.duck_music()
	# the reveal chime, once, as the card enters (Olex Mazur pack) — softened
	# to sit IN the dipped music, not on top of it (Advika: blend both)
	AudioManager.play_sfx(preload("res://assets/audio/wizard_card_reveal.ogg"), -10.0)


func _serif(names: Array) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	return f


func _title_font(names: Array, spacing: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = _serif(names)
	v.spacing_glyph = spacing
	return v


func _label(parent: Control, text: String, font: Font, sz: int, y: float,
		color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(CARD_W, sz + 8)
	parent.add_child(l)
	return l


# The reveal side's text, mapped to the frame's own furniture: numeral above
# the top hairline, name below the bottom hairline-with-diamond, the verses
# in the open zone between the two flanking eyes.
func _build_reveal_ui() -> void:
	_reveal_ui = Control.new()
	_reveal_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_ui.visible = false
	_card.add_child(_reveal_ui)

	var cinzel := ["Cinzel", "Georgia", "Times New Roman", "serif"]
	var garamond := ["EB Garamond", "Georgia", "serif"]

	# everything below is a FRACTION of the card, so resizing the card never
	# unships the layout again (round 1 hard-coded pixels; text overflowed)
	_label(_reveal_ui, numeral, _title_font(cinzel, 3), int(CARD_H * 0.063),
			CARD_H * 0.032)                                     # above y≈183/1720

	# the illustration: the storm's author himself, above the flanking eyes
	var art := TextureRect.new()
	art.texture = portrait
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(CARD_W * 0.5 - CARD_W * 0.40, CARD_H * 0.06)
	art.size = Vector2(CARD_W * 0.80, CARD_H * 0.34)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_ui.add_child(art)

	# and the second threat: the void moth OWNS the card's foot — big, with
	# THE TRIAL drawn over its lower wisps (title added after = on top)
	var moth := TextureRect.new()
	moth.texture = preload("res://assets/enemies/void_moth/fly_01.png")
	moth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moth.position = Vector2(CARD_W * 0.5 - CARD_W * 0.45, CARD_H * 0.60)
	moth.size = Vector2(CARD_W * 0.90, CARD_H * 0.22)
	moth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_ui.add_child(moth)

	_label(_reveal_ui, card_title, _title_font(cinzel, 6), int(CARD_H * 0.05),
			CARD_H * 0.795)                                     # below y≈1335/1720

	var y := CARD_H * 0.40    # five verses now — tucked so the big moth fits
	for verse in verses:
		var l := _label(_reveal_ui, verse, _serif(garamond), int(CARD_H * 0.028), y)
		l.visible_characters = 0
		_verse_labels.append(l)
		y += CARD_H * 0.046


func _process(delta: float) -> void:
	_t += delta
	# the float: screen center + a slow breath, the glow a half-step behind
	_wrapper.position = _root.size * 0.5 \
			+ Vector2(0.0, sin(_t * TAU / 3.4) * 5.0 + _rise)
	_glow.modulate.a = 0.30 + sin(_t * TAU / 3.4 + 0.9) * 0.07
	if _typing:
		_type_chars += TYPE_CPS * delta
		while _type_line < _verse_labels.size():
			var l := _verse_labels[_type_line]
			l.visible_characters = int(_type_chars)
			if l.visible_characters < l.text.length():
				break
			l.visible_characters = -1
			_type_chars -= l.text.length() + 3.0   # a small held breath per line
			_type_line += 1
		if _type_line >= _verse_labels.size():
			_typing = false
			_done = true
			_show_prompt()


func _show_prompt() -> void:
	var t := create_tween()
	t.tween_property(_prompt, "modulate:a", 1.0, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed or _closing:
		return
	get_viewport().set_input_as_handled()
	if not _flipped:
		_flip()
	elif _typing:
		# snap-to-complete, DialogueBox manners
		for l in _verse_labels:
			l.visible_characters = -1
		_typing = false
		_done = true
		_show_prompt()
	elif _done:
		# any command begins — click, interact, any key (Advika: no key
		# pressing per se; the mouse alone must carry the whole card)
		_begin()


# The flip: fold edge-on with a breath of squash, swap faces, spring open
# with overshoot, and a glint sweeps the fresh face. The screen kicks a
# whisper at the swap — the card has weight.
func _flip() -> void:
	_flipped = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_card, "scale:x", 0.0, 0.18)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_card, "scale:y", 1.06, 0.18)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		_face.texture = load("res://assets/ui/tarot/trial_reveal_frame.png")
		_reveal_ui.visible = true
		Haptics.buzz(30, 0.22)
		_glow.modulate.a = 0.55)
	tw.chain().tween_property(_card, "scale:x", 1.0, 0.22)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_card, "scale:y", 1.0, 0.22)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_glint)
	tw.chain().tween_callback(func() -> void:
		_typing = true
		_type_chars = 0.0)


# A cream glint sweeping the face right after the spring-open.
func _glint() -> void:
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0.0, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.gradient = Gradient.new()
	g.gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.gradient.colors = PackedColorArray([Color(1, 1, 1, 0),
			Color(0.92, 0.89, 0.8, 0.30), Color(1, 1, 1, 0)])
	g.width = 64
	g.height = 64
	var sweep := TextureRect.new()
	sweep.texture = g
	sweep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sweep.size = Vector2(CARD_W * 0.7, CARD_H)
	sweep.rotation = 0.18
	sweep.position = Vector2(-CARD_W, -20)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(sweep)
	var t := create_tween()
	t.tween_property(sweep, "position:x", CARD_W * 1.3, 0.32)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.finished.connect(sweep.queue_free)


func _begin() -> void:
	_closing = true
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_wrapper, "modulate:a", 0.0, 0.45)
	t.tween_property(_prompt, "modulate:a", 0.0, 0.3)
	t.tween_method(func(v: float) -> void: _rise = v, 0.0, -18.0, 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func() -> void:
		get_tree().paused = false
		AudioManager.unduck_music()
		closed.emit()
		queue_free())
