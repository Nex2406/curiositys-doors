extends SceneTree
# Palette-match the rune-orb pack to the realm (Advika, 2026-07-12): the orb's
# crystal purple is rotated so its mean hue lands on a shipped realm2 violet
# reference — same measured-not-guessed method as tint_wizard_pack.gd /
# slice_mossy_pack.gd. Only the purple/magenta band moves; the gold banding,
# the sparkle trail, and the warm specks stay exactly as drawn (gold is the
# realm's one warm accent and the orb must still read against the moss).
#
# Usage:
#   godot --headless --script tools/tint_runeorb_pack.gd -- \
#       <src_dir> <out_dir> <ref_violet.png>
#
# <src_dir> holds runeorb1..12.png + runeorbspawn1..12.png (Downloads).
# Overwrites <out_dir> in place with the shifted frames, same names.

const PURPLE_LO := 0.60   # violet through magenta — the crystal + its smoke
const PURPLE_HI := 0.97


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <src_dir> <out_dir> <ref_violet.png>")
		quit(1)
		return
	var ref := Image.load_from_file(args[2])
	if ref == null:
		push_error("cannot load violet reference: " + args[2])
		quit(1)
		return
	var target := _mean_hue_sat(ref, 0.0, 1.0)

	var sample := Image.load_from_file(args[0] + "/runeorb5.png")
	if sample == null:
		push_error("cannot load runeorb5.png under " + args[0])
		quit(1)
		return
	var orb := _mean_hue_sat(sample, PURPLE_LO, PURPLE_HI)
	var delta := wrapf(target.x - orb.x, -0.5, 0.5)
	# Ease the saturation toward the realm's muted read, but never below 70%
	# of its own — the orb is a hazard, it must not dissolve into the moss.
	var sat_scale := clampf(target.y / maxf(orb.y, 0.01), 0.7, 1.0)
	print("[orbtint] orb_hue=%.3f (%.0f deg)  target=%.3f (%.0f deg)  delta=%.0f deg  sat_scale=%.2f" %
			[orb.x, orb.x * 360.0, target.x, target.x * 360.0, delta * 360.0, sat_scale])

	DirAccess.make_dir_recursive_absolute(args[1])
	var n := 0
	for prefix in ["runeorb", "runeorbspawn"]:
		for i in range(1, 13):
			var name := "%s%d.png" % [prefix, i]
			var img := Image.load_from_file(args[0] + "/" + name)
			if img == null:
				push_error("cannot load " + args[0] + "/" + name)
				quit(1)
				return
			img.convert(Image.FORMAT_RGBA8)
			_shift_band(img, PURPLE_LO, PURPLE_HI, delta, sat_scale)
			img.save_png(args[1] + "/" + name)
			n += 1
	print("[orbtint] %d frames -> %s  DONE" % [n, args[1]])
	quit(0)


# Circular mean hue + mean sat (weighted by sat*alpha) of pixels inside [lo, hi].
func _mean_hue_sat(img: Image, lo: float, hi: float) -> Vector2:
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
		if c.h < lo or c.h > hi:
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


# Rotate pixels whose hue falls in [lo, hi] by delta and scale their sat.
func _shift_band(img: Image, lo: float, hi: float, delta: float, sat_scale: float) -> void:
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		if d[i + 3] == 0:
			continue
		var c := Color8(d[i], d[i + 1], d[i + 2])
		if c.s < 0.05 or c.v < 0.03:
			continue
		if c.h < lo or c.h > hi:
			continue
		var out := Color.from_hsv(wrapf(c.h + delta, 0.0, 1.0),
				clampf(c.s * sat_scale, 0.0, 1.0), c.v)
		d[i] = int(out.r * 255.0)
		d[i + 1] = int(out.g * 255.0)
		d[i + 2] = int(out.b * 255.0)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
