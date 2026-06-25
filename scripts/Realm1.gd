extends Node2D

# Realm 1 — "The Crimson Hollow".
#
# IMPORTANT: the level geometry is HAND-PAINTED by Advika directly into the
# $TileMapLayer node in the Godot editor. This script does NOT generate any
# tiles. It only does the plumbing that makes a painted level playable:
#
#   1. Collision   — every painted cell becomes solid ground at runtime, so
#                    you stand on exactly what you see. Paint more tiles and
#                    they are automatically walkable. No code change needed.
#   2. Spawn       — Curiosity is placed on top of the painted floor, at its
#                    left edge.
#   3. Exit door   — anchored to the right edge of the painted floor; pressing
#                    the interact key (Y) while standing in it returns to the hub.
#   4. Camera      — limits clamped to the painted level's bounds.
#
# The old code-that-generated-the-whole-level approach was removed: it built a
# second, invisible level that fought the painted one (Curiosity spawned ~700px
# below the floor you could see). One level system now — yours.

@onready var _tiles: TileMapLayer = $TileMapLayer
@onready var _curiosity: CharacterBody2D = $Curiosity
@onready var _motes: GPUParticles2D = $CeilingMotes
@onready var _exit_door: Area2D = $ExitDoor/DoorArea

# Vertical offset from the camera's view-center up to where motes spawn.
const MOTE_SPAWN_ABOVE_CENTER: float = 400.0

# Curiosity's size in this realm (overrides the scene value at runtime).
const CURIOSITY_SCALE: float = 0.17

# Eyes-as-lives HUD: 3 eyes, one closes per death (constant rule every realm).
const LIVES_HUD := preload("res://scenes/UI/LivesHUD.tscn")
const STARTING_LIVES: int = 3

var _cam: Camera2D
var _cam_pos: Vector2 = Vector2.ZERO   # our own smoothed camera position (parent-independent)
var _cam_target_y: float = 0.0         # vertical follow target; only updates while grounded
var _at_exit: bool = false

var _lives: LivesHUD
var _spawn_pos: Vector2
var _kill_y: float = INF      # fall below this (a pit) and you die
var _dying: bool = false      # guards the death/respawn sequence


# Camera zoom (the camera inherits Curiosity's scale, so this counter-zooms to
# frame the cave). Lower = more world on screen.
const CAMERA_ZOOM: float = 2.0

# Camera follow feel (we drive the camera in _drive_camera).
const CAM_LERP: float = 4.5      # follow responsiveness (higher = tighter / snappier)
const CAM_Y_LOOK: float = -50.0  # bias the view slightly above Curiosity

# Cave-art sizing. The parallax layers render smaller as we zoom out, which
# opens a dark void below the art. Scale them up so the cave fills the frame
# down to the floor, and shift vertically so the waterline meets the floor.
# Tuned by eye for CAMERA_ZOOM above.
const BG_SCALE: float = 2.5
const BG_Y_OFFSET: float = -500.0
const BG_IMG_WIDTH: float = 960.0  # source background image width (for tiling)


func _ready() -> void:
	# Ambient bed for the Crimson Hollow (placeholder drone until a real track).
	AudioManager.play_placeholder("realm1")
	_align_background()
	_setup_atmosphere()
	_setup_pieces()
	_make_painted_tiles_solid()
	_add_boundary_walls()
	_place_curiosity_on_floor()
	_place_exit_door()
	_wire_exit_door()
	_setup_camera_limits()
	_setup_lives()


# Horizontal parallax speed per band, BG1 (farthest) → BG4 (nearest). Wider spread
# = stronger receding-space feel: the far cave nearly crawls, the near rock rushes
# as Curiosity walks. (World/gameplay layer moves at 1.0.)
const PARALLAX_X: Array[float] = [0.04, 0.14, 0.32, 0.62]

func _align_background() -> void:
	var pbg: Node = get_node_or_null("ParallaxBackground")
	if pbg == null:
		return
	var idx: int = 0
	for layer in pbg.get_children():
		var spr: Node2D = (layer as Node).get_node_or_null("Sprite") as Node2D
		if spr != null:
			spr.scale = Vector2(BG_SCALE, BG_SCALE)
			spr.position.y = BG_Y_OFFSET
		# Keep horizontal tiling matched to the new art width so there are no
		# seams as the camera scrolls, and widen the per-band speed spread.
		if layer is ParallaxLayer:
			(layer as ParallaxLayer).motion_mirroring = Vector2(BG_IMG_WIDTH * BG_SCALE, 0)
			if idx < PARALLAX_X.size():
				(layer as ParallaxLayer).motion_scale = Vector2(PARALLAX_X[idx], 0.0)
		idx += 1


# ─── atmosphere (depth pass) ───────────────────────────────────────────────
# Hollow-Knight depth = VALUE SEPARATION (far layers brighter/cooler, near layers
# pushed dark) + a VIGNETTE that frames the view. Done in code so it stays tunable
# and reversible. (Foreground silhouette frame + camera headroom are later passes.)

# Multiply tint per parallax band, BG1 (farthest) → BG4 (nearest). Far = light &
# cool (reads as hazy distance); near = dark. This bright→dark gradient is the
# core depth cue.
const BAND_TINTS: Array[Color] = [
	Color(1.02, 1.08, 1.24),   # BG1 farthest — cool brighten, hazy
	Color(0.86, 0.92, 1.08),   # BG2
	Color(0.70, 0.76, 0.92),   # BG3
	Color(0.56, 0.60, 0.76),   # BG4 nearest bg — darkest (but lifted)
]

# Ambient light level (overrides the scene's CanvasModulate). Higher = brighter
# base; the lantern/glows still read as the focal warmth on top of this.
const AMBIENT_LIGHT: Color = Color(0.88, 0.90, 1.02)

const VIGNETTE_STRENGTH: float = 0.32   # 0..1 edge darkness
const VIGNETTE_INNER: float = 0.48     # where the darkening starts (smaller = more)
const VIGNETTE_COLOR: Color = Color(0.02, 0.01, 0.05, 1.0)

const VIGNETTE_SHADER := "
shader_type canvas_item;
uniform float strength = 0.6;
uniform float inner = 0.48;
uniform vec4 vcolor : source_color = vec4(0.02, 0.01, 0.05, 1.0);
void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(inner, 0.96, d) * strength;
	COLOR = vec4(vcolor.rgb, v);
}
"

func _setup_atmosphere() -> void:
	var cm: CanvasModulate = get_node_or_null("CanvasModulate") as CanvasModulate
	if cm != null:
		cm.color = AMBIENT_LIGHT
	_tint_parallax_bands()
	_add_vignette()


func _tint_parallax_bands() -> void:
	var pbg: Node = get_node_or_null("ParallaxBackground")
	if pbg == null:
		return
	var bands: Array[String] = ["BG1", "BG2", "BG3", "BG4"]
	for i in range(bands.size()):
		var layer: Node = pbg.get_node_or_null(bands[i])
		if layer == null:
			continue
		var spr: CanvasItem = layer.get_node_or_null("Sprite") as CanvasItem
		if spr != null and i < BAND_TINTS.size():
			spr.self_modulate = BAND_TINTS[i]


func _add_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.name = "Vignette"
	cl.layer = 2   # above the world, below the lives HUD
	add_child(cl)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", VIGNETTE_STRENGTH)
	mat.set_shader_parameter("inner", VIGNETTE_INNER)
	mat.set_shader_parameter("vcolor", VIGNETTE_COLOR)
	rect.material = mat
	cl.add_child(rect)


# ─── collision ───────────────────────────────────────────────────────────
# Build one StaticBody2D with a box collider per painted cell. Parented under
# the TileMapLayer so it inherits the layer's transform (the tiles' offset).
# Deterministic, self-contained — doesn't touch the TileSet resource, so it
# can't desync from the painted art.
func _make_painted_tiles_solid() -> void:
	if _tiles == null or _tiles.tile_set == null:
		return
	var tsize: Vector2 = Vector2(_tiles.tile_set.tile_size)
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "PaintedCollision"
	_tiles.add_child(body)
	# Every still-painted cell becomes solid ground. (Moving planks were already
	# erased from the layer in _extract_moving_planks, so they're skipped here.)
	var remaining := {}
	for cell in _tiles.get_used_cells():
		remaining[cell] = true
	_emit_merged_colliders(body, remaining, tsize)


# Greedy-merge a set of cells (Dictionary<Vector2i, true>) into maximal rectangles
# and add one CollisionShape2D per rectangle to `body`. One box PER CELL left
# internal seams that Curiosity's collider caught on — she jittered and
# is_on_floor() failed, freezing her in the air pose. Merging (grow each rect
# right, then down) yields seamless colliders. Consumes `remaining`.
func _emit_merged_colliders(body: CollisionObject2D, remaining: Dictionary, tsize: Vector2) -> void:
	var keys: Array = remaining.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.y * 100000 + a.x) < (b.y * 100000 + b.x))
	for start in keys:
		if not remaining.has(start):
			continue
		# Grow width along the row.
		var w: int = 1
		while remaining.has(Vector2i(start.x + w, start.y)):
			w += 1
		# Grow height while the full-width row below is present.
		var h: int = 1
		while true:
			var row_ok: bool = true
			for dx in range(w):
				if not remaining.has(Vector2i(start.x + dx, start.y + h)):
					row_ok = false
					break
			if not row_ok:
				break
			h += 1
		# Consume the rectangle's cells and emit one collider for it.
		for dy in range(h):
			for dx in range(w):
				remaining.erase(Vector2i(start.x + dx, start.y + dy))
		var cs: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(w, h) * tsize
		cs.shape = rect
		cs.position = (Vector2(start) + Vector2(w, h) * 0.5) * tsize
		body.add_child(cs)


# ─── moving pieces ─────────────────────────────────────────────────────────
# Advika hand-paints the whole level — floor, structures, and the thin floating
# planks/logs — into one static TileMapLayer. A baked tile can't move, so to make
# a piece move we LIFT its cells out of the layer into a self-contained
# AnimatableBody2D (its own copy of the art + a collider) and animate it.
# Curiosity rides them correctly: an AnimatableBody2D with sync_to_physics carries
# a CharacterBody2D standing on it.
#
# Pieces are found by connected components of the painted cells: the floor (+
# anything sitting on it) is one huge component, left baked & static; every other
# component is a movable "piece" — thin ones are planks, taller ones structures.
const PLANK_MAX_H: int = 4      # tiles tall; taller floating groups are "structures"
const PLANK_MIN_W: int = 4      # tiles wide; narrower floating bits are "structures" too
const FLOOR_MIN_CELLS: int = 150 # a component this big is the painted floor/terrain
const FLOOR_MIN_W: int = 45      # …or this wide

# Global speed dial for every piece's motion: lower = faster. 1.0 = original feel.
const MOTION_DURATION_SCALE: float = 0.5

# DEBUG: float each movable piece's index above it in-game so Advika can call out
# which piece should get which motion. Set false to hide the numbers.
const DEBUG_PIECE_LABELS: bool = false

# Per-piece motion override, keyed by the piece index shown above it. Values:
# "side" (←→ slide), "updown" (↑↓ elevator), "bob" (slow drift), "static" (frozen).
# Pieces not listed fall back to their kind's default: planks animate (mixed
# slide/elevator/bob), floating structures stay still.
const PIECE_MOTION := {
	# ── left half ──
	2: "updown",        # brick gateway structure — elevator
	3: "side",          # plank — slides left/right
	4: "side",
	5: "side",
	6: "updown",        # structure — elevator
	10: "side",
	# fast, alternating-direction gauntlet over the tight stepping-stone cluster
	12: "side_fast",
	13: "updown_fast",
	14: "side_fast",
	15: "updown_fast",
	16: "side_fast",
	# ── right half (mirror, index +17) — same layout duplicated across the map ──
	19: "updown",
	20: "side",
	21: "side",
	22: "side",
	23: "updown",
	27: "side",
	29: "side_fast",
	30: "updown_fast",
	31: "side_fast",
	32: "updown_fast",
	33: "side_fast",
}

# Per-piece fine tuning (both default to 1.0 when unlisted).
#   PIECE_SPEED — higher = faster motion
#   PIECE_DIST  — higher = travels farther
const PIECE_SPEED := {
	10: 1.6,
	19: 1.5,
	22: 1.5,
	27: 1.6,
}
const PIECE_DIST := {
	10: 1.25,
	20: 1.6,
	27: 1.5,
}

func _setup_pieces() -> void:
	if _tiles == null or _tiles.tile_set == null:
		return
	var tsize: Vector2 = Vector2(_tiles.tile_set.tile_size)
	var pieces: Array = _find_pieces()
	for i in range(pieces.size()):
		var p: Dictionary = pieces[i]
		var motion: String = PIECE_MOTION.get(i, "")
		if motion == "":
			motion = "static" if p["kind"] == "structure" else _default_plank_motion(i)
		var body: AnimatableBody2D = null
		if motion != "static":
			body = _lift_piece(p, tsize, i, motion)
		if DEBUG_PIECE_LABELS:
			_label_piece(p, tsize, i, body)


# Connected components (4-connectivity) of painted cells, minus the floor/terrain
# (one huge component). Each remaining component is a movable piece. Sorted
# left-to-right (then top-to-bottom) so indices are stable across runs.
func _find_pieces() -> Array:
	var cells := {}
	for c in _tiles.get_used_cells():
		cells[c] = true
	var seen := {}
	var pieces: Array = []
	for start in cells.keys():
		if seen.has(start):
			continue
		var stack: Array = [start]
		var group: Array = []
		var mn := Vector2i(1 << 30, 1 << 30)
		var mx := Vector2i(-(1 << 30), -(1 << 30))
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			if seen.has(c) or not cells.has(c):
				continue
			seen[c] = true
			group.append(c)
			mn.x = mini(mn.x, c.x); mn.y = mini(mn.y, c.y)
			mx.x = maxi(mx.x, c.x); mx.y = maxi(mx.y, c.y)
			stack.append(c + Vector2i(1, 0)); stack.append(c + Vector2i(-1, 0))
			stack.append(c + Vector2i(0, 1)); stack.append(c + Vector2i(0, -1))
		var w: int = mx.x - mn.x + 1
		var h: int = mx.y - mn.y + 1
		if group.size() >= FLOOR_MIN_CELLS or w >= FLOOR_MIN_W:
			continue   # the floor / main terrain
		var kind: String = "plank" if (h <= PLANK_MAX_H and w >= PLANK_MIN_W) else "structure"
		pieces.append({"cells": group, "mn": mn, "mx": mx, "kind": kind})
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector2i = a["mn"]; var pb: Vector2i = b["mn"]
		return (pa.x * 100000 + pa.y) < (pb.x * 100000 + pb.y))
	return pieces


# Default motion for an un-overridden plank: cycle slide / elevator / bob so the
# cave feels alive rather than synchronized.
func _default_plank_motion(idx: int) -> String:
	match idx % 3:
		0: return "side"
		1: return "updown"
		_: return "bob"


# Lift a piece's cells out of the static layer into an animated AnimatableBody2D
# (own art + collider) and start its motion. Returns the body.
func _lift_piece(p: Dictionary, tsize: Vector2, idx: int, motion: String) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.sync_to_physics = true   # carry riders standing on it
	body.name = "MovingPiece%d" % idx
	_tiles.add_child(body)        # parent under the layer to inherit its transform

	# Visual: a child layer painting just this piece's cells (same art) at their
	# original world coords. The body starts at local (0,0), so the art lands
	# exactly where Advika painted it; the tween offsets from there.
	var art := TileMapLayer.new()
	art.name = "Art"
	art.tile_set = _tiles.tile_set
	body.add_child(art)
	var remaining := {}
	for c in p["cells"]:
		art.set_cell(c, _tiles.get_cell_source_id(c), _tiles.get_cell_atlas_coords(c),
			_tiles.get_cell_alternative_tile(c))
		remaining[c] = true

	# Collider(s): merged rectangles over the piece, at the same world coords.
	_emit_merged_colliders(body, remaining, tsize)

	# Erase the originals so no static ghost remains (and they're not re-baked).
	for c in p["cells"]:
		_tiles.erase_cell(c)

	_animate_piece(body, idx, tsize, motion)
	return body


# Drive one piece's looping motion. Per-piece timing (by index) keeps neighbours
# out of phase. Each pattern oscillates symmetrically around the painted spot and
# returns home, so a piece always passes back through where it started.
func _animate_piece(body: AnimatableBody2D, idx: int, tsize: Vector2, motion: String) -> void:
	# Alternating start direction (by index) so neighbours in a cluster sweep
	# opposite ways — reads as "different directions".
	var dir: float = -1.0 if (idx % 2 == 1) else 1.0
	# Speed: global dial / per-piece speed (higher speed → shorter duration).
	var s: float = MOTION_DURATION_SCALE / float(PIECE_SPEED.get(idx, 1.0))
	var dst: float = float(PIECE_DIST.get(idx, 1.0))   # per-piece travel distance
	var t: Tween = create_tween().set_loops()
	match motion:
		"side":          # horizontal slide — ride it across the gap
			_ping(t, body, "position:x", tsize.x * 2.5 * dst, (2.8 + float(idx % 4) * 0.35) * s)
		"updown":        # vertical elevator — lifts Curiosity toward higher ledges
			_ping(t, body, "position:y", -tsize.y * 2.0 * dst, (2.4 + float(idx % 3) * 0.4) * s)
		"side_fast":     # quick horizontal — for the harder gauntlet
			_ping(t, body, "position:x", dir * tsize.x * 3.0 * dst, (1.05 + float(idx % 3) * 0.12) * s)
		"updown_fast":   # quick vertical — for the harder gauntlet
			_ping(t, body, "position:y", dir * tsize.y * 2.6 * dst, (0.95 + float(idx % 3) * 0.12) * s)
		_:               # bob — gentle atmospheric drift
			_ping(t, body, "position:y", tsize.y * 0.7 * dst, (3.4 + float(idx % 5) * 0.3) * s)


# Append a symmetric 0 → +amp → -amp → 0 oscillation on `prop` to a looping tween.
func _ping(t: Tween, body: AnimatableBody2D, prop: String, amp: float, d: float) -> void:
	t.tween_property(body, prop, amp, d) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(body, prop, -amp, d * 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(body, prop, 0.0, d) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# DEBUG: float the piece's index above it. Rides a moving body; pinned for static.
func _label_piece(p: Dictionary, tsize: Vector2, idx: int, body: AnimatableBody2D) -> void:
	var lbl := Label.new()
	lbl.text = "#%d" % idx
	lbl.add_theme_font_size_override("font_size", int(maxf(tsize.y * 2.5, 24.0)))
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.35))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.z_index = 200
	var mn: Vector2i = p["mn"]
	var mx: Vector2i = p["mx"]
	lbl.position = Vector2((float(mn.x) + float(mx.x) + 1.0) * 0.5 * tsize.x - tsize.x * 1.6,
		float(mn.y) * tsize.y - tsize.y * 2.2)
	if body != null:
		body.add_child(lbl)
	else:
		_tiles.add_child(lbl)


# ─── boundary walls ──────────────────────────────────────────────────────
# Invisible walls at the far-left and far-right edges of the painted level so
# Curiosity can't walk off the world into the void. Tall enough that you can't
# jump over them either. Derived from the level bounds, so they stay correct at
# any level length.
func _add_boundary_walls() -> void:
	if _tiles == null or _tiles.tile_set == null:
		return
	var ur: Rect2i = _tiles.get_used_rect()
	var tsize: Vector2 = Vector2(_tiles.tile_set.tile_size)
	var top: float = float(ur.position.y) * tsize.y
	var bottom: float = float(ur.position.y + ur.size.y) * tsize.y
	var center_y: float = (top + bottom) * 0.5
	# Span the whole level height plus a generous buffer above/below.
	var wall_h: float = (bottom - top) + tsize.y * 60.0
	var left_x: float = float(ur.position.x) * tsize.x
	var right_x: float = float(ur.position.x + ur.size.x) * tsize.x

	var body: StaticBody2D = StaticBody2D.new()
	body.name = "BoundaryWalls"
	_tiles.add_child(body)
	for wall_x in [left_x, right_x]:
		var cs: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(tsize.x * 2.0, wall_h)
		cs.shape = rect
		cs.position = Vector2(wall_x, center_y)
		body.add_child(cs)


# ─── placement ───────────────────────────────────────────────────────────
func _place_curiosity_on_floor() -> void:
	if _curiosity == null or _tiles == null or _tiles.tile_set == null:
		return
	_curiosity.scale = Vector2(CURIOSITY_SCALE, CURIOSITY_SCALE)
	var ur: Rect2i = _tiles.get_used_rect()
	var tsize: Vector2 = Vector2(_tiles.tile_set.tile_size)
	# Spawn a few tiles in from the left, on the MAIN FLOOR — find the top of the
	# contiguous solid band at the bottom (scan up from the bottom row), so we
	# skip any floating platform above and Curiosity always starts grounded.
	var spawn_col: int = ur.position.x + 6
	var bottom_row: int = ur.position.y + ur.size.y - 1
	var surface_row: int = bottom_row
	for r in range(bottom_row, ur.position.y - 1, -1):
		if _tiles.get_cell_source_id(Vector2i(spawn_col, r)) != -1:
			surface_row = r
		else:
			break
	var floor_top: float = _tiles.to_global(Vector2(spawn_col, surface_row) * tsize).y
	var left_x: float = _tiles.to_global(Vector2(spawn_col, surface_row) * tsize).x
	_curiosity.position = Vector2(
		left_x,
		floor_top - _curiosity_half_height()          # feet rest on the floor top
	)
	_spawn_pos = _curiosity.position
	# A "pit" kill plane well below the floor — falling past it counts as a death.
	var bottom: float = _tiles.to_global(Vector2(ur.position + ur.size) * tsize).y
	_kill_y = bottom + tsize.y * 30.0


func _curiosity_half_height() -> float:
	var shape_node: CollisionShape2D = _curiosity.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size.y * 0.5 * _curiosity.scale.y
	return 100.0 * _curiosity.scale.y


const DOOR_SPRITE_HALF_H: float = 90.0   # door_arch.png is 180px tall, centred

func _place_exit_door() -> void:
	var door: Node2D = get_node_or_null("ExitDoor") as Node2D
	if door == null or _tiles == null or _tiles.tile_set == null:
		return
	var ur: Rect2i = _tiles.get_used_rect()
	var tsize: Vector2 = Vector2(_tiles.tile_set.tile_size)
	var right_x: float = _tiles.to_global(Vector2(ur.position + ur.size) * tsize).x
	# Find the FLOOR SURFACE at the door's column (scan down to the first solid
	# cell) — not ur.position.y, which is the top of the highest platform and
	# left the door floating high in the air.
	var door_col: int = ur.position.x + ur.size.x - 4
	var surface_row: int = ur.position.y + ur.size.y - 1
	for r in range(ur.position.y, ur.position.y + ur.size.y):
		if _tiles.get_cell_source_id(Vector2i(door_col, r)) != -1:
			surface_row = r
			break
	var surface_y: float = _tiles.to_global(Vector2(door_col, surface_row) * tsize).y
	# Lift the door half its sprite height so its base rests on the floor.
	door.position = Vector2(right_x - tsize.x * 4.0, surface_y - DOOR_SPRITE_HALF_H)


# ─── exit interaction ──────────────────────────────────────────────────────
# The door only fires when an external controller calls trigger() (the Hub does
# the same). Here the realm is that controller: while Curiosity overlaps the
# exit door, pressing "interact" (Y) returns to the hub.
func _wire_exit_door() -> void:
	if _exit_door == null:
		return
	_exit_door.near_door.connect(func(_d: Node) -> void: _at_exit = true)
	_exit_door.left_door.connect(func(_d: Node) -> void: _at_exit = false)


func _setup_camera_limits() -> void:
	if _curiosity == null:
		return
	var cam: Camera2D = _curiosity.get_node_or_null("Camera") as Camera2D
	if cam == null or _tiles == null or _tiles.tile_set == null:
		return
	var ur: Rect2i = _tiles.get_used_rect()
	var tsize: Vector2 = Vector2(_tiles.tile_set.tile_size)
	var top_left: Vector2 = _tiles.to_global(Vector2(ur.position) * tsize)
	var bot_right: Vector2 = _tiles.to_global(Vector2(ur.position + ur.size) * tsize)
	cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	var view_h: float = get_viewport().get_visible_rect().size.y / (CAMERA_ZOOM * maxf(absf(cam.global_scale.y), 0.001))
	# Horizontal: clamp to the painted level width.
	cam.limit_left = int(top_left.x)
	cam.limit_right = int(bot_right.x)
	# Vertical: keep the band AT LEAST one view tall so the floor is always pinned
	# to the bottom (never reveals the void below it). When the level is taller
	# than the view, the top limit rises above the floor so the camera SCROLLS UP
	# as Curiosity climbs; when short, it stays locked with the floor at bottom.
	cam.limit_bottom = int(bot_right.y)
	cam.limit_top = int(minf(top_left.y - tsize.y * 4.0, bot_right.y - view_h))
	# Steady the camera: we drive it ourselves (see _drive_camera). It follows X
	# always and follows Curiosity's HEIGHT only while she's grounded — during a
	# jump the vertical target holds, so hops never bob the view, yet it still
	# tracks where she lands / when she's carried up a platform. No dead-zone drift.
	cam.position_smoothing_enabled = false
	cam.drag_vertical_enabled = false
	cam.drag_horizontal_enabled = false
	_cam = cam
	_cam_target_y = _curiosity.global_position.y + CAM_Y_LOOK
	_cam_pos = Vector2(_curiosity.global_position.x, _cam_target_y)
	cam.global_position = _cam_pos


# Follow Curiosity: X always; Y only while she's grounded (held during jumps so
# hops don't bob the view). Camera2D limits still clamp the final view to the
# level bounds.
func _drive_camera(delta: float) -> void:
	if _cam == null or _curiosity == null:
		return
	if _curiosity.is_on_floor():
		_cam_target_y = _curiosity.global_position.y + CAM_Y_LOOK
	# Track our own position (not the camera's, which the parent yanks each frame)
	# so the vertical hold during a jump is absolute, not a tug-of-war.
	var t: float = clampf(delta * CAM_LERP, 0.0, 1.0)
	_cam_pos.x = lerpf(_cam_pos.x, _curiosity.global_position.x, t)
	_cam_pos.y = lerpf(_cam_pos.y, _cam_target_y, t)
	_cam.global_position = _cam_pos


# ─── lives / death / respawn ───────────────────────────────────────────────
func _setup_lives() -> void:
	_lives = LIVES_HUD.instantiate() as LivesHUD
	add_child(_lives)
	_lives.reset(STARTING_LIVES)


# Run the death beat: flinch, close an eye, respawn at the start. When the last
# eye closes, refill to full (soft reset) so the realm is always playable.
func _die() -> void:
	if _dying:
		return
	_dying = true
	_curiosity.hurt()
	var remaining: int = _lives.lose_eye()
	await get_tree().create_timer(0.45).timeout
	if remaining <= 0:
		_lives.reset(STARTING_LIVES)
	_respawn()
	_dying = false


func _respawn() -> void:
	_curiosity.velocity = Vector2.ZERO
	_curiosity.position = _spawn_pos


func _input(event: InputEvent) -> void:
	# DEV (temporary): Backspace takes a hit, so the eyes/respawn are testable
	# before real damage (creatures/hazards) exists. Remove with the enemy brick.
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_BACKSPACE:
		_die()


func _process(delta: float) -> void:
	_drive_camera(delta)
	if _at_exit and Input.is_action_just_pressed("interact"):
		_exit_door.trigger()
	# Fall into a pit (below the kill plane) → death.
	if not _dying and _curiosity != null and _curiosity.global_position.y > _kill_y:
		_die()
	# Keep the ceiling-mote emitter pinned just above the top of the view so
	# falling motes always fill the screen as the camera travels.
	if _cam != null and _motes != null:
		var center: Vector2 = _cam.get_screen_center_position()
		_motes.global_position = Vector2(center.x, center.y - MOTE_SPAWN_ABOVE_CENTER)
