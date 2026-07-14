extends Node2D
## R2-M1 — THE QUAKE + LIFTOFF, playable grey-box on the living background.
## Flat mossy ground → walk right onto the half-buried chunk → the storm
## builds (wind, shake, dark sky) → the ground TEARS → the chunk rises with
## Curiosity aboard — and KEEPS rising: the climb is boss-gated (Advika,
## 2026-07-08), it only ends when the wizard falls (R2-M7 calls
## stop_levitation()). The corridor dressing recycles seamlessly forever.
## Controls: Curiosity's own (move/jump/dash). R restarts. ESC returns to
## the Hub (works headless/editor too — the Hub is just another scene).
## Reached in-game via the Hub's middle door (Door2 → "realm_2"). The arrival
## has no timer: the player sits above the canopy as long as they like and
## leaves via ESC (on-screen label) until the wizard + sky door land (R2-M7+).
## The wizard himself already APPEARS: ~2.5s into the airborne climb he
## flickers into existence beside the island and rides along, watching.
## R2_SHOT env: screenshot at 1s + quit. R2_SHOT_LIFT: jump to mid-ascent first.

const BASE := "res://assets/realms/realm2_moss/"
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const WIZARD_SCENE := preload("res://scenes/Wizard.tscn")
const STARTING_LIVES: int = 3  # same rules as Realm 1
const HUB_SCENE := "res://scenes/Hub.tscn"
const FLOOR_Y := 300.0
const CHUNK_X := 1500.0
const CHUNK_START_Y := 420.0
const LIFT_TOP_Y := -2400.0
# embedded island tint — the chunk art is intrinsically ~3x brighter than the
# ground strips, so the camo sits proportionally darker to land on the same
# rendered brightness
const CAMO_TINT := Color(0.26, 0.245, 0.34)
const WAKE_TIME := 7.0  # seconds to blossom to full color during the rise

# The storm's author shows himself: once the island has been AIRBORNE this
# long (RISING state, not the pre-tear shake), the wizard flickers into
# existence ON the island — planted at its far end, facing Curiosity across
# the moss (Advika, 2026-07-12: on the platform, not hovering beside it) —
# and begins his TRIAL: teleporting across the island, conjuring rune orbs
# (max 2, born in front of him) that harry Curiosity toward the edges.
# Strike him (J/Z, five blows — catch him mid-appear/cast, he escape-teleports
# when you close in) and the island finally stops: died -> stop_levitation()
# -> arrived -> DONE. The boss gate, closed at last.
const WIZARD_APPEAR_DELAY := 7.0  # Advika 2026-07-12: a good 7s alone with the climb first
# Feet on the moss top: collider top is -120 rel chunk; the figure's feet sit
# ~134px below the 512-frame center, so origin rides 134*scale above the top.
const WIZARD_OFFSET := Vector2(255.0, -194.0)  # open moss, clear of the right hedge's dark mass
const WIZARD_SCALE := 0.55                     # Curiosity is ~110px here; he reads taller
const WIZARD_TRIAL_HALF_X := 470.0             # teleport span: inside the hedges' dark masses

# The trial's difficulty (Advika, second pass: "this level isnt hard"):
# orbs are fast, twitchy, long-lived and shove HARD; the deck is rarely
# quiet. Orb scale tracks the smaller hero here (0.24 vs the test's 0.28).
const ORB_SCALE := 0.48  # settled up from 0.44 (Advika: a bit bigger again)
const ORB_ROLL_SPEED := 280.0  # harder to evade (Advika) — outruns her walk; dash/jump to escape
const ORB_REVERSE_MIN := 1.4   # was 0.8-1.8: with rolling inertia, reversals breathe
const ORB_REVERSE_MAX := 2.8
const ORB_PUSH_FORCE := 540.0
const ORB_PUSH_COOLDOWN := 0.3 # shoves chain a beat quicker
const ORB_SEEK_BIAS := 0.7     # most whim-reversals turn TOWARD her — standing still isn't safe
const ORB_LEAVE_MIN := 8.0    # they overstay — the deck stays saturated
const ORB_LEAVE_MAX := 14.0
const JUMP_BOOST := 1.15   # this level jumps slightly higher — orbs must be clearable

# The wizard fights dirtier here: quicker cast cadence, wider escape sense,
# a slimmer grace beat — and the storm itself sharpens when he takes the deck.
const WIZ_IDLE_MIN := 1.5
const WIZ_IDLE_MAX := 2.5
const WIZ_ESCAPE_RANGE := 340.0
const WIZ_ESCAPE_GRACE := 0.6
const STORM_SWAY_AMP := 40.0     # island sway once he's aboard (calm was 22)
const STORM_SWAY_PERIOD := 2.7   # (calm was 3.4)

# THE VOID MOTH (Advika, 2026-07-14): an independent creature — NOT the
# wizard's — that arrives on its own partway through the trial, stalking
# the climb and dive-bombing. It dies ONLY to sustained lantern-light
# (hold L, ~5s on it). Moths keep coming until the wizard falls; a live
# one leaves on his defeat, flying off upward.
const VOID_MOTH := preload("res://scenes/VoidMoth.tscn")
const MOTH_SCALE := 0.78         # BIG (Advika, three passes) — it fills the sky over her
const MOTH_FROM_BELOW_P := 0.7   # rising from the void beneath is the thematic entrance
const MOTH_STAGGER := 8.0        # gap between arrivals while building to the cap
@export var moth_cap := 3              # 2-3 aloft at once (Advika) — they build up staggered
@export var moth_first_delay := 10.0   # TEST VALUE — flip back to 90.0 (Advika: remind her)
@export var moth_respawn_pressure := true
@export var moth_respawn_delay := 25.0
@export var moth_regrace := 10.0       # fall after the phase began -> next moth this soon

enum Phase { INTRO, BUILD, RIDE, DONE }

var phase := Phase.INTRO
var _pt := 0.0            # time in current phase
var _t := 0.0
var _bg: Realm2Background
var _chunk: LevitatingIsland
var _chunk_glow: Sprite2D
var _curi: CharacterBody2D
var _cam: Camera2D
var _trauma := 0.0
var _lbl: Label
var _lives: LivesHUD
var _dying := false
var _leaving := false
var _hedge_dissolve: ShaderMaterial
var _wake := 0.0  # 0 = embedded/dormant island, 1 = fully awake (glow breathes)
var _wizard: Wizard = null
var _airborne_t := 0.0  # seconds the island has been RISING (wizard spawn clock)
var _moth_timer := -1.0        # counts down to the next arrival while > 0
var _moth_phase_begun := false # first moth has arrived at least once
var _soak := false             # R2_TRIAL_LOG: deaths don't spend lifelines


func _ready() -> void:
	_bg = Realm2Background.new()
	_bg.include_chunk = false  # OUR chunk is a physics body, not decor
	add_child(_bg)
	_build_ground()
	_build_ascent_dressing()
	_build_forest_dressing()
	_build_fireflies()
	_build_chunk()
	_build_player()
	_build_camera()
	_build_ui()
	if OS.get_environment("R2_SHOT") != "":
		_self_screenshot(OS.get_environment("R2_SHOT"))


func _build_ground() -> void:
	# collision floor
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12000, 120)
	col.shape = shape
	col.position = Vector2(400, FLOOR_Y + 60)
	body.add_child(col)
	# side walls so the only way forward is the chunk
	for wx in [-750.0, 2250.0]:
		var w := CollisionShape2D.new()
		var ws := RectangleShape2D.new()
		ws.size = Vector2(60, 1600)
		w.shape = ws
		w.position = Vector2(wx, FLOOR_Y - 700)
		body.add_child(w)
	add_child(body)

	# visual: dark earth + the mossy hedge band along the floor line
	var earth := Polygon2D.new()
	earth.polygon = PackedVector2Array([Vector2(-6000, FLOOR_Y + 6), Vector2(6400, FLOOR_Y + 6),
			Vector2(6400, FLOOR_Y + 1400), Vector2(-6000, FLOOR_Y + 1400)])
	earth.color = Color(7.0 / 255.0, 5.0 / 255.0, 16.0 / 255.0)  # near-black soil, not a purple band
	add_child(earth)
	# the band texture is 100% opaque to its last row — undissolved, its sprite
	# bottom cuts a razor-straight line across the level (world y = 326), so the
	# last ~5% of the texture fades out into the dark undergrowth instead
	var dissolve := Shader.new()
	dissolve.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR.a *= 1.0 - smoothstep(0.95, 0.995, UV.y);\n}"
	_hedge_dissolve = ShaderMaterial.new()
	_hedge_dissolve.shader = dissolve
	for i in 2:
		var hedge := Sprite2D.new()
		hedge.texture = load(BASE + "band_ground.png")
		hedge.centered = false
		hedge.scale = Vector2(0.7, 0.7)
		hedge.position = Vector2(-1900 + i * 3840 * 0.7, FLOOR_Y - 1080 * 0.7 + 26)
		hedge.material = _hedge_dissolve
		hedge.set_meta("dbg", "hedge")
		add_child(hedge)

	# continuous moss MAT behind the hero — grass always under the feet,
	# no floating over visual dips (tileable, no seams)
	for i in 3:
		var mat := Sprite2D.new()
		mat.texture = load(BASE + "moss_mat.png")
		mat.centered = false
		mat.scale = Vector2(0.7, 0.7)
		mat.position = Vector2(-2200 + i * 3840 * 0.7, 210.0)
		mat.set_meta("dbg", "mat")
		add_child(mat)

	# CREST — the mat's top edge is a flat line against the sky; a dark row of
	# the tippy strip + scattered tuft mounds make the skyline organic. All z0,
	# behind the hero and the brighter rows.
	for i in 4:
		var crest := Sprite2D.new()
		crest.texture = load(BASE + "moss_front.png")
		crest.centered = false
		crest.scale = Vector2(0.7, 0.7)
		crest.position = Vector2(-2200 - 960 + i * 3840 * 0.7, 150.0)
		crest.modulate = Color(0.50, 0.48, 0.62)
		crest.set_meta("dbg", "crest")
		add_child(crest)
	# mound clusters along the crest (kept off the island's own silhouette)
	for p in [[-1750.0, 0.55], [-1150.0, 0.42], [-600.0, 0.60], [-50.0, 0.45],
			[450.0, 0.55], [2500.0, 0.50], [3100.0, 0.62], [3700.0, 0.45]]:
		var tf := Sprite2D.new()
		tf.texture = load(BASE + "tuft_%d.png" % (randi() % 3))
		tf.scale = Vector2(p[1], p[1])
		tf.position = Vector2(p[0], 262.0 - tf.texture.get_height() * p[1] * 0.5)
		tf.modulate = Color(0.52, 0.50, 0.64)
		tf.set_meta("dbg", "mound")
		add_child(tf)

	# SEAM BELT — the upper moss masses and the ground rows are horizontal
	# strips at constant heights, which reads as a dark flat channel running
	# the whole level ("the canopy is separate from the scene"). A belt of
	# mid-tone tufts straddles that seam at varied x/height/scale so the two
	# masses interlock. z0 late in the tree: over the crest/mats, but behind
	# Curiosity and the z11/z12 rows so the hero never drowns in it.
	var belt_rng := RandomNumberGenerator.new()
	belt_rng.seed = 20260707  # fixed: the belt is level design, not weather
	var bx := -2100.0
	while bx < 3900.0:
		if absf(bx - CHUNK_X) > 800.0:  # the island owns its own silhouette
			var bt := Sprite2D.new()
			bt.texture = load(BASE + "tuft_%d.png" % (belt_rng.randi() % 3))
			var bs := belt_rng.randf_range(0.30, 0.52)
			bt.scale = Vector2(bs, bs)
			bt.flip_h = belt_rng.randf() < 0.5
			bt.position = Vector2(bx + belt_rng.randf_range(-60.0, 60.0),
					belt_rng.randf_range(210.0, 280.0))
			var bb := belt_rng.randf_range(0.34, 0.58)
			bt.modulate = Color(bb, bb * 0.96, bb * 1.22)
			bt.set_meta("dbg", "belt")
			add_child(bt)
		bx += belt_rng.randf_range(190.0, 330.0)

	# DEPTH STACK — staggered rows of the same tileable strip, each lower and
	# darker, so the whole floor band is one seamless moss mound fading into
	# soil (no black gap-windows anywhere). z11: over the plug (z10) and the
	# embedded island core, behind the z12 front row.
	# (the 272 near-black shadow row straddles the soil plug's flat top edge —
	# without it that edge cuts a dead-straight line across the level)
	# (the two deepest rows sink the band into silhouette-black before the
	# fine-grained mat texture can show through — big fingers all the way down,
	# no small-vs-thick moss scale contrast)
	for row in [[272.0, 0.13, 0.11, 0.20, -672.0, "shadow272"], [228.0, 0.58, 0.55, 0.70, -1344.0, "mid228"],
			[296.0, 0.38, 0.36, 0.48, 0.0, "mid296"], [362.0, 0.22, 0.20, 0.30, -1344.0, "mid362"],
			[424.0, 0.12, 0.11, 0.17, -448.0, "mid424"], [488.0, 0.06, 0.05, 0.10, -1792.0, "mid488"]]:
		for i in 4:
			var mid := Sprite2D.new()
			mid.texture = load(BASE + "moss_front.png")
			mid.centered = false
			mid.scale = Vector2(0.7, 0.7)
			# per-tile height wobble so the strip rows don't sit on one flat line
			mid.position = Vector2(-2200 + row[4] + i * 3840 * 0.7,
					row[0] + sin(i * 2.6 + row[0]) * 10.0)
			mid.modulate = Color(row[1], row[2], row[3])
			mid.z_index = 11
			mid.set_meta("dbg", row[5])
			add_child(mid)

	# FRONT moss row — dedicated tileable strip drawn OVER Curiosity
	# (organic tips to the waist; no crop slices, no seams)
	for i in 3:
		var front := Sprite2D.new()
		front.texture = load(BASE + "moss_front.png")
		front.centered = false
		front.scale = Vector2(0.7, 0.7)
		front.position = Vector2(-2200 + i * 3840 * 0.7, 236.0 + sin(i * 2.1 + 4.0) * 9.0)
		front.modulate = Color(0.86, 0.84, 0.94)
		front.z_index = 12
		front.set_meta("dbg", "front")
		add_child(front)


	# R2_TINT env: flat-color every tagged ground layer (layer forensics)
	if OS.get_environment("R2_TINT") != "":
		var tints := {"hedge": Color(1, 1, 1), "mat": Color(1, 0.5, 0),
				"crest": Color(1, 0, 1), "mound": Color(0.55, 0, 1),
				"shadow272": Color(0, 0, 1), "mid228": Color(0, 1, 0),
				"mid296": Color(0, 1, 1), "mid362": Color(1, 1, 0),
				"mid424": Color(0.5, 1, 0), "mid488": Color(1, 0.5, 0.5),
				"front": Color(1, 0, 0)}
		var flat := Shader.new()
		flat.code = "shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint;
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a);
}"
		for c in get_children():
			if c is Sprite2D and c.has_meta("dbg"):
				var fm := ShaderMaterial.new()
				fm.shader = flat
				fm.set_shader_parameter("tint", tints[c.get_meta("dbg")])
				c.material = fm


# ASCENT SIDE DRESSING — the corridor the island rises through. Empty sky
# reads as a void (Advika, 2026-07-08); the reference look is moss masses
# hugging both screen edges. Three passes, all Mossy-pack elements sliced +
# violet-shifted by tools/slice_mossy_pack.gd, all pure decor (no collision):
# Overhang assemblies: a slab jutting in from the edge, moss beards/ferns
# swaying from its underside (storm-responsive SWAY_SHADER), an occasional
# mossy rock on top, an animated pack plant in the fringe, and on some a
# whole vine trunk growing through the slab (up like growth or down like
# roots — always one whole piece, never tiled, never flip_v'd). The WHOLE
# assembly is one Node2D that bobs and tilts together, so nothing can ever
# detach, orphan, or open a seam ("no leaves hanging in air" — Advika).
# The climb is ENDLESS (boss-gated), so the corridor never thins: every
# element that drops a screen below the camera wraps to above the view,
# shifted by its pass's full span so spacing and stacking stay seamless.
const _DRESS_SEED := 20260708  # fixed: the corridor is level design
const _VIEW_HALF_X := 1130.0   # half view width at the lift camera's zoom (16:9)
const _GRP_SPAN := 3000.0      # overhang pass wrap distance (-180 .. -3180)

# every animated dressing node: {n, base_y, amp, rate, ph} (+rot_amp for tilt)
var _dress_bobs: Array[Dictionary] = []

func _build_ascent_dressing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _DRESS_SEED
	var plats: Array[Texture2D] = []
	for n in ["platform_wide_0", "platform_wide_1", "platform_wide_2", "platform_grand"]:
		plats.append(load(BASE + n + ".png"))
	var beards: Array[Texture2D] = []
	for n in ["hang_beard_0", "hang_beard_1"]:
		beards.append(load(BASE + n + ".png"))
	var ferns: Array[Texture2D] = []
	for n in ["hang_fern_0", "hang_fern_1", "hang_fern_2", "hang_fern_3", "hang_fern_4",
			"hang_curl_0", "hang_curl_1", "hang_curl_2"]:
		ferns.append(load(BASE + n + ".png"))
	var vines: Array[Texture2D] = []
	for n in ["vine_trunk_0", "vine_trunk_1", "vine_trunk_2", "vine_trunk_3"]:
		vines.append(load(BASE + n + ".png"))
	var rocks: Array[Texture2D] = []
	for n in ["rock_moss_0", "rock_moss_1", "rock_moss_2"]:
		rocks.append(load(BASE + n + ".png"))

	# (a standalone vine-trunk pass lived here and was cut: the trunks are
	# S-curved standalone pieces, not tiles — stacking them left bark gaps at
	# every joint (Advika, 2026-07-08). Trunks now grow from the overhang
	# assemblies instead, the way the pack draws them.)

	# 2. overhang platforms with hangers — each side walks the corridor
	# independently so neither edge ever goes bare for a full screen height.
	# NO SKY SLIVERS (Advika, 2026-07-08): two neighbours that land almost
	# touching get interlocked by 70px+ instead — a near-miss gap winks open
	# and closed with their independent bobs and reads as a glitch. Either
	# clearly apart or genuinely merged, never the sliver between.
	for s in [-1.0, 1.0]:
		var py := -180.0 if s < 0.0 else -420.0  # offset phases, no mirroring
		var prev_top := INF  # top edge (smallest y) of the assembly below
		while py > -180.0 - _GRP_SPAN + 200.0:
			var d := _spawn_overhang(rng, s, py, plats, beards, ferns, rocks, vines)
			var sliver: float = prev_top - (float(d.base_y) + float(d.half_h))
			if sliver > 0.0 and sliver < 90.0:
				d.base_y += sliver + 70.0  # pull down into the neighbour: interlock
				(d.n as Node2D).position.y = d.base_y
			prev_top = float(d.base_y) - float(d.half_h)
			py = float(d.base_y) - rng.randf_range(420.0, 640.0)

	# (a near-black z13 "foreground silhouette" pass lived here and was cut:
	# a barely-on-screen black slab corner reads as a glitch blob, not depth —
	# Advika, 2026-07-08, three separate screenshots.)


# Advika (2026-07-12, circling the corridor assemblies): more of the pack on
# the forest floor. Grounded TREES in the corridor's own grammar — each spot
# is ONE assembly: a whole vine trunk rooted in the moss (never tiled, never
# flip_v), sometimes a canopy slab resting on its crown with storm-sway
# hangers tucked under the fringe, a mossy rock or animated plant at the
# base. Rooted = STATIC: earth doesn't bob; only the corridor floats.
# Fixed seed — the forest is level design, not weather.
# Fireflies EVERYWHERE (Advika, 2026-07-12): the background's own emitter
# only covers x -900..900, so everything beyond the island sat dark. Gold
# motes now drift across the whole forest span — and a column rides above
# the island so liftoff doesn't snuff them all at once.
func _build_fireflies() -> void:
	var spans := [
		[Vector2(-750.0, FLOOR_Y - 180.0), Vector2(1300.0, 400.0), 14],
		[Vector2(1500.0, FLOOR_Y - 180.0), Vector2(1300.0, 400.0), 14],
		[Vector2(3050.0, FLOOR_Y - 180.0), Vector2(1300.0, 400.0), 14],
		[Vector2(CHUNK_X, -900.0), Vector2(900.0, 700.0), 10],  # the early climb
	]
	for s in spans:
		var ff := CPUParticles2D.new()
		ff.texture = load(BASE + "firefly.png")
		ff.amount = s[2]
		ff.lifetime = 9.0
		ff.preprocess = 9.0
		ff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		ff.emission_rect_extents = s[1]
		ff.gravity = Vector2.ZERO
		ff.initial_velocity_min = 6.0
		ff.initial_velocity_max = 18.0
		ff.spread = 180.0
		ff.scale_amount_min = 0.35
		ff.scale_amount_max = 0.8
		ff.position = s[0]
		ff.z_index = 40
		add_child(ff)


func _build_forest_dressing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260712
	var plats: Array[Texture2D] = []
	for n in ["platform_wide_0", "platform_wide_1", "platform_wide_2"]:
		plats.append(load(BASE + n + ".png"))
	var ferns: Array[Texture2D] = []
	for n in ["hang_fern_0", "hang_fern_1", "hang_fern_2", "hang_fern_3", "hang_fern_4",
			"hang_curl_0", "hang_curl_1", "hang_curl_2"]:
		ferns.append(load(BASE + n + ".png"))
	var beards: Array[Texture2D] = []
	for n in ["hang_beard_0", "hang_beard_1"]:
		beards.append(load(BASE + n + ".png"))
	var vines: Array[Texture2D] = []
	for n in ["vine_trunk_0", "vine_trunk_1", "vine_trunk_2", "vine_trunk_3"]:
		vines.append(load(BASE + n + ".png"))
	var rocks: Array[Texture2D] = []
	for n in ["rock_moss_0", "rock_moss_1", "rock_moss_2"]:
		rocks.append(load(BASE + n + ".png"))
	var boulders: Array[Texture2D] = []
	for n in ["boulder_0", "boulder_1", "boulder_2"]:
		boulders.append(load(BASE + n + ".png"))

	# GRAND FEATURES (Advika, 2026-07-12: more jazz beyond the island itself):
	# landmark growths at fixed posts — twin trunks carrying a grand moss
	# ledge, a dark cascade spilling off its lip, hangers and a perched rock.
	# Rooted like everything else; the island's clearing stays untouched.
	for gx in [-1050.0, -80.0, 2550.0, 3250.0]:
		if absf(gx - CHUNK_X) > 750.0:
			_spawn_forest_grand(rng, gx, vines, ferns, beards, rocks)

	# Edge to edge of everything the camera can ever see (walls sit at -750 /
	# 2250 but the view reaches ~1130 past the hero) — the forest doesn't end
	# where the walkable map does. (Advika: the right side was hella plain.)
	var x := -1500.0
	while x < 3800.0:
		var dx := absf(x - CHUNK_X)
		var right_side := x > CHUNK_X
		# the island keeps a TIGHT clearing (just past its own fringe at ±550):
		# no trees against its silhouette, low boulders may hug its skirts.
		# The right flank leans tree-heavy — it only has the wall-to-backdrop
		# span to work with, so every spot there must pull weight (Advika:
		# one side still read plain).
		if dx > 650.0:
			var tree_p := 0.75 if right_side else 0.6
			if rng.randf() < tree_p:
				_spawn_forest_tree(rng, x, vines, plats, ferns, beards, rocks)
			else:
				_spawn_forest_boulders(rng, x, boulders, rocks)
		elif dx > 580.0:
			_spawn_forest_boulders(rng, x, boulders, rocks)
		x += rng.randf_range(280.0, 470.0) if right_side else rng.randf_range(340.0, 560.0)

	# UNDERGROWTH CARPET (Advika, 2026-07-12: "jass up this side" — the seam
	# right of the island rolled thin). Trees are the big beats; this is the
	# guarantee: a small tuft/rock/plant cluster every ~150px across the WHOLE
	# map, deterministic, so no stretch can ever roll bare. Skips only the
	# island's own art footprint (it lifts away — nothing may pop from behind).
	var tufts: Array[Texture2D] = []
	for n in ["tuft_0", "tuft_1", "tuft_2"]:
		tufts.append(load(BASE + n + ".png"))
	var ux := -1500.0
	while ux < 3800.0:
		if absf(ux - CHUNK_X) > 600.0:
			var b := rng.randf_range(0.30, 0.50)
			var roll := rng.randf()
			if roll < 0.5:
				var tt: Texture2D = tufts[rng.randi() % tufts.size()]
				var tsc := rng.randf_range(0.16, 0.30)
				var tf := Sprite2D.new()
				tf.texture = tt
				tf.scale = Vector2(tsc, tsc)
				tf.flip_h = rng.randf() < 0.5
				tf.position = Vector2(ux, FLOOR_Y + 16.0 - tt.get_height() * tsc * 0.38)
				tf.modulate = Color(b, b * 0.96, b * 1.22)
				tf.set_meta("dbg", "under_tuft")
				add_child(tf)
			elif roll < 0.75:
				var rt: Texture2D = rocks[rng.randi() % rocks.size()]
				var rsc := rng.randf_range(0.12, 0.22)
				var rk := Sprite2D.new()
				rk.texture = rt
				rk.scale = Vector2(rsc, rsc)
				rk.flip_h = rng.randf() < 0.5
				rk.position = Vector2(ux, FLOOR_Y + 14.0 - rt.get_height() * rsc * 0.30)
				rk.modulate = Color(b, b * 0.95, b * 1.18)
				rk.set_meta("dbg", "under_rock")
				add_child(rk)
			else:
				var pdir: String = ["flower", "plant1", "plant_wind"][rng.randi() % 3]
				var plant := _dress_plant(pdir, rng.randf_range(7.0, 10.0),
						rng.randf_range(0.12, 0.20), rng)
				plant.position = Vector2(ux, FLOOR_Y + 8.0)
				plant.modulate = Color(b * 1.05, b, b * 1.25)
				plant.set_meta("dbg", "under_plant")
				add_child(plant)
		ux += rng.randf_range(120.0, 210.0)


# One grounded tree: trunk rooted in the moss line, optional canopy slab on
# the crown, hangers under the canopy, a rock hugging the base.
func _spawn_forest_tree(rng: RandomNumberGenerator, x: float,
		vines: Array[Texture2D], plats: Array[Texture2D],
		ferns: Array[Texture2D], beards: Array[Texture2D],
		rocks: Array[Texture2D]) -> void:
	var depth := rng.randf()  # 0 = far/dim/small, 1 = near/lit/tall
	var b := lerpf(0.30, 0.52, depth)
	var grp := Node2D.new()
	grp.position = Vector2(x, FLOOR_Y + 18.0)  # anchor sits IN the moss body
	add_child(grp)

	var vt: Texture2D = vines[rng.randi() % vines.size()]
	var vsc := rng.randf_range(0.42, 0.78) * lerpf(0.7, 1.0, depth)
	var vh := vt.get_height() * vsc
	# the crown must stay IN FRAME at the ground camera — a canopy just above
	# the top edge leaves its beards hanging from nothing (silhouette law)
	const MAX_TREE_H := 640.0
	if vh > MAX_TREE_H:
		vsc *= MAX_TREE_H / vh
		vh = MAX_TREE_H
	var flip := rng.randf() < 0.5
	var trunk := Sprite2D.new()
	trunk.texture = vt
	trunk.scale = Vector2(vsc, vsc)
	trunk.flip_h = flip
	# base buried below the anchor, crown in the sky — a whole piece, rooted
	trunk.position = Vector2(0.0, -vh * 0.5 + 26.0)
	trunk.modulate = Color(b, b * 0.95, b * 1.22)
	trunk.set_meta("dbg", "forest_trunk")
	grp.add_child(trunk)

	# canopy: a moss slab resting ON the crown (the circled read), its fringe
	# sunk into the trunk top so they read as one growth — no near-miss gap
	if rng.randf() < 0.65:
		var pt: Texture2D = plats[rng.randi() % plats.size()]
		var psc := rng.randf_range(0.34, 0.48) * lerpf(0.75, 1.0, depth)
		var ph := pt.get_height() * psc
		var canopy := Sprite2D.new()
		canopy.texture = pt
		canopy.scale = Vector2(psc, psc)
		canopy.flip_h = rng.randf() < 0.5
		canopy.position = Vector2(rng.randf_range(-40.0, 40.0),
				-vh + 26.0 + ph * 0.30)
		canopy.modulate = Color(b * 1.04, b, b * 1.24)
		canopy.set_meta("dbg", "forest_canopy")
		grp.add_child(canopy)
		# the canopy is a place, not a lid: a mossy rock perched on the crown
		# and/or an animated plant breathing up there (corridor grammar)
		if rng.randf() < 0.4:
			var prt: Texture2D = rocks[rng.randi() % rocks.size()]
			var prsc := rng.randf_range(0.16, 0.26) * psc / 0.4
			var prk := Sprite2D.new()
			prk.texture = prt
			prk.scale = Vector2(prsc, prsc)
			prk.flip_h = rng.randf() < 0.5
			prk.position = canopy.position + Vector2(
					rng.randf_range(-pt.get_width() * psc * 0.25, pt.get_width() * psc * 0.25),
					-ph * 0.30 - prt.get_height() * prsc * 0.35)
			prk.modulate = Color(b, b * 0.95, b * 1.18)
			prk.set_meta("dbg", "forest_perch")
			grp.add_child(prk)
		if rng.randf() < 0.45:
			var cpd: String = ["flower", "plant1", "plant_wind"][rng.randi() % 3]
			var cplant := _dress_plant(cpd, rng.randf_range(7.0, 10.0),
					rng.randf_range(0.16, 0.24) * psc / 0.4, rng)
			cplant.position = canopy.position + Vector2(
					rng.randf_range(-pt.get_width() * psc * 0.3, pt.get_width() * psc * 0.3),
					-ph * 0.32)
			cplant.modulate = Color(b * 1.05, b, b * 1.25)
			cplant.set_meta("dbg", "forest_canopy_plant")
			grp.add_child(cplant)
		# hangers under the canopy fringe, tops tucked in, tips storm-swaying.
		# NO TWINS (Advika, 2026-07-12, circled): one assembly never hangs the
		# same texture twice — picks come from the pool without replacement —
		# and two hangers split the canopy's halves so they can't stack.
		var n_hang := 1 + (rng.randi() % 2)
		var pool: Array[Texture2D] = []
		pool.append_array(ferns)
		pool.append_array(beards)
		for i in n_hang:
			var pick := rng.randi() % pool.size()
			var ht: Texture2D = pool[pick]
			pool.remove_at(pick)
			var hsc := rng.randf_range(0.30, 0.48) * psc / 0.4
			var hg := Sprite2D.new()
			hg.texture = ht
			hg.centered = false
			hg.offset = Vector2(-ht.get_width() * 0.5, -24.0)
			hg.scale = Vector2(hsc, hsc)
			hg.flip_h = rng.randf() < 0.5
			var span := pt.get_width() * psc * 0.32
			var hx := rng.randf_range(-span, -span * 0.2) if (n_hang == 2 and i == 0) \
					else (rng.randf_range(span * 0.2, span) if n_hang == 2 \
					else rng.randf_range(-span, span))
			hg.position = canopy.position + Vector2(hx, ph * 0.24)
			var hbr := b * rng.randf_range(0.8, 1.05)
			hg.modulate = Color(hbr, hbr * 0.95, hbr * 1.22)
			hg.material = _bg._sway_material(rng.randf_range(7.0, 15.0),
					rng.randf_range(0.7, 1.3), rng.randf() * TAU)
			hg.set_meta("dbg", "forest_hang")
			grp.add_child(hg)

	# a mossy rock hugging the base, half sunk in the moss
	if rng.randf() < 0.7:
		var rt: Texture2D = rocks[rng.randi() % rocks.size()]
		var rsc := rng.randf_range(0.20, 0.34) * lerpf(0.75, 1.0, depth)
		var rk := Sprite2D.new()
		rk.texture = rt
		rk.scale = Vector2(rsc, rsc)
		rk.flip_h = rng.randf() < 0.5
		rk.position = Vector2((1.0 if flip else -1.0) * rng.randf_range(40.0, 90.0),
				-rt.get_height() * rsc * 0.30 + 8.0)
		var rb := b * rng.randf_range(0.85, 1.0)
		rk.modulate = Color(rb, rb * 0.95, rb * 1.18)
		rk.set_meta("dbg", "forest_rock")
		grp.add_child(rk)

	# an animated pack plant breathing at the roots — the same living plants
	# the island and corridor wear (use the pack to the max, Advika)
	if rng.randf() < 0.5:
		var pdir: String = ["flower", "plant1", "plant_wind"][rng.randi() % 3]
		var plant := _dress_plant(pdir, rng.randf_range(7.0, 10.0),
				rng.randf_range(0.16, 0.26) * lerpf(0.75, 1.0, depth), rng)
		plant.position = Vector2((-1.0 if flip else 1.0) * rng.randf_range(50.0, 110.0), -6.0)
		plant.modulate = Color(b * 1.05, b, b * 1.25)
		plant.set_meta("dbg", "forest_plant")
		grp.add_child(plant)


# A grand landmark: TWIN trunks (distinct textures) carrying a grand moss
# ledge across their crowns, a dark cascade spilling off the lip (top tucked
# under the fringe — it falls FROM somewhere), storm-sway hangers, a rock
# perched on the ledge. The forest's occasional exclamation mark.
func _spawn_forest_grand(rng: RandomNumberGenerator, x: float,
		vines: Array[Texture2D], ferns: Array[Texture2D],
		beards: Array[Texture2D], rocks: Array[Texture2D]) -> void:
	var b := rng.randf_range(0.40, 0.55)  # landmarks sit a touch nearer/brighter
	var grp := Node2D.new()
	grp.position = Vector2(x, FLOOR_Y + 18.0)
	add_child(grp)

	# twin trunks, distinct pieces, leaning slightly apart
	var vi := rng.randi() % vines.size()
	var trunk_h := 0.0
	for t in 2:
		var vt: Texture2D = vines[(vi + 1 + t) % vines.size()]
		var vsc := rng.randf_range(0.50, 0.62)
		var vh := vt.get_height() * vsc
		if vh > 560.0:
			vsc *= 560.0 / vh
			vh = 560.0
		trunk_h = maxf(trunk_h, vh)
		var trunk := Sprite2D.new()
		trunk.texture = vt
		trunk.scale = Vector2(vsc, vsc)
		trunk.flip_h = t == 1
		trunk.position = Vector2(-70.0 + 140.0 * t, -vh * 0.5 + 26.0)
		var tb := b * rng.randf_range(0.85, 1.0)
		trunk.modulate = Color(tb, tb * 0.95, tb * 1.22)
		trunk.set_meta("dbg", "grand_trunk")
		grp.add_child(trunk)

	# the grand ledge laid across both crowns, fringe sunk into them
	var lt: Texture2D = load(BASE + ("platform_grand.png" if rng.randf() < 0.6 else "platform_tall.png"))
	var lsc := rng.randf_range(0.40, 0.50)
	var lh := lt.get_height() * lsc
	var ledge := Sprite2D.new()
	ledge.texture = lt
	ledge.scale = Vector2(lsc, lsc)
	ledge.flip_h = rng.randf() < 0.5
	ledge.position = Vector2(0.0, -trunk_h + 26.0 + lh * 0.28)
	ledge.modulate = Color(b * 1.04, b, b * 1.24)
	ledge.set_meta("dbg", "grand_ledge")
	grp.add_child(ledge)

	# the cascade: dark moss-fall spilling off the ledge lip, top buried in
	# the fringe so it falls FROM the growth, tail dissolving toward the moss
	var ct: Texture2D = load(BASE + ("cascade_dark.png" if rng.randf() < 0.7 else "cascade.png"))
	var csc := rng.randf_range(0.34, 0.44)
	var ch := ct.get_height() * csc
	var casc := Sprite2D.new()
	casc.texture = ct
	casc.scale = Vector2(csc, csc)
	casc.flip_h = rng.randf() < 0.5
	casc.position = Vector2(rng.randf_range(-lt.get_width() * lsc * 0.25, lt.get_width() * lsc * 0.25),
			ledge.position.y + lh * 0.20 + ch * 0.42)
	var cb := b * rng.randf_range(0.7, 0.85)
	casc.modulate = Color(cb, cb * 0.95, cb * 1.25)
	casc.set_meta("dbg", "grand_cascade")
	casc.show_behind_parent = false
	grp.add_child(casc)

	# hangers off the ledge — no twins, halves split
	var pool: Array[Texture2D] = []
	pool.append_array(ferns)
	pool.append_array(beards)
	for i in 2:
		var pick := rng.randi() % pool.size()
		var ht: Texture2D = pool[pick]
		pool.remove_at(pick)
		var hsc := rng.randf_range(0.36, 0.52)
		var hg := Sprite2D.new()
		hg.texture = ht
		hg.centered = false
		hg.offset = Vector2(-ht.get_width() * 0.5, -24.0)
		hg.scale = Vector2(hsc, hsc)
		hg.flip_h = rng.randf() < 0.5
		var span := lt.get_width() * lsc * 0.34
		var hx := rng.randf_range(-span, -span * 0.25) if i == 0 \
				else rng.randf_range(span * 0.25, span)
		hg.position = ledge.position + Vector2(hx, lh * 0.22)
		var hbr := b * rng.randf_range(0.8, 1.0)
		hg.modulate = Color(hbr, hbr * 0.95, hbr * 1.22)
		hg.material = _bg._sway_material(rng.randf_range(7.0, 15.0),
				rng.randf_range(0.7, 1.3), rng.randf() * TAU)
		hg.set_meta("dbg", "grand_hang")
		grp.add_child(hg)

	# a rock perched on the ledge crown
	var prt: Texture2D = rocks[rng.randi() % rocks.size()]
	var prsc := rng.randf_range(0.20, 0.30)
	var prk := Sprite2D.new()
	prk.texture = prt
	prk.scale = Vector2(prsc, prsc)
	prk.flip_h = rng.randf() < 0.5
	prk.position = ledge.position + Vector2(
			rng.randf_range(-lt.get_width() * lsc * 0.2, lt.get_width() * lsc * 0.2),
			-lh * 0.30 - prt.get_height() * prsc * 0.35)
	prk.modulate = Color(b, b * 0.95, b * 1.18)
	prk.set_meta("dbg", "grand_perch")
	grp.add_child(prk)


# A boulder cluster: two-three mossy masses half-buried in the moss line,
# leaning into each other — clearly merged, never the sliver between.
func _spawn_forest_boulders(rng: RandomNumberGenerator, x: float,
		boulders: Array[Texture2D], rocks: Array[Texture2D]) -> void:
	var depth := rng.randf()
	var b := lerpf(0.32, 0.50, depth)
	var grp := Node2D.new()
	grp.position = Vector2(x, FLOOR_Y + 14.0)
	add_child(grp)
	var n := 2 + (rng.randi() % 2)
	var cx := 0.0
	for i in n:
		var bt: Texture2D = boulders[rng.randi() % boulders.size()] if rng.randf() < 0.6 \
				else rocks[rng.randi() % rocks.size()]
		var bsc := rng.randf_range(0.26, 0.44) * lerpf(0.75, 1.0, depth)
		var bw := bt.get_width() * bsc
		var bd := Sprite2D.new()
		bd.texture = bt
		bd.scale = Vector2(bsc, bsc)
		bd.flip_h = rng.randf() < 0.5
		# each next mass overlaps the previous by a third — one merged pile
		bd.position = Vector2(cx, -bt.get_height() * bsc * 0.30 + rng.randf_range(0.0, 10.0))
		var bb := b * rng.randf_range(0.85, 1.05)
		bd.modulate = Color(bb, bb * 0.95, bb * 1.2)
		bd.set_meta("dbg", "forest_boulder")
		grp.add_child(bd)
		cx += bw * 0.62


func _spawn_overhang(rng: RandomNumberGenerator, side: float, y: float,
		plats: Array[Texture2D], beards: Array[Texture2D],
		ferns: Array[Texture2D], rocks: Array[Texture2D],
		vines: Array[Texture2D]) -> Dictionary:
	var tex: Texture2D = plats[rng.randi() % plats.size()]
	var depth := rng.randf()  # 0 = far/dim, 1 = near/lit
	var sc := rng.randf_range(0.42, 0.60) * lerpf(0.72, 1.0, depth)
	var half := tex.get_width() * sc * 0.5
	# inner tip lands 60..320px inside the screen edge; island channel stays clear
	var inset := rng.randf_range(60.0, 320.0)
	var tip_x := CHUNK_X + side * (_VIEW_HALF_X - inset)
	if absf(tip_x - CHUNK_X) < 820.0:
		tip_x = CHUNK_X + side * 820.0
		inset = _VIEW_HALF_X - 820.0
	var b := lerpf(0.34, 0.60, depth)

	# the whole overhang is ONE assembly anchored at the slab's inner tip —
	# slab, hangers, rock and plant bob/tilt together and can never separate
	var grp := Node2D.new()
	grp.position = Vector2(tip_x, y)
	grp.rotation = rng.randf_range(-0.04, 0.04) * side
	add_child(grp)
	var entry := {"n": grp, "base_y": y, "base_rot": grp.rotation,
			"amp": rng.randf_range(4.0, 8.0), "rate": rng.randf_range(0.22, 0.4),
			"ph": rng.randf() * TAU, "rot_amp": rng.randf_range(0.004, 0.010),
			"wrap": _GRP_SPAN, "half_h": tex.get_height() * sc * 0.5}
	_dress_bobs.append(entry)

	var slab := Sprite2D.new()
	slab.texture = tex
	slab.scale = Vector2(sc, sc)
	slab.flip_h = side > 0.0
	slab.position = Vector2(side * half, 0)
	slab.modulate = Color(b, b * 0.95, b * 1.22)
	slab.set_meta("dbg", "dress_slab")
	grp.add_child(slab)
	var slab_h := tex.get_height() * sc

	# a vine trunk growing THROUGH the slab on some assemblies — always a
	# whole piece (never tiled/stacked: joints gap; never flip_v: the leaves
	# invert). Behind the slab, rising from it like the reference growth —
	# or hanging beneath it as roots.
	if rng.randf() < 0.5:
		var vt: Texture2D = vines[rng.randi() % vines.size()]
		var vsc := rng.randf_range(0.45, 0.65) * sc / 0.5
		var vine := Sprite2D.new()
		vine.texture = vt
		vine.scale = Vector2(vsc, vsc)
		vine.flip_h = side > 0.0
		vine.z_index = -1  # behind the slab: rooted in the moss, not pasted on
		var vh := vt.get_height() * vsc
		var upward := rng.randf() < 0.7
		var vx := side * rng.randf_range(half * 0.35, half * 0.95)
		if upward:
			# tip in the air above, base buried in the slab body
			vine.position = Vector2(vx, -vh * 0.5 + slab_h * 0.22)
		else:
			# hanging under the fringe like a root cascade
			vine.position = Vector2(vx, vh * 0.5 + slab_h * 0.10)
		var vb := b * rng.randf_range(0.7, 0.9)
		vine.modulate = Color(vb, vb * 0.95, vb * 1.25)
		vine.set_meta("dbg", "dress_vine")
		grp.add_child(vine)

	# hangers: only on slabs with a real visible body, attached INSIDE the
	# visible span and tucked up into the moss fringe — never orphaned in air.
	# Storm-responsive sway shader: the tops stay pinned, the tips whip.
	if inset >= 140.0:
		var n_hang := 1 + (rng.randi() % 2)
		# no twins on one assembly (same law as the forest trees)
		var pool: Array[Texture2D] = []
		pool.append_array(ferns)
		pool.append_array(beards)
		for i in n_hang:
			var pick := rng.randi() % pool.size()
			var ht: Texture2D = pool[pick]
			pool.remove_at(pick)
			var hsc := rng.randf_range(0.38, 0.58) * sc / 0.5
			var hg := Sprite2D.new()
			hg.texture = ht
			hg.centered = false
			hg.offset = Vector2(-ht.get_width() * 0.5, -24.0)
			hg.scale = Vector2(hsc, hsc)
			hg.flip_h = rng.randf() < 0.5
			hg.position = Vector2(side * rng.randf_range(50.0, maxf(120.0, inset * 0.85)),
					slab_h * 0.26)
			var hbr := b * rng.randf_range(0.8, 1.05)
			hg.modulate = Color(hbr, hbr * 0.95, hbr * 1.22)
			hg.material = _bg._sway_material(rng.randf_range(7.0, 15.0),
					rng.randf_range(0.7, 1.3), rng.randf() * TAU)
			hg.set_meta("dbg", "dress_hang")
			grp.add_child(hg)

	# an occasional mossy rock perched on the slab
	if rng.randf() < 0.4:
		var rt: Texture2D = rocks[rng.randi() % rocks.size()]
		var rsc := rng.randf_range(0.22, 0.34) * sc / 0.5
		var rk := Sprite2D.new()
		rk.texture = rt
		rk.scale = Vector2(rsc, rsc)
		rk.flip_h = rng.randf() < 0.5
		rk.position = Vector2(side * rng.randf_range(80.0, half * 0.9),
				-slab_h * 0.30 - rt.get_height() * rsc * 0.35)
		var rb := b * rng.randf_range(0.85, 1.0)
		rk.modulate = Color(rb, rb * 0.95, rb * 1.18)
		rk.set_meta("dbg", "dress_rock")
		grp.add_child(rk)

	# an animated pack plant growing from the fringe on some slabs — the same
	# living plants the island itself wears, breathing on the corridor walls
	if rng.randf() < 0.55:
		var pdir: String = ["flower", "plant1", "plant_wind"][rng.randi() % 3]
		var plant := _dress_plant(pdir, rng.randf_range(7.0, 10.0),
				rng.randf_range(0.20, 0.30) * sc / 0.5, rng)
		plant.position = Vector2(side * rng.randf_range(70.0, half * 0.8),
				-slab_h * 0.32)
		plant.modulate = Color(b * 1.05, b, b * 1.25)
		plant.set_meta("dbg", "dress_plant")
		grp.add_child(plant)
	return entry


# Same recipe as Realm2Background._animated, but deliberately NOT registered
# with the background's _plants — those freeze with the island's camouflage
# wake cycle; the corridor's plants live on their own clock.
func _dress_plant(dir: String, fps: float, sc: float,
		rng: RandomNumberGenerator) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("sway")
	frames.set_animation_loop("sway", true)
	frames.set_animation_speed("sway", fps)
	var i := 0
	while ResourceLoader.exists(BASE + dir + "/frame_%03d.png" % i):
		frames.add_frame("sway", load(BASE + dir + "/frame_%03d.png" % i))
		i += 1
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.scale = Vector2(sc, sc)
	a.play("sway")
	a.frame = rng.randi() % maxi(i, 1)  # desync: no two plants pulse in unison
	return a


func _build_chunk() -> void:
	# the chunk IS a LevitatingIsland — self-contained shake/debris/ascent/hover
	_chunk = LevitatingIsland.new()
	_chunk.position = Vector2(CHUNK_X, CHUNK_START_Y)
	_chunk.rise_height = CHUNK_START_Y - LIFT_TOP_Y
	_chunk.rise_duration = 24.0
	# BOSS-GATED: the island does not stop until the wizard falls (Advika,
	# 2026-07-08) — and there is no wizard yet, so it does not stop. R2-M7
	# calls _chunk.stop_levitation() on the defeat beat.
	_chunk.endless = true
	_chunk.sway_amplitude = 22.0
	_chunk.sway_period = 3.4
	_chunk.bob_amplitude = 8.0
	_chunk.shake_duration = 0.8
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1100, 32)  # match the wide island art, not just its center
	col.shape = shape
	col.position = Vector2(0, -104)  # sunk into the fringe — he stands IN the moss
	_chunk.add_child(col)
	add_child(_chunk)
	_chunk_glow = _bg.build_chunk_visuals(_chunk)
	# CAMOUFLAGE: while embedded, the island wears the ground's own dark
	# violet — bright chunk art in a dark field reads as pasted-on. Its
	# animated plants freeze and the gold glow banks to a still ember: any
	# motion in an otherwise still field gives the island away instantly.
	# At the tear it all wakes together (tint tween + _wake ramp + plants).
	_chunk.modulate = CAMO_TINT
	for c in _chunk.get_children():
		if c is AnimatedSprite2D:
			c.pause()

	# soil plug: hides the island's pink under-moss while it's embedded (same
	# near-black as the earth). It stays with the ground — the island rises
	# OUT of it at the tear. Its top sits at FLOOR_Y+140, NOT at the floor
	# line: chunk.png's bright fringe lives at world y 291-312, so a floor-line
	# plug slices it into a razor-straight brightness cut across the level.
	# The island's 312-440 band is near-black rock that reads as soil, and the
	# pink underbelly only starts at ~459 — still safely under the plug.
	var plug := Polygon2D.new()
	plug.polygon = PackedVector2Array([
		Vector2(CHUNK_X - 730, FLOOR_Y + 140), Vector2(CHUNK_X + 730, FLOOR_Y + 140),
		Vector2(CHUNK_X + 730, FLOOR_Y + 900), Vector2(CHUNK_X - 730, FLOOR_Y + 900)])
	plug.color = Color(7.0 / 255.0, 5.0 / 255.0, 16.0 / 255.0)
	plug.z_index = 10  # over the island underbelly, under the z11 mid moss row
	add_child(plug)
	_chunk.levitation_started.connect(func() -> void:
		_lbl.text = ""
		# the island wakes: camouflage violet -> its own bright moss colors,
		# glow breathing ramps in, plants stir back to life
		create_tween().tween_property(_chunk, "modulate", Color(1, 1, 1), WAKE_TIME)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		create_tween().tween_property(self, "_wake", 1.0, WAKE_TIME)
		for c in _chunk.get_children():
			if c is AnimatedSprite2D:
				c.play())
	# `arrived` only fires from stop_levitation() — the wizard's defeat.
	_chunk.arrived.connect(func() -> void:
		_set_phase(Phase.DONE))


func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = Vector2(150, FLOOR_Y - 120)
	# the world is authored at 1080-scale; shrink the hero to stand ~110px tall
	_curi.scale = Vector2(0.24, 0.24)
	# this level jumps slightly higher (Advika) — the wizard's orbs must be clearable
	_curi.jump_velocity *= JUMP_BOOST
	add_child(_curi)

	# the SAME eye lifeline counter as Realm 1 — shared scene, same rules
	_lives = LIVES_HUD.instantiate() as LivesHUD
	_lives.eye_scale = 0.22     # bigger lifelines (R1 default is 0.15)
	_lives.eye_spacing = 112.0  # keep centers apart at the larger size
	add_child(_lives)
	_lives.reset(STARTING_LIVES)
	if _curi.has_signal("died") and not _curi.died.is_connected(_die):
		_curi.died.connect(_die)


func _build_camera() -> void:
	_cam = Camera2D.new()
	var vp := get_viewport_rect().size
	var z := 0.85 * vp.y / 1080.0  # zoomed out: the island travels through a big sky
	_cam.zoom = Vector2(z, z)
	_cam.position = Vector2(150, FLOOR_Y - 220)
	add_child(_cam)
	_cam.make_current()
	_chunk.camera_path = _chunk.get_path_to(_cam)  # island drives it once active


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var vr := ColorRect.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = SCREEN_UV - vec2(0.5);\n\tfloat d = length(uv * vec2(1.2, 1.35));\n\tCOLOR = vec4(0.02, 0.012, 0.055, smoothstep(0.45, 0.95, d) * 0.85);\n}"
	var m := ShaderMaterial.new()
	m.shader = sh
	vr.material = m
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(vr)
	_lbl = Label.new()
	_lbl.text = "R2-M1 LIFT TEST — walk right →   (J strike · hold L: the light · R restart · ESC hub)"
	_lbl.position = Vector2(16, 12)
	_lbl.add_theme_color_override("font_color", Color(0.78, 0.73, 0.92, 0.6))
	cl.add_child(_lbl)


func _self_screenshot(path: String) -> void:
	if OS.get_environment("R2_SHOT_X") != "":
		# park the hero at a given ground x (pre-liftoff framing checks)
		_curi.position = Vector2(float(OS.get_environment("R2_SHOT_X")), FLOOR_Y - 140.0)
		_curi.velocity = Vector2.ZERO
		_cam.position = Vector2(_curi.position.x, FLOOR_Y - 220.0)
	if OS.get_environment("R2_SHOT_LIFT") != "":
		# jump straight to mid-ascent for the screenshot. Let the island's
		# physics body settle at the jumped position FIRST — placing the hero
		# in the same tick lets the teleport sweep past him (he falls home).
		_set_phase(Phase.RIDE)
		_chunk.modulate = Color(1, 1, 1)  # mid-ascent = fully awake colors
		_wake = 1.0
		for c in _chunk.get_children():
			if c is AnimatedSprite2D:
				c.play()
		# R2_SHOT_LIFT may carry an ascent progress (0..1); bare "1" means midway
		var prog := 0.5
		var pv := OS.get_environment("R2_SHOT_LIFT")
		if pv.is_valid_float() and float(pv) != 1.0:
			prog = clampf(float(pv), 0.02, 0.98)
		_chunk.debug_jump(prog)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_curi.global_position = _chunk.global_position + Vector2(0, -175.0)
		if OS.get_environment("R2_SHOT_FALL") != "":
			# drop the hero below the island instead — proves the fall→respawn beat
			_curi.global_position = _chunk.global_position + Vector2(0, 400.0)
		_curi.velocity = Vector2.ZERO
		_bg.set_storm(0.75)
		_cam.position = Vector2(CHUNK_X, _chunk.global_position.y - 120.0)
		_spawn_wizard(true)  # mid-ascent = he's long since appeared
	# R2_TRIAL_LOG: don't screenshot — observe the trial economy for 45s
	# (casts must keep coming as orbs vacate; regression guard for the
	# "wizard stops conjuring" wedge) and quit.
	if OS.get_environment("R2_TRIAL_LOG") != "":
		# soak armor: the parked hero would otherwise be chain-shoved off and
		# burn all three lifelines standing still — a player moves, this rig
		# doesn't. Deaths still happen (respawn/clear logic runs); they just
		# never spend lifelines, so the soak survives its own realism.
		_soak = true
		var casts: Array[int] = [0]
		_wizard.cast_committed.connect(func(_p: Vector2) -> void: casts[0] += 1)
		for i in range(15):
			await get_tree().create_timer(3.0).timeout
			var moths := get_tree().get_nodes_in_group("moths")
			var moth_s := "none"
			if moths.size() > 0:
				var states: Array[String] = []
				for m in moths:
					states.append(VoidMoth.State.keys()[m.state])
				moth_s = ",".join(states)
			print("TRIALLOG t=%d casts=%d hazards=%d moths=%d(%s) island_y=%.0f" %
					[(i + 1) * 3, casts[0], get_tree().get_nodes_in_group("hazards").size(),
					moths.size(), moth_s, _chunk.global_position.y])
			# R2_MOTH_BURN: headless stand-in for holding L — force-burn one
			# live moth partway through the soak to prove death + respawn timer
			if OS.get_environment("R2_MOTH_BURN") != "" and i == 6 and moths.size() > 0:
				moths[0]._light_t = moths[0].burn_time + 1.0  # past threshold: unlit decay runs first
		get_tree().quit()
		return
	# fall mode needs the ride guard (1s) + death beat (0.45s) to play out first
	var delay := 2.5 if OS.get_environment("R2_SHOT_FALL") != "" else 1.0
	await get_tree().create_timer(delay).timeout
	print("SHOT curi=", _curi.global_position, " island=", _chunk.global_position,
			" state=", _chunk.state, " visible=", _curi.visible)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


# Realm 1's death beat, verbatim rules: eye closes, respawn with full health;
# last eye → whole scene restarts.
func _die() -> void:
	if _dying or _leaving:
		return
	_dying = true
	if _curi.has_method("hurt"):
		_curi.hurt()
	var remaining: int = 99 if _soak else _lives.lose_eye()
	await get_tree().create_timer(0.45).timeout
	if remaining <= 0:
		get_tree().reload_current_scene()
		return
	# respawn: on the island if it's flying, else back on solid ground
	if _chunk.state != LevitatingIsland.State.IDLE:
		_curi.global_position = _chunk.global_position + Vector2(0, -170)
	else:
		_curi.position = Vector2(clampf(_curi.position.x, -600.0, 2100.0), FLOOR_Y - 140.0)
	_curi.velocity = Vector2.ZERO
	if _curi.has_method("refill_health"):
		_curi.refill_health()
	# the respawn reads as a blink: Curiosity's own invulnerability flicker
	if _curi.has_method("grant_invuln"):
		_curi.grant_invuln(1.6)
	# a fall clears the deck: live orbs vanish, any moth withdraws, and the
	# wizard resets his cast pacing. The escalation does NOT restart from
	# zero — once the moth phase has begun, the next one is only a short
	# grace away (Advika's spec).
	for orb in get_tree().get_nodes_in_group("hazards"):
		orb.queue_free()
	for m in get_tree().get_nodes_in_group("moths"):
		m.queue_free()
	if _wizard != null and is_instance_valid(_wizard):
		_wizard.reset_pacing()
	if _moth_phase_begun:
		_moth_timer = moth_regrace
	_dying = false


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_return_to_hub()
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


# The conjurer takes the island: the wizard blinks in standing on the far
# end AS A CHILD OF THE CHUNK (teleports land in island-local space, the
# climb carries him), then begins the trial — teleport, conjure, repeat —
# until Curiosity's blade finds him. Instant (no flicker) for the harness.
func _spawn_wizard(instant := false) -> void:
	if _wizard != null:
		return
	_wizard = WIZARD_SCENE.instantiate()
	_wizard.scale = Vector2(WIZARD_SCALE, WIZARD_SCALE)
	_wizard.hover_amplitude = 0.0  # planted on the moss — the island carries him
	_wizard.position = WIZARD_OFFSET
	_chunk.add_child(_wizard)
	_wizard.watch(_curi)
	_wizard.configure_trial(WIZARD_TRIAL_HALF_X, WIZARD_OFFSET.y)
	# hard-mode temperament (see the difficulty consts)
	_wizard.trial_idle_min = WIZ_IDLE_MIN
	_wizard.trial_idle_max = WIZ_IDLE_MAX
	_wizard.escape_range = WIZ_ESCAPE_RANGE
	_wizard.escape_grace = WIZ_ESCAPE_GRACE
	# the storm answers its author: the island pitches harder under everyone
	_chunk.sway_amplitude = STORM_SWAY_AMP
	_chunk.sway_period = STORM_SWAY_PERIOD
	# His cast births an orb in front of him, on the island's deck. Fallen
	# orbs despawn by airborne_lifetime — the island's height is ever-changing.
	_wizard.cast_committed.connect(func(pos: Vector2) -> void:
		OrbSpawner.conjure_orb(_chunk, _chunk.to_local(pos), self, ORB_SCALE,
				_wizard.facing_dir()))  # the orb rolls the way it was cast
	# THE BOSS GATE: his fall is what finally stops the climb — and releases
	# the moth pressure: a live moth loses interest and flies off upward.
	_wizard.died.connect(func() -> void:
		_chunk.stop_levitation()
		_moth_timer = -1.0
		# the flock loses interest — every live moth leaves, upward and gone
		for m in get_tree().get_nodes_in_group("moths"):
			if m is VoidMoth:
				m.exit_flyaway())
	if instant:
		_wizard.appear_instant()
		_wizard.start_trial()
		_moth_timer = moth_first_delay
	else:
		_wizard.materialize()
		# One breath after the flicker settles, the trial begins — and the
		# void's own clock starts with it.
		_wizard.materialized.connect(func() -> void:
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				if _wizard != null and is_instance_valid(_wizard):
					_wizard.start_trial()
					_moth_timer = moth_first_delay))


# A moth arrives BY FLYING IN: spawned off-screen — from the void beneath
# the island (70%, the thematic entrance) or swooping from above — then a
# curved 1.2s approach to a hover post near the deck. Harmless until it
# lands; then the stalk begins. Arrivals stagger until the cap is aloft;
# every light-kill re-arms the pressure timer.
func _spawn_moth() -> void:
	_moth_phase_begun = true
	var moth: VoidMoth = VOID_MOTH.instantiate()
	moth.scale = Vector2(MOTH_SCALE, MOTH_SCALE)
	add_child(moth)
	# from-below entries start OUTSIDE the island's span, so the rise passes
	# its side and curves in — never through the deck's body
	var from_below := randf() < MOTH_FROM_BELOW_P
	var sx := (1.0 if randf() < 0.5 else -1.0) * randf_range(700.0, 950.0) if from_below \
			else randf_range(-500.0, 500.0)
	var spawn: Vector2 = _chunk.global_position \
			+ (Vector2(sx, 950.0) if from_below else Vector2(sx, -1000.0))
	# each moth claims its own first post so the flock spreads, not stacks;
	# below-entries post on their OWN side so the approach never needs to
	# cross the island's body
	var hover := Vector2(signf(sx) * randf_range(260.0, 430.0), randf_range(-420.0, -260.0)) \
			if from_below else Vector2(randf_range(-400.0, 400.0), randf_range(-420.0, -260.0))
	moth.enter_from(spawn, _chunk, hover, _curi)
	moth.died_to_light.connect(func() -> void:
		print("[VoidMoth] unmade by the light")
		if moth_respawn_pressure and _wizard != null and is_instance_valid(_wizard) \
				and not _wizard._dead:
			_moth_timer = moth_respawn_delay)
	# more to come until the cap flies
	_moth_timer = MOTH_STAGGER if get_tree().get_nodes_in_group("moths").size() < moth_cap else -1.0
	print("[VoidMoth] inbound (%s)" % ("from below" if spawn.y > _chunk.global_position.y else "from above"))


func _return_to_hub() -> void:
	if _leaving:
		return
	_leaving = true
	# Transition.last_door_id was set by Door2 on the way in and hub-bound
	# trips leave it intact, so the Hub respawns Curiosity under Door2.
	Transition.transition_to(HUB_SCENE)


func _set_phase(p: Phase) -> void:
	phase = p
	_pt = 0.0
	match p:
		Phase.BUILD:
			_lbl.text = "the wind is changing…"
		Phase.RIDE:
			_trauma = 1.0
		Phase.DONE:
			_lbl.text = "the wizard falls — the storm relents   (R restart · ESC hub)"
			print("trial complete")


func _physics_process(delta: float) -> void:
	# AnimatableBody2D with sync_to_physics MUST be moved here, not _process.
	_pt += delta
	match phase:
		Phase.INTRO:
			# trigger: Curiosity steps onto the chunk region
			if _curi.global_position.x > CHUNK_X - 260.0:
				_set_phase(Phase.BUILD)
		Phase.BUILD:
			var k := clampf(_pt / 5.0, 0.0, 1.0)
			_bg.set_storm(k * 0.85)
			_trauma = maxf(_trauma, k * 0.55)
			if _pt >= 5.0:
				_chunk.start_levitation()  # island owns shake/debris/ascent now
				_set_phase(Phase.RIDE)
		Phase.RIDE:
			_bg.set_storm(0.8)
			_trauma = maxf(_trauma, 0.15)
			# the wizard appears once the island has truly been in the sky a beat
			if _wizard == null and _chunk.state == LevitatingIsland.State.RISING:
				_airborne_t += delta
				if _airborne_t >= WIZARD_APPEAR_DELAY:
					_spawn_wizard()
			# the void moths keep their own clock — they are no one's conjuration.
			# They build up staggered until the cap flies together.
			if _moth_timer > 0.0 \
					and get_tree().get_nodes_in_group("moths").size() < moth_cap \
					and _wizard != null and is_instance_valid(_wizard) and not _wizard._dead:
				_moth_timer -= delta
				if _moth_timer <= 0.0:
					_spawn_moth()
			# the trial's difficulty dials ride on every live orb — and so does
			# the KILL PLANE: a fallen orb must die once it's clearly gone, or
			# it lands on the old intro ground far below and squats in the
			# "hazards" group forever, wedging the wizard's max-2 cap (the
			# "he stops conjuring" bug). 900px under the deck is off-frame.
			for orb in get_tree().get_nodes_in_group("hazards"):
				if orb is RuneOrb:
					if not orb.has_meta("tuned"):
						orb.set_meta("tuned", true)
						orb.roll_speed = ORB_ROLL_SPEED
						orb.reverse_time_min = ORB_REVERSE_MIN
						orb.reverse_time_max = ORB_REVERSE_MAX
						orb.push_force = ORB_PUSH_FORCE
						orb.push_cooldown = ORB_PUSH_COOLDOWN
						orb.seek_bias = ORB_SEEK_BIAS
						orb.set_leave_window(ORB_LEAVE_MIN, ORB_LEAVE_MAX)
					orb.kill_y = _chunk.global_position.y + 900.0
			# fell off mid-ascent: the fall plays out PAST the bottom of the frame
			# (view half-height is 1080/(2*zoom) ≈ 635px), THEN the eye closes and
			# the respawn blinks in. Frame-relative so it can never strand the hero
			# on the old ground while the island sails away.
			# _pt guard: never fire in the ride's first moments (spawn/settle race).
			if _pt > 1.0 and _curi.global_position.y > _cam.global_position.y + 700.0:
				_die()
		Phase.DONE:
			# only reachable via the wizard's defeat (R2-M7 wires
			# _chunk.stop_levitation()); the island hovers, storm relents.
			_bg.set_storm(0.35)
			# walking off the hovering island is a fall like any other
			if _curi.global_position.y > _cam.global_position.y + 700.0:
				_die()


func _process(delta: float) -> void:
	_t += delta
	_trauma = maxf(_trauma - delta * 0.8, 0.0)

	# the corridor breathes AND recycles: overhang assemblies bob + tilt, and
	# any assembly a screen below the camera wraps to above the view shifted
	# by the pass's full span — the endless climb never reaches a bare
	# stretch. (hanger leaf-bending is the storm sway shader, on the GPU.)
	var cam_y := _cam.global_position.y
	for d in _dress_bobs:
		if d.base_y > cam_y + 1400.0:
			d.base_y -= d.wrap
		(d.n as Node2D).position.y = d.base_y + sin(_t * d.rate + d.ph) * d.amp
		if d.rot_amp > 0.0:
			(d.n as Node2D).rotation = d.base_rot \
					+ sin(_t * d.rate * 0.7 + d.ph) * d.rot_amp

	# chunk glow: still faint ember while embedded, breathes once awake
	if _chunk_glow:
		var breath := 0.82 + sin(_t * 1.1) * 0.1 + sin(_t * 1.7 + 1.3) * 0.06
		_chunk_glow.modulate.a = lerpf(0.10, breath, _wake)

	# camera: ours until the island wakes, then the island drives it
	if _chunk.state == LevitatingIsland.State.IDLE:
		var target := Vector2(
			clampf(_curi.global_position.x, -450.0, CHUNK_X + 250.0),
			clampf(_curi.global_position.y - 130.0, LIFT_TOP_Y - 200.0, FLOOR_Y - 220.0))
		_cam.position = _cam.position.lerp(target, 1.0 - pow(0.001, delta))
		var sh := _trauma * _trauma
		_cam.offset = Vector2(
			randf_range(-1.0, 1.0) * 16.0 * sh,
			randf_range(-1.0, 1.0) * 12.0 * sh)
		_cam.rotation = randf_range(-1.0, 1.0) * 0.012 * sh
