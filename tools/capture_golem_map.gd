extends Node2D

# GOLEM MAP — boot Realm1, let the golems settle, then label each one (G0..Gn, sorted
# left-to-right, with its world-x) over the real level so Advika can call out which to
# remove. Captures readable horizontal strips to tools/shots/golemmap_*.png. Run WINDOWED.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"
const VIEW_W := 1920.0
const STRIP_W := 3800.0   # world px per strip → readable labels

var _realm: Node = null
var _golems: Array = []   # {x, y, idx}


func _ready() -> void:
	_realm = load(REALM).instantiate()
	add_child(_realm)
	# Push the level behind our overlay so the labels always draw on top.
	_realm.z_as_relative = false
	_realm.z_index = -100
	# Let physics settle every golem onto the floor.
	for i in range(90):
		await get_tree().physics_frame
	var list: Array = get_tree().get_nodes_in_group("enemies")
	list.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	for i in range(list.size()):
		var g: Node2D = list[i]
		_golems.append({"x": g.global_position.x, "y": g.global_position.y, "idx": i})
	queue_redraw()
	await get_tree().process_frame

	var n := ceili((15360.0) / STRIP_W)
	var zoom := VIEW_W / STRIP_W
	for i in range(n):
		var cx := (float(i) + 0.5) * STRIP_W
		await _shoot(Vector2(cx, 430.0), Vector2(zoom, zoom),
			"res://tools/shots/golemmap_%d.png" % i)
	print("GOLEM_COUNT=%d" % _golems.size())
	for gm in _golems:
		print("  G%d  x=%d" % [gm["idx"], int(gm["x"])])
	print("GOLEM_MAP_DONE")
	get_tree().quit()


func _shoot(cam_pos: Vector2, zoom: Vector2, path: String) -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.global_position = cam_pos
	cam.zoom = zoom
	cam.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	cam.queue_free()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for gm in _golems:
		var px: float = gm["x"]
		var py: float = gm["y"]
		# Bright ring on the golem + a vertical stalk up to a label chip so it's legible.
		draw_circle(Vector2(px, py - 30.0), 34.0, Color(1, 0.3, 0.85, 0.35))
		draw_arc(Vector2(px, py - 30.0), 34.0, 0.0, TAU, 40, Color(1, 0.3, 0.85), 3.0)
		draw_line(Vector2(px, py - 64.0), Vector2(px, py - 150.0), Color(1, 0.3, 0.85), 2.0)
		var text := "G%d" % gm["idx"]
		var sub := "x%d" % int(px)
		_chip(font, px, py - 150.0, text, sub)


func _chip(font: Font, cx: float, bottom_y: float, text: String, sub: String) -> void:
	var fs := 40
	var w := 150.0
	var h := 84.0
	var rect := Rect2(cx - w * 0.5, bottom_y - h, w, h)
	draw_rect(rect, Color(0, 0, 0, 0.8), true)
	draw_rect(rect, Color(1, 0.3, 0.85), false, 3.0)
	draw_string(font, Vector2(rect.position.x + 12.0, rect.position.y + 40.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.6, 0.95))
	draw_string(font, Vector2(rect.position.x + 12.0, rect.position.y + 74.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.8, 0.8, 0.85))
