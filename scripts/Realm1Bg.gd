extends RefCounted
## Consumers: `const Realm1Bg := preload("res://scripts/Realm1Bg.gd")` —
## no class_name, so fresh headless runs never hit a stale class cache.
## Shared builder for the Realm 1 cave background — the fused-strip
## parallax stack + diagonal fog spill + drifting mist that passed Advika's
## eye (2026-07-22). Any Realm 1 scene calls `Realm1Bg.build(host)` and
## gets the identical background; tuning lives HERE, in one place.

const CUT := "res://assets/realms/realm1_cut/"
const SOFT := "res://assets/realms/realm1_soft/"
const SPAN := 5200.0

## STEP 6 (Advika's spec): animated vegetation. Six sequences from the
## PlantsAnimated pack, baked into grid sheets by tools/pack_plant_sheets.gd.
## name -> [sheet_file, frame_w, frame_h, count, cols] (mirror the packer).
const VEG_SHEETS := "res://assets/realms/realm1_plants/sheets/"
const VEG_SPEC := {
	"comp1":      ["comp1.png", 256, 256, 30, 16],
	"grass2":     ["grass2.png", 256, 256, 30, 16],
	"grass3":     ["grass3.png", 256, 512, 30, 16],
	"grass4":     ["grass4.png", 256, 512, 30, 16],
	"grass5":     ["grass5.png", 410, 410, 40,  8],
	"groupplant": ["groupplant.png", 512, 256, 45, 8],
}
## the three tall sequences that read as vines when hung upside down
const VEG_VINES: Array[String] = ["grass3", "grass4", "grass5"]
## fraction DOWN each frame where the plant's VISIBLE base sits (measured from
## the sheets). Lets make_plant root a plant so its real base — not the sprite's
## transparent bottom edge — lands on the surface. Without this the base floats.
const VEG_BASE := {
	"comp1": 0.836, "grass2": 0.805, "grass3": 0.838,
	"grass4": 0.830, "grass5": 0.924, "groupplant": 0.883,
}
static var _veg_cache := {}
## live tally so any scene can report its vegetation instance count
static var veg_instance_count := 0

## SpriteFrames for one sequence, sliced from its grid sheet as AtlasTextures
## (one shared base texture per sheet). loop = true, default fps 12.
static func veg_frames(name: String) -> SpriteFrames:
	if _veg_cache.has(name):
		return _veg_cache[name]
	var spec: Array = VEG_SPEC[name]
	var base: Texture2D = load(VEG_SHEETS + spec[0])
	var fw: int = spec[1]
	var fh: int = spec[2]
	var count: int = spec[3]
	var cols: int = spec[4]
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", true)
	sf.set_animation_speed("default", 12.0)
	for i in range(count):
		var at := AtlasTexture.new()
		at.atlas = base
		at.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		at.filter_clip = true
		sf.add_frame("default", at)
	_veg_cache[name] = sf
	return sf

## one animated plant with its OWN random frame / speed / horizontal flip —
## the single most important part of step 6: without per-instance variation
## every plant sways in perfect lockstep and reads worse than static. `tint`
## is the layer colour it sits on; `flip_v` + `top_anchor` make a hanging
## vine that roots at `pos` and falls `height` px downward.
static func make_plant(name: String, pos: Vector2, height: float, tint: Color,
		z: int, rng: RandomNumberGenerator, flip_v := false,
		top_anchor := false, root_base := false, bury := 12.0) -> AnimatedSprite2D:
	var sf := veg_frames(name)
	var count := sf.get_frame_count("default")
	var native_h: float = VEG_SPEC[name][2]
	var sc := height / native_h
	var an := AnimatedSprite2D.new()
	an.sprite_frames = sf
	an.z_index = z
	an.modulate = tint
	# --- per-instance randomization (no lockstep) ---
	an.frame = rng.randi() % count
	an.speed_scale = rng.randf_range(0.7, 1.15)
	var flip_h := rng.randi() % 2 == 0
	an.scale = Vector2(-sc if flip_h else sc, -sc if flip_v else sc)
	var cy: float
	if root_base:
		# put the VISIBLE base `bury` px below pos.y (into the rock), using the
		# measured base fraction — never the sprite's transparent bottom.
		var bf: float = VEG_BASE.get(name, 0.83)
		cy = (pos.y + bury) - height * (bf - 0.5)
	elif top_anchor:
		cy = pos.y + height * 0.5
	else:
		cy = pos.y
	an.position = Vector2(pos.x, cy)
	an.play("default")
	veg_instance_count += 1
	return an

## every fog-driven material registers here so the wandering light can
## move them all in lockstep (backdrop, bands, platforms)
static var fog_mats: Array = []
static func build(host: Node2D) -> void:
	var cache := {}
	fog_mats.clear()
	veg_instance_count = 0
	RenderingServer.set_default_clear_color(Color(0.020, 0.024, 0.016))
	# fog spill backdrop
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = -100
	host.add_child(fog_layer)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fmat := ShaderMaterial.new()
	fmat.shader = load("res://shaders/cave_fog_spill.gdshader")
	fog.material = fmat
	fog_layer.add_child(fog)
	fog_mats.append(fmat)
	# band strips
	var pb := ParallaxBackground.new()
	pb.layer = -50
	host.add_child(pb)
	_backdrop(pb)
	_bg_near(host, pb)
	_strip(pb, cache, 0.15, "band_far.png", 1.03, 0.12, Vector3(1.0, 1.2, 0.75))
	_strip(pb, cache, 0.35, "band_spires.png", 0.85, 0.65, Vector3(1.10, 0.95, 0.80))
	_shafts(host, pb)
	var noise := _noise()
	_mist(pb, noise, 0.020, 0.14, 0.0)
	_strip(pb, cache, 0.60, "band_mid.png", 0.55, 0.60, Vector3(1.05, 0.90, 0.80))
	_mist(pb, noise, -0.034, 0.10, 0.45)
	_mist(pb, noise, 0.048, 0.07, 0.8)
	# floor fog river: dense low mist rolling along the bottom
	var river := _mist(pb, noise, 0.06, 0.17, 1.3)
	river.material.set_shader_parameter("band_zone", Vector4(0.55, 0.82, 1.2, 1.0))
	_motes(pb)
	_glow_pulse(host, pb)
	_drips(pb)
	# ROCK NEVER MOVES (lesson of 2026-07-22: heaving bands look silly).
	# Motion belongs to fog, particles, plants — and the light, which
	# wanders only a whisper so shadows creep without reading as a spotlight
	# STEP 1 CORRECTION (Advika): only the backdrop shows. Every other
	# background/midground layer hidden (NOT deleted) — re-enabled in step 4.
	fog_layer.visible = false
	for child in pb.get_children():
		if child.name != "bg_backdrop" and child.name != "bg_backdrop_far" \
				and child.name != "bg_backdrop_mid" and child.name != "bg_near" \
				and not str(child.name).begins_with("bg_columns") \
				and not str(child.name).begins_with("bg_dust") \
				and not str(child.name).begins_with("bg_haze"):
			child.visible = false
	_depth_columns(pb, cache)
	_depth_dust(pb)
	_cave_mist(host, noise)
	var wander := host.create_tween().set_loops()
	wander.tween_method(_set_fog_center, Vector2(0.20, 0.28),
			Vector2(0.218, 0.295), 14.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wander.tween_method(_set_fog_center, Vector2(0.218, 0.295),
			Vector2(0.20, 0.28), 12.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_frame(host)
	_glow_motes(host)
	_vignette(host)


## STEP 4/7 (Advika's spec): ONE near background band, low, on a shared
## ridgeline at 0.90 * viewport height — the ridgeline rule makes it read
## as one plane. Middle 30% stays sparse (load-bearing emptiness). Dark
## warm ramp keeps it under the backdrop's values so depth never inverts.
static func _bg_near(host: Node2D, pb: ParallaxBackground) -> void:
	var vs := host.get_viewport().get_visible_rect().size
	var kx := vs.x / 1920.0
	var pl := ParallaxLayer.new()
	pl.name = "bg_near"
	pl.motion_scale = Vector2(0.68, 0.55)
	pl.motion_mirroring = Vector2(5200, 0)
	pb.add_child(pl)
	var grp := Node2D.new()
	grp.position = -Vector2(vs.x * 0.5 * 0.68, vs.y * 0.5 * 0.55)
	pl.add_child(grp)
	var ramp := ShaderMaterial.new()
	ramp.shader = load("res://shaders/band_ramp.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cache := {}
	var ridge := vs.y * 0.90
	var blobs: Array[String] = ["combo_00.png", "combo_03.png", "combo_05.png",
			"combo_07.png", "combo_10.png", "bigrock_02.png", "bigrock_06.png",
			"bigrock_08.png"]
	var spikes: Array[String] = ["rock_29.png", "rock_31.png", "rock_33.png",
			"rock_35.png", "rock_37.png"]
	# 8 overlapping blobs, full width EXCEPT the middle 30% (576..1344 clear)
	for bx0: float in [40.0, 200.0, 380.0, 545.0, 1350.0, 1510.0, 1680.0, 1865.0]:
		var bx := bx0 * kx
		var tex := _frame_tex(cache, blobs[rng.randi() % blobs.size()])
		var w := rng.randf_range(110.0, 190.0)
		var sc := w / float(tex.get_width())
		var h := float(tex.get_height()) * sc
		var frac := rng.randf_range(0.62, 0.86)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(sc, sc)
		s.flip_h = rng.randf() < 0.5
		s.position = Vector2(bx + rng.randf_range(-20.0, 20.0),
				ridge + h * (0.5 - frac))
		s.material = ramp
		grp.add_child(s)
	# (band stalagmites removed — they read as lone floaters)
	# the band's own whisper of haze — this layer only
	var fogr := ColorRect.new()
	fogr.position = Vector2(-2600, -220)
	fogr.size = Vector2(5200, 1520)
	fogr.color = Color(0.114, 0.075, 0.035, 0.07)   # #1d1309 @ 0.07, Mix
	grp.add_child(fogr)


## STEP 3/7 (Advika's spec): the silhouette FRAME — the camera looks
## THROUGH a hole in the rock. Pure black cutout (#040302 via layer
## modulate), 1.1px DOF blur on the whole layer, centre stays empty.
## Left wall integrates with the scene's existing wall rock (edge blobs
## overlap it rather than doubling a second wall).
static func _frame(host: Node2D) -> void:
	# FIXED design resolution — the ceiling's geometry is world-absolute, so it is
	# IDENTICAL at every window size. (Authoring it against the live viewport made it
	# shrink/shift on any non-1920x1080 window and drift off the world-space cliffs.)
	var vs := Vector2(1920.0, 1080.0)
	# The cave FRAME (ceiling) lives in WORLD space, exactly like the closing cliffs
	# and the platforms — NOT on a ParallaxBackground (which re-centers by the live
	# window) and NOT sized to the window. Anything window-relative slid off the
	# world-space cliffs as the camera panned or the window resized, unsealing the
	# top corner (visible even in "fullscreen" when it isn't 1920x1080). World-
	# absolute = the whole cave outline is one rigid piece; the corners always seal.
	var grp := Node2D.new()
	grp.name = "fg_frame"
	grp.z_index = 40                 # in front of platforms, like a foreground frame
	grp.modulate = Color("665033")   # lighten the ceiling rock off pure black
	grp.position = Vector2(0.0, -600.0)   # raised a touch for platform headroom under the roof
	host.add_child(grp)
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = load("res://shaders/frame_blur.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cache := {}
	var spikes: Array[String] = ["rock_29.png", "rock_31.png", "rock_33.png",
			"rock_35.png", "rock_37.png"]
	var blobs: Array[String] = ["combo_00.png", "combo_03.png", "combo_07.png",
			"combo_10.png", "bigrock_02.png", "bigrock_06.png", "bigrock_08.png"]
	# STEP 6 rebuild (Advika 2026-07-25): a THICK collapsing roof — giant
	# clustered rocks wall-to-wall across the WHOLE level. The old ceiling ran
	# dry at half and read thin/pathetic; C_MAX covers the fg_frame's 1.35x
	# parallax over the ~9000px level so it never runs out.
	var C_MIN := -1200.0
	var C_MAX := 15000.0
	var clump_pool: Array[String] = ["combo_00.png", "combo_01.png",
			"combo_03.png", "combo_04.png", "combo_05.png", "combo_06.png",
			"combo_07.png", "combo_08.png", "combo_09.png", "combo_10.png",
			"combo_11.png", "bigrock_02.png", "bigrock_06.png", "bigrock_08.png"]
	# SOLID roof band — reaches deep enough (13% of height) that the upper zone
	# is fully opaque, so no backdrop light peeks through the ceiling there. The
	# hanging masses below just add the ragged rocky underside. (Advika: NO gaps.)
	var band := ColorRect.new()
	band.position = Vector2(C_MIN, -340.0)
	band.size = Vector2(C_MAX - C_MIN, 340.0 + vs.y * 0.095)
	band.color = Color(0.10, 0.075, 0.052)
	grp.add_child(band)
	var band_b := vs.y * 0.095   # Advika: pushed the roof UP a bit
	var ceiling_count := 0
	# HEM: a dense row of rock straddling the band's bottom edge. The band is a solid
	# rectangle, and wherever the hanging masses left a gap its straight bottom edge
	# showed through as a black bar under the roof (Advika 2026-07-27: "get rid of
	# this rectangle thing on the ceiling"). Tight spacing means no straight edge is
	# ever exposed, whatever the masses above happen to do.
	var hem_pool: Array[String] = ["combo_00.png", "combo_03.png", "combo_07.png",
			"combo_10.png", "bigrock_02.png", "bigrock_08.png", "combo_05.png"]
	var hx := C_MIN
	var hi := 0
	while hx < C_MAX:
		var htex := _frame_tex(cache, hem_pool[hi % hem_pool.size()])
		var hh := rng.randf_range(130.0, 210.0)
		var hsc := hh / float(htex.get_height())
		var hs := Sprite2D.new()
		hs.texture = htex
		hs.flip_v = true
		hs.flip_h = rng.randf() < 0.5
		hs.scale = Vector2(hsc * rng.randf_range(1.2, 1.9), hsc)
		# centred ON the edge, so the rock sits half above and half below it
		hs.position = Vector2(hx + rng.randf_range(-24.0, 24.0),
				band_b - hh * rng.randf_range(0.12, 0.34))
		hs.material = blur_mat
		grp.add_child(hs)
		ceiling_count += 1
		hx += rng.randf_range(58.0, 94.0)
	# Advika 2026-07-26: above the hanging masses the solid band showed as a flat
	# BLACK bar across the top of the screen — the stretch aspect is "expand", so a
	# window taller than 16:9 reveals more world and exposes it. Pack the band with
	# real rock so the roof reads as thick textured stone right off the top edge of
	# any window. These go in FIRST, so every hanging mass still draws over them.
	# 5 rows: fullscreen and tall windows reveal more world above the roof line, and
	# 3 rows still left a dark strip along the very top (Advika 2026-07-27).
	for row in range(5):
		var fy := band_b - 30.0 - float(row) * 150.0
		var fx := C_MIN
		var fi := row
		while fx < C_MAX:
			var ftex := _frame_tex(cache, clump_pool[fi % clump_pool.size()])
			var fh := rng.randf_range(210.0, 320.0)
			var fsc := fh / float(ftex.get_height())
			var f := Sprite2D.new()
			f.texture = ftex
			f.flip_v = rng.randf() < 0.5
			f.flip_h = rng.randf() < 0.5
			f.scale = Vector2(fsc * rng.randf_range(1.4, 2.1), fsc)
			f.position = Vector2(fx + rng.randf_range(-40.0, 40.0),
					fy + rng.randf_range(-28.0, 28.0))
			f.material = blur_mat
			grp.add_child(f)
			ceiling_count += 1
			fx += ftex.get_width() * fsc * rng.randf_range(0.55, 0.78)
			fi += 1
	var clump_spots: Array = []
	# Advika 2026-07-25: the roof read UGLY because every clump was the same
	# round lump at the same size. Now three distinct classes are mixed —
	# chunky broad bigrock giants, round combo clumps, and pointed elongated
	# stalactites — each with its OWN height / vertical-stretch / hang-depth /
	# width range, so the skyline is ragged and varied, never repetitive. All
	# tops are buried in the solid roof band, so nothing hangs detached.
	var round_pool: Array[String] = ["combo_00.png", "combo_01.png",
			"combo_03.png", "combo_04.png", "combo_05.png", "combo_06.png",
			"combo_07.png", "combo_09.png", "combo_10.png"]
	var chunk_pool: Array[String] = ["bigrock_02.png", "bigrock_06.png",
			"bigrock_08.png", "combo_08.png", "combo_11.png"]
	var cx := C_MIN
	while cx < C_MAX:
		var roll := rng.randf()
		var tex: Texture2D
		var h: float
		var stretch: float
		var widen: float
		var bottom_y: float
		# Advika 2026-07-25 (r1 pass 3): each mass is placed by where its BOTTOM
		# hangs to (moderate for rounded masses, deeper for the spikes she likes),
		# then its TOP is clamped so it always buries >=25px into the solid band.
		# That means no mass can leave a bright gap up to the band. SHAPE varies.
		if roll < 0.16:
			# pointed stalactite — a SPARSE accent on the bottom edge (kept few so
			# they never leave bright gaps between them)
			tex = _frame_tex(cache, spikes[rng.randi() % spikes.size()])
			h = rng.randf_range(150.0, 220.0)
			stretch = rng.randf_range(1.25, 1.55)
			widen = rng.randf_range(0.8, 1.1)
			bottom_y = rng.randf_range(vs.y * 0.24, vs.y * 0.32)
		elif roll < 0.58:
			# chunky bigrock giant — BROAD so neighbours overlap into a solid body
			tex = _frame_tex(cache, chunk_pool[rng.randi() % chunk_pool.size()])
			h = rng.randf_range(200.0, 290.0)
			stretch = rng.randf_range(0.9, 1.1)
			widen = rng.randf_range(1.6, 2.2)
			bottom_y = rng.randf_range(vs.y * 0.18, vs.y * 0.26)
		else:
			# round combo clump — WIDE + lumpy, fills between the giants
			tex = _frame_tex(cache, round_pool[rng.randi() % round_pool.size()])
			h = rng.randf_range(170.0, 240.0)
			stretch = rng.randf_range(0.9, 1.12)
			widen = rng.randf_range(1.2, 1.7)
			bottom_y = rng.randf_range(vs.y * 0.16, vs.y * 0.24)
		var sc := h / float(tex.get_height())
		var rh := h * stretch   # rendered height
		var s := Sprite2D.new()
		s.texture = tex
		s.flip_v = true
		s.flip_h = rng.randf() < 0.5
		s.scale = Vector2(sc * widen, sc * stretch)
		# bottom at bottom_y, but pull up so the top is buried >=25px in the band
		var cy := minf(bottom_y - rh * 0.5, band_b - 25.0 + rh * 0.5)
		s.position = Vector2(cx + rng.randf_range(-45.0, 45.0), cy)
		s.material = blur_mat
		grp.add_child(s)
		clump_spots.append(Vector3(s.position.x, cy, rh))
		ceiling_count += 1
		cx += rng.randf_range(70.0, 115.0)   # very dense — masses overlap solid
	# mid filler jammed between the giants — thickens the cluster and closes
	# any gap, scaled to the full span so density holds the whole level
	for i in range(int((C_MAX - C_MIN) / 105.0)):
		var base: Vector3 = clump_spots[rng.randi() % clump_spots.size()]
		var mid_is_clump := rng.randf() < 0.7
		var h2 := rng.randf_range(120.0, 210.0)
		var tex2: Texture2D
		if mid_is_clump:
			tex2 = _frame_tex(cache, clump_pool[rng.randi() % clump_pool.size()])
		else:
			tex2 = _frame_tex(cache, spikes[rng.randi() % spikes.size()])
		var sc2 := h2 / float(tex2.get_height())
		var s2 := Sprite2D.new()
		s2.texture = tex2
		s2.flip_v = true
		s2.flip_h = rng.randf() < 0.5
		s2.scale = Vector2(sc2 * rng.randf_range(1.15, 1.8), sc2)
		s2.position = Vector2(base.x + rng.randf_range(-90.0, 90.0),
				band_b + h2 * 0.5 - rng.randf_range(40.0, 90.0))
		s2.material = blur_mat
		grp.add_child(s2)
		ceiling_count += 1
	# small shards tucked under the bellies for a ragged hanging edge
	for i in range(int((C_MAX - C_MIN) / 400.0)):
		var h3 := rng.randf_range(35.0, 80.0)
		var tex3 := _frame_tex(cache, spikes[rng.randi() % spikes.size()])
		var sc3 := h3 / float(tex3.get_height())
		var s3 := Sprite2D.new()
		s3.texture = tex3
		s3.flip_v = true
		s3.flip_h = rng.randf() < 0.5
		s3.scale = Vector2(sc3 * rng.randf_range(0.8, 1.2), sc3)
		var b2: Vector3 = clump_spots[rng.randi() % clump_spots.size()]
		s3.position = Vector2(b2.x + rng.randf_range(-b2.z * 0.28, b2.z * 0.28),
				b2.y + b2.z * rng.randf_range(0.05, 0.22))
		s3.material = blur_mat
		grp.add_child(s3)
		ceiling_count += 1
	# (Advika 2026-07-25: ceiling vines REMOVED — grass draping off the roof read
	# as plants floating in air, which she does not want anywhere.)
	print("ceiling pieces: ", ceiling_count)
	# left + right walls: backing columns (gap-proof) + 5 blobs per side,
	# roughly half of each hanging off-screen
	# WALLS moved to world-space level-end geometry (step 6b fix: at
	# motion 1.35 they swept across mid-level as black slabs)
	# (Advika 2026-07-25: the bottom fg-frame plants + hanging ceiling vines
	# were removed — they sat in the 1.35x frame layer / dangled in open air
	# and read as FLOATING plants. All vegetation now lives grounded in the
	# ground + platform assemblies.)


## Imported resource first — see the note on Realm1PlatformTest._tex: loading art by
## FILE PATH works in the editor and returns null in an exported build, which left the
## live web build with a cave made of nothing.
static func _frame_tex(cache: Dictionary, tex_name: String) -> Texture2D:
	if not cache.has(tex_name):
		var t: Texture2D = load(CUT + tex_name)
		if t == null:
			var img := Image.load_from_file(
					ProjectSettings.globalize_path(CUT + tex_name))
			if img != null:
				t = ImageTexture.create_from_image(img)
		cache[tex_name] = t
	return cache[tex_name]


## STEP 2/7 (Advika's spec): the vignette — hard elliptical falloff,
## corners near-black, centre untouched. Anchored Full Rect so it tracks
## viewport resizes.
static func _vignette(host: Node2D) -> void:
	var cl := CanvasLayer.new()
	cl.name = "vignette_layer"
	cl.layer = 100
	host.add_child(cl)
	var r := ColorRect.new()
	r.name = "vignette"
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette_gold.gdshader")
	r.material = mat
	cl.add_child(r)


## STEP 1/7 (Advika's spec 2026-07-22): the painted gold backdrop —
## Tunnel 11 raw, her grade shader does all colour work. Furthest layer,
## NO tiling/mirroring (baked vanishing point; a repeat seam would show).
## Position: the painting's lower third sits on the level's horizon line.
## NOTE for the real level: clamp this layer at both level ends (the spec's
## ~2900px of covered camera travel) — the gallery has no ends yet.
static func _backdrop(pb: ParallaxBackground) -> void:
	# TWO-DEEP painted parallax (Advika: bg felt flat): a slower, hazier,
	# larger copy of the tunnel far behind, and the main graded copy in
	# front at a faster motion so the arches slide against the platforms.
	# Both tile with MIRRORING (odd copies flipped) — bright meets bright.
	var vs := pb.get_viewport().get_visible_rect().size
	var tex: Texture2D = load("res://assets/realms/realm1_backdrop/tunnel_11.png")
	var tw := float(tex.get_width())
	# far copy: motion 0.05, scale 1.15, extra blur + haze
	var pl_far := ParallaxLayer.new()
	pl_far.name = "bg_backdrop_far"
	pl_far.motion_scale = Vector2(0.05, 0.02)
	pb.add_child(pl_far)
	var mat_far := ShaderMaterial.new()
	mat_far.shader = load("res://shaders/backdrop_gold.gdshader")
	mat_far.set_shader_parameter("blur_lod", 4.5)
	mat_far.set_shader_parameter("fog_amount", 0.38)
	mat_far.set_shader_parameter("contrast", 0.5)
	var sc_far := 1.15
	var tw_far := tw * sc_far
	var base_far := -vs.x * 0.5 * 0.05
	var y_far := vs.y * 0.5 + 478.0 - 1024.0 * sc_far - vs.y * 0.5 * 0.02
	for k in range(-1, 4):
		var sf := Sprite2D.new()
		sf.texture = tex
		sf.centered = false
		sf.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sf.material = mat_far
		if absi(k) % 2 == 1:
			sf.scale = Vector2(-sc_far, sc_far)
			sf.position = Vector2(base_far + float(k + 1) * tw_far, y_far)
		else:
			sf.scale = Vector2(sc_far, sc_far)
			sf.position = Vector2(base_far + float(k) * tw_far, y_far)
		pl_far.add_child(sf)
	# MID copy (Advika C): a third depth plane between far and main. Scaled 1.09
	# and lifted a touch so its arches peek above/between the main copy — with
	# far (0.05), mid (0.15), main (0.30) + near band (0.68) + platforms (1.0),
	# panning now reveals five distinct depth rates instead of two.
	var pl_mid := ParallaxLayer.new()
	pl_mid.name = "bg_backdrop_mid"
	pl_mid.motion_scale = Vector2(0.15, 0.045)
	pb.add_child(pl_mid)
	var mat_mid := ShaderMaterial.new()
	mat_mid.shader = load("res://shaders/backdrop_gold.gdshader")
	mat_mid.set_shader_parameter("blur_lod", 4.0)
	mat_mid.set_shader_parameter("fog_amount", 0.32)
	mat_mid.set_shader_parameter("contrast", 0.56)
	var sc_mid := 1.09
	var tw_mid := tw * sc_mid
	var base_mid := -vs.x * 0.5 * 0.15
	var y_mid := vs.y * 0.5 + 478.0 - 1024.0 * sc_mid - vs.y * 0.5 * 0.045 - 26.0
	for k in range(-1, 4):
		var sm := Sprite2D.new()
		sm.texture = tex
		sm.centered = false
		sm.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sm.material = mat_mid
		if absi(k) % 2 == 1:
			sm.scale = Vector2(-sc_mid, sc_mid)
			sm.position = Vector2(base_mid + float(k + 1) * tw_mid, y_mid)
		else:
			sm.scale = Vector2(sc_mid, sc_mid)
			sm.position = Vector2(base_mid + float(k) * tw_mid, y_mid)
		pl_mid.add_child(sm)
	# main copy: motion 0.30 — visibly slides
	var pl := ParallaxLayer.new()
	pl.name = "bg_backdrop"
	pl.motion_scale = Vector2(0.30, 0.06)
	pb.add_child(pl)
	var base_x := -vs.x * 0.5 * 0.22
	var y := vs.y * 0.5 + 478.0 - 1024.0 - vs.y * 0.5 * 0.05
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/backdrop_gold.gdshader")
	for k in range(-1, 4):
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.material = mat
		if absi(k) % 2 == 1:
			s.scale = Vector2(-1, 1)
			s.position = Vector2(base_x + float(k + 1) * tw, y)
		else:
			s.position = Vector2(base_x + float(k) * tw, y)
		pl.add_child(s)
	# Advika 2026-07-25: slow autonomous drift so the backdrop BREATHES even
	# when the player stands still — the two layers slide at different rates,
	# so the arches shimmer with parallax life instead of sitting dead.
	var d_far := pb.create_tween().set_loops()
	d_far.tween_property(pl_far, "motion_offset", Vector2(40, 12), 23.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	d_far.tween_property(pl_far, "motion_offset", Vector2(-40, -12), 23.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var d_main := pb.create_tween().set_loops()
	d_main.tween_property(pl, "motion_offset", Vector2(-22, 7), 17.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	d_main.tween_property(pl, "motion_offset", Vector2(22, -7), 17.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Advika 2026-07-25 (more parallax): two drifting HAZE planes between the
	# backdrop and the platforms. Each crawls on its own (TIME) AND slides at
	# its own depth rate when the camera pans — real midground parallax, warm-
	# tinted to sit inside the amber backdrop. Kept visible by the build filter.
	var noise := _noise()
	for hz: Array in [["bg_haze_far", 0.34, 0.15, 0.9], ["bg_haze_near", 0.52, 0.12, 1.3]]:
		var hl := ParallaxLayer.new()
		hl.name = hz[0]
		hl.motion_scale = Vector2(hz[1], float(hz[1]) * 0.45)
		hl.motion_mirroring = Vector2(2600, 0)
		pb.add_child(hl)
		var hr := ColorRect.new()
		hr.position = Vector2(-1300, -260)
		hr.size = Vector2(2600, 1320)
		hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hm := ShaderMaterial.new()
		hm.shader = load("res://shaders/cave_mist.gdshader")
		hm.set_shader_parameter("noise_tex", noise)
		hm.set_shader_parameter("speed", float(hz[3]) * 0.01)
		hm.set_shader_parameter("strength", hz[2])
		hm.set_shader_parameter("tint", Vector3(0.34, 0.25, 0.14))
		hr.material = hm
		hl.add_child(hr)


static func _set_fog_center(v: Vector2) -> void:
	for m: ShaderMaterial in fog_mats:
		m.set_shader_parameter("center", v)


static func mass_mat(lift: float, detail: float,
		brighten := Vector3(1.0, 1.2, 0.75)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog_mass_screen.gdshader")
	mat.set_shader_parameter("lift", lift)
	mat.set_shader_parameter("detail", detail)
	mat.set_shader_parameter("brighten", brighten)
	fog_mats.append(mat)
	return mat


static func _strip(pb: ParallaxBackground, cache: Dictionary, motion: float,
		tex_name: String, lift: float, detail: float, brighten: Vector3) -> void:
	var pl := ParallaxLayer.new()
	pl.name = "bg_strip"   # kept visible (re-enabled midground parallax planes)
	pl.motion_scale = Vector2(motion, 0.15)   # low vertical so it never "heaves"
	pl.motion_mirroring = Vector2(SPAN, 0.0)
	pb.add_child(pl)
	var s := Sprite2D.new()
	if not cache.has(tex_name):
		var t: Texture2D = load(SOFT + tex_name)     # imported first; see _frame_tex
		if t == null:
			var img := Image.load_from_file(
					ProjectSettings.globalize_path(SOFT + tex_name))
			if img != null:
				t = ImageTexture.create_from_image(img)
		cache[tex_name] = t
	s.texture = cache[tex_name]
	s.centered = false
	s.position = Vector2(-SPAN * 0.5, -900.0)
	s.material = mass_mat(lift, detail, brighten)
	s.z_index = 1
	pl.add_child(s)


static func _glow_tex() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = grad
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


## faint light shafts leaking down the spill diagonal, slowly breathing —
## the mysterious aura's heartbeat
static func _shafts(host: Node2D, pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var beams: Array[Polygon2D] = []
	for b: Array in [
			[Vector2(-780, -560), Vector2(-600, -560), 1500.0, 0.13],
			[Vector2(-420, -560), Vector2(-330, -560), 1250.0, 0.085]]:
		var dirv := Vector2(cos(0.5), sin(0.5))
		var poly := Polygon2D.new()
		var a: Vector2 = b[0]
		var c: Vector2 = b[1]
		poly.polygon = PackedVector2Array([a, c,
				c + dirv * (b[2] as float) + Vector2(90, 0),
				a + dirv * (b[2] as float) - Vector2(30, 0)])
		poly.color = Color(0.55, 0.55, 0.33, b[3])
		poly.material = add_mat
		pl.add_child(poly)
		beams.append(poly)
	# slow asynchronous breathing
	var tw := host.create_tween().set_loops()
	tw.tween_property(beams[0], "modulate:a", 0.45, 4.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(beams[0], "modulate:a", 1.0, 5.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tw2 := host.create_tween().set_loops()
	tw2.tween_property(beams[1], "modulate:a", 0.35, 7.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(beams[1], "modulate:a", 1.0, 6.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## sparse dust motes drifting through the lit air — additive glints, slow
## as snowfall, alive even when the camera is still
## Drifting glowing MOTES (Advika 2026-07-25: "add hues / tiny glowing balls to
## make it feel alive"). Soft additive orbs in the realm hues — lantern amber,
## Curiosity violet, a cool teal — sparse + slow, each bobbing, swaying and
## flickering on its own phase, at mixed depths (some behind platforms, some in
## front) so the cave air feels populated and alive.
static func _glow_motes(host: Node2D) -> void:
	var layer := Node2D.new()
	layer.name = "glow_motes"
	host.add_child(layer)
	var tex := _glow_dot()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var hues: Array[Color] = [Color("f5b870"), Color("c79be0"), Color("7fb8a6"),
			Color("f0a860"), Color("b78fd6"), Color("9ad0c0"), Color("d6a0e8"),
			Color("ffcf8a"), Color("8ab4e0")]   # more hue variety (Advika)
	for i in range(150):
		var m := Sprite2D.new()
		m.texture = tex
		m.material = mat
		var hue: Color = hues[rng.randi() % hues.size()]
		# boost past 1.0 so the additive core reads as a real glow, even over the
		# lit backdrop; the halo keeps the hue
		hue = hue * 1.7
		var a0 := rng.randf_range(0.6, 1.0)
		hue.a = a0
		m.modulate = hue
		var sz := rng.randf_range(0.10, 0.28)
		m.scale = Vector2(sz, sz)
		m.z_index = 7 if rng.randf() < 0.28 else 3   # some foreground, most mid
		var x := rng.randf_range(-900.0, 9900.0)
		var y := rng.randf_range(70.0, 500.0)
		m.position = Vector2(x, y)
		layer.add_child(m)
		# slow bob + sway on its own period
		var bob := rng.randf_range(16.0, 42.0)
		var swy := rng.randf_range(10.0, 28.0)
		var dur := rng.randf_range(3.6, 7.2)
		var tw := host.create_tween().set_loops()
		tw.tween_property(m, "position", Vector2(x + swy, y - bob), dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(m, "position", Vector2(x - swy, y + bob), dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# gentle flicker
		var fa := host.create_tween().set_loops()
		fa.tween_property(m, "modulate:a", a0 * 0.35, rng.randf_range(1.1, 2.6)) \
				.set_trans(Tween.TRANS_SINE)
		fa.tween_property(m, "modulate:a", a0, rng.randf_range(1.1, 2.6)) \
				.set_trans(Tween.TRANS_SINE)


## a soft round glow sprite (radial falloff), built once and shared by the motes
static func _glow_dot() -> Texture2D:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := sz * 0.5
	for y in sz:
		for x in sz:
			var d := Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a   # soft, tight core with a faint halo
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


static func _motes(pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var p := GPUParticles2D.new()
	p.amount = 34
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.texture = _glow_tex()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add_mat
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1000, 520, 1)
	m.direction = Vector3(0.7, -0.3, 0)
	m.spread = 180.0
	m.initial_velocity_min = 4.0
	m.initial_velocity_max = 16.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.10
	m.scale_max = 0.38
	m.color = Color(0.85, 0.85, 0.55, 1.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.30),
			Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	pl.add_child(p)


## the glow pocket itself breathes — a soft additive pulse over the core
static func _glow_pulse(host: Node2D, pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var s := Sprite2D.new()
	s.texture = _glow_tex()
	s.position = Vector2(-576, -238)
	s.scale = Vector2(16, 13)
	s.modulate = Color(0.75, 0.75, 0.45, 0.05)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = add_mat
	pl.add_child(s)
	var tw := host.create_tween().set_loops()
	tw.tween_property(s, "modulate:a", 0.10, 4.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(s, "modulate:a", 0.025, 3.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## occasional glinting drips falling from the lit stretch of ceiling
static func _drips(pb: ParallaxBackground) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var p := GPUParticles2D.new()
	p.amount = 5
	p.lifetime = 1.5
	p.preprocess = 3.0
	p.texture = _glow_tex()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add_mat
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(550, 8, 1)
	m.gravity = Vector3(0, 900, 0)
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.0
	m.scale_min = 0.05
	m.scale_max = 0.09
	m.color = Color(0.85, 0.9, 0.6, 1.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55),
			Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	p.position = Vector2(-250, -430)
	pl.add_child(p)
	# hero motes: a few bigger, slower, brighter drifters in the light pocket
	var hero := GPUParticles2D.new()
	hero.amount = 8
	hero.lifetime = 20.0
	hero.preprocess = 20.0
	hero.texture = _glow_tex()
	hero.material = add_mat
	var hm := ParticleProcessMaterial.new()
	hm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	hm.emission_box_extents = Vector3(450, 300, 1)
	hm.gravity = Vector3.ZERO
	hm.initial_velocity_min = 2.0
	hm.initial_velocity_max = 8.0
	hm.spread = 180.0
	hm.direction = Vector3(0.7, -0.3, 0)
	hm.scale_min = 0.40
	hm.scale_max = 0.80
	hm.color = Color(0.85, 0.85, 0.55, 1.0)
	var hramp := Gradient.new()
	hramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	hramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.5),
			Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
	var hramp_tex := GradientTexture1D.new()
	hramp_tex.gradient = hramp
	hm.color_ramp = hramp_tex
	hero.process_material = hm
	hero.position = Vector2(-450, -150)
	pl.add_child(hero)


static func _noise() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = 0.006
	var ntex := NoiseTexture2D.new()
	ntex.noise = n
	ntex.seamless = true
	ntex.width = 512
	ntex.height = 512
	return ntex


## A MIDDLE depth between the painted backdrop (motion 0.05-0.30) and the near band
## (0.68): tall rock columns as flat silhouettes at 0.46, so walking slides them
## against both and the cavern reads as having room in it (Advika 2026-07-26: "make
## the background feel alive, add more parallax"). Deliberately low contrast and
## sparse — this is depth, not scenery, and it must never become the black slabs
## that got scrapped in step 6b.
static func _depth_columns(pb: ParallaxBackground, cache: Dictionary) -> void:
	# THREE depths of rock between the painted backdrop (0.05-0.30) and the near
	# band (0.68), each with its own speed, size, density and shade, so panning
	# separates them all (Advika 2026-07-26, twice: "add more parallax", "MORE
	# PARALLAX IN BG"). Far ones are big, pale and sparse; near ones smaller,
	# darker and busier — the standard depth cues, done with the cave's own rock.
	# name, motion, mirror span, height range, spacing, tint
	for spec: Array in [
			# five rock depths now (Advika asked for more parallax three times) —
			# 0.12 through 0.60, each slower, bigger, paler and sparser than the next
			["bg_columns_deep", 0.12, 5200.0, Vector2(760.0, 1250.0),
					Vector2(700.0, 1100.0), Color(0.36, 0.32, 0.26, 0.22), 907],
			["bg_columns_far", 0.22, 4200.0, Vector2(620.0, 1050.0),
					Vector2(520.0, 820.0), Color(0.34, 0.30, 0.24, 0.34), 1811],
			["bg_columns_mid", 0.34, 3800.0, Vector2(560.0, 960.0),
					Vector2(430.0, 700.0), Color(0.32, 0.28, 0.22, 0.44), 2609],
			["bg_columns", 0.46, 3400.0, Vector2(520.0, 900.0),
					Vector2(360.0, 620.0), Color(0.30, 0.26, 0.20, 0.55), 3311],
			["bg_columns_near", 0.60, 2600.0, Vector2(360.0, 620.0),
					Vector2(240.0, 430.0), Color(0.20, 0.17, 0.13, 0.72), 5417],
			# a sixth, nearly at walking speed: it slides fast past everything behind
			# it, which is the depth cue you actually FEEL while moving
			["bg_columns_close", 0.80, 2000.0, Vector2(300.0, 520.0),
					Vector2(300.0, 520.0), Color(0.13, 0.11, 0.09, 0.80), 6803]]:
		var pl := ParallaxLayer.new()
		pl.name = String(spec[0])
		pl.motion_scale = Vector2(float(spec[1]), float(spec[1]) * 0.19)
		pl.motion_mirroring = Vector2(float(spec[2]), 0)
		pb.add_child(pl)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(spec[6])
		var pool: Array[String] = ["bigrock_06.png", "bigrock_02.png", "combo_11.png",
				"combo_08.png", "bigrock_08.png"]
		var hr: Vector2 = spec[3]
		var gap: Vector2 = spec[4]
		var x := 60.0
		while x < float(spec[2]):
			var tex := _frame_tex(cache, pool[rng.randi() % pool.size()])
			var h := rng.randf_range(hr.x, hr.y)
			var sc := h / float(tex.get_height())
			var s := Sprite2D.new()
			s.texture = tex
			s.flip_h = rng.randf() < 0.5
			s.scale = Vector2(sc * rng.randf_range(0.55, 0.9), sc)
			# feet below the frame, heads into the upper haze — pillars, not boulders
			s.position = Vector2(x, rng.randf_range(120.0, 300.0))
			s.modulate = spec[5]                     # a shade, not a shape
			s.z_index = -2
			pl.add_child(s)
			x += rng.randf_range(gap.x, gap.y)


## Two depths of drifting dust — the cheapest, clearest parallax cue there is: specks
## at 0.5 and 0.9 slide past each other and past the rock as she walks.
static func _depth_dust(pb: ParallaxBackground) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = grad
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.width = 64
	dot.height = 64
	# motion, span, count, size range, alpha
	for spec: Array in [
			[0.52, 2400.0, 34, Vector2(0.05, 0.14), 0.30],
			[0.90, 1700.0, 26, Vector2(0.08, 0.22), 0.42]]:
		var pl := ParallaxLayer.new()
		pl.name = "bg_dust_%d" % int(float(spec[0]) * 100.0)
		pl.motion_scale = Vector2(float(spec[0]), float(spec[0]) * 0.5)
		pl.motion_mirroring = Vector2(float(spec[1]), 0)
		pb.add_child(pl)
		for i in range(int(spec[2])):
			var s := Sprite2D.new()
			s.texture = dot
			var sz: Vector2 = spec[3]
			var k: float = rng.randf_range(sz.x, sz.y)
			s.scale = Vector2(k, k)
			s.position = Vector2(rng.randf_range(0.0, float(spec[1])),
					rng.randf_range(-360.0, 420.0))
			s.modulate = Color(0.96, 0.90, 0.78, rng.randf_range(0.12, float(spec[4])))
			pl.add_child(s)
			# each speck breathes and drifts on its own clock
			var per: float = rng.randf_range(3.0, 8.0)
			var t := pb.create_tween().set_loops()
			t.tween_property(s, "position:y", s.position.y - rng.randf_range(20.0, 70.0), per) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(s, "position:y", s.position.y, per) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Drifting mist between the backdrop and the cave itself (Advika 2026-07-26:
## "the background seems too plain and dead"). Its own CanvasLayer at -40 — behind
## every world node (platforms, floor, roof are all layer 0) but in front of the
## parallax backdrop at -50, so the mist reads as air INSIDE the cavern rather than
## a film over the whole picture. Screen-anchored full-rect sheets, so no window
## size can leave an edge; each crawls at its own speed and direction and lives in
## its own vertical band, so the air never pulses in unison.
static func _cave_mist(host: Node2D, noise: NoiseTexture2D) -> void:
	var cl := CanvasLayer.new()
	cl.name = "cave_mist"
	cl.layer = -40
	host.add_child(cl)
	# Advika 2026-07-26: fast and noticeable, and then "too organised — make it
	# chaotic topsy turvy". So: cave_mist_churn (domain-warped, three octaves), each
	# sheet with its OWN rotation, drift direction and warp strength, and bands that
	# overlap heavily so no horizontal seam shows. Nothing here travels straight.
	# speed, strength, y_shift, band, tint, drift dir, warp, rotation
	# ...and then pulled WAY back (Advika: "way too much, it looks foreign and
	# strange"). Two sheets instead of four, a third of the density, drifting mostly
	# sideways with only a little fold — air in a cave, not weather. The low river
	# survives because mist belongs on a cave floor; the mid-air sheets do not.
	for spec: Array in [
			[0.055, 0.10, 0.00, Vector4(0.06, 0.40, 1.10, 0.74), Vector3(0.44, 0.40, 0.26),
					Vector2(1.0, -0.12), 0.22, 0.0],
			# the low river, hugging the floor
			[0.075, 0.16, 1.30, Vector4(0.60, 0.88, 1.30, 1.00), Vector3(0.42, 0.38, 0.24),
					Vector2(-1.0, -0.06), 0.30, 0.4]]:
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/cave_mist_churn.gdshader")
		mat.set_shader_parameter("noise_tex", noise)
		mat.set_shader_parameter("speed", spec[0])
		mat.set_shader_parameter("strength", spec[1])
		mat.set_shader_parameter("y_shift", spec[2])
		mat.set_shader_parameter("band_zone", spec[3])
		mat.set_shader_parameter("tint", spec[4])
		mat.set_shader_parameter("drift", spec[5])
		mat.set_shader_parameter("warp", spec[6])
		mat.set_shader_parameter("rot", spec[7])
		r.material = mat
		cl.add_child(r)


static func _mist(pb: ParallaxBackground, noise: NoiseTexture2D, speed: float,
		strength: float, y_shift: float) -> ColorRect:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2.ZERO
	pb.add_child(pl)
	var r := ColorRect.new()
	r.position = Vector2(-960, -540)
	r.size = Vector2(1920, 1080)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cave_mist.gdshader")
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("y_shift", y_shift)
	r.material = mat
	pl.add_child(r)
	return r
