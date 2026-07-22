extends SceneTree
## RECUT the Maaot slices for the background bands (Advika 2026-07-22:
## "if u have to recut all of the sprites to get rid of that outline then
## do that"). Two operations per piece, both at the pixel level, output
## stays FULLY OPAQUE — no transparency tricks:
##   1. EDGE SHAVE: erode the sprite border by ~the outline stroke width,
##      so the black contour ring is physically cut off.
##   2. STROKE INPAINT: interior near-black contour lines are replaced
##      with the surrounding rock color (sampled from a heavy blur).
## Output: assets/realms/realm1_cut/<name>.png. Repeatable.

const SRC := "res://assets/realms/realm1_cavern/"
const DST := "res://assets/realms/realm1_cut/"
const PIECES: Array[String] = [
	"combo_00.png", "combo_01.png", "combo_02.png", "combo_03.png",
	"combo_04.png", "combo_05.png", "combo_06.png", "combo_07.png",
	"combo_08.png", "combo_09.png", "combo_10.png", "combo_11.png",
	"combo_12.png", "combo_13.png", "combo_14.png", "combo_15.png",
	"bigrock_02.png", "bigrock_03.png", "bigrock_05.png", "bigrock_06.png",
	"bigrock_08.png",
	"rock_13.png", "rock_14.png", "rock_20.png", "rock_21.png", "rock_22.png",
	"rock_29.png", "rock_31.png", "rock_33.png", "rock_35.png", "rock_37.png",
	# platform assembly pieces
	"plat_00.png", "plat_01.png", "plat_02.png", "plat_03.png", "plat_04.png",
	"plat_05.png", "plat_06.png", "plat_07.png", "plat_08.png", "plat_09.png",
	"plat_10.png", "floor_07.png", "floor_08.png", "bigrock_00.png",
	"floor_22.png", "floor_23.png",
	"rock_00.png", "rock_03.png", "rock_05.png", "rock_08.png", "rock_10.png",
]
const STROKE_LUM := 0.085   # below this = a drawn contour stroke
const ERODE_CUT := 0.72     # mask-blur threshold; higher shaves deeper


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DST)
	for p in PIECES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + p))
		var w := img.get_width()
		var h := img.get_height()
		# color source for inpainting: strokes dissolved into neighbors
		var blurred := img.duplicate() as Image
		blurred.resize(maxi(w / 8, 1), maxi(h / 8, 1), Image.INTERPOLATE_BILINEAR)
		blurred.resize(w, h, Image.INTERPOLATE_BILINEAR)
		# soft mask of the alpha: its falloff measures distance to the edge
		var mask := img.duplicate() as Image
		mask.resize(maxi(w / 6, 1), maxi(h / 6, 1), Image.INTERPOLATE_BILINEAR)
		mask.resize(w, h, Image.INTERPOLATE_BILINEAR)
		for y in range(h):
			for x in range(w):
				var c := img.get_pixel(x, y)
				if c.a < 0.05:
					continue
				if mask.get_pixel(x, y).a < ERODE_CUT:
					c.a = 0.0            # edge shave: the outline ring dies
					img.set_pixel(x, y, c)
					continue
				c.a = 1.0                # interior is SOLID — no fade tricks
				var lum := (c.r + c.g + c.b) * 0.3333
				if lum < STROKE_LUM:
					var fill := blurred.get_pixel(x, y)
					c.r = fill.r
					c.g = fill.g
					c.b = fill.b         # inpaint interior stroke lines
				img.set_pixel(x, y, c)
		img.save_png(ProjectSettings.globalize_path(DST + p))
		print("cut: ", p)
	quit()
