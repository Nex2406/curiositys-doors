extends SceneTree
# One-off importer for the "BlueWizard Animations" pack (Downloads). The pack's
# wizard is navy-blue; the realm (and Advika's call, 2026-07-12) wants him
# PURPLE — same cloth as the violet-shifted Mossy environment. Like
# slice_mossy_pack.gd, the shift is MEASURED, not guessed: the wizard's cool
# blue band is rotated so its mean hue lands on a shipped realm2 violet
# reference. The glowing yellow eyes rotate to RED (Advika, 2026-07-12 — the
# player should read him as evil at a glance). Blacks and greys stay as drawn.
#
# Usage:
#   godot --headless --script tools/tint_wizard_pack.gd -- \
#       <src_root> <out_root> <ref_violet.png>
#
# <src_root> is the extracted pack's BlueWizard/ folder. Writes
# <out_root>/<set>/<set>_NN.png for each animation set below.

# Cool band that counts as "the wizard's blue" — cyan through indigo.
const COOL_LO := 0.45
const COOL_HI := 0.80

# Warm band that counts as "the eye glow" — orange through yellow-green. The
# dash smears drag the glow across many pixels, so the band is generous.
const EYE_LO := 0.02
const EYE_HI := 0.30
const EYE_TARGET_HUE := 0.0  # pure red

# Pack folder → committed set name. Dash2/DashEffect ride along for the
# animation viewer; only the chosen blink variant ships in the actor scene.
const SETS := {
	"2BlueWizardIdle": "idle",
	"2BlueWizardWalk": "walk",
	"2BlueWizardJump": "jump",
	"2BlueWizardJump/Dash2": "blink_a",
	"2BlueWizardJump/Dash3": "blink_b",
	"2BlueWizardJump/DashEffect": "blink_c",
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <src_root> <out_root> <ref_violet.png>")
		quit(1)
		return
	var ref := Image.load_from_file(args[2])
	if ref == null:
		push_error("cannot load violet reference: " + args[2])
		quit(1)
		return
	var target_hue := _mean_cool_hue(ref, 0.0, 1.0)

	# Measure the wizard's own blue from the first idle frame.
	var idle_dir: String = args[0] + "/2BlueWizardIdle"
	var first := _pngs_in(idle_dir)
	if first.is_empty():
		push_error("no idle frames under " + idle_dir)
		quit(1)
		return
	var sample := Image.load_from_file(idle_dir + "/" + first[0])
	var wizard_hue := _mean_cool_hue(sample, COOL_LO, COOL_HI)
	var delta := wrapf(target_hue - wizard_hue, -0.5, 0.5)
	var eye_hue := _mean_cool_hue(sample, EYE_LO, EYE_HI)
	var eye_delta := wrapf(EYE_TARGET_HUE - eye_hue, -0.5, 0.5)
	print("[tint] wizard_hue=%.3f (%.0f deg)  target_hue=%.3f (%.0f deg)  delta=%.3f (%.0f deg)" %
			[wizard_hue, wizard_hue * 360.0, target_hue, target_hue * 360.0, delta, delta * 360.0])
	print("[tint] eye_hue=%.3f (%.0f deg) -> red  eye_delta=%.3f (%.0f deg)" %
			[eye_hue, eye_hue * 360.0, eye_delta, eye_delta * 360.0])

	for src_sub: String in SETS:
		var set_name: String = SETS[src_sub]
		var src_dir: String = args[0] + "/" + src_sub
		var out_dir: String = args[1] + "/" + set_name
		DirAccess.make_dir_recursive_absolute(out_dir)
		var files := _pngs_in(src_dir)
		var idx := 0
		for f in files:
			var img := Image.load_from_file(src_dir + "/" + f)
			if img == null:
				push_error("cannot load " + src_dir + "/" + f)
				quit(1)
				return
			img.convert(Image.FORMAT_RGBA8)
			_shift_cool_band(img, delta)
			_shift_band(img, EYE_LO, EYE_HI, eye_delta)
			img.save_png("%s/%s_%02d.png" % [out_dir, set_name, idx])
			idx += 1
		print("[tint] %s: %d frames -> %s" % [src_sub, idx, out_dir])
	print("[tint] DONE")
	quit(0)


# Only the dash subfolders hold strays; sort by name = frame order in this pack.
func _pngs_in(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			out.append(f)
	out.sort()
	return out


# Circular mean hue (weighted by sat*alpha) of pixels inside [lo, hi] hue.
# Same sampling rules as slice_mossy_pack.gd's _mean_hue_sat.
func _mean_cool_hue(img: Image, lo: float, hi: float) -> float:
	img.convert(Image.FORMAT_RGBA8)
	var d := img.get_data()
	var sx := 0.0
	var sy := 0.0
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
	var hue := atan2(sy, sx) / TAU
	if hue < 0.0:
		hue += 1.0
	return hue


# Rotate only the cool band by `delta`; blacks and greys pass through untouched.
func _shift_cool_band(img: Image, delta: float) -> void:
	_shift_band(img, COOL_LO, COOL_HI, delta)


# Rotate pixels whose hue falls in [lo, hi] by `delta`, preserving sat/val.
func _shift_band(img: Image, lo: float, hi: float, delta: float) -> void:
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		if d[i + 3] == 0:
			continue
		var c := Color8(d[i], d[i + 1], d[i + 2])
		if c.s < 0.05 or c.v < 0.03:
			continue
		if c.h < lo or c.h > hi:
			continue
		var out := Color.from_hsv(wrapf(c.h + delta, 0.0, 1.0), c.s, c.v)
		d[i] = int(out.r * 255.0)
		d[i + 1] = int(out.g * 255.0)
		d[i + 2] = int(out.b * 255.0)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
