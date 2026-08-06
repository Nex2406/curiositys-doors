extends Control
class_name LanternHUD

## Her health, as her lantern. Replaces the red strip in Realm 2.
##
## Two reads, deliberately doubled up (Advika's spec):
##   OIL   — a fill inside the glass, linear in health. This is the PRECISE
##           read: you can measure it if you look.
##   FLAME — size, colour and stability. This is the FELT read: you know you
##           are in trouble before you have looked at anything.
##
## The flame always sits ON the oil surface, so as she bleeds the light sinks
## down inside its own glass. Below 8% it is all but out — catching for two or
## three frames at irregular intervals, never a rhythm.
##
## Drawn procedurally so the flame and the oil are independently drivable and
## nothing has to be re-exported to retune a colour.
##
## Nothing outside the silhouette but the glow. No numbers, no bar, no text.

# ---- form ----
@export var lantern_size := Vector2(84.0, 110.0)
@export var hud_margin := 22.0
## where it sits. Negative on either axis = fall back to hud_margin.
@export var hud_position := Vector2(-1, -1)

# ---- the word under it ----
## Set empty to draw nothing.
##
## EXACTLY the "Press Y to enter" voice — EB Garamond 20 in dim cream, and NO
## outline. `Door.gd` sets no font at all, so matching it would have meant
## Godot's default; the font the player actually reads is the override Realm 1
## puts on that prompt, which Advika picked off the tarot card. An outline was
## tried on that line once and was half of what read wrong.
@export var label_text := "Health"
const LABEL_FONT := "res://assets/fonts/eb_garamond.ttf"
const LABEL_SIZE := 20
const LABEL_COLOR := Color("EAE6DA", 0.55)
## the word is lit BY the lantern, so the halo is the flame's own warm cream,
## laid down as two soft passes rather than one hard ring
const LABEL_GLOW := Color(1.0, 0.86, 0.60)
@export_range(0.0, 1.0) var label_glow := 0.25

# ---- the lantern's own hue ----
## The brass is a lamp, not a brown shape with a fire inside it. This washes
## the whole object in its own warm light and tints the metal toward it.
@export var hue := Color(1.0, 0.72, 0.36)
@export_range(0.0, 1.0) var hue_strength := 0.55

# ---- levitation ----
## it hangs, so it drifts. Never enough to read as motion — just enough that it
## is not nailed to the corner like a stat box.
@export var bob_amplitude := 3.0
@export var bob_period := 3.6

## start invisible and wait to be told. Realm 2 only lights it once the island
## is up and the wizard has arrived — before that there is nothing to survive.
@export var start_hidden := false
## the four state edges, as fractions of full health
@export var t_full := 0.76
@export var t_high := 0.51
@export var t_mid := 0.26
@export var t_low := 0.09
## the precise read can be switched off and left to the flame alone
@export var show_oil := true

# ---- palette (spec) ----
const BRASS := Color("#8A6533")
const BRASS_LIT := Color("#D99A3F")
const BRASS_FLASH := Color("#FFE6B0")
const GLASS_IN := Color("#140E28")
const OIL := Color("#C98F4E")
const OIL_TOP := Color("#F2D69B")
const FLAME_A := Color("#F2C15A")   # 100-51%
const FLAME_CORE := Color("#FDF3DE")
const FLAME_B := Color("#E09A3E")   # 50-26%
const FLAME_C := Color("#C96A2A")   # 25-9%

var _health := 1.0        # where health actually is
var _oil := 1.0           # where the oil is drawn (tweened behind _health)
var _t := 0.0
var _flick := 1.0         # current flicker multiplier — the glow rides this
var _flare := 1.0         # heal flare — scales the whole flame
## damage knocks it FLAT, not small: vertical only, so the flame squats and
## stands back up rather than shrinking away and returning
var _compress := 1.0
var _brass_flash := 0.0
var _relight := 0.0       # the near-dead flame catching for a few frames
var _next_relight := 0.0
var _drops: Array = []    # [x, y, vy, life]
## the levitation, applied INSIDE _draw. Godot rounds a Control's position to
## whole pixels, so animating `position` would make it stair-step up and down;
## drawing at an offset keeps the drift subpixel-smooth.
var _bob := 0.0
var _label: Label = null
var _label_home := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	custom_minimum_size = lantern_size
	size = lantern_size
	if hud_position.x >= 0.0 and hud_position.y >= 0.0:
		position = hud_position
	else:
		position = Vector2(hud_margin, hud_margin)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if start_hidden:
		modulate.a = 0.0
	_build_label()
	set_process(true)


## The word under the foot.
##
## This is a Label with a theme font override — the SAME mechanism Realm 1's
## "Press Y to enter" uses, which is known to render correctly in this project.
## It was `draw_string` before and every glyph came out as a filled block; the
## font was never at fault (a headless probe confirmed EB Garamond hands back
## real glyphs and a 54x27 measurement for "Health").
func _build_label() -> void:
	if label_text == "":
		return
	_label = Label.new()
	_label.text = label_text
	_label.add_theme_font_override("font", load(LABEL_FONT))
	_label.add_theme_font_size_override("font_size", LABEL_SIZE)
	_label.add_theme_color_override("font_color", LABEL_COLOR)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# wider than the lantern and centred on it, so a longer word still centres
	_label.size = Vector2(lantern_size.x + 80.0, 28.0)
	_label_home = Vector2(-40.0, lantern_size.y * 0.945 + 8.0)
	_label.position = _label_home
	add_child(_label)


## light it. Realm 2 calls this the moment the wizard arrives.
func appear(dur := 1.4) -> void:
	if modulate.a > 0.99:
		return
	create_tween().tween_property(self, "modulate:a", 1.0, dur)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## the one entry point — everything else follows from it
func set_health(cur: int, maximum: int) -> void:
	var target: float = clampf(float(cur) / maxf(float(maximum), 1.0), 0.0, 1.0)
	var healing: bool = target > _health
	_health = target
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# healing pours in slower than damage drains out
	tw.tween_method(func(v: float) -> void: _oil = v, _oil, target,
			0.5 if healing else 0.35)
	if healing:
		_pour()
		_flare = 1.3
		var ft := create_tween()
		ft.tween_interval(0.25)
		ft.tween_method(func(v: float) -> void: _flare = v, 1.3, 1.0, 0.18)
	else:
		# the flame is knocked flat, then stands back up — VERTICAL only
		_compress = 0.75
		var ft := create_tween()
		ft.tween_interval(0.12)
		ft.tween_method(func(v: float) -> void: _compress = v, 0.75, 1.0, 0.10)
		_brass_flash = 1.0
		var bt := create_tween()
		bt.tween_interval(0.08)
		bt.tween_method(func(v: float) -> void: _brass_flash = v, 1.0, 0.0, 0.06)


## 6-8 droplets tipped in over the cap, staggered
func _pour() -> void:
	var n: int = _rng.randi_range(6, 8)
	for i in n:
		_drops.append([_rng.randf_range(-9.0, 9.0), -18.0 - float(i) * 7.0,
				0.0, -float(i) * 0.07])


func _band() -> int:
	if _health >= t_full:
		return 0
	if _health >= t_high:
		return 1
	if _health >= t_mid:
		return 2
	if _health >= t_low:
		return 3
	return 4


func _process(delta: float) -> void:
	_t += delta
	var band := _band()
	match band:
		0:
			# steady, a gentle 2s breathe
			_flick = 1.0 + sin(_t * PI) * 0.05
		1:
			_flick = 1.0 + sin(_t * PI * 1.45) * 0.06
		2:
			# visible flicker — small random jitter, not a clean wave
			_flick = 0.88 + _rng.randf() * 0.18
		3:
			# heavy flicker: opacity swinging on noise between 0.55 and 0.85
			_flick = _rng.randf_range(0.55, 0.85)
		4:
			# almost out. It sits near zero and CATCHES for 2-3 frames at
			# irregular intervals — a timer, never a rhythm.
			_relight = maxf(0.0, _relight - delta)
			_next_relight -= delta
			if _next_relight <= 0.0:
				_next_relight = _rng.randf_range(0.45, 1.6)
				_relight = _rng.randf_range(0.033, 0.05)   # 2-3 frames
			_flick = 0.9 if _relight > 0.0 else _rng.randf_range(0.02, 0.09)

	if bob_period > 0.0:
		_bob = sin(_t * TAU / bob_period) * bob_amplitude
	if _label != null:
		# the word hangs with the lantern
		_label.position = _label_home + Vector2(0.0, _bob)
		# and is lit by it: the cream warms and lifts as the flame breathes
		var lg: float = clampf(0.45 + _flick * 0.55, 0.0, 1.0)
		_label.add_theme_color_override("font_color",
				LABEL_COLOR.lerp(LABEL_GLOW, label_glow * lg))
	for d in _drops:
		d[3] += delta
		if d[3] > 0.0:
			d[2] += 520.0 * delta
			d[1] += d[2] * delta
	_drops = _drops.filter(func(d: Array) -> bool: return d[3] < 0.75)
	queue_redraw()


# ---------- geometry ----------

## 60x68 inside an 84x110 body — held as RATIOS, not pixels. As pixels the
## glass stayed one size while the body grew, so every extra pixel of height
## fell through to the base and the foot became a plinth.
const GLASS_W_R := 60.0 / 84.0
const GLASS_H_R := 0.645
const GLASS_TOP_R := 0.235
## how much of the glass the oil occupies at FULL health — the remainder is
## the air the flame stands up in
const OIL_MAX_R := 0.58


func _glass_rect() -> Rect2:
	var w: float = lantern_size.x
	var h: float = lantern_size.y
	return Rect2(w * (1.0 - GLASS_W_R) * 0.5, h * GLASS_TOP_R,
			w * GLASS_W_R, h * GLASS_H_R)


func _draw() -> void:
	# everything below rides the levitation
	draw_set_transform(Vector2(0.0, _bob))
	var w: float = lantern_size.x
	var h: float = lantern_size.y
	var glass := _glass_rect()
	# the metal carries the hue too, so it reads as lit rather than painted
	var brass: Color = BRASS.lerp(hue, hue_strength * 0.22)\
			.lerp(BRASS_FLASH, _brass_flash)
	var lit: Color = BRASS_LIT.lerp(hue, hue_strength * 0.30)\
			.lerp(BRASS_FLASH, _brass_flash)

	# ---- the hue: a broad warm wash over the WHOLE object, drawn first so it
	# sits behind the brass. Wider and fainter than the flame's own glow, and
	# it dims as she does, so a dying lantern stops colouring its surroundings.
	if hue_strength > 0.0:
		var hc := Vector2(w * 0.5, h * 0.55)
		var hr: float = maxf(w, h) * 0.80
		var ha: float = hue_strength * (0.30 + 0.70 * _health) \
				* clampf(_flick, 0.35, 1.0)
		for i in 7:
			var hk: float = 1.0 - float(i) / 7.0
			draw_circle(hc, hr * (0.45 + 0.55 * (1.0 - hk)),
					Color(hue.r, hue.g, hue.b, ha * hk * 0.085))

	# ---- glow, behind everything (the only thing outside the silhouette) ----
	var r: float = lerpf(16.0, 50.0, _health)
	var ga: float = clampf(_health * _flick, 0.0, 1.0) * 0.5
	var gc := Vector2(w * 0.5, glass.position.y + glass.size.y * 0.62)
	for i in 9:
		var k: float = 1.0 - float(i) / 9.0
		draw_circle(gc, r * (0.35 + 0.65 * (1.0 - k)),
				Color(FLAME_A.r, FLAME_A.g, FLAME_A.b, ga * k * 0.18))

	# ---- hook + hanging arms ----
	draw_arc(Vector2(w * 0.5, h * 0.075), 7.5, PI * 0.15, PI * 0.85, 14,
			brass, 3.0)
	draw_line(Vector2(w * 0.5 - 7.0, h * 0.085),
			Vector2(glass.position.x + 3.0, h * 0.20), brass, 2.5)
	draw_line(Vector2(w * 0.5 + 7.0, h * 0.085),
			Vector2(glass.end.x - 3.0, h * 0.20), brass, 2.5)

	# ---- flared cap ----
	draw_colored_polygon(PackedVector2Array([
			Vector2(glass.position.x + 4.0, h * 0.185),
			Vector2(glass.end.x - 4.0, h * 0.185),
			Vector2(glass.end.x + 6.0, glass.position.y),
			Vector2(glass.position.x - 6.0, glass.position.y)]), brass)

	# ---- glass interior ----
	draw_rect(glass, Color(GLASS_IN.r, GLASS_IN.g, GLASS_IN.b, 0.9), true)

	# ---- oil ----
	var oil_y: float = glass.end.y
	if show_oil:
		# THE OIL MAY NEVER FILL THE GLASS. At full health it did, which left
		# the flame zero headroom to stand in — so the one state that should
		# burn brightest was the one state with no flame drawn at all. Full is
		# a bit over half the glass; the rest is the flame's air.
		var fill_h: float = glass.size.y * OIL_MAX_R * clampf(_oil, 0.0, 1.0)
		oil_y = glass.end.y - fill_h
		if fill_h > 0.5:
			draw_rect(Rect2(glass.position.x, oil_y, glass.size.x, fill_h),
					Color(OIL.r, OIL.g, OIL.b, 0.55), true)
			draw_line(Vector2(glass.position.x, oil_y),
					Vector2(glass.end.x, oil_y), OIL_TOP, 1.5)
	else:
		oil_y = glass.position.y + glass.size.y * 0.35

	# ---- the falling droplets, while a pour is in flight ----
	for d in _drops:
		if d[3] < 0.0:
			continue
		var dy: float = glass.position.y + d[1] + 18.0
		if dy > oil_y:
			continue
		draw_circle(Vector2(w * 0.5 + d[0], dy), 2.0,
				Color(OIL_TOP.r, OIL_TOP.g, OIL_TOP.b, 0.9))

	# ---- flame, standing on the oil ----
	_draw_flame(Vector2(w * 0.5, oil_y - 1.0), glass)

	# ---- two vertical brass bars over the glass ----
	var bx: float = glass.size.x / 3.0
	for i in 2:
		draw_rect(Rect2(glass.position.x + bx * float(i + 1) - 1.5,
				glass.position.y, 3.0, glass.size.y), brass, true)

	# ---- glass frame highlight ----
	draw_rect(glass, lit, false, 2.0)

	# ---- flared base: a short foot, not a plinth ----
	var base_bot: float = h * 0.945
	var flare: float = w * 0.095
	draw_colored_polygon(PackedVector2Array([
			Vector2(glass.position.x - w * 0.024, glass.end.y),
			Vector2(glass.end.x + w * 0.024, glass.end.y),
			Vector2(glass.end.x + flare, base_bot),
			Vector2(glass.position.x - flare, base_bot)]), brass)

	# The word under the foot is a real Label — see _build_label(). draw_string
	# rendered every glyph as a filled block here, and no amount of retuning the
	# glow fixed that, because the glow was never what was wrong.


func _draw_flame(foot: Vector2, glass: Rect2) -> void:
	var band := _band()
	var sizes := [1.0, 0.8, 0.6, 0.4, 0.12]
	var cols := [FLAME_A, FLAME_A, FLAME_B, FLAME_C, FLAME_C]
	var core_a := [1.0, 1.0, 0.6, 0.12, 0.0]
	var s: float = sizes[band] * _flare
	var col: Color = cols[band]
	var alpha: float = clampf(_flick, 0.0, 1.0)
	if band < 2:
		alpha = 1.0
	# a teardrop: wide foot, drawn-out tip, kept inside the glass
	var fh: float = minf(34.0 * s * _compress * (0.85 + _flick * 0.15),
			foot.y - glass.position.y - 3.0)
	if fh <= 1.0:
		return
	var fw: float = 9.0 * s
	var jitter: float = 0.0 if band < 2 else _rng.randf_range(-1.2, 1.2) * s
	draw_colored_polygon(PackedVector2Array([
			Vector2(foot.x - fw, foot.y),
			Vector2(foot.x - fw * 0.72, foot.y - fh * 0.45),
			Vector2(foot.x + jitter, foot.y - fh),
			Vector2(foot.x + fw * 0.72, foot.y - fh * 0.45),
			Vector2(foot.x + fw, foot.y)]),
			Color(col.r, col.g, col.b, alpha))
	var ca: float = core_a[band] * alpha
	if ca > 0.01:
		draw_colored_polygon(PackedVector2Array([
				Vector2(foot.x - fw * 0.42, foot.y),
				Vector2(foot.x + jitter * 0.5, foot.y - fh * 0.62),
				Vector2(foot.x + fw * 0.42, foot.y)]),
				Color(FLAME_CORE.r, FLAME_CORE.g, FLAME_CORE.b, ca))
