extends SceneTree

# Extract Advika's hand-painted floating platforms (everything ABOVE the floor,
# row < FLOOR_TOP) as connected modules, so we can replicate her exact tiles when
# extending the level. Prints each platform group: position, size, and its cells
# (relative to the group's top-left) with atlas coords + alt flags.

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const FLOOR_TOP := 40


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	var above := {}  # Vector2i -> [atlas_x, atlas_y, alt]
	for i in range(n):
		var off := 2 + i * CELL
		var x := data.decode_s16(off)
		var y := data.decode_s16(off + 2)
		if y < FLOOR_TOP:
			above[Vector2i(x, y)] = [data.decode_u16(off + 6), data.decode_u16(off + 8), data.decode_u16(off + 10)]

	print("above-floor cells: %d" % above.size())
	if above.is_empty():
		quit()
		return

	# Flood-fill into connected groups (4-connectivity).
	var seen := {}
	var groups := []
	for key in above.keys():
		if seen.has(key):
			continue
		var stack := [key]
		var group := []
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			if seen.has(c) or not above.has(c):
				continue
			seen[c] = true
			group.append(c)
			stack.append(c + Vector2i(1, 0))
			stack.append(c + Vector2i(-1, 0))
			stack.append(c + Vector2i(0, 1))
			stack.append(c + Vector2i(0, -1))
		groups.append(group)

	groups.sort_custom(func(a, b): return _minc(a).x < _minc(b).x)
	print("platform groups: %d\n" % groups.size())
	for gi in range(groups.size()):
		var g = groups[gi]
		var mn := _minc(g)
		var mx := Vector2i(-9999, -9999)
		for c in g:
			mx.x = maxi(mx.x, c.x)
			mx.y = maxi(mx.y, c.y)
		print("GROUP %d  at (col=%d,row=%d)  size=%dx%d  cells=%d  height_above_floor=%d" % [
			gi, mn.x, mn.y, mx.x - mn.x + 1, mx.y - mn.y + 1, g.size(), FLOOR_TOP - mn.y])
		g.sort_custom(func(a, b): return (a.y * 1000 + a.x) < (b.y * 1000 + b.x))
		for c in g:
			var t = above[c]
			print("   rel(%d,%d) atlas=(%d,%d) alt=%d" % [c.x - mn.x, c.y - mn.y, t[0], t[1], t[2]])
	quit()


func _minc(g: Array) -> Vector2i:
	var mn := Vector2i(9999, 9999)
	for c in g:
		mn.x = mini(mn.x, c.x)
		mn.y = mini(mn.y, c.y)
	return mn
