extends SceneTree
## Pre-blur Maaot slices for the background planes of cave_ref_03 —
## the ref's billows/faded spikes have NO crisp edges, so the background
## copies get a strong gaussian-ish blur (downscale + upscale, twice).
## Output: assets/realms/realm1_soft/<name>_soft.png. Repeatable.

const SRC := "res://assets/realms/realm1_cavern/"
const DST := "res://assets/realms/realm1_soft/"
const PIECES: Array[String] = [
	"bigrock_00.png", "bigrock_01.png", "bigrock_02.png", "bigrock_03.png",
	"bigrock_04.png", "bigrock_05.png", "bigrock_06.png", "bigrock_07.png",
	"bigrock_08.png",
	"combo_12.png", "combo_13.png", "combo_14.png", "combo_15.png",
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DST)
	for p in PIECES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + p))
		var w := img.get_width()
		var h := img.get_height()
		# pad so the blur can bleed past the silhouette instead of clipping
		var pad := 80
		var padded := Image.create(w + pad * 2, h + pad * 2, false, Image.FORMAT_RGBA8)
		padded.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(pad, pad))
		for divisor: int in [3, 3, 2, 2]:
			padded.resize((w + pad * 2) / divisor, (h + pad * 2) / divisor,
					Image.INTERPOLATE_BILINEAR)
			padded.resize(w + pad * 2, h + pad * 2, Image.INTERPOLATE_BILINEAR)
		var out := DST + p.trim_suffix(".png") + "_soft.png"
		padded.save_png(ProjectSettings.globalize_path(out))
		print("soft: ", out)
	quit()
