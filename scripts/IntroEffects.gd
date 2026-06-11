extends Node2D

# Per-background ambient effects for the intro montage. Each of the six painted
# backgrounds gets its own effect group (particles + soft additive "hero" glow
# sprites) tailored to its content.
#
# PERFORMANCE CONTRACT: only ONE group is ever live at a time. Inactive groups
# are hidden, process-disabled, and their emitters switched off, so the browser
# only ever simulates the active background's effects (plus, briefly, the
# outgoing one during a ~FADE cross-fade). Never all six at once.
#
# Effects layer ABOVE the background image (separate CanvasLayer at -10) and
# BELOW the dialogue box (CanvasLayer 1): this node lives at the root canvas
# (layer 0). Glow positions are authored in NORMALISED frame coords via _n().

const FADE: float = 1.2          # matches Intro.gd cross-fade
const KIND_PULSE: int = 0        # smooth sine breathing
const KIND_FLICKER: int = 1      # irregular candle / lantern flicker

var _groups: Array[Node2D] = []
var _glows: Array = []           # per-group Array of glow descriptors
var _active: int = -1
var _t: float = 0.0

var _halo: Texture2D
var _firefly: Texture2D
var _add_mat: CanvasItemMaterial


func _ready() -> void:
	_halo = load("res://assets/effects/lantern_halo.png")
	_firefly = load("res://assets/effects/firefly.png")
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	for i in 6:
		var grp := Node2D.new()
		grp.name = "Fx%d" % i
		add_child(grp)
		_groups.append(grp)
		_glows.append([])

	_build_cauldron(0)
	_build_grimoire(1)
	_build_shelves6(2)
	_build_shelves2(3)
	_build_shelves1(4)
	_build_tent(5)

	# Everything starts cold; Intro.gd calls set_active(0) once it's wired up.
	for grp in _groups:
		grp.modulate.a = 0.0
		grp.visible = false
		grp.process_mode = Node.PROCESS_MODE_DISABLED


# --- Activation -------------------------------------------------------------

# Make only `idx` live; cross-fade the previously active group out.
func set_active(idx: int) -> void:
	if idx == _active or idx < 0 or idx >= _groups.size():
		return
	if _active >= 0:
		_deactivate(_active)
	_activate(idx)
	_active = idx
	_t = 0.0


# Pause whatever group is live without bringing another up (used by the
# Shelves 6 dive so its mist stops the moment the camera flies into the glass).
func deactivate_current() -> void:
	if _active >= 0:
		_deactivate(_active)
		_active = -1


func _activate(i: int) -> void:
	var g: Node2D = _groups[i]
	g.visible = true
	g.process_mode = Node.PROCESS_MODE_INHERIT
	for child in g.get_children():
		if child is CPUParticles2D:
			child.restart()
			child.emitting = true
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", 1.0, FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _deactivate(i: int) -> void:
	var g: Node2D = _groups[i]
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", 0.0, FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		g.visible = false
		g.process_mode = Node.PROCESS_MODE_DISABLED
		for child in g.get_children():
			if child is CPUParticles2D:
				child.emitting = false)


func _process(delta: float) -> void:
	if _active < 0:
		return
	_t += delta
	for gd in _glows[_active]:
		var s: Sprite2D = gd.node
		var f: float
		if gd.kind == KIND_FLICKER:
			# Sum of incommensurate sines reads as irregular flame flicker.
			f = 0.5 + 0.30 * sin(_t * gd.speed) \
				+ 0.18 * sin(_t * gd.speed * 2.3 + 1.7) \
				+ 0.08 * sin(_t * gd.speed * 5.1)
			f = clampf(f, 0.0, 1.0)
		else:
			f = 0.5 + 0.5 * sin(_t * gd.speed)
		s.modulate.a = lerpf(gd.amin, gd.amax, f)
		s.scale = gd.bscale * (1.0 + gd.samt * (f - 0.5) * 2.0)


# --- Builders ---------------------------------------------------------------

func _n(x: float, y: float) -> Vector2:
	return Vector2(x * 1920.0, y * 1080.0)


# Soft additive radial glow. `scl` is the sprite scale (halo texture is 256px),
# `kind` pulse or flicker, `amin`/`amax` the alpha sweep, `samt` scale breathing.
func _glow(gi: int, pos: Vector2, tint: Color, scl: Vector2, kind: int,
		speed: float, amin: float, amax: float, samt: float = 0.05,
		rot: float = 0.0) -> void:
	var s := Sprite2D.new()
	s.texture = _halo
	s.position = pos
	s.scale = scl
	s.rotation = rot
	s.material = _add_mat
	s.modulate = Color(tint.r, tint.g, tint.b, amax)
	_groups[gi].add_child(s)
	_glows[gi].append({
		"node": s, "kind": kind, "speed": speed,
		"amin": amin, "amax": amax, "bscale": scl, "samt": samt,
	})


# Alpha-in / hold / alpha-out gradient so particles fade rather than pop.
func _ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0),
		Color(c.r, c.g, c.b, c.a),
		Color(c.r, c.g, c.b, c.a),
		Color(c.r, c.g, c.b, 0.0),
	])
	return g


func _particles(gi: int, pos: Vector2, cfg: Dictionary) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = cfg.amount
	p.lifetime = cfg.lifetime
	p.lifetime_randomness = cfg.get("life_rand", 0.4)
	p.preprocess = float(cfg.lifetime) * 0.7
	p.texture = _halo if cfg.tex == "halo" else _firefly
	p.emitting = false
	if cfg.has("rect"):
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = cfg.rect
	p.direction = cfg.dir
	p.spread = cfg.spread
	p.gravity = cfg.grav
	p.initial_velocity_min = cfg.vmin
	p.initial_velocity_max = cfg.vmax
	p.scale_amount_min = cfg.smin
	p.scale_amount_max = cfg.smax
	var ang: float = cfg.get("angmax", 0.0)
	if ang != 0.0:
		p.angular_velocity_min = -ang
		p.angular_velocity_max = ang
	# Optional churn: orbit (swirl around emission centre), tangential/radial
	# acceleration (curl), and damping (settle) for living, billowing mist.
	var orbit: float = cfg.get("orbit", 0.0)
	if orbit != 0.0:
		p.orbit_velocity_min = orbit * 0.4
		p.orbit_velocity_max = orbit
	var tang: float = cfg.get("tang", 0.0)
	if tang != 0.0:
		p.tangential_accel_min = -tang
		p.tangential_accel_max = tang
	var radial: float = cfg.get("radial", 0.0)
	if radial != 0.0:
		p.radial_accel_min = radial
		p.radial_accel_max = radial * 0.4
	var damping: float = cfg.get("damping", 0.0)
	if damping != 0.0:
		p.damping_min = 0.0
		p.damping_max = damping
	p.color = Color(1, 1, 1, 1)
	p.color_ramp = _ramp(cfg.color)
	if cfg.get("add", false):
		p.material = _add_mat
	_groups[gi].add_child(p)


# 1 — CAULDRON 2: misty forest brew. Low rolling ground fog, rising white-teal
# smoke, ground smoke-ring shimmer, warm cauldron-emblem glow, drifting embers.
func _build_cauldron(gi: int) -> void:
	# Churning ground mist pooled around the cauldron base (y ~0.58-0.80): large
	# soft white-teal puffs that orbit/curl AND drift sideways, fading in and out
	# over their lifetime so the cloud constantly reshapes — living steam, not a
	# frozen bank. This is the focal effect. Added first (behind smoke/glow).
	_particles(gi, _n(0.46, 0.7), {
		"amount": 16, "lifetime": 9.0, "tex": "halo",
		"rect": Vector2(900, 240), "dir": Vector2(1, 0), "spread": 22.0,
		"grav": Vector2(0, -2), "vmin": 6.0, "vmax": 16.0,
		"smin": 1.6, "smax": 3.0, "color": Color(0.78, 0.93, 0.92, 0.1),
		"life_rand": 0.5, "orbit": 0.09, "tang": 9.0, "radial": -3.0,
		"damping": 4.0,
	})
	# Faint higher wisp, a touch faster with a slight curl, for depth.
	_particles(gi, _n(0.5, 0.58), {
		"amount": 10, "lifetime": 13.0, "tex": "halo",
		"rect": Vector2(1100, 150), "dir": Vector2(1, 0), "spread": 10.0,
		"grav": Vector2(0, -1), "vmin": 12.0, "vmax": 24.0,
		"smin": 1.4, "smax": 2.6, "color": Color(0.8, 0.94, 0.93, 0.05),
		"life_rand": 0.5, "tang": 4.0,
	})
	_particles(gi, _n(0.42, 0.45), {
		"amount": 16, "lifetime": 5.0, "tex": "halo",
		"dir": Vector2(0, -1), "spread": 14.0, "grav": Vector2(0, -6),
		"vmin": 8.0, "vmax": 20.0, "smin": 0.5, "smax": 1.1,
		"color": Color(0.75, 0.92, 0.92, 0.16), "angmax": 8.0,
	})
	_particles(gi, _n(0.42, 0.6), {
		"amount": 8, "lifetime": 3.5, "tex": "firefly",
		"dir": Vector2(0, -1), "spread": 25.0, "grav": Vector2(0, -10),
		"vmin": 12.0, "vmax": 28.0, "smin": 0.3, "smax": 0.7,
		"color": Color(1.0, 0.6, 0.25, 0.9), "add": true,
	})
	# Ground smoke-ring: a wide, flat, slow teal shimmer.
	_glow(gi, _n(0.42, 0.66), Color(0.5, 0.95, 0.85), Vector2(3.0, 1.1),
		KIND_PULSE, 0.8, 0.18, 0.45)
	# Hero glow — warm orange on the cauldron emblem.
	_glow(gi, _n(0.42, 0.58), Color(1.0, 0.55, 0.2), Vector2(1.6, 1.6),
		KIND_PULSE, 0.7, 0.35, 0.7, 0.06)


# 2 — GRIMOIRE 1: open spellbook. Drifting dust catching light, red gem hero
# glow + softer cluster glow, warm candlelight flicker over the page.
func _build_grimoire(gi: int) -> void:
	_particles(gi, _n(0.5, 0.5), {
		"amount": 18, "lifetime": 7.0, "tex": "firefly",
		"rect": Vector2(900, 500), "dir": Vector2(0, -1), "spread": 60.0,
		"grav": Vector2(0, 2), "vmin": 3.0, "vmax": 9.0,
		"smin": 0.25, "smax": 0.6, "color": Color(1.0, 0.93, 0.75, 0.5),
		"add": true, "angmax": 10.0,
	})
	# A scattered constellation of gem/orb glows — each its own brightness and
	# pulse rate so no two twinkle in sync.
	_glow(gi, _n(0.42, 0.65), Color(1.0, 0.18, 0.15), Vector2(1.0, 1.0),
		KIND_PULSE, 1.1, 0.45, 0.95, 0.1)     # red gem — brightest, strong
	_glow(gi, _n(0.37, 0.32), Color(0.5, 0.95, 0.6), Vector2(0.9, 0.9),
		KIND_PULSE, 0.7, 0.3, 0.6)            # green goblet — medium, cooler
	_glow(gi, _n(0.18, 0.46), Color(0.4, 0.9, 0.95), Vector2(0.85, 0.85),
		KIND_PULSE, 0.45, 0.15, 0.4)          # teal orb left — faint, slow
	_glow(gi, _n(0.4, 0.44), Color(0.95, 0.97, 1.0), Vector2(0.8, 0.8),
		KIND_PULSE, 0.6, 0.2, 0.5)            # pale orbs centre — soft white
	_glow(gi, _n(0.62, 0.42), Color(0.55, 0.92, 0.55), Vector2(0.85, 0.85),
		KIND_PULSE, 0.85, 0.28, 0.58)         # green orb right — medium
	_glow(gi, _n(0.66, 0.66), Color(0.45, 0.6, 1.0), Vector2(0.8, 0.8),
		KIND_PULSE, 0.4, 0.15, 0.4)           # blue vial — faint, slow
	_glow(gi, _n(0.3, 0.4), Color(1.0, 0.75, 0.35), Vector2(0.55, 0.55),
		KIND_FLICKER, 5.0, 0.2, 0.5)          # amber accent — low, quick flicker
	_glow(gi, _n(0.72, 0.4), Color(1.0, 0.78, 0.4), Vector2(0.55, 0.55),
		KIND_FLICKER, 6.0, 0.2, 0.5)          # amber accent — low, quick flicker


# 3 — SHELVES 6: foggy teal alchemy bottles. Rolling fog is the star, faint
# rising bubbles, broad teal glow pulse over the bottles.
func _build_shelves6(gi: int) -> void:
	_particles(gi, _n(0.5, 0.55), {
		"amount": 14, "lifetime": 11.0, "tex": "halo",
		"rect": Vector2(1100, 400), "dir": Vector2(1, 0), "spread": 20.0,
		"grav": Vector2(0, -1), "vmin": 6.0, "vmax": 16.0,
		"smin": 1.6, "smax": 3.0, "color": Color(0.6, 0.85, 0.85, 0.1),
		"angmax": 4.0, "life_rand": 0.5,
	})
	_particles(gi, _n(0.5, 0.7), {
		"amount": 10, "lifetime": 4.0, "tex": "firefly",
		"dir": Vector2(0, -1), "spread": 18.0, "grav": Vector2(0, -12),
		"vmin": 10.0, "vmax": 22.0, "smin": 0.25, "smax": 0.55,
		"color": Color(0.7, 0.95, 0.95, 0.8), "add": true,
	})
	# Broad teal glow over the bottles (position-agnostic, centre frame).
	_glow(gi, _n(0.5, 0.5), Color(0.3, 0.85, 0.8), Vector2(4.5, 3.2),
		KIND_PULSE, 0.5, 0.12, 0.28)


# 4 — SHELVES 2: pink crystal shop. Hero glow on the big crystal, sparkle motes
# drifting up, a faint diagonal light ray from the upper area.
func _build_shelves2(gi: int) -> void:
	# Hero glow — soft pink-white on the big crystal, slow breathing.
	_glow(gi, _n(0.78, 0.4), Color(1.0, 0.7, 0.85), Vector2(1.8, 1.8),
		KIND_PULSE, 0.55, 0.35, 0.72, 0.08)
	_particles(gi, _n(0.7, 0.5), {
		"amount": 16, "lifetime": 6.0, "tex": "firefly",
		"rect": Vector2(700, 500), "dir": Vector2(0, -1), "spread": 40.0,
		"grav": Vector2(0, -3), "vmin": 4.0, "vmax": 12.0,
		"smin": 0.2, "smax": 0.55, "color": Color(1.0, 0.8, 0.9, 0.9),
		"add": true,
	})
	# Faint diagonal light ray from the upper area.
	_glow(gi, _n(0.7, 0.28), Color(1.0, 0.85, 0.92), Vector2(0.7, 3.4),
		KIND_PULSE, 0.4, 0.1, 0.22, 0.04, deg_to_rad(-35.0))


# 5 — SHELVES 1: purple crystal shop. Lavender hero glow on the teardrop
# crystal, slow misty centre cloud, purple sparkle motes.
func _build_shelves1(gi: int) -> void:
	# Hero glow — lavender on the big teardrop crystal.
	_glow(gi, _n(0.8, 0.2), Color(0.75, 0.6, 1.0), Vector2(1.7, 1.7),
		KIND_PULSE, 0.5, 0.35, 0.72, 0.08)
	# Misty centre cloud: slow billowing drift.
	_particles(gi, _n(0.45, 0.55), {
		"amount": 10, "lifetime": 8.0, "tex": "halo",
		"dir": Vector2(0, -1), "spread": 35.0, "grav": Vector2(0, -2),
		"vmin": 3.0, "vmax": 9.0, "smin": 1.4, "smax": 2.6,
		"color": Color(0.7, 0.6, 0.9, 0.12), "life_rand": 0.5,
	})
	_particles(gi, _n(0.45, 0.5), {
		"amount": 14, "lifetime": 6.0, "tex": "firefly",
		"rect": Vector2(600, 500), "dir": Vector2(0, -1), "spread": 45.0,
		"grav": Vector2(0, -3), "vmin": 4.0, "vmax": 11.0,
		"smin": 0.2, "smax": 0.5, "color": Color(0.8, 0.6, 1.0, 0.9),
		"add": true,
	})


# 6 — TENT 3: warm lamplit tent. Lantern flicker + hero glow on the brightest
# lamp, lazy incense wisp rising, warm dust motes in the lamplight.
func _build_tent(gi: int) -> void:
	# Hanging bulb (top) — small blue-white, gentle irregular flicker.
	_glow(gi, _n(0.32, 0.13), Color(0.7, 0.85, 1.0), Vector2(1.0, 1.0),
		KIND_FLICKER, 3.0, 0.3, 0.6)
	# Main lantern on the table — brightest, slow irregular warm-gold flicker.
	_glow(gi, _n(0.38, 0.42), Color(1.0, 0.72, 0.35), Vector2(2.0, 2.0),
		KIND_FLICKER, 4.0, 0.45, 0.85, 0.05)
	# Faint object glows, each a little different.
	_glow(gi, _n(0.16, 0.5), Color(1.0, 0.3, 0.2), Vector2(1.1, 1.1),
		KIND_PULSE, 0.5, 0.12, 0.32)          # red glowing panel left
	_glow(gi, _n(0.27, 0.5), Color(1.0, 0.8, 0.4), Vector2(1.0, 1.0),
		KIND_PULSE, 0.45, 0.12, 0.3)          # ornate gold panel
	_glow(gi, _n(0.45, 0.58), Color(1.0, 0.78, 0.5), Vector2(0.7, 0.7),
		KIND_PULSE, 0.7, 0.1, 0.28)           # small trinkets on the table
	# Faint warm haze drifting slowly through the mid-tent (cozy smoke).
	_particles(gi, _n(0.4, 0.42), {
		"amount": 8, "lifetime": 10.0, "tex": "halo",
		"rect": Vector2(700, 220), "dir": Vector2(1, 0), "spread": 15.0,
		"grav": Vector2(0, -1), "vmin": 4.0, "vmax": 12.0,
		"smin": 1.2, "smax": 2.2, "color": Color(1.0, 0.85, 0.6, 0.06),
		"life_rand": 0.5, "tang": 4.0,
	})
	# Lazy incense smoke wisp, slight sway.
	_particles(gi, _n(0.5, 0.62), {
		"amount": 10, "lifetime": 6.0, "tex": "halo",
		"dir": Vector2(0, -1), "spread": 10.0, "grav": Vector2(0, -7),
		"vmin": 6.0, "vmax": 14.0, "smin": 0.4, "smax": 0.9,
		"color": Color(0.95, 0.9, 0.8, 0.14), "angmax": 8.0,
	})
	# Warm dust motes in the lamplight.
	_particles(gi, _n(0.5, 0.5), {
		"amount": 14, "lifetime": 7.0, "tex": "firefly",
		"rect": Vector2(800, 500), "dir": Vector2(0, -1), "spread": 50.0,
		"grav": Vector2(0, 1), "vmin": 3.0, "vmax": 8.0,
		"smin": 0.25, "smax": 0.55, "color": Color(1.0, 0.85, 0.55, 0.55),
		"add": true,
	})
