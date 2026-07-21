extends SceneTree
## Fuse each Realm 1 platform assembly into ONE texture (Advika 2026-07-22:
## "blend it more smoothly u can still see outlines in the platforms").
## Pieces are blitted with their shading baked in (multiply), the union is
## solidified, and a light blur melts every internal seam — one shape, no
## per-piece boundaries. Output: assets/realms/realm1_soft/plat_<name>.png.
## The scene renders each with fog_mass_screen at detail 1.0 (art lit by
## local fog), so depth still comes from the light, never from alpha.

const CUT := "res://assets/realms/realm1_cut/"
const OUT := "res://assets/realms/realm1_soft/"

var _cache := {}


func _init() -> void:
	_compose("wall_ledge", Vector2i(800, 1600), Vector2(240, 800), _wall_pieces())
	_compose("small_a", Vector2i(360, 300), Vector2(180, 150), [
		["combo_04.png", 6.0, -58.0, 0.16, false, 0.95],
		["plat_02.png", 0.0, 0.0, 0.50, false, 0.42],
		["rock_14.png", 34.0, 48.0, 0.14, false, 0.13]])
	_compose("small_b", Vector2i(300, 300), Vector2(150, 150), [
		["bigrock_08.png", -8.0, -44.0, 0.13, true, 0.95],
		["plat_05.png", 0.0, 0.0, 0.34, false, 0.34]])
	_compose("medium_a", Vector2i(480, 340), Vector2(240, 170), [
		["combo_05.png", -52.0, -54.0, 0.20, false, 0.95],
		["plat_02.png", 12.0, 30.0, 0.55, false, 0.30],
		["plat_08.png", 0.0, -34.0, 0.75, false, 0.42],
		["rock_13.png", 66.0, 74.0, 0.17, false, 0.13]])
	_compose("medium_b", Vector2i(480, 360), Vector2(240, 180), [
		["combo_07.png", -14.0, -62.0, 0.20, true, 0.95],
		["plat_02.png", 84.0, 44.0, 0.44, true, 0.30],
		["plat_02.png", -40.0, 0.0, 0.62, false, 0.42],
		["rock_14.png", -70.0, 56.0, 0.15, false, 0.13]])
	_compose("large_b", Vector2i(460, 440), Vector2(230, 220), [
		["combo_04.png", -30.0, -104.0, 0.22, true, 0.95],
		["floor_08.png", 0.0, 44.0, 0.80, false, 0.30],
		["plat_08.png", 0.0, -76.0, 0.80, false, 0.42],
		["rock_13.png", -88.0, -18.0, 0.18, false, 0.13]])
	quit()


func _wall_pieces() -> Array:
	var pieces: Array = []
	# pebble column stack, top-down z order matches the scene
	var y := 620.0
	var i := 0
	while y > -700.0:
		var tex := "floor_0%d.png" % (7 if i % 2 == 0 else 8)
		var h := _src(tex).get_height() * 1.05
		pieces.append([tex, 20.0 + (14.0 if i % 2 else -8.0), y - h * 0.5,
				1.05, i % 2 == 1, 0.30])
		y -= h * 0.8
		i += 1
	pieces.append(["combo_10.png", 175.0, -120.0, 0.26, false, 0.95])
	pieces.append(["floor_07.png", 100.0, 0.0, 0.85, false, 0.28])
	pieces.append(["plat_02.png", 90.0, 250.0, 0.50, true, 0.30])
	pieces.append(["plat_08.png", 195.0, -85.0, 1.0, false, 0.42])
	pieces.append(["rock_20.png", 105.0, 20.0, 0.42, false, 0.13])
	pieces.append(["rock_14.png", 120.0, 320.0, 0.16, false, 0.13])
	return pieces


func _src(piece: String) -> Image:
	if not _cache.has(piece):
		_cache[piece] = Image.load_from_file(
				ProjectSettings.globalize_path(CUT + piece))
	return _cache[piece]


func _compose(pname: String, size: Vector2i, origin: Vector2,
		pieces: Array) -> void:
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for p: Array in pieces:
		var img := _src(p[0]).duplicate() as Image
		var w := int(img.get_width() * float(p[3]))
		var h := int(img.get_height() * float(p[3]))
		if w < 2 or h < 2:
			continue
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		if p[4]:
			img.flip_x()
		var mult: float = p[5]
		for yy in range(h):
			for xx in range(w):
				var c := img.get_pixel(xx, yy)
				if c.a > 0.0:
					c.r *= mult
					c.g *= mult
					c.b *= mult
					img.set_pixel(xx, yy, c)
		canvas.blend_rect(img, Rect2i(0, 0, w, h),
				Vector2i(int(origin.x + float(p[1])) - w / 2,
				int(origin.y + float(p[2])) - h / 2))
	# melt internal seams, then re-solidify the union
	for divisor: int in [2, 2]:
		canvas.resize(size.x / divisor, size.y / divisor,
				Image.INTERPOLATE_BILINEAR)
		canvas.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	for yy in range(size.y):
		for xx in range(size.x):
			var c := canvas.get_pixel(xx, yy)
			if c.a > 0.0:
				c.a = smoothstep(0.25, 0.70, c.a)
				canvas.set_pixel(xx, yy, c)
	canvas.save_png(ProjectSettings.globalize_path(OUT + "plat_%s.png" % pname))
	print("platform: ", pname)
