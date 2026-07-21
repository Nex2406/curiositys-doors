extends SceneTree
## Compose the cave_ref_03 billow BANK as one texture: bigrock pieces
## overlapped into a single rising-falling mass, blurred as a whole so the
## lobes fuse with no internal seams. Output: assets/realms/realm1_soft/
## fog_bank.png. Repeatable.

const SRC := "res://assets/realms/realm1_cavern/"
const OUT := "res://assets/realms/realm1_soft/fog_bank.png"
const W := 2600
const H := 1400
# [piece, center x, center y, scale] in bank-local px — lower-left rise,
# plume heads, sink to the right
const LOBES: Array = [
	# baseline row first — wide, so no upper lobe overhangs into open air
	["bigrock_02.png", 350.0, 980.0, 1.1],
	["bigrock_08.png", 900.0, 950.0, 1.1],
	["bigrock_01.png", 1500.0, 980.0, 1.2],
	["bigrock_06.png", 2050.0, 1000.0, 1.0],
	# plume heads riding the baseline
	["bigrock_00.png", 800.0, 600.0, 0.9],
	["bigrock_07.png", 1150.0, 420.0, 0.75],
	["bigrock_06.png", 1500.0, 650.0, 0.8],
]


func _init() -> void:
	var bank := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for l: Array in LOBES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + l[0]))
		var sw := int(img.get_width() * float(l[3]))
		var sh := int(img.get_height() * float(l[3]))
		img.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
		bank.blend_rect(img, Rect2i(0, 0, sw, sh),
				Vector2i(int(l[1]) - sw / 2, int(l[2]) - sh / 2))
	for divisor: int in [3, 3, 2, 2]:
		bank.resize(W / divisor, H / divisor, Image.INTERPOLATE_BILINEAR)
		bank.resize(W, H, Image.INTERPOLATE_BILINEAR)
	# the art's bases are alpha-faded, leaving coverage holes between lobes.
	# Make the bank ONE solid mass: fill every column from its skyline down,
	# thinning out toward the canvas base so the smoke dissolves into the
	# ground mist. The blurred skyline edge above the fill stays soft.
	for x in range(W):
		var top := -1
		for y in range(H):
			if bank.get_pixel(x, y).a > 0.55:
				top = y
				break
		if top < 0:
			continue
		for y in range(top, H):
			var c := bank.get_pixel(x, y)
			var want := smoothstep(float(H), H * 0.72, float(y))
			if c.a < want:
				c.a = want
				bank.set_pixel(x, y, c)
	bank.save_png(ProjectSettings.globalize_path(OUT))
	print("bank: ", OUT)
	quit()
