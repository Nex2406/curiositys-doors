extends Control
class_name HourglassTimer

## REALM 3'S CLOCK, AS AN HOURGLASS — and it does not own the time.
##
## The level holds the clock; this only reads it. That is the whole design of
## the thing: because the frame is derived from elapsed time every tick rather
## than played as an animation, pausing the level freezes the sand for free,
## and nothing can ever drift out of agreement with the number underneath it.
##
##   frame = clamp(int(elapsed / total * 16), 0, 15)
##
## Sixteen stages over ten minutes is one drop every 37.5 seconds, landing on
## the drained frame exactly at expiry. It is NEVER tweened between frames —
## the step is the point. It should tick like a verdict, not drain like a
## progress bar.
##
## The glass is genuinely semi-transparent (alpha ~0.2-0.9), so the motes drawn
## BEHIND it show through the bulbs and are hidden by the opaque frame with no
## mask or clipping shader involved.

const FRAMES := 16
const FRAME_DIR := "res://assets/ui/hourglass/hourglass_%02d.png"
## the art, at its true size — every frame is exactly this, untrimmed
const ART_SIZE := Vector2(206.0, 396.0)

## how tall the hourglass reads on screen; the widget scales as ONE unit
@export var display_height := 180.0
## margin from the top and right edges of the viewport — pulled well in off the
## right edge (Advika), so it hangs in the frame rather than clinging to it
@export var margin := Vector2(58.0, 26.0)

## it hangs from a chain, so it drifts — the same slow lift the lantern has
@export var bob_amplitude := 4.0
@export var bob_period := 4.2
## the level's own length, in seconds. Only used if nobody calls set_time().
@export var total_seconds := 600.0

## the countdown's voice — the same EB Garamond the door prompt speaks in
const LABEL_FONT := "res://assets/fonts/eb_garamond.ttf"
## sand gold — the motes live in this family
const MOTE_COLOR := Color("#E8D48A")

# ---- the timer's own hue ----
## The glass is lit from inside by its own sand. This is the wash that says so
## — the same idea as the lantern's, in the hourglass's warmer gold.
@export var hue := Color(1.0, 0.80, 0.45)
@export_range(0.0, 1.0) var hue_strength := 0.5
## the digits get their own share of it: a warm bloom behind them, and the
## cream of the numerals themselves pulled toward the gold
@export_range(0.0, 1.0) var text_hue_strength := 0.5
## under this many seconds the orbs warm and the glass starts to tremble
const DREAD_SECS := 60.0
const PANIC_SECS := 10.0

## a soft dark oval behind everything, for when the fungal backdrop turns the
## see-through bulbs to mush. Off until proven necessary.
@export var backing_panel := false
@export_range(0.0, 1.0) var backing_alpha := 0.4

var _sprite: Sprite2D
var _carrier: Node2D       # what levitates: glass + digits, as one object
var _root: Node2D          # the one scaled unit: motes + glass + tremble
var _motes: CPUParticles2D
var _label: Label
var _panel: Node2D
var _hue_node: Node2D
var _text_hue: Node2D
var _label_rect := Rect2()
## the countdown's resting colour, before the gold is mixed in
const TEXT_BASE := Color("EAE6DA", 0.78)
## the hue breathes very slowly, so the corner is never a static blob
var _hue_pulse := 1.0
var _textures: Array[Texture2D] = []

var _elapsed := 0.0
var _remaining := 0.0
var _frame := 0
var _tick := 0.0
var _t := 0.0
## debug: cycle every frame fast to prove nothing drifts
var _cycling := false
var _cycle_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# pinned to the TOP-RIGHT by anchors, never by absolute coordinates, so it
	# holds its corner at any window size and in fullscreen
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	# HORIZONTAL: the glass on the left, the time beside it on the same line.
	# The widget's own width is measured from both, so anchoring its right edge
	# to the viewport keeps the TEXT inside the screen rather than hanging off.
	var scl: float = display_height / ART_SIZE.y
	var draw_w: float = ART_SIZE.x * scl
	var lfont: Font = load(LABEL_FONT)
	var fsize: int = int(round(display_height * 0.30))
	# measured on "00:00", not on the current time, so the layout cannot shift
	# as the digits change
	var text_w: float = lfont.get_string_size("00:00",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var gap: float = display_height * 0.10
	var total_w: float = draw_w + gap + text_w
	offset_left = -(total_w + margin.x)
	offset_right = -margin.x
	offset_top = margin.y
	offset_bottom = margin.y + display_height

	for i in FRAMES:
		_textures.append(load(FRAME_DIR % (i + 1)))

	# The carrier is what LEVITATES — glass and digits together, as one hanging
	# object. It is a Node2D on purpose: Godot rounds Control positions to
	# whole pixels, so bobbing the Control (or the Label) would stair-step.
	_carrier = Node2D.new()
	add_child(_carrier)

	# ONE scaled unit. Everything inside is authored at art scale and the root
	# carries the single scale value, so no child can pick up its own rounding.
	_root = Node2D.new()
	_root.scale = Vector2(scl, scl)
	_carrier.add_child(_root)

	if backing_panel:
		_panel = Node2D.new()
		_panel.z_index = -2
		_root.add_child(_panel)
		_panel.draw.connect(_draw_panel)

	# the hue sits UNDER the motes, which sit under the glass
	if hue_strength > 0.0:
		_hue_node = Node2D.new()
		_hue_node.z_index = -3
		_root.add_child(_hue_node)
		_hue_node.draw.connect(_draw_hue)

	_build_motes()

	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _textures[0]
	_sprite.z_index = 0
	_root.add_child(_sprite)

	_label = Label.new()
	_label.add_theme_font_override("font", lfont)
	_label.add_theme_font_size_override("font_size", fsize)
	_label.add_theme_color_override("font_color", Color("EAE6DA", 0.78))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# full widget height + centred, so the digits sit level with the glass's
	# waist no matter what size the hourglass is set to
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size = Vector2(text_w, display_height)
	_label.position = Vector2(draw_w + gap, 0.0)
	_label_rect = Rect2(_label.position, _label.size)

	# the digits' own warm bloom, BEHIND them. A halo drawn as soft shapes,
	# never as stacked copies of the text — stamping the glyphs is what turned
	# the lantern's "Health" into a row of bricks.
	if text_hue_strength > 0.0:
		_text_hue = Node2D.new()
		_text_hue.z_index = -1
		_carrier.add_child(_text_hue)
		_text_hue.draw.connect(_draw_text_hue)

	# inside the carrier, so the digits rise and fall WITH the glass instead of
	# staying nailed in place while it drifts
	_carrier.add_child(_label)

	set_time(0.0, total_seconds)

	if OS.get_environment("R3_GLASS_DEBUG") != "":
		await get_tree().process_frame
		await get_tree().process_frame
		print("GLASS rect=", get_global_rect(),
				"  visible=", is_visible_in_tree(),
				"  modulate=", modulate,
				"  root_scale=", _root.scale,
				"  tex=", _textures[0],
				"  tex_size=", _textures[0].get_size() if _textures[0] else "NULL",
				"  viewport=", get_viewport_rect().size,
				"  parent=", get_parent())


## THE ONLY ENTRY POINT. The level tells it where the clock is; it never counts.
func set_time(elapsed: float, total: float) -> void:
	total_seconds = maxf(total, 0.001)
	_elapsed = clampf(elapsed, 0.0, total_seconds)
	_remaining = total_seconds - _elapsed
	_apply_frame()
	_apply_label()


func _apply_frame() -> void:
	if _cycling:
		return
	# the stepped drop, straight off the clock. int() floors, so frame 16 is
	# only reached when the time is genuinely gone.
	var f: int = clampi(int(_elapsed / total_seconds * float(FRAMES)),
			0, FRAMES - 1)
	if f != _frame:
		_frame = f
		_sprite.texture = _textures[f]


func _apply_label() -> void:
	var secs: int = int(ceil(_remaining))
	_label.text = "%d:%02d" % [secs / 60, secs % 60]


func _build_motes() -> void:
	# Behind the glass (z -1), so the semi-transparent bulbs show them and the
	# opaque frame hides them. No clipping shader anywhere.
	_motes = CPUParticles2D.new()   # CPU: the web export prefers it
	_motes.z_index = -1
	_motes.amount = 9
	_motes.lifetime = 4.2
	_motes.preprocess = 2.0
	_motes.local_coords = true
	# a narrow vertical box over the bulbs' own footprint
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(ART_SIZE.x * 0.20, ART_SIZE.y * 0.34)
	_motes.position = Vector2(ART_SIZE.x * 0.5, ART_SIZE.y * 0.5)
	# NO GRAVITY. CPUParticles2D defaults to (0, 98), which dragged the motes
	# straight down out of the glass and left a streak falling into the level.
	# These are meant to rise inside the bulbs and nowhere else.
	_motes.gravity = Vector2.ZERO
	# spore-light rising off the sand: slow up, gentle wander
	_motes.direction = Vector2(0, -1)
	_motes.spread = 22.0
	_motes.initial_velocity_min = 5.0
	_motes.initial_velocity_max = 13.0
	_motes.damping_min = 0.4
	_motes.damping_max = 1.1
	_motes.scale_amount_min = 2.0
	_motes.scale_amount_max = 4.0
	_motes.color = Color(MOTE_COLOR.r, MOTE_COLOR.g, MOTE_COLOR.b, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(MOTE_COLOR.r, MOTE_COLOR.g, MOTE_COLOR.b, 0.0))
	ramp.set_color(1, Color(MOTE_COLOR.r, MOTE_COLOR.g, MOTE_COLOR.b, 0.0))
	ramp.add_point(0.35, Color(MOTE_COLOR.r, MOTE_COLOR.g, MOTE_COLOR.b, 0.75))
	# a Gradient, NOT a GradientTexture1D — the wrong type here is a parse
	# error, which kills the whole script and leaves no widget on screen at all
	_motes.color_ramp = ramp
	_motes.texture = _mote_texture()
	_root.add_child(_motes)


## a tiny soft round mote, built in code so nothing has to be exported
func _mote_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 16
	t.height = 16
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## the digits' halo: a soft warm pool sitting under the numerals, wider than it
## is tall so it follows the shape of the line rather than balling up
func _draw_text_hue() -> void:
	var c: Vector2 = _label_rect.position + _label_rect.size * 0.5
	var a: float = text_hue_strength * _hue_pulse
	for i in 7:
		var k: float = 1.0 - float(i) / 7.0
		var r: float = _label_rect.size.x * 0.62 * (0.40 + 0.60 * (1.0 - k))
		_text_hue.draw_set_transform(c, 0.0, Vector2(1.0, 0.52))
		_text_hue.draw_circle(Vector2.ZERO, r,
				Color(hue.r, hue.g, hue.b, a * k * 0.085))
	_text_hue.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## a warm bloom centred on the glass, widest and faintest at the edge — the
## sand lighting its own bulbs, and the corner of the screen with them
func _draw_hue() -> void:
	var c := Vector2(ART_SIZE.x * 0.5, ART_SIZE.y * 0.5)
	var r: float = ART_SIZE.y * 0.62
	var a: float = hue_strength * _hue_pulse
	for i in 8:
		var k: float = 1.0 - float(i) / 8.0
		_hue_node.draw_circle(c, r * (0.42 + 0.58 * (1.0 - k)),
				Color(hue.r, hue.g, hue.b, a * k * 0.075))


func _draw_panel() -> void:
	# a soft dark oval under the whole widget
	var c := Vector2(ART_SIZE.x * 0.5, ART_SIZE.y * 0.52)
	for i in 8:
		var k: float = 1.0 - float(i) / 8.0
		_panel.draw_circle(c, ART_SIZE.y * 0.36 * (0.5 + 0.5 * (1.0 - k)),
				Color(0.02, 0.04, 0.04, backing_alpha * k * 0.22))


func _process(delta: float) -> void:
	_t += delta
	if _cycling:
		_cycle_t += delta
		if _cycle_t >= 0.12:
			_cycle_t = 0.0
			_frame = (_frame + 1) % FRAMES
			_sprite.texture = _textures[_frame]
			_label.text = "frame %d" % (_frame + 1)
		return

	# ---- the hue breathes, and warms as the sand runs out ----
	if _hue_node != null:
		_hue_pulse = 0.82 + 0.18 * sin(_t * 0.9)
		if _remaining <= DREAD_SECS:
			_hue_pulse *= 1.25
		_hue_node.queue_redraw()
	if _text_hue != null:
		_text_hue.queue_redraw()
	if _label != null:
		# the numerals themselves warm toward the gold, breathing with the rest
		_label.add_theme_color_override("font_color",
				TEXT_BASE.lerp(hue, text_hue_strength * 0.75 * _hue_pulse))

	# ---- the levitation: the whole thing hangs and drifts ----
	if bob_period > 0.0 and _carrier != null:
		_carrier.position.y = sin(_t * TAU / bob_period) * bob_amplitude

	# ---- last-minute dread: it whispers, it does not flash ----
	var trem := 0.0
	if _remaining <= PANIC_SECS:
		trem = 1.9
	elif _remaining <= DREAD_SECS:
		trem = 1.0
	if trem > 0.0:
		# a 1px sine tremble on the glass itself (art-space, so the widget's
		# own scale keeps it at ~1px on screen)
		_sprite.position = Vector2(sin(_t * 26.0) * trem, sin(_t * 31.0) * trem * 0.6)
		# and the orbs warm and lift, without touching the sprite's colour
		var warm: float = 0.35 if _remaining <= PANIC_SECS else 0.2
		_motes.color = Color(MOTE_COLOR, 1.0).lerp(Color(1.0, 0.72, 0.42, 1.0), warm)
		_motes.color.a = 0.5 + warm * 0.5
	else:
		_sprite.position = Vector2.ZERO
		_motes.color = Color(MOTE_COLOR.r, MOTE_COLOR.g, MOTE_COLOR.b, 0.5)


## debug: rapid-cycle all sixteen. The frame, the vines and the eye must be
## rock-still with only the sand moving.
func toggle_cycle() -> void:
	_cycling = not _cycling
	if not _cycling:
		_apply_frame()
		_apply_label()
