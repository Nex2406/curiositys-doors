extends SceneTree
## Compose each parallax GROUND band of Realm1BgTest into ONE strip
## texture (5200 x 1800, world y -900..900): pieces blended, silhouette
## union solidified per column, then a per-band blur so internal outlines
## melt and the band reads as one flowing mass — Advika's note 2026-07-21:
## no visible per-asset boundaries. Output: assets/realms/realm1_soft/
## band_<name>.png. Repeatable; placement rng matches the live rig's seeds.

const SLICES := "res://assets/realms/realm1_cut/"  # RECUT pieces, outline-free
const SOFT := "res://assets/realms/realm1_soft/"
const SPAN := 5200
const H := 1800
const Y_OFF := 900

const FAR_SOFT: Array[String] = ["bigrock_00_soft.png", "bigrock_01_soft.png",
	"bigrock_02_soft.png", "bigrock_03_soft.png", "bigrock_04_soft.png",
	"bigrock_06_soft.png", "bigrock_07_soft.png", "bigrock_08_soft.png"]
const SPIRE_CUT: Array[String] = ["combo_12.png", "combo_13.png",
	"combo_14.png", "combo_15.png", "bigrock_05.png", "bigrock_03.png"]
const MID_RAW: Array[String] = ["combo_00.png", "combo_01.png", "combo_03.png",
	"combo_04.png", "combo_05.png", "combo_06.png", "combo_07.png",
	"combo_08.png", "combo_09.png", "combo_10.png", "combo_11.png",
	"bigrock_02.png", "bigrock_06.png", "bigrock_08.png"]
const NEAR_RAW: Array[String] = ["combo_07.png", "combo_10.png", "combo_11.png",
	"rock_29.png", "rock_31.png", "rock_33.png", "rock_35.png", "rock_37.png"]
const SPIKE_RAW: Array[String] = ["rock_29.png", "rock_31.png", "rock_33.png",
	"rock_35.png", "rock_37.png"]

var _img_cache := {}


const TEETH_RAW: Array[String] = ["rock_13.png", "rock_14.png", "rock_20.png",
	"rock_21.png", "rock_22.png"]


func _init() -> void:
	# recut pieces, near-zero blur — solid rock, not mush (Advika 2026-07-22)
	_compose("far", 16, FAR_SOFT, 220.0, 0.85, 1.35, 260.0, true, 2, [3, 2])
	_compose("spires", 36, SPIRE_CUT, 110.0, 0.35, 0.75, 400.0, false, 5, [2],
			[0.5, 0.9, 31])
	_compose("mid", 32, MID_RAW, 120.0, 0.35, 0.7, 465.0, false, 7, [2])
	_compose("near", 30, NEAR_RAW, 120.0, 0.35, 0.8, 525.0, false, 11, [],
			[0.7, 1.2, 13])
	quit()


func _src(piece: String, soft: bool) -> Image:
	var key := ("s:" if soft else "r:") + piece
	if not _img_cache.has(key):
		var dir := SOFT if soft else SLICES
		_img_cache[key] = Image.load_from_file(
				ProjectSettings.globalize_path(dir + piece))
	return _img_cache[key]


func _blit(strip: Image, piece: String, soft: bool, cx: float, cy: float,
		sc: float, flip: bool) -> void:
	var img := _src(piece, soft).duplicate() as Image
	var w := int(img.get_width() * sc)
	var h := int(img.get_height() * sc)
	if w < 2 or h < 2:
		return
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	if flip:
		img.flip_x()
	var x0 := int(cx) - w / 2
	var y0 := int(cy) - h / 2
	strip.blend_rect(img, Rect2i(0, 0, w, h), Vector2i(x0, y0))
	# wrap horizontally so the strip tiles with no cut pieces at the seam
	if x0 < 0:
		strip.blend_rect(img, Rect2i(0, 0, w, h), Vector2i(x0 + SPAN, y0))
	elif x0 + w > SPAN:
		strip.blend_rect(img, Rect2i(0, 0, w, h), Vector2i(x0 - SPAN, y0))


func _compose(band: String, count: int, pool: Array[String], gap: float,
		sc_min: float, sc_max: float, belt: float, soft: bool, seed_v: int,
		blur: Array, ceiling: Array = []) -> void:
	var strip := Image.create(SPAN, H, false, Image.FORMAT_RGBA8)
	# ceiling first (if the band has one): teeth hanging from a solid top
	# belt, fused into the same strip so their outlines melt with the rest
	if not ceiling.is_empty():
		var crng := RandomNumberGenerator.new()
		crng.seed = int(ceiling[2])
		var cx := -SPAN * 0.5
		while cx < SPAN * 0.5:
			var piece: String = TEETH_RAW[crng.randi() % TEETH_RAW.size()]
			var sc := crng.randf_range(float(ceiling[0]), float(ceiling[1]))
			var h := _src(piece, false).get_height() * sc
			var flip := crng.randf() < 0.5
			_blit(strip, piece, false, cx + SPAN * 0.5,
					-500.0 + h * 0.38 + Y_OFF, sc, flip)
			cx += crng.randf_range(120.0, 300.0)
		# solidify UP: from each column's lowest tooth pixel to the top edge
		for col in range(SPAN):
			var bottom := 400
			for y in range(880, -1, -1):
				if strip.get_pixel(col, y).a > 0.55:
					bottom = y
					break
			for y in range(0, bottom + 1):
				var c := strip.get_pixel(col, y)
				if c.a < 1.0:
					if c.a < 0.05:
						c = Color(0.10, 0.09, 0.08, 1.0)
					else:
						c.a = 1.0
					strip.set_pixel(col, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var x := -SPAN * 0.5
	# run to the SEAM, not to a count — coverage must be continuous across
	# the wrap or the tile boundary shows as a vertical cliff
	while x < SPAN * 0.5:
		var piece: String = pool[rng.randi() % pool.size()]
		var sc := rng.randf_range(sc_min, sc_max)
		var h := _src(piece, soft).get_height() * sc
		var cx := x + rng.randf_range(-40.0, 40.0)
		var flip := rng.randf() < 0.5
		_blit(strip, piece, soft, cx + SPAN * 0.5, belt + 60.0 - h * 0.5 + Y_OFF,
				sc, flip)
		x += gap + rng.randf_range(0.0, gap * 0.6)
	rng.seed = seed_v * 31 + 7
	x = -SPAN * 0.5 + gap * 0.4
	while x < SPAN * 0.5:
		var piece2: String = SPIKE_RAW[rng.randi() % SPIKE_RAW.size()]
		var sc2 := rng.randf_range(0.14, 0.30)
		var h2 := _src(piece2, false).get_height() * sc2
		var flip2 := rng.randf() < 0.5
		_blit(strip, piece2, false, x + SPAN * 0.5,
				belt + 50.0 - h2 * 0.42 + Y_OFF, sc2, flip2)
		x += rng.randf_range(110.0, 260.0)
	# union-solidify: below each column's skyline the band is SOLID — the
	# belt fill is part of the shape, so no separate lip line can show.
	# Scan starts BELOW the ceiling zone (rows 0..~880) or the ceiling fill
	# would read as the skyline and flood the whole column.
	# the fill's own skyline UNDULATES (two sines + drift) so an uncovered
	# stretch of belt never prints a straight lip line
	for col in range(SPAN):
		var wave := sin(col * 0.011 + float(seed_v)) * 14.0 \
				+ sin(col * 0.0037 + float(seed_v) * 2.7) * 22.0
		var belt_top := int(belt + 70.0 + wave + Y_OFF)
		var top := belt_top
		for y in range(950, H):
			if strip.get_pixel(col, y).a > 0.55:
				top = mini(top, y)
				break
		for y in range(top, H):
			var c := strip.get_pixel(col, y)
			if c.a < 1.0:
				# fresh fill gets a dark rock base color so the detail mix
				# never prints raw transparent-black
				if c.a < 0.05:
					c = Color(0.10, 0.09, 0.08, 1.0)
				else:
					c.a = 1.0
				strip.set_pixel(col, y, c)
	# per-band blur melts the outlines; far bands melt more. WRAP-AWARE:
	# extend each side with the opposite side's content, blur, crop back —
	# otherwise edge clamping prints a step at the tile seam
	var ext := 240
	var wide := Image.create(SPAN + ext * 2, H, false, Image.FORMAT_RGBA8)
	wide.blit_rect(strip, Rect2i(0, 0, SPAN, H), Vector2i(ext, 0))
	wide.blit_rect(strip, Rect2i(SPAN - ext, 0, ext, H), Vector2i(0, 0))
	wide.blit_rect(strip, Rect2i(0, 0, ext, H), Vector2i(SPAN + ext, 0))
	for divisor: int in blur:
		wide.resize((SPAN + ext * 2) / divisor, H / divisor,
				Image.INTERPOLATE_BILINEAR)
		wide.resize(SPAN + ext * 2, H, Image.INTERPOLATE_BILINEAR)
	strip.blit_rect(wide, Rect2i(ext, 0, SPAN, H), Vector2i.ZERO)
	strip.save_png(ProjectSettings.globalize_path(SOFT + "band_%s.png" % band))
	print("band: ", band)
