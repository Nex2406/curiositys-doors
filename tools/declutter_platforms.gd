extends SceneTree
## Advika 2026-07-25: several fused platform textures (plat_*.png) have
## DETACHED bits baked in — e.g. plat_large_b's left spike cluster + a small
## top-right blob float free of the platform body and read as floating rocks.
## A platform must be ONE connected mass, so this keeps only the largest
## connected (alpha) component per texture and clears the rest.
##
## Run: godot --headless --script tools/declutter_platforms.gd
## Repeatable; overwrites in place. git-revertable.

const DIR := "res://assets/realms/realm1_soft/"
const NAMES: Array[String] = ["plat_wall_ledge", "plat_small_a", "plat_small_b",
		"plat_medium_a", "plat_medium_b", "plat_large_b"]
const A_THRESH := 0.12


func _init() -> void:
	for n: String in NAMES:
		_clean(DIR + n + ".png")
	quit()


func _clean(res_path: String) -> void:
	var path := ProjectSettings.globalize_path(res_path)
	var img := Image.load_from_file(path)
	if img == null:
		push_error("missing %s" % path)
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	# label connected components (4-conn) over solid pixels
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(0)
	var sizes: Array = [0]          # component 0 = unused
	var next_label := 1
	for sy in range(h):
		for sx in range(w):
			var idx := sy * w + sx
			if label[idx] != 0 or img.get_pixel(sx, sy).a < A_THRESH:
				continue
			# flood fill this component
			var count := 0
			var stack: Array = [idx]
			label[idx] = next_label
			while not stack.is_empty():
				var ci: int = stack.pop_back()
				count += 1
				var cx := ci % w
				var cy := ci / w
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := cx + d.x
					var ny := cy + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni := ny * w + nx
					if label[ni] == 0 and img.get_pixel(nx, ny).a >= A_THRESH:
						label[ni] = next_label
						stack.push_back(ni)
			sizes.append(count)
			next_label += 1
	if sizes.size() <= 2:
		print("  %s: single mass, unchanged" % res_path.get_file())
		return
	# find the largest component
	var keep := 1
	for l in range(1, sizes.size()):
		if sizes[l] > sizes[keep]:
			keep = l
	# clear every pixel not in the kept component
	var cleared := 0
	for sy in range(h):
		for sx in range(w):
			var idx := sy * w + sx
			if label[idx] != 0 and label[idx] != keep:
				img.set_pixel(sx, sy, Color(0, 0, 0, 0))
				cleared += 1
	img.save_png(path)
	print("  %s: kept largest of %d components, cleared %d px"
			% [res_path.get_file(), sizes.size() - 1, cleared])
