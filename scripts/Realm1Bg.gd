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

## every fog-driven material registers here so the wandering light can
## move them all in lockstep (backdrop, bands, platforms)
static var fog_mats: Array = []
static func build(host: Node2D) -> void:
	var cache := {}
	fog_mats.clear()
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
		if child.name != "bg_backdrop" and child.name != "bg_near":
			child.visible = false
	var wander := host.create_tween().set_loops()
	wander.tween_method(_set_fog_center, Vector2(0.20, 0.28),
			Vector2(0.218, 0.295), 14.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wander.tween_method(_set_fog_center, Vector2(0.218, 0.295),
			Vector2(0.20, 0.28), 12.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_frame(host)
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
	# 20 stalagmites rising from the ridgeline; only a few LOW ones in the
	# sparse middle
	var sx: Array = [-10.0, 110.0, 240.0, 330.0, 470.0, 610.0, 660.0, 1270.0,
			1400.0, 1460.0, 1590.0, 1720.0, 1800.0, 1900.0, 1930.0, 60.0]
	for x0: float in sx:
		var x := x0 * kx
		var tex2 := _frame_tex(cache, spikes[rng.randi() % spikes.size()])
		var h2 := rng.randf_range(35.0, 92.0)
		var sc2 := h2 / float(tex2.get_height())
		var s2 := Sprite2D.new()
		s2.texture = tex2
		s2.scale = Vector2(sc2 * rng.randf_range(0.8, 1.2), sc2)
		s2.position = Vector2(x + rng.randf_range(-20.0, 20.0), ridge - h2 * 0.5)
		s2.material = ramp
		grp.add_child(s2)
	for x20: float in [740.0, 940.0, 1090.0, 1180.0]:
		var x2 := x20 * kx
		var tex3 := _frame_tex(cache, spikes[rng.randi() % spikes.size()])
		var h3 := rng.randf_range(35.0, 55.0)
		var sc3 := h3 / float(tex3.get_height())
		var s3 := Sprite2D.new()
		s3.texture = tex3
		s3.scale = Vector2(sc3, sc3)
		s3.position = Vector2(x2 + rng.randf_range(-20.0, 20.0), ridge - h3 * 0.5)
		s3.material = ramp
		grp.add_child(s3)
	# the band's own whisper of haze — this layer only
	var fogr := ColorRect.new()
	fogr.position = Vector2(-2600, -220)
	fogr.size = Vector2(7120, 1520)
	fogr.color = Color(0.114, 0.075, 0.035, 0.07)   # #1d1309 @ 0.07, Mix
	grp.add_child(fogr)


## STEP 3/7 (Advika's spec): the silhouette FRAME — the camera looks
## THROUGH a hole in the rock. Pure black cutout (#040302 via layer
## modulate), 1.1px DOF blur on the whole layer, centre stays empty.
## Left wall integrates with the scene's existing wall rock (edge blobs
## overlap it rather than doubling a second wall).
static func _frame(host: Node2D) -> void:
	var vs := host.get_viewport().get_visible_rect().size
	var pb2 := ParallaxBackground.new()
	pb2.layer = 50
	host.add_child(pb2)
	var pl := ParallaxLayer.new()
	pl.name = "fg_frame"
	pl.motion_scale = Vector2(1.35, 1.10)
	pl.modulate = Color("040302")
	pb2.add_child(pl)
	var grp := Node2D.new()
	# ParallaxBackground shifts layer content by screen_center * motion —
	# compensate with the LIVE viewport size (a smaller window otherwise
	# shifts the frame and exposes the right wall — Advika's step 3b bug)
	grp.position = -Vector2(vs.x * 0.5 * 1.35, vs.y * 0.5 * 1.10)
	pl.add_child(grp)
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = load("res://shaders/frame_blur.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cache := {}
	var spikes: Array[String] = ["rock_29.png", "rock_31.png", "rock_33.png",
			"rock_35.png", "rock_37.png"]
	var blobs: Array[String] = ["combo_00.png", "combo_03.png", "combo_07.png",
			"combo_10.png", "bigrock_02.png", "bigrock_06.png", "bigrock_08.png"]
	# ceiling: solid band across the top 6% (over-extended for parallax)
	var band := ColorRect.new()
	band.position = Vector2(-3600, -220)
	band.size = Vector2(vs.x + 7200, 220.0 + vs.y * 0.13)  # STEP 3d: solid top, roots buried
	band.color = Color.WHITE            # layer modulate blackens
	grp.add_child(band)
	# STEP 3c: CHAOTIC ceiling — big flipped rock clumps with wild-size
	# spikes jammed between and beneath. Edge-heavy, ragged, no row, no
	# grid; centre-top third stays clearer so one arch reads through.
	var band_b := vs.y * 0.095
	var clump_pool: Array[String] = ["combo_00.png", "combo_01.png",
			"combo_03.png", "combo_04.png", "combo_05.png", "combo_06.png",
			"combo_07.png", "combo_08.png", "combo_09.png", "combo_10.png",
			"combo_11.png", "bigrock_02.png", "bigrock_06.png", "bigrock_08.png"]
	var ceiling_count := 0
	var clump_spots: Array = []
	# 14 big hanging masses (180-280px), edge-weighted, 2 modest ones centre
	for i in range(14):
		var cx: float
		var h: float
		if i >= 12:
			cx = vs.x * 0.5 + rng.randf_range(-vs.x * 0.10, vs.x * 0.10)
			h = rng.randf_range(120.0, 170.0)
		elif i % 2 == 0:
			cx = rng.randf_range(-680.0, vs.x * 0.36)
			h = rng.randf_range(180.0, 280.0)
		else:
			cx = rng.randf_range(vs.x * 0.64, vs.x + 680.0)
			h = rng.randf_range(180.0, 280.0)
		var tex := _frame_tex(cache, clump_pool[rng.randi() % clump_pool.size()])
		var sc := h / float(tex.get_height())
		var s := Sprite2D.new()
		s.texture = tex
		s.flip_v = true
		s.flip_h = rng.randf() < 0.5
		s.scale = Vector2(sc * rng.randf_range(0.85, 1.35), sc)
		var cy := band_b + h * 0.5 - rng.randf_range(35.0, 90.0)
		s.position = Vector2(cx, cy)
		s.material = blur_mat
		grp.add_child(s)
		clump_spots.append(Vector3(cx, cy, h))
		ceiling_count += 1
	# 13 mid pieces (clumps and spikes mixed, 60-160px) crammed against them
	for i in range(13):
		var base: Vector3 = clump_spots[rng.randi() % clump_spots.size()]
		var mid_is_clump := rng.randf() < 0.45
		var h2 := rng.randf_range(60.0, 160.0)
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
		s2.scale = Vector2(sc2 * rng.randf_range(0.8, 1.3), sc2)
		s2.position = Vector2(base.x + rng.randf_range(-160.0, 160.0),
				band_b + h2 * 0.5 - rng.randf_range(28.0, 75.0))
		s2.material = blur_mat
		grp.add_child(s2)
		ceiling_count += 1
	# 14 tiny shards (25-60px) — under clump bellies and along the band
	for i in range(14):
		var h3 := rng.randf_range(25.0, 60.0)
		var tex3 := _frame_tex(cache, spikes[rng.randi() % spikes.size()])
		var sc3 := h3 / float(tex3.get_height())
		var s3 := Sprite2D.new()
		s3.texture = tex3
		s3.flip_v = true
		s3.flip_h = rng.randf() < 0.5
		s3.scale = Vector2(sc3 * rng.randf_range(0.8, 1.2), sc3)
		if i % 2 == 0 and clump_spots.size() > 0:
			# STEP 3d: tight anchor — shard stays inside its parent's body
			# (x within ~quarter of parent size, top buried in the clump)
			var b2: Vector3 = clump_spots[rng.randi() % clump_spots.size()]
			s3.position = Vector2(b2.x + rng.randf_range(-b2.z * 0.22, b2.z * 0.22),
					b2.y + b2.z * rng.randf_range(0.05, 0.30) + h3 * 0.4)
		else:
			s3.position = Vector2(rng.randf_range(-660.0, vs.x + 660.0),
					band_b + h3 * 0.5 - rng.randf_range(18.0, 38.0))
		s3.material = blur_mat
		grp.add_child(s3)
		ceiling_count += 1
	# STEP 3d: bridge clumps over the two reported holes (x ~30%, ~75%)
	for gx: float in [0.30, 0.75]:
		var texg := _frame_tex(cache, clump_pool[rng.randi() % clump_pool.size()])
		var hg := rng.randf_range(140.0, 200.0)
		var scg := hg / float(texg.get_height())
		var sg := Sprite2D.new()
		sg.texture = texg
		sg.flip_v = true
		sg.flip_h = rng.randf() < 0.5
		sg.scale = Vector2(scg * 1.3, scg)
		sg.position = Vector2(vs.x * gx, band_b + hg * 0.5 - rng.randf_range(40.0, 75.0))
		sg.material = blur_mat
		grp.add_child(sg)
		ceiling_count += 1
	print("ceiling pieces: ", ceiling_count)
	# left + right walls: backing columns (gap-proof) + 5 blobs per side,
	# roughly half of each hanging off-screen
	# WALLS moved to world-space level-end geometry (step 6b fix: at
	# motion 1.35 they swept across mid-level as black slabs)
	# bottom: 9 stalagmites on the floor line + 4 large plant silhouettes
	for i in range(9):
		var tex3 := _frame_tex(cache, spikes[rng.randi() % spikes.size()])
		var h3 := rng.randf_range(70.0, 170.0)
		var sc3 := h3 / float(tex3.get_height())
		var s3 := Sprite2D.new()
		s3.texture = tex3
		s3.scale = Vector2(sc3 * rng.randf_range(0.8, 1.2), sc3)
		s3.position = Vector2(-660.0 + (vs.x + 1320.0) * float(i) / 8.0
				+ rng.randf_range(-30.0, 30.0), vs.y * 0.5 + 478.0 - h3 * 0.35)
		s3.material = blur_mat
		grp.add_child(s3)
	var plant_specs: Array = [
		["grass2/Grass2_%05d.png", 30, 90.0],
		["groupplants/GroupPlants_%05d.png", 45, 165.0],
		["plantsmall/PlantSmall_%05d.png", 30, 120.0],
		["grass2/Grass2_%05d.png", 30, 150.0]]
	for i in range(4):
		var spec: Array = plant_specs[i]
		var sf := SpriteFrames.new()
		sf.set_animation_loop("default", true)
		sf.set_animation_speed("default", 15.0)
		for f in range(spec[1]):
			var img := Image.load_from_file(ProjectSettings.globalize_path(
					"res://assets/realms/realm1_plants/" + (spec[0] as String) % f))
			sf.add_frame("default", ImageTexture.create_from_image(img))
		var an := AnimatedSprite2D.new()
		an.sprite_frames = sf
		var native_h := float(sf.get_frame_texture("default", 0).get_height())
		var sc4 := (spec[2] as float) / native_h
		an.scale = Vector2(sc4, sc4)
		an.position = Vector2(-300.0 + (vs.x + 600.0) * float(i) / 3.0
				+ rng.randf_range(-60.0, 60.0),
				vs.y * 0.5 + 495.0 - (spec[2] as float) * 0.4)
		an.play("default")
		an.frame = rng.randi() % int(spec[1])
		an.material = blur_mat
		grp.add_child(an)


static func _frame_tex(cache: Dictionary, tex_name: String) -> Texture2D:
	if not cache.has(tex_name):
		var img := Image.load_from_file(
				ProjectSettings.globalize_path(CUT + tex_name))
		cache[tex_name] = ImageTexture.create_from_image(img)
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
	var pl := ParallaxLayer.new()
	pl.name = "bg_backdrop"
	pl.motion_scale = Vector2(0.08, 0.04)
	pb.add_child(pl)
	var vs := pb.get_viewport().get_visible_rect().size
	# STEP 6a (Advika): the backdrop TILES across the whole level with
	# horizontal MIRRORING — odd copies flipped so bright meets bright and
	# dark meets dark at every join (Tunnel 11 is lit directionally; a
	# plain repeat would seam). Manual instancing: 5 copies, one shared
	# ShaderMaterial. Level still starts at the painting's left edge; the
	# vertical lower-third-on-horizon rule is unchanged.
	var tex: Texture2D = load("res://assets/realms/realm1_backdrop/tunnel_11.png")
	var tw := float(tex.get_width())   # 2688
	var base_x := -vs.x * 0.5 * 0.08
	var y := vs.y * 0.5 + 478.0 - 1024.0 - vs.y * 0.5 * 0.04
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/backdrop_gold.gdshader")
	for k in range(-2, 3):
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.material = mat
		var flip := absi(k) % 2 == 1
		if flip:
			s.scale = Vector2(-1, 1)
			s.position = Vector2(base_x + float(k + 1) * tw, y)
		else:
			s.position = Vector2(base_x + float(k) * tw, y)
		pl.add_child(s)


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
	pl.motion_scale = Vector2(motion, 1.0)
	pl.motion_mirroring = Vector2(SPAN, 0.0)
	pb.add_child(pl)
	var s := Sprite2D.new()
	if not cache.has(tex_name):
		var img := Image.load_from_file(
				ProjectSettings.globalize_path(SOFT + tex_name))
		cache[tex_name] = ImageTexture.create_from_image(img)
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
