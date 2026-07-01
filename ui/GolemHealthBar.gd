extends Control
class_name GolemHealthBar

## Self-contained, procedurally drawn boss health bar for the Crystal Golem.
## Lives in a HUD CanvasLayer, anchored top-right. Hidden until the first hit lands,
## then slides in from the right. Fades out when the boss dies. No image assets.

signal revealed
signal damaged(current: float, max: float)
signal died

@export var max_health: float = 300.0
@export var boss_name: String = "CRYSTAL GOLEM"
@export var bar_width: float = 240.0
@export var bar_height: float = 20.0
@export var slant: float = 7.0            # top edge shifted right by this many px

# ── palette ────────────────────────────────────────────────────────────────
const C_FILL0 := Color("7cf0ee")   # fill gradient top → bottom
const C_FILL1 := Color("3ad0ce")
const C_FILL2 := Color("2f9a99")
const C_FILL3 := Color("1f6a6b")
const C_TRACK := Color("08272a")
const C_EDGE_A := Color("7cf0ee")   # glow-edge gradient
const C_EDGE_B := Color("1f6a6b")
const C_TRAIL := Color("1e615f")   # recent-damage trail
const C_GLINT := Color("aefcfa")   # leading-edge glint
const C_GLOW := Color("4fd8d6")    # outer glow / shards
const C_LABEL := Color("b6f0ee")
const C_HP := Color("57a4a1")

const LABEL_H := 22.0
const MARGIN := 9.0                 # room around the bar for the outer glow

var _health: float
var _display_frac: float = 1.0      # fast-tweened visible fill
var _trail_frac: float = 1.0        # slow-draining damage trail
var _flash: float = 0.0             # white hit-flash alpha
var _sheen_t: float = 0.0
var _slide_px: float = 38.0         # reveal slide offset (px, tweened 38 → 0)
var _shake: Vector2 = Vector2.ZERO
var _shake_time: float = 0.0
var _shards: Array = []             # {pos, vel, life, maxlife, rot, spin}
var _revealed: bool = false
var _dead: bool = false
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_health = max_health
	custom_minimum_size = Vector2(bar_width + slant + MARGIN * 2.0,
		LABEL_H + bar_height + MARGIN * 2.0)
	modulate.a = 0.0
	visible = false
	set_process(true)


# ── public API ───────────────────────────────────────────────────────────—
func take_damage(amount: float) -> void:
	if _dead:
		return
	if not _revealed:
		_reveal()
	_health = clampf(_health - amount, 0.0, max_health)
	var frac: float = _health / max_health

	# Fill snaps down fast; the trail behind it drains slower after a short beat.
	create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC) \
		.tween_method(_set_display_frac, _display_frac, frac, 0.24)
	var tt := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tt.tween_interval(0.24)
	tt.tween_method(_set_trail_frac, _trail_frac, frac, 0.68)

	# White flash sweep, tiny shake, a spray of shards off the drained edge.
	_flash = 0.6
	create_tween().tween_method(_set_flash, 0.6, 0.0, 0.28)
	_shake_time = 0.14
	_spawn_shards(frac)

	damaged.emit(_health, max_health)
	if _health <= 0.0:
		_die()


func reset(new_max: float) -> void:
	# Re-arm the bar for a fresh target (e.g. a different golem) after a previous one died.
	max_health = new_max
	_health = new_max
	_display_frac = 1.0
	_trail_frac = 1.0
	_flash = 0.0
	_shards.clear()
	_dead = false
	_revealed = false
	visible = false
	modulate.a = 0.0
	queue_redraw()


func set_health(current: float) -> void:
	# Convenience: jump the bar to an absolute value (no reveal / fx).
	_health = clampf(current, 0.0, max_health)
	_display_frac = _health / max_health
	_trail_frac = _display_frac
	queue_redraw()


func _set_display_frac(v: float) -> void: _display_frac = v; queue_redraw()
func _set_trail_frac(v: float) -> void: _trail_frac = v; queue_redraw()
func _set_flash(v: float) -> void: _flash = v; queue_redraw()
func _set_slide(v: float) -> void: _slide_px = v; queue_redraw()


func _reveal() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
	_slide_px = 38.0
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 1.0, 0.38)
	tw.tween_method(_set_slide, 38.0, 0.0, 0.38)
	revealed.emit()


func _die() -> void:
	if _dead:
		return
	_dead = true
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: visible = false)
	died.emit()


func _spawn_shards(frac: float) -> void:
	var edge_x: float = MARGIN + slant * 0.5 + frac * bar_width
	var edge_y: float = MARGIN + LABEL_H + bar_height * 0.5
	for i in range(4):
		_shards.append({
			"pos": Vector2(edge_x, edge_y + randf_range(-bar_height * 0.4, bar_height * 0.4)),
			"vel": Vector2(randf_range(20.0, 80.0), randf_range(-55.0, 30.0)),
			"life": randf_range(0.35, 0.6), "maxlife": 0.6,
			"rot": randf() * TAU, "spin": randf_range(-8.0, 8.0),
		})


# ── per-frame ────────────────────────────────────────────────────────────—
func _process(delta: float) -> void:
	if not visible:
		return
	_sheen_t = fmod(_sheen_t + delta / 4.0, 1.0)   # sheen loop ~4s
	if _shake_time > 0.0:
		_shake_time -= delta
		var m: float = clampf(_shake_time / 0.14, 0.0, 1.0) * 2.0
		_shake = Vector2(randf_range(-m, m), randf_range(-m, m))
	else:
		_shake = Vector2.ZERO
	if not _shards.is_empty():
		for s in _shards:
			s["life"] -= delta
			s["vel"].y += 240.0 * delta
			s["pos"] += s["vel"] * delta
			s["rot"] += s["spin"] * delta
		_shards = _shards.filter(func(s): return s["life"] > 0.0)
	queue_redraw()


# ── drawing ──────────────────────────────────────────────────────────────—
func _grad(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t < 0.33: return C_FILL0.lerp(C_FILL1, t / 0.33)
	if t < 0.66: return C_FILL1.lerp(C_FILL2, (t - 0.33) / 0.33)
	return C_FILL2.lerp(C_FILL3, (t - 0.66) / 0.34)


# Parallelogram (fraction of full width) with the top edge slid right by `slant`.
func _para(f: float, ox: float, oy: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(ox + slant, oy),
		Vector2(ox + slant + f * bar_width, oy),
		Vector2(ox + f * bar_width, oy + bar_height),
		Vector2(ox, oy + bar_height)])


func _draw() -> void:
	draw_set_transform(Vector2(_slide_px, 0) + _shake, 0.0, Vector2.ONE)
	var ox := MARGIN
	var oy := MARGIN + LABEL_H

	# Soft outer glow (fake drop-shadow): a few expanding low-alpha passes.
	for i in range(4):
		var g: float = float(i + 1) * 1.8
		var gc := Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, 0.05)
		draw_colored_polygon(_expand(_para(1.0, ox, oy), g), gc)

	# Track background.
	draw_colored_polygon(_para(1.0, ox, oy), C_TRACK)

	# Recent-damage trail (drains slower, sits behind the fill).
	if _trail_frac > _display_frac:
		draw_colored_polygon(_para(_trail_frac, ox, oy), C_TRAIL)

	# Fill — vertical 4-stop gradient via horizontal strips (keeps the slant).
	_draw_fill(_display_frac, ox, oy)

	# Glow edge (1.5px gradient outline).
	_draw_edge(_para(1.0, ox, oy))

	# White hit-flash across the whole bar.
	if _flash > 0.0:
		draw_colored_polygon(_para(1.0, ox, oy), Color(1, 1, 1, _flash))

	# Crystal shards flung from the drained edge.
	for s in _shards:
		var a: float = clampf(s["life"] / s["maxlife"], 0.0, 1.0)
		_draw_shard(s["pos"], s["rot"], 3.0 * a + 1.0, Color(C_GLINT.r, C_GLINT.g, C_GLINT.b, a))

	# Labels above the bar.
	_draw_labels(ox, oy)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fill(f: float, ox: float, oy: float) -> void:
	if f <= 0.0:
		return
	var steps := 14
	for i in range(steps):
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var y0 := oy + bar_height * t0
		var y1 := oy + bar_height * t1
		var lx0 := ox + slant * (1.0 - t0)
		var lx1 := ox + slant * (1.0 - t1)
		var w := f * bar_width
		draw_colored_polygon(PackedVector2Array([
			Vector2(lx0, y0), Vector2(lx0 + w, y0),
			Vector2(lx1 + w, y1), Vector2(lx1, y1)]), _grad(t0))

	# Bright top-highlight line along the fill top.
	draw_line(Vector2(ox + slant, oy + 0.75), Vector2(ox + slant + f * bar_width, oy + 0.75),
		Color(1, 1, 1, 0.55), 1.5)

	# Sheen: a soft diagonal band sweeping across the fill.
	var sx: float = ox + slant + _sheen_t * (f * bar_width + 20.0) - 10.0
	var sc := Color(1, 1, 1, 0.10)
	if sx > ox and sx < ox + slant + f * bar_width:
		draw_line(Vector2(sx + slant, oy), Vector2(sx - slant, oy + bar_height), sc, 6.0)

	# Leading-edge glint (bright cyan + soft glow) at the fill's right edge.
	var etop := Vector2(ox + slant + f * bar_width, oy)
	var ebot := Vector2(ox + f * bar_width, oy + bar_height)
	draw_line(etop, ebot, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, 0.4), 6.0)
	draw_line(etop, ebot, C_GLINT, 2.5)


func _draw_edge(p: PackedVector2Array) -> void:
	# Top edge bright, bottom edge deep, sides interpolate.
	draw_line(p[0], p[1], C_EDGE_A, 1.5)
	draw_line(p[1], p[2], C_EDGE_A.lerp(C_EDGE_B, 0.5), 1.5)
	draw_line(p[2], p[3], C_EDGE_B, 1.5)
	draw_line(p[3], p[0], C_EDGE_B.lerp(C_EDGE_A, 0.5), 1.5)


func _draw_shard(pos: Vector2, rot: float, sz: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for a in [0.0, TAU * 0.25, TAU * 0.5, TAU * 0.75]:
		pts.append(pos + Vector2(cos(a + rot), sin(a + rot) * 1.7) * sz)
	draw_colored_polygon(pts, col)


func _draw_labels(ox: float, oy: float) -> void:
	var right: float = ox + slant + bar_width
	# Boss name, uppercase, right-aligned, with letter spacing + faint glow.
	var name := boss_name.to_upper()
	var name_size := 16
	var spacing := float(name_size) * 0.28
	var total := 0.0
	for ch in name:
		total += _font.get_char_size(ch.unicode_at(0), name_size).x + spacing
	var x := right - total
	var y := oy - 6.0
	# glow pass
	for off in [Vector2(0.8, 0), Vector2(-0.8, 0), Vector2(0, 0.8)]:
		_draw_spaced(name, x + off.x, y + off.y, name_size, spacing, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, 0.25))
	_draw_spaced(name, x, y, name_size, spacing, C_LABEL)
	# HP integer to the LEFT of the name.
	var hp := str(int(ceil(_health)))
	var hp_size := 13
	var hpw := _font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, hp_size).x
	draw_string(_font, Vector2(x - hpw - 8.0, y), hp, HORIZONTAL_ALIGNMENT_LEFT, -1, hp_size, C_HP)


func _draw_spaced(text: String, x: float, y: float, size: int, spacing: float, col: Color) -> void:
	var cx := x
	for ch in text:
		var code := ch.unicode_at(0)
		draw_char(_font, Vector2(cx, y), ch, size, col)
		cx += _font.get_char_size(code, size).x + spacing


# Expand a convex polygon outward from its centroid by `d` px (soft-glow passes).
func _expand(p: PackedVector2Array, d: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for v in p: c += v
	c /= p.size()
	var out := PackedVector2Array()
	for v in p:
		out.append(v + (v - c).normalized() * d)
	return out
