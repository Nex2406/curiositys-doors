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
## R2_SHOT env: screenshot at 1s + quit. R2_SHOT_LIFT: jump to mid-ascent first.

const BASE := "res://assets/realms/realm2_moss/"
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
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


func _ready() -> void:
	_bg = Realm2Background.new()
	_bg.include_chunk = false  # OUR chunk is a physics body, not decor
	add_child(_bg)
	_build_ground()
	_build_ascent_dressing()
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
		for i in n_hang:
			var hb := rng.randf() < 0.45
			var ht: Texture2D = beards[rng.randi() % beards.size()] if hb \
					else ferns[rng.randi() % ferns.size()]
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
	# `arrived` only fires from stop_levitation() — the wizard's defeat (R2-M7)


func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = Vector2(150, FLOOR_Y - 120)
	# the world is authored at 1080-scale; shrink the hero to stand ~110px tall
	_curi.scale = Vector2(0.24, 0.24)
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
	_lbl.text = "R2-M1 LIFT TEST — walk right →   (R restart · ESC hub)"
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
	var remaining: int = _lives.lose_eye()
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
	_dying = false


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		_return_to_hub()
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


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
			_lbl.text = "above the canopy — R2-M1 complete   (R restart · ESC hub)"


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
