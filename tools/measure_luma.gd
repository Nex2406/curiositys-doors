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
	print("centreUpper %.1f" % _patch(img, int(w * 0.3), 0, int(w * 0.4),
			int(h * 0.4)))
	# BEFORE=<png>: max luminance among pixels that CHANGED vs the before
	# image (isolates a newly added layer's own values)
	if OS.get_environment("BEFORE") != "":
		var prev := Image.load_from_file(OS.get_environment("BEFORE"))
		var bmax := 0.0
		for y in range(0, h):
			for x in range(0, w):
				var ca := img.get_pixel(x, y)
				var cb := prev.get_pixel(x, y)
				var la := (0.3 * ca.r + 0.59 * ca.g + 0.11 * ca.b) * 255.0
				var lb := (0.3 * cb.r + 0.59 * cb.g + 0.11 * cb.b) * 255.0
				if absf(la - lb) > 8.0:
					bmax = maxf(bmax, la)
		print("band max   %.1f" % bmax)
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
	# REGION="x0,y0,w,h": print max luminance inside that rect
	if OS.get_environment("REGION") != "":
		var parts := OS.get_environment("REGION").split(",")
		var rmax2 := 0.0
		for y in range(int(parts[1]), int(parts[1]) + int(parts[3])):
			for x in range(int(parts[0]), int(parts[0]) + int(parts[2])):
				var cr := img.get_pixel(x, y)
				rmax2 = maxf(rmax2, (0.3 * cr.r + 0.59 * cr.g + 0.11 * cr.b) * 255.0)
		print("region max %.1f" % rmax2)
	# CEILSCAN=1: in each column's top 14%, a lit pixel (>40) ABOVE a dark
	# rock pixel (<15) = a hole in the ceiling. Report failing columns.
	if OS.get_environment("CEILSCAN") != "":
		var zone := int(h * 0.14)
		var fails: Array = []
		for x in range(0, w):
			var seen_lit := false
			for y in range(0, zone):
				var cc := img.get_pixel(x, y)
				var lc := (0.3 * cc.r + 0.59 * cc.g + 0.11 * cc.b) * 255.0
				if lc > 40.0:
					seen_lit = true
					if fails.size() < 3 and x >= 655 and x <= 741:
						print("dbg x=%d first lit y=%d lum=%.0f" % [x, y, lc])
				elif seen_lit and lc < 15.0:
					fails.append(x)
					if fails.size() <= 3:
						print("dbg fail x=%d dark y=%d" % [x, y])
					break
		print("ceiling fail columns: %d %s" % [fails.size(),
				str(fails.slice(0, 12))])
	# COLPROBE=<x>: print luma down that column, top 16% every 3px
	if OS.get_environment("COLPROBE") != "":
		var cx := int(OS.get_environment("COLPROBE"))
		var line := ""
		for y in range(0, int(h * 0.16), 3):
			var cp := img.get_pixel(cx, y)
			line += "%d:%d " % [y, int((0.3 * cp.r + 0.59 * cp.g + 0.11 * cp.b) * 255.0)]
		print(line)
	# DARKFRAC=1: fraction of pixels under luma 15 (silhouette coverage),
	# whole frame + top 25% strip + side 15% columns
	if OS.get_environment("DARKFRAC") != "":
		var tot := 0
		var dk := 0
		var top_tot := 0
		var top_dk := 0
		var side_tot := 0
		var side_dk := 0
		for y in range(0, h, 2):
			for x in range(0, w, 2):
				var cd := img.get_pixel(x, y)
				var ld := (0.3 * cd.r + 0.59 * cd.g + 0.11 * cd.b) * 255.0
				tot += 1
				var isdk := 1 if ld < 15.0 else 0
				dk += isdk
				if y < int(h * 0.25):
					top_tot += 1
					top_dk += isdk
				if x < int(w * 0.15) or x >= w - int(w * 0.15):
					side_tot += 1
					side_dk += isdk
		print("darkfrac all %.3f top %.3f sides %.3f" % [float(dk) / tot,
				float(top_dk) / top_tot, float(side_dk) / side_tot])
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
