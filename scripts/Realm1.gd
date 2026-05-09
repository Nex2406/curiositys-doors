extends Node2D

# Realm 1 — caves. A linear left-to-right platforming level built on top of
# mainlev_build.png (32x32 atlas, 32 cols x 32 rows). The TileSet is built
# at runtime: every non-empty 32x32 cell in the source becomes an atlas
# tile, but only a curated subset of coordinates carry collision shapes
# (the brick floor / wood platforms — see SOLID_TILES). Decorative tiles
# like ceiling stalactites end up on a separate non-colliding TileMapLayer.
#
# Why runtime rather than a pre-baked .tres: it keeps the tile palette
# discoverable (any new coord we want to use can be added to a constant
# rather than re-exported), and it avoids hand-authoring a 472-tile
# resource we'd never visually edit anyway. The cost is a ~50ms _ready()
# scan; for one level on scene-change that's invisible.

const SOURCE_TEXTURE: Texture2D = preload("res://assets/realms/realm1_caves/mainlev_build.png")
const ATLAS_TILE_SIZE: Vector2i = Vector2i(32, 32)

# Atlas coords picked from the source sheet (see scripts/sample_tiles.py for
# the visual sample sheet that informed these picks).
const T_BRICK_A: Vector2i = Vector2i(26, 12)   # primary brick floor / wall
const T_BRICK_B: Vector2i = Vector2i(26, 14)   # brick variant (reduces tiling)
const T_BRICK_C: Vector2i = Vector2i(26, 16)   # brick variant (sub-floor fill)
const T_WOOD_L:  Vector2i = Vector2i(28, 1)    # wooden plank, left half
const T_WOOD_R:  Vector2i = Vector2i(29, 1)    # wooden plank, right half
const T_CEIL_A:  Vector2i = Vector2i(11, 11)   # stalactite ceiling decor
const T_CEIL_B:  Vector2i = Vector2i(12, 11)   # stalactite ceiling decor variant

const SOLID_TILES: Array[Vector2i] = [T_BRICK_A, T_BRICK_B, T_BRICK_C, T_WOOD_L, T_WOOD_R]

# Level dimensions. With TileMapLayers parented to a Node2D scaled (2, 2)
# the visual cell is 64x64. 96 tiles wide -> 6144 world pixels.
const LEVEL_WIDTH_TILES: int = 96
const LEVEL_HEIGHT_TILES: int = 14
const FLOOR_Y: int = 9                 # tile row of the playable floor surface
const SUBFLOOR_DEPTH: int = 4          # how many rows under FLOOR_Y to fill

# Visual tile size after the parent scale-2 transform.
const VISUAL_TILE: int = 64

# Floor gaps (tile_x_start inclusive, tile_x_end exclusive). Curiosity must
# jump these. Widths are in source-tile units; multiply by VISUAL_TILE for
# pixel width. Default jump arc clears ~3 tiles comfortably; gap 3 is the
# stretch goal that needs a bridge platform.
const FLOOR_GAPS: Array = [
	[14, 17],   # 3-tile gap, easy
	[28, 32],   # 4-tile gap, medium
	[46, 51],   # 5-tile gap, requires the platform at x=48
	[66, 70],   # 4-tile gap
	[80, 83],   # 3-tile gap, ends in a high-step
]

# Aerial wooden platforms: [x_left, x_right, y]. Two-tile wide (left + right
# halves of the plank art). Y is in tile coords with 0 = top.
const PLATFORMS: Array = [
	[18, 19, 7],
	[22, 23, 6],
	[36, 37, 7],
	[48, 49, 7],   # bridges the wide gap
	[55, 56, 5],   # high jump up
	[60, 61, 7],
	[74, 75, 7],
	[88, 89, 6],
]

# Walls (vertical brick segments) for visual cap at the level bookends and
# a couple of mid-level chokes. [x, y_start, y_end_exclusive].
const WALLS: Array = [
	[0, 0, FLOOR_Y],            # left bookend
	[LEVEL_WIDTH_TILES - 1, 0, FLOOR_Y],   # right bookend
	[42, FLOOR_Y - 4, FLOOR_Y],    # mid-level pillar
]

const SPAWN_TILE: Vector2i = Vector2i(2, FLOOR_Y - 1)
const EXIT_DOOR_TILE: Vector2i = Vector2i(LEVEL_WIDTH_TILES - 4, FLOOR_Y - 1)

@onready var _solids: TileMapLayer = $World/Solids
@onready var _decor: TileMapLayer = $World/Decor
@onready var _curiosity: CharacterBody2D = $Curiosity


func _ready() -> void:
	var tile_set: TileSet = _build_tileset()
	_solids.tile_set = tile_set
	_decor.tile_set = tile_set
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

	ts.add_source(src, 0)
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
	# Floor strip + sub-floor fill, with gaps cut out
	for x in range(LEVEL_WIDTH_TILES):
		if _x_in_gap(x):
			continue
		var top_coord: Vector2i = T_BRICK_A if (x % 6) < 4 else T_BRICK_B
		_solids.set_cell(Vector2i(x, FLOOR_Y), 0, top_coord)
		for d in range(1, SUBFLOOR_DEPTH + 1):
			_solids.set_cell(Vector2i(x, FLOOR_Y + d), 0, T_BRICK_C)

	for p in PLATFORMS:
		_solids.set_cell(Vector2i(p[0], p[2]), 0, T_WOOD_L)
		_solids.set_cell(Vector2i(p[1], p[2]), 0, T_WOOD_R)

	for w in WALLS:
		var wx: int = w[0]
		for wy in range(w[1], w[2]):
			var brick: Vector2i = T_BRICK_A if (wy % 2) == 0 else T_BRICK_B
			_solids.set_cell(Vector2i(wx, wy), 0, brick)


func _paint_decor() -> void:
	# Stalactite ceiling specks every few tiles, alternating variants. No
	# collision — Decor's TileMapLayer just doesn't read the physics layer.
	for x in range(2, LEVEL_WIDTH_TILES - 2, 4):
		var coord: Vector2i = T_CEIL_A if ((x / 4) % 2) == 0 else T_CEIL_B
		_decor.set_cell(Vector2i(x, 1), 0, coord)


func _x_in_gap(x: int) -> bool:
	for g in FLOOR_GAPS:
		if x >= int(g[0]) and x < int(g[1]):
			return true
	return false


func _position_curiosity() -> void:
	var floor_top_world: float = float(FLOOR_Y) * float(VISUAL_TILE)
	# Curiosity's collision rect (88x432 at 0.5 scale) -> half-height 108.
	_curiosity.position = Vector2(
		float(SPAWN_TILE.x) * float(VISUAL_TILE),
		floor_top_world - 108.0
	)


func _position_exit_door() -> void:
	var door: Node2D = get_node_or_null("ExitDoor") as Node2D
	if door == null:
		return
	# Match Hub's visual relationship: door root sits ~340 above the floor
	# top so the arch reads as towering and the interaction collider
	# (relative y +125) lands just above Curiosity's body center.
	var floor_top: float = float(FLOOR_Y) * float(VISUAL_TILE)
	door.position = Vector2(
		float(EXIT_DOOR_TILE.x) * float(VISUAL_TILE),
		floor_top - 340.0
	)


func _setup_camera_limits() -> void:
	var cam: Camera2D = _curiosity.get_node_or_null("Camera") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_right = LEVEL_WIDTH_TILES * VISUAL_TILE
	cam.limit_top = -400
	cam.limit_bottom = (FLOOR_Y + SUBFLOOR_DEPTH + 1) * VISUAL_TILE
