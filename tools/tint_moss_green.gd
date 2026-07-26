extends SceneTree
# Rotates the realm2_moss slices BACK to the Mossy pack's ORIGINAL green
# (Advika 2026-07-19: Realm 1's rebuild keeps the packs' own palette — no
# hue shift anywhere). The violet realm2_moss pieces were made from green by
# a measured rotation; this measures the same distance in reverse (mean hue
# of a violet slice vs the pack's green vegetation sheet) and applies it to
# every piece, so the proven crops + semantic names carry over unchanged.
# Subdirectories (the animated plants: flower/plant1/plant_wind) come along.
#
# Usage:
#   godot --headless --script tools/tint_moss_green.gd -- \
#       <src_dir> <out_dir> <ref_green.png> <ref_violet.png>

# not vegetation (sky/celestials/particles/gold glows/parallax bands/the
# island chunk) — realm 1 doesn't take these, they stay violet-realm-only
const SKIP := ["sky.png", "star.png", "moon.png", "cloud.png", "chunk.png",
		"band_far.png", "band_mid.png", "band_ground.png", "glow_gold.png",
		"fog.png", "spore.png", "firefly.png"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("usage: -- <src_dir> <out_dir> <ref_green> <ref_violet>")
		quit(1)
		return
	var green := Image.load_from_file(args[2])
	var violet := Image.load_from_file(args[3])
	if green == null or violet == null:
		push_error("cannot load reference images")
		quit(1)
		return
	var hg := _mean_hue_sat(green)
	var hv := _mean_hue_sat(violet)
	var hue_delta := wrapf(hg.x - hv.x, -0.5, 0.5)
	var sat_scale := hg.y / maxf(hv.y, 0.01)
	print("[green] measured hue_delta=%.3f (%.0f deg)  sat_scale=%.2f" %
			[hue_delta, hue_delta * 360.0, sat_scale])
	var n := _convert_dir(args[0], args[1], hue_delta, sat_scale)
	print("[green] %d pieces converted. DONE" % n)
	quit(0)


func _convert_dir(src: String, dst: String, delta: float, sscale: float) -> int:
	DirAccess.make_dir_recursive_absolute(dst)
	var n := 0
	var dir := DirAccess.open(src)
	if dir == null:
		push_error("cannot open " + src)
		return 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var sp := src.path_join(f)
		if dir.current_is_dir():
			if not f.begins_with("."):
				n += _convert_dir(sp, dst.path_join(f), delta, sscale)
		elif f.ends_with(".png") and not SKIP.has(f):
			var img := Image.load_from_file(sp)
			if img != null:
				img.convert(Image.FORMAT_RGBA8)
				_shift_hue(img, delta, sscale)
				img.save_png(dst.path_join(f))
				n += 1
		f = dir.get_next()
	dir.list_dir_end()
	return n


# Circular mean of hue (weighted by sat*alpha) + mean saturation.
func _mean_hue_sat(img: Image) -> Vector2:
	img.convert(Image.FORMAT_RGBA8)
	var d := img.get_data()
	var sx := 0.0
	var sy := 0.0
	var sat_sum := 0.0
	var n := 0.0
	for i in range(0, d.size(), 16):
		var a := d[i + 3]
		if a < 128:
			continue
		var c := Color8(d[i], d[i + 1], d[i + 2])
		if c.s < 0.15 or c.v < 0.10:
			continue
		var w := c.s * (a / 255.0)
		sx += cos(c.h * TAU) * w
		sy += sin(c.h * TAU) * w
		sat_sum += c.s
		n += 1.0
	if n == 0.0:
		return Vector2.ZERO
	var hue := atan2(sy, sx) / TAU
	if hue < 0.0:
		hue += 1.0
	return Vector2(hue, sat_sum / n)


func _shift_hue(img: Image, delta: float, sat_scale: float) -> void:
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		if d[i + 3] == 0:
			continue
		var c := Color8(d[i], d[i + 1], d[i + 2])
		if c.s < 0.05 or c.v < 0.03:
			continue  # keep blacks/greys untouched — outlines and shadow cores
		var out := Color.from_hsv(wrapf(c.h + delta, 0.0, 1.0),
				clampf(c.s * sat_scale, 0.0, 1.0), c.v)
		d[i] = int(out.r * 255.0)
		d[i + 1] = int(out.g * 255.0)
		d[i + 2] = int(out.b * 255.0)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
