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
@export var type_sound := true    # the tick that stuck: crisp-tip-in-muffled-body
                                  # (Advika picked "3 and 5 mixed" off the board)
@export var numeral := "II"
@export var card_title := "THE TRIAL"
@export var portrait: Texture2D = preload("res://assets/enemies/wizard/idle/idle_00.png")
# The second illustration at the card's foot (Realm 2: the void moth; Realm 1
# feeds a jade shard here). And a tint on the painted card faces so each realm can
# recolour the same art to its own palette (white = the original ink-and-cream).
@export var second_art: Texture2D = preload("res://assets/enemies/void_moth/fly_01.png")
## Optional material for that foot illustration. Realm 2 hands it the moth's own
## palette shader so the creature painted on the card is the same colour as the one
## that comes out of the storm — the card kept showing the old violet after the moth
## itself had moved (Advika: *"update them in the tarot card as well"*). Realm 1 feeds
## a jade shard through `second_art` and leaves this null, so nothing recolours it.
@export var second_art_material: Material = null
@export var face_tint: Color = Color(1, 1, 1)
# The painted card faces are dark ink + light ornament; a multiply-tint can't lift
# the near-black body to a colour. When `recolor` is on, a luminance ramp remaps the
# whole face: dark body -> face_lo, bright ornament -> face_hi. Realm 1 sets a warm
# sepia body + gold ornament to match its cave. Off = Realm 2's original faces.
@export var screen_offset: Vector2 = Vector2.ZERO   # nudge off screen-centre (compare view)
# The dim behind the card — ALSO what shows through the card's see-through centre, so
# it IS the card's body colour. Realm 1 sets a warm dark here to recolour the exact
# same card without touching its structure. Default = Realm 2's cool dark.
@export var overlay_color: Color = Color(0.02, 0.015, 0.05, 0.86)
# Modulate on BOTH illustrations (portrait + foot). Realm 2's art is painted dark and
# melts into the card; Realm 1's jade/golem art is bright and loud, so Realm 1 dims it
# here to sit back the same way. White = untouched (Realm 2).
@export var art_tint: Color = Color(1, 1, 1)
## foot illustration size + verse size, as multipliers. Defaults keep Realm 2's
## approved card EXACTLY as shipped; Realm 1 shrinks its jade to buy bigger text.
@export var foot_art_scale := 1.0
@export var verse_scale := 1.0
@export var recolor := false
@export var face_lo: Color = Color(0.40, 0.30, 0.17)
@export var face_hi: Color = Color(1.0, 0.84, 0.5)
const RECOLOR := preload("res://shaders/recolor_warm.gdshader")
# Warm paper filled over the frame's transparent centre (behind the text) — the
# realm's card body. Transparent (default) keeps Realm 2's see-through look.
@export var body_color: Color = Color(0, 0, 0, 0)
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
var _tick: AudioStreamPlayer   # soft felt-blip under the typewriter
var _type_chars := 0.0
var _done := false
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	var dim := ColorRect.new()
	dim.color = overlay_color
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
	if recolor:
		# remap the whole painted face to the realm's palette (dark body -> face_lo,
		# gold ornament -> face_hi) — a multiply-tint can't lift the near-black body
		var m := ShaderMaterial.new()
		m.shader = RECOLOR
		m.set_shader_parameter("lo", face_lo)
		m.set_shader_parameter("hi", face_hi)
		m.set_shader_parameter("boost", 1.35)
		_face.material = m
	else:
		_face.modulate = face_tint   # per-realm recolour of the painted card art
	# mip-filter the big painted face as it downscales, so thin frame lines resolve
	# smoothly instead of shimmering (Advika: interior lines flickering)
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_card.add_child(_face)

	_build_reveal_ui()

	_prompt = Label.new()
	_prompt.text = "click or press any key to begin"
	_prompt.add_theme_font_override("font", _garamond)
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
	AudioManager.play_sfx(preload("res://assets/audio/wizard_card_reveal.ogg"), -14.0)
	# the typewriter's voice: a tiny synthesized felt-tick, pitch-wobbled per
	# use so 14/s doesn't read as a machine gun. Child of the card, so it
	# plays through the pause like everything else here.
	_tick = AudioStreamPlayer.new()
	_tick.stream = preload("res://assets/audio/ui_type_tick.wav")
	_tick.volume_db = -15.0
	add_child(_tick)

	# CARD_SHOT=<path>: flip immediately, snap the verses, screenshot the
	# reveal side, quit — layout gets verified by EYE before it ships
	# (the web-font spill shipped blind; never again)
	if OS.get_environment("CARD_SHOT") != "":
		_flip()
		await get_tree().create_timer(1.2).timeout
		for l in _verse_labels:
			l.visible_characters = -1
		_typing = false
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("CARD_SHOT"))
		get_tree().quit()


# Crop a texture to its opaque pixels so aspect-fit sizes the BODY, not
# the canvas padding.
func _cropped(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = used
	return at


# BUNDLED fonts (assets/fonts/, OFL): the web build has no system fonts —
# SystemFont silently fell back to Godot's wider default and the verses
# spilled off the card on the live link (Advika). Bundled files render
# identically on every platform, and the card finally gets its real
# typography.
var _cinzel: Font = preload("res://assets/fonts/cinzel.ttf")
var _garamond: Font = preload("res://assets/fonts/eb_garamond.ttf")


func _title_font(spacing: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = _cinzel
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

	# SEMI-TRANSPARENT body wash over the frame's centre, covering the FULL interior up
	# to the border (so no lighter rectangle edge). Being see-through, the frame's own
	# eyes/hairlines/crest read THROUGH it as lighter marks. (Realm 1: solid dark brown.)
	if body_color.a > 0.0:
		var paper := ColorRect.new()
		paper.color = body_color
		paper.position = Vector2(CARD_W * 0.055, CARD_H * 0.035)
		paper.size = Vector2(CARD_W * 0.89, CARD_H * 0.925)
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reveal_ui.add_child(paper)

	# CROP to the opaque pixels: both portraits are tall canvases that are
	# mostly transparent padding — aspect-fit sized the PADDING, so every
	# "bigger box" bought almost nothing (Advika, at volume, correctly)

	# everything below is a FRACTION of the card, so resizing the card never
	# unships the layout again (round 1 hard-coded pixels; text overflowed)
	_label(_reveal_ui, numeral, _title_font(3), int(CARD_H * 0.063),
			CARD_H * 0.032)                                     # above y≈183/1720

	# the illustration: the storm's author himself, above the flanking eyes
	var art := TextureRect.new()
	art.texture = _cropped(portrait)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(CARD_W * 0.5 - CARD_W * 0.342, CARD_H * 0.145)
	art.size = Vector2(CARD_W * 0.685, CARD_H * 0.208)  # clears the II above
	art.modulate = art_tint
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_ui.add_child(art)

	# The verses' size is solved BEFORE the foot art, because the foot art gets out
	# of their way rather than the other way round (Advika 2026-07-26: shrink the
	# jade so the text can be bigger).
	var vtop := CARD_H * 0.372   # verses, tight, clearing the foot illustration below
	var vsize := _fit_verse_size()
	var vspace: float = maxf(CARD_H * (0.044 if verses.size() <= 5 else 0.036), vsize * 1.45)
	var vbottom: float = vtop + vspace * float(maxi(verses.size() - 1, 0)) + float(vsize)

	# and the second threat: the void moth OWNS the card's foot — big, with
	# THE TRIAL drawn over its lower wisps (title added after = on top)
	var moth := TextureRect.new()
	moth.texture = _cropped(second_art)
	moth.material = second_art_material
	moth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moth.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# strictly INSIDE the open zone: below the last verse, above the bottom
	# hairline-with-diamond (Advika: it was blocking the card detailing).
	# foot_art_scale shrinks it (Realm 1) without touching Realm 2's approved card.
	var msize := Vector2(CARD_W * 0.80, CARD_H * 0.15) * foot_art_scale
	moth.size = msize                                  # breathing room to the diamond
	var my: float = maxf(CARD_H * 0.60, vbottom + CARD_H * 0.015)
	if foot_art_scale < 1.0:
		# a shrunk foot piece would otherwise hang right under the last verse with a
		# dead gap beneath it (Advika 2026-07-26) — sit it in the MIDDLE of the space
		# between the verses and the bottom hairline instead. Full-size art (Realm 2's
		# moth) keeps its approved placement exactly.
		var gap_top: float = vbottom + CARD_H * 0.012
		var gap_bot: float = CARD_H * 0.775
		my = gap_top + maxf(0.0, (gap_bot - gap_top - msize.y) * 0.5)
	moth.position = Vector2(CARD_W * 0.5 - msize.x * 0.5,
			clampf(my, 0.0, CARD_H * 0.775 - msize.y))
	moth.modulate = art_tint
	moth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_ui.add_child(moth)

	_label(_reveal_ui, card_title, _title_font(6), int(CARD_H * 0.05),
			CARD_H * 0.795)                                     # below y≈1335/1720

	var y := vtop
	for verse in verses:
		var l := _label(_reveal_ui, verse, _garamond, vsize, y)
		l.visible_characters = 0
		_verse_labels.append(l)
		y += vspace


## The biggest shared verse size whose LONGEST line still fits inside the frame.
## A long verse used to draw straight over the gold border (Advika 2026-07-26:
## "the text needs to fit into the box not spill") — Labels don't clip and the line
## is centred, so it bled out both sides. Solving it here means wording is never
## constrained by the layout, and `verse_scale` can ask for bigger text without
## risking a spill. One size for every line: they must stay uniform.
func _fit_verse_size() -> int:
	var sz := int(CARD_H * 0.030 * verse_scale)
	var safe_w := CARD_W * 0.80          # inner opening (0.89) with a real margin
	                                     # — at 0.88 the longest line kissed the gold
	while sz > int(CARD_H * 0.021):
		var widest := 0.0
		for verse in verses:
			widest = maxf(widest, _garamond.get_string_size(
					verse, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
		if widest <= safe_w:
			break
		sz -= 1
	return sz


func _process(delta: float) -> void:
	_t += delta
	# Hold the card on WHOLE pixels and DON'T bob it — the sub-pixel float made the
	# thin gold frame + interior hairlines shimmer/crawl, and the pulsing glow made
	# the border flicker (Advika: "borders glitching / lines flickering"). Steady card
	# + steady glow = crisp frame. The enter/exit still drifts via _rise.
	_wrapper.position = (_root.size * 0.5 + screen_offset + Vector2(0.0, _rise)).round()
	_glow.modulate.a = 0.33
	if _typing:
		_type_chars += TYPE_CPS * delta
		while _type_line < _verse_labels.size():
			var l := _verse_labels[_type_line]
			# the held breath leaves _type_chars NEGATIVE — and any negative
			# visible_characters means SHOW ALL, so the whole upcoming verse
			# flashed for the breath's length (Advika caught it). Clamp to 0.
			var vc := maxi(0, int(_type_chars))
			if type_sound and vc > l.visible_characters and vc % 2 == 0:
				_tick.pitch_scale = randf_range(0.9, 1.1)
				_tick.play()
			l.visible_characters = vc
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
