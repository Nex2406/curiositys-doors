extends SceneTree
## Luminance verification for Advika's step specs. MEASURE=<png path>.
## Prints: 40x40 corner patch means, 200x150 centre mean, overall mean
## (0-255 luma, 0.3/0.59/0.11 weights).


func _patch(img: Image, x0: int, y0: int, w: int, h: int) -> float:
	var sum := 0.0
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var c := img.get_pixel(x, y)
			sum += (0.3 * c.r + 0.59 * c.g + 0.11 * c.b) * 255.0
	return sum / float(w * h)


func _init() -> void:
	var path := OS.get_environment("MEASURE")
	var img := Image.load_from_file(path)
	var w := img.get_width()
	var h := img.get_height()
	print("corner TL  %.1f" % _patch(img, 0, 0, 40, 40))
	print("corner TR  %.1f" % _patch(img, w - 40, 0, 40, 40))
	print("corner BL  %.1f" % _patch(img, 0, h - 40, 40, 40))
	print("corner BR  %.1f" % _patch(img, w - 40, h - 40, 40, 40))
	print("centre     %.1f" % _patch(img, w / 2 - 100, h / 2 - 75, 200, 150))
	print("centre40x50 %.1f" % _patch(img, int(w * 0.3), int(h * 0.25),
			int(w * 0.4), int(h * 0.5)))
	var lmax := 0.0
	var rmax := 0.0
	for y in range(0, h):
		for x in range(0, 120):
			var c1 := img.get_pixel(x, y)
			lmax = maxf(lmax, (0.3 * c1.r + 0.59 * c1.g + 0.11 * c1.b) * 255.0)
			var c2 := img.get_pixel(w - 120 + x, y)
			rmax = maxf(rmax, (0.3 * c2.r + 0.59 * c2.g + 0.11 * c2.b) * 255.0)
	print("Lcol max   %.1f" % lmax)
	print("Rcol max   %.1f" % rmax)
	var step := 4
	var sum := 0.0
	var n := 0
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			sum += (0.3 * c.r + 0.59 * c.g + 0.11 * c.b) * 255.0
			n += 1
	print("frame mean %.1f" % (sum / float(n)))
	quit()
