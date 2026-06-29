extends SceneTree

# Re-lay the floating WOODEN jump-platforms across the full level at EVEN gaps and
# a RAISED height band, addressing Advika's notes: "increase height of these
# platforms" + "fix the distances". Her floor (rows >= FLOOR_TOP) and her tall
# ROCK formations (connected groups taller than THIN_MAX) are kept exactly where
# they are — only the thin ledges are moved. The thin pieces re-used are her own
# painted tiles (extracted from the left half as a palette, cycled across).

const SCENE_PATH := "res://assets/realms/realm1_caves/Realm1.tscn"
const MARKER := "tile_map_data = PackedByteArray(\""
const CELL := 12
const FLOOR_TOP := 40     # rows >= this = floor (kept)
const THIN_MAX := 2       # group height <= this = a jump-platform; taller = rock

# Layout knobs (tune + re-render):
const START_COL := 8
const END_COL := 935      # leave room before the exit door (~col 956)
const GAP := 17           # even horizontal gap between platforms (cols)
const BASE_ROW := 32      # height band centre (floor is row 40 → 8 above)
const WAVE_AMP := 2       # gentle up/down so it's not a flat line
const PALETTE_MAX_COL := 460   # extract thin modules from originals only


func _init() -> void:
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var start := text.find(MARKER) + MARKER.length()
	var ce := text.find("\"", start)
	var data := Marshalls.base64_to_raw(text.substr(start, ce - start))
	var n := (data.size() - 2) / CELL

	var cells := {}  # Vector2i -> PackedByteArray(12)
	for i in range(n):
		var off := 2 + i * CELL
		cells[Vector2i(data.decode_s16(off), data.decode_s16(off + 2))] = data.slice(off, off + CELL)

	# Above-floor cells → connected groups (4-connectivity).
	var above := {}
	for key in cells:
		if key.y < FLOOR_TOP:
			above[key] = true
	var groups := _flood(above)

	# Classify groups; build the thin-module palette (from originals) and the set
	# of rock cells/columns to keep + dodge.
	var palette := []          # [ {w:int, cells:[ [relV2i, bytes] ]} ] sorted by col
	var rock_cols := {}        # column -> true (blocked for platform placement)
	var thin_keys := {}        # all thin cells to remove
	for g in groups:
		var mn := Vector2i(1 << 30, 1 << 30)
		var mx := Vector2i(-(1 << 30), -(1 << 30))
		for c in g:
			mn.x = mini(mn.x, c.x); mn.y = mini(mn.y, c.y)
			mx.x = maxi(mx.x, c.x); mx.y = maxi(mx.y, c.y)
		var height := mx.y - mn.y + 1
		if height <= THIN_MAX:
			for c in g:
				thin_keys[c] = true
			if mn.x < PALETTE_MAX_COL:
				var mod := {"w": mx.x - mn.x + 1, "col": mn.x, "cells": []}
				for c in g:
					mod["cells"].append([Vector2i(c.x - mn.x, c.y - mn.y), cells[c]])
				palette.append(mod)
		else:
			for c in g:
				rock_cols[c.x] = true

	palette.sort_custom(func(a, b): return a["col"] < b["col"])
	if palette.is_empty():
		print("no thin modules found — aborting"); quit(); return

	# Remove every thin platform (both halves).
	for k in thin_keys:
		cells.erase(k)

	# Re-stamp the palette across the full width at even gaps + raised wavy band.
	var col := START_COL
	var i := 0
	var placed := 0
	while col <= END_COL:
		var mod = palette[i % palette.size()]
		var w: int = mod["w"]
		# Dodge rock columns: if this slot overlaps a rock, jump past it.
		var blocked := false
		for cx in range(col, col + w):
			if rock_cols.has(cx):
				blocked = true
				break
		if blocked:
			col += 1
			continue
		var target_top := BASE_ROW + int(round(WAVE_AMP * sin(i * 0.7)))
		for entry in mod["cells"]:
			var rel: Vector2i = entry[0]
			var pos := Vector2i(col + rel.x, target_top + rel.y)
			var c: PackedByteArray = (entry[1] as PackedByteArray).duplicate()
			c.encode_s16(0, pos.x)
			c.encode_s16(2, pos.y)
			cells[pos] = c
		placed += 1
		i += 1
		col += w + GAP

	# Rebuild blob.
	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, 0)
	for key in cells:
		out.append_array(cells[key])
	var new_text := text.substr(0, start) + Marshalls.raw_to_base64(out) + text.substr(ce)
	var w2 := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	w2.store_string(new_text)
	w2.close()
	print("palette=%d modules; placed %d platforms; rock cols kept=%d; total cells=%d" % [
		palette.size(), placed, rock_cols.size(), cells.size()])
	quit()


# Flood-fill a position-set into connected groups (4-connectivity).
func _flood(occ: Dictionary) -> Array:
	var seen := {}
	var groups := []
	for key in occ:
		if seen.has(key):
			continue
		var stack := [key]
		var group := []
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			if seen.has(c) or not occ.has(c):
				continue
			seen[c] = true
			group.append(c)
			stack.append(c + Vector2i(1, 0))
			stack.append(c + Vector2i(-1, 0))
			stack.append(c + Vector2i(0, 1))
			stack.append(c + Vector2i(0, -1))
		groups.append(group)
	return groups
