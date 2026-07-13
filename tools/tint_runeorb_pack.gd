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
#       <src_dir> <out_dir> <ref_violet.png> [sat_mult] [val_scale] [gold_sat] [gold_val]
#
# <src_dir> holds runeorb1..12.png + runeorbspawn1..12.png (Downloads).
# Overwrites <out_dir> in place with the shifted frames, same names.
# sat_mult: absolute sat multiplier for the crystal band (omit = measured
#           ratio toward the ref, floored at 0.7). val_scale darkens it.
# gold_sat/gold_val (default 1.0/1.0): mute the gold bands — 0.55/0.72 is
#           the BRONZE Advika picked from the 2026-07-13 variant sheets,
#           paired with crystal 0.50/0.62 ("deep dusk").

const PURPLE_LO := 0.60   # violet through magenta — the crystal + its smoke
const PURPLE_HI := 0.97
const GOLD_LO := 0.02     # the band/trail warm range (red trail specks excluded)
const GOLD_HI := 0.22


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
	# Ease the saturation toward the realm's muted read; sat_floor bounds how
	# far — the orb is a hazard, it must not dissolve into the moss entirely.
	var sat_scale := float(args[3]) if args.size() > 3 \
			else clampf(target.y / maxf(orb.y, 0.01), 0.7, 1.0)
	var val_scale := float(args[4]) if args.size() > 4 else 1.0
	var gold_sat := float(args[5]) if args.size() > 5 else 1.0
	var gold_val := float(args[6]) if args.size() > 6 else 1.0
	print("[orbtint] orb_hue=%.0fdeg -> %.0fdeg  crystal sat=%.2f val=%.2f  gold sat=%.2f val=%.2f" %
			[orb.x * 360.0, target.x * 360.0, sat_scale, val_scale, gold_sat, gold_val])

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
			_shift_band(img, PURPLE_LO, PURPLE_HI, delta, sat_scale, val_scale)
			if gold_sat != 1.0 or gold_val != 1.0:
				_shift_band(img, GOLD_LO, GOLD_HI, 0.0, gold_sat, gold_val)
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


# Rotate pixels whose hue falls in [lo, hi] by delta; scale their sat + val.
func _shift_band(img: Image, lo: float, hi: float, delta: float, sat_scale: float,
		val_scale := 1.0) -> void:
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
				clampf(c.s * sat_scale, 0.0, 1.0), clampf(c.v * val_scale, 0.0, 1.0))
		d[i] = int(out.r * 255.0)
		d[i + 1] = int(out.g * 255.0)
		d[i + 2] = int(out.b * 255.0)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
