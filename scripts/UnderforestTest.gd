extends "res://scripts/Realm3FungalTest.gd"
## THE UNDERWORLD — built EXACTLY like Realm 3 (same script, new seed),
## and LAYERED (Advika 2026-07-16): the floor gaps don't have bottoms.
## Fall through one and you drop into ANOTHER full stretch of the same
## forest, one layer deeper — each layer this exact builder with its own
## seed. The underworld goes down, and down, and down.
## NOT COMMITTED until Advika approves.

# the holes, chosen between the climbing arcs so no platform overhangs one
const GAPS := [[6650.0, 6950.0], [8550.0, 8850.0], [12550.0, 12850.0]]

static var uw_depth := 0            # survives scene reloads, resets on boot

var _pit_pass := false              # my own shaft geometry bypasses the splits
var _descending := false


func _ready() -> void:
	# verbatim Realm3FungalTest._ready(), reseeded per layer — then the gaps
	RenderingServer.set_default_clear_color(Color(0.04, 0.09, 0.08))
	_rng.seed = 20260716 + uw_depth * 977
	_build_backdrop()
	_build_background()
	_build_terrain()
	_build_platforms()
	_build_ceiling()
	_build_setpieces()
	_build_dressing()
	_build_density()
	_build_foreground()
	_build_atmosphere()
	_build_fog_layers()
	_build_player()
	_build_exit_door()
	_build_camera()
	_build_ui()
	_punch_gaps()
	# arriving from above: she falls out of the dark into the new layer
	if uw_depth > 0:
		_curi.position = Vector2(SPAWN.x, -260.0)
		_curi.velocity = Vector2.ZERO
	if _lbl != null:
		_lbl.text = "R3 UNDERWORLD — layer %d · gaps lead deeper (R restart · ESC hub)" % (uw_depth + 1)
	var grade := CanvasModulate.new()
	grade.color = AMBIENT
	add_child(grade)
	if OS.get_environment("R3_SHOT") != "":
		_self_screenshot(OS.get_environment("R3_SHOT"))


func _process(delta: float) -> void:
	super(delta)
	# fell through a gap: the dark swallows her, the next layer begins
	if not _descending and _curi != null \
			and _curi.global_position.y > FLOOR_Y + 620.0:
		_descending = true
		uw_depth += 1
		Transition.transition_to("res://scenes/UnderforestTest.tscn")


# ---------- gap-aware overrides (surface calls these; we split at holes) ----------

func _fill_rect(x0: float, x1: float, y0: float, y1: float, z: int,
		col := FILL_DARK) -> void:
	# the one world-wide SOIL slab under the meadow gets split at the gaps
	if not _pit_pass and y0 == FLOOR_Y and x1 - x0 > 20000.0:
		var cursor := x0
		for g in GAPS:
			super(cursor, g[0], y0, y1, z, col)
			cursor = g[1]
		super(cursor, x1, y0, y1, z, col)
		return
	super(x0, x1, y0, y1, z, col)


func _collider_rect(x0: float, x1: float, y0: float, y1: float,
		one_way := false) -> void:
	if not _pit_pass:
		# the main floor collider: split at the gaps
		if y0 == FLOOR_Y and x1 - x0 > 20000.0:
			var cursor := x0
			for g in GAPS:
				super(cursor, g[0], y0, y1, one_way)
				cursor = g[1]
			super(cursor, x1, y0, y1, one_way)
			return
		# anything walkable the seed drops over a hole: no ghost floors
		if y0 > FLOOR_Y - 170.0 and y0 < FLOOR_Y + 130.0:
			for g in GAPS:
				if x1 > g[0] - 40.0 and x0 < g[1] + 40.0:
					return
	super(x0, x1, y0, y1, one_way)


# ---------- the holes: open throats into the next layer ----------

func _punch_gaps() -> void:
	# sweep away meadow/prop art painted across the holes (the ground band
	# builds its rows directly, so we clean up after the fact)
	for child in get_children():
		if child is Sprite2D:
			var p: Vector2 = child.position
			for g in GAPS:
				if p.x > g[0] - 30.0 and p.x < g[1] + 30.0 \
						and p.y > FLOOR_Y - 260.0 and p.y < FLOOR_Y + 520.0:
					child.queue_free()
					break
	_pit_pass = true
	for g in GAPS:
		_build_throat(g[0], g[1])
	_pit_pass = false


func _build_throat(x0: float, x1: float) -> void:
	# lips: chunky pebbles + fringe spilling over the edge (reads intended)
	for lip: float in [x0, x1]:
		var out := -1.0 if lip == x0 else 1.0
		_sprite("fungalground%d.png" % [1, 8][0 if lip == x0 else 1],
				Vector2(lip, FLOOR_Y + 14.0), 0.46, 2, Color.WHITE, lip == x1)
		_fringe(lip - out * 90.0 - 45.0, lip - out * 90.0 + 45.0,
				FLOOR_Y + 8.0, false, 0.18, 0.28, 4, FRINGE_NEAR)
	# cut faces: pebble armor, hanging curls, and glowers marking the way
	# down — the throat never bottoms out
	_pebble_col(x0, FLOOR_Y + 30.0, FLOOR_Y + 860.0, 0.42, 1)
	_pebble_col(x1, FLOOR_Y + 30.0, FLOOR_Y + 860.0, 0.42, 1)
	_prop_hang("fungalfrond%d.png" % (18 + _rng.randi() % 2), x0 + 40.0,
			FLOOR_Y + 60.0, 0.22, 1, FRINGE_HANG)
	_prop_hang("fungalfrond%d.png" % (18 + _rng.randi() % 2), x1 - 40.0,
			FLOOR_Y + 90.0, 0.2, 1, FRINGE_HANG)
	var wg := _prop("mushroomglow%d.png" % [17, 23, 12][_rng.randi() % 3],
			x0 + 50.0, FLOOR_Y + 520.0, 0.24, 1, Color.WHITE)
	_glow_light(wg, [GLOW_COOL, GLOW_MOSS][_rng.randi() % 2], 0.3, 1.0)
	# the dark rises to meet whoever falls: a fade-to-black down the shaft
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
			Vector2(x0 - 10.0, FLOOR_Y + 200.0), Vector2(x1 + 10.0, FLOOR_Y + 200.0),
			Vector2(x1 + 10.0, FLOOR_Y + 880.0), Vector2(x0 - 10.0, FLOOR_Y + 880.0)])
	p.vertex_colors = PackedColorArray([
			Color(0, 0, 0, 0), Color(0, 0, 0, 0),
			Color(0.004, 0.008, 0.007, 1.0), Color(0.004, 0.008, 0.007, 1.0)])
	p.color = Color.WHITE
	p.z_index = 7
	add_child(p)
