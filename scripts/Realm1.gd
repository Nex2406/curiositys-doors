extends Node2D

# Realm 1 — caves. Linear left-to-right platforming. Geometry sits ON TOP
# of an 8-layer parallax cave backdrop that fills the viewport at every
# camera position (deepest layer is fully opaque, every layer mirrors
# horizontally).
#
# Tile palette (audited via scripts/inspect_tileset.py density pass —
# every coord below is a 100% / >95% opaque cell on mainlev_build.png):
#
#   GROUND   (solid floor, dark rocky cave variants)
#     (7,23)  (8,23)  (9,23)  (7,24)  (8,24)
#   BRICK    (solid wall, brick texture)
#     (26,16) (27,16) (30,16)
#   WOOD     (solid wooden plank platform — used in 3-tile-wide runs)
#     (23,1)  left-end with bevel
#     (25,1)  middle with X-brace
#     (28,1)  right-end with bevel
#   CEIL     (solid ceiling — brown rocky blocks matching the floor)
#     (7,26)  (9,26)
#   DECOR    (no collision)
#     (20,24) (20,25)  red glowing gem cluster
#     (7,3)            stalactite cluster
#
# The TileSet is built at runtime: every non-empty 32x32 cell on the
# source sheet becomes an atlas tile, but only the curated SOLID_TILES
# coords above carry collision polygons. Decorative tiles end up on a
# separate non-colliding TileMapLayer.

const SOURCE_TEXTURE: Texture2D = preload("res://assets/realms/realm1_caves/mainlev_build.png")
const ATLAS_TILE_SIZE: Vector2i = Vector2i(32, 32)

# Atlas coords — see header comment for source.
const T_GROUND_A: Vector2i = Vector2i(7, 23)
const T_GROUND_B: Vector2i = Vector2i(8, 23)
const T_GROUND_C: Vector2i = Vector2i(9, 23)
const T_GROUND_D: Vector2i = Vector2i(7, 24)
const T_GROUND_E: Vector2i = Vector2i(8, 24)
const T_BRICK_A:  Vector2i = Vector2i(26, 16)
const T_BRICK_B:  Vector2i = Vector2i(27, 16)
const T_BRICK_C:  Vector2i = Vector2i(30, 16)
const T_WOOD_L:   Vector2i = Vector2i(23, 1)   # plank left-end (left overhang bevel)
const T_WOOD_M:   Vector2i = Vector2i(25, 1)   # plank middle with X-brace
const T_WOOD_R:   Vector2i = Vector2i(28, 1)   # plank right-end (right overhang bevel)
const T_CEIL_A:   Vector2i = Vector2i(7, 26)
const T_CEIL_B:   Vector2i = Vector2i(9, 26)
const T_DECOR_GEM_A: Vector2i = Vector2i(20, 24)
const T_DECOR_GEM_B: Vector2i = Vector2i(20, 25)
const T_DECOR_STAL:  Vector2i = Vector2i(7, 3)

const GROUND_VARIANTS: Array[Vector2i] = [T_GROUND_A, T_GROUND_B, T_GROUND_C, T_GROUND_D, T_GROUND_E]
const BRICK_VARIANTS: Array[Vector2i] = [T_BRICK_A, T_BRICK_B, T_BRICK_C]
const SOLID_TILES: Array[Vector2i] = [
	T_GROUND_A, T_GROUND_B, T_GROUND_C, T_GROUND_D, T_GROUND_E,
	T_BRICK_A, T_BRICK_B, T_BRICK_C,
	T_WOOD_L, T_WOOD_M, T_WOOD_R,
	T_CEIL_A, T_CEIL_B,
]

# World scale: parent Node2D scales TileMapLayers 2x so visual cells
# read as 64x64. Level extents are kept in tile coords below.
const VISUAL_TILE: int = 64

# Level dimensions. 96 tiles wide x 64 = 6144 world px, just past the
# requested ~6000. Floor sits at tile_y = 9 so its top edge lands at
# world y = 576 (matches the spec's "floor y around 550-720").
const LEVEL_WIDTH_TILES: int = 96
const FLOOR_Y: int = 9
const SUBFLOOR_DEPTH: int = 3   # rows below the floor surface (out-of-view fill)

# Reachability note: jump_velocity=-240, gravity=350 → ~82px peak. From
# the floor (y=9) Curiosity can land on tile_y=8; from y=8 she reaches
# y=7; etc. So multi-tier platforms must be staircased one tile at a
# time.

# Floor gaps Curiosity must jump. [tile_x_start_inclusive, tile_x_end_exclusive].
const FLOOR_GAPS: Array = [
	[15, 18],   # 3-tile gap, easy
	[33, 37],   # 4-tile gap, medium
	[50, 55],   # 5-tile gap, bridged by a platform at y=8
	[72, 75],   # 3-tile gap, easy
]

# Floating platforms — wooden planks. [tile_x_left, tile_x_right_inclusive, tile_y].
# 10 platforms total; chain at x=25-30 climbs y=8 → 7 → 6 ; chain at
# x=63-66 ascends y=7 → 6.
const PLATFORMS: Array = [
	[10, 12, 8],
	[22, 24, 8],
	[25, 27, 7],
	[28, 30, 6],
	[40, 42, 8],
	[51, 53, 8],   # bridges floor gap 3
	[60, 62, 8],
	[63, 65, 7],
	[78, 80, 8],
	[82, 84, 7],   # chained from the y=8 platform — 2-tile gap clears under jump
]

# Bookend brick walls — purely visual, frame the level.
# [tile_x, tile_y_start_inclusive, tile_y_end_exclusive].
const WALLS: Array = [
	[0, 5, 9],
	[LEVEL_WIDTH_TILES - 1, 5, 9],
]

# Solid ceiling tiles — overhead at tile_y=0 across the level.
const CEILING_RUNS: Array = [
	[0, LEVEL_WIDTH_TILES],   # one run, full level width
]

# Decorative ceiling stalactites at tile_y=1, sparse.
const DECOR_STAL_X: Array = [4, 11, 19, 26, 35, 44, 53, 61, 70, 78, 87]
# Decorative red gem clusters on the ground at tile_y=8 — anchor moments.
const DECOR_GEM_X: Array = [7, 38, 67]

const SPAWN_TILE: Vector2i = Vector2i(2, FLOOR_Y - 1)
const EXIT_DOOR_TILE: Vector2i = Vector2i(LEVEL_WIDTH_TILES - 4, FLOOR_Y - 1)

@onready var _solids: TileMapLayer = $World/Solids
@onready var _decor: TileMapLayer = $World/Decor
@onready var _curiosity: CharacterBody2D = $Curiosity


func _ready() -> void:
	var ts: TileSet = _build_tileset()
	_solids.tile_set = ts
	_decor.tile_set = ts
	_paint_solids()
	_paint_decor()
	_position_curiosity()
	_position_exit_door()
	_setup_camera_limits()


func _build_tileset() -> TileSet:
	var ts: TileSet = TileSet.new()
	ts.tile_size = ATLAS_TILE_SIZE
	var phys_layer_id: int = ts.get_physics_layers_count()
	ts.add_physics_layer(phys_layer_id)

	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	src.texture = SOURCE_TEXTURE
	src.texture_region_size = ATLAS_TILE_SIZE
	# Source must be attached BEFORE create_tile so the TileSet's physics
	# layers propagate to per-tile data; otherwise add_collision_polygon
	# errors with physics.size()=0 and every tile ends up non-colliding
	# (which is what made Curiosity fall through the floor).
	ts.add_source(src, 0)

	var img: Image = SOURCE_TEXTURE.get_image()
	if img == null:
		push_error("[Realm1] tileset source has no image — import failed?")
		return ts
	var cols: int = img.get_width() / ATLAS_TILE_SIZE.x
	var rows: int = img.get_height() / ATLAS_TILE_SIZE.y
	for ty in range(rows):
		for tx in range(cols):
			var coord: Vector2i = Vector2i(tx, ty)
			if not _cell_is_filled(img, coord):
				continue
			src.create_tile(coord)
			if SOLID_TILES.has(coord):
				_attach_full_collision(src, coord, phys_layer_id)

	return ts


func _cell_is_filled(img: Image, coord: Vector2i) -> bool:
	# 5% non-transparent coverage is enough to count as a populated cell.
	var threshold: int = int(ATLAS_TILE_SIZE.x * ATLAS_TILE_SIZE.y * 0.05)
	var nonempty: int = 0
	var ax: int = coord.x * ATLAS_TILE_SIZE.x
	var ay: int = coord.y * ATLAS_TILE_SIZE.y
	for y in range(ATLAS_TILE_SIZE.y):
		for x in range(ATLAS_TILE_SIZE.x):
			if img.get_pixel(ax + x, ay + y).a > 0.12:
				nonempty += 1
				if nonempty > threshold:
					return true
	return false


func _attach_full_collision(src: TileSetAtlasSource, coord: Vector2i, phys_layer: int) -> void:
	var data: TileData = src.get_tile_data(coord, 0)
	if data == null:
		return
	var half: float = float(ATLAS_TILE_SIZE.x) * 0.5
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
	data.add_collision_polygon(phys_layer)
	data.set_collision_polygon_points(phys_layer, 0, poly)


func _paint_solids() -> void:
	# Floor strip + sub-floor fill, with gaps cut out.
	for x in range(LEVEL_WIDTH_TILES):
		if _x_in_gap(x):
			continue
		var top_coord: Vector2i = GROUND_VARIANTS[x % GROUND_VARIANTS.size()]
		_solids.set_cell(Vector2i(x, FLOOR_Y), 0, top_coord)
		# Sub-floor fill — keeps the cave from looking like a floating ribbon.
		for d in range(1, SUBFLOOR_DEPTH + 1):
			var sub_coord: Vector2i = GROUND_VARIANTS[(x + d) % GROUND_VARIANTS.size()]
			_solids.set_cell(Vector2i(x, FLOOR_Y + d), 0, sub_coord)

	# Floating wooden platforms — left-end / middle (with X-brace) / right-end.
	for p in PLATFORMS:
		var px_left: int = int(p[0])
		var px_right: int = int(p[1])
		var py: int = int(p[2])
		_solids.set_cell(Vector2i(px_left, py), 0, T_WOOD_L)
		for mx in range(px_left + 1, px_right):
			_solids.set_cell(Vector2i(mx, py), 0, T_WOOD_M)
		_solids.set_cell(Vector2i(px_right, py), 0, T_WOOD_R)

	# Bookend brick walls.
	for w in WALLS:
		var wx: int = int(w[0])
		for wy in range(int(w[1]), int(w[2])):
			var brick: Vector2i = BRICK_VARIANTS[wy % BRICK_VARIANTS.size()]
			_solids.set_cell(Vector2i(wx, wy), 0, brick)

	# Solid ceiling at tile_y = 0 across the level — frames the play area
	# overhead and blocks any future high-jump glitches from leaving frame.
	for run in CEILING_RUNS:
		for cx in range(int(run[0]), int(run[1])):
			var ceil_coord: Vector2i = T_CEIL_A if (cx % 2) == 0 else T_CEIL_B
			_solids.set_cell(Vector2i(cx, 0), 0, ceil_coord)


func _paint_decor() -> void:
	for x in DECOR_STAL_X:
		_decor.set_cell(Vector2i(int(x), 1), 0, T_DECOR_STAL)
	for x in DECOR_GEM_X:
		# Anchor gems just below the floor surface line for a glow accent.
		_decor.set_cell(Vector2i(int(x), FLOOR_Y - 1), 0, T_DECOR_GEM_A)
		_decor.set_cell(Vector2i(int(x), FLOOR_Y), 0, T_DECOR_GEM_B)


func _x_in_gap(x: int) -> bool:
	for g in FLOOR_GAPS:
		if x >= int(g[0]) and x < int(g[1]):
			return true
	return false


func _position_curiosity() -> void:
	var floor_top_world: float = float(FLOOR_Y) * float(VISUAL_TILE)
	# Curiosity collision rect = 88x432 at scene scale 0.5 → half-height 108.
	_curiosity.position = Vector2(
		float(SPAWN_TILE.x) * float(VISUAL_TILE) + float(VISUAL_TILE) * 0.5,
		floor_top_world - 108.0
	)


func _position_exit_door() -> void:
	var door: Node2D = get_node_or_null("ExitDoor") as Node2D
	if door == null:
		return
	# Door root sits ~340 above the floor — matches Hub's relative geometry,
	# so the arch reads as towering and the interaction collider (rel y +125)
	# lands just above Curiosity's body center.
	var floor_top: float = float(FLOOR_Y) * float(VISUAL_TILE)
	door.position = Vector2(
		float(EXIT_DOOR_TILE.x) * float(VISUAL_TILE) + float(VISUAL_TILE) * 0.5,
		floor_top - 340.0
	)


func _setup_camera_limits() -> void:
	var cam: Camera2D = _curiosity.get_node_or_null("Camera") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_right = LEVEL_WIDTH_TILES * VISUAL_TILE
	cam.limit_top = 0
	cam.limit_bottom = 720
	cam.position_smoothing_enabled = true
