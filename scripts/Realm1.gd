extends Node2D

# Realm 1 — caves. Classic-platformer geometry: continuous rocky floor
# along the bottom with 4 intentional gaps, distinct floating wood-plank
# platforms above at varied heights, parallax cave painting behind.
#
# Tile palette — ONE tile coord per role. No mixing within a row.
#
#   T_GROUND_TOP  (4,20)   peak-up rocky rim   — the cave-floor surface,
#                                                used uniformly across
#                                                every floor cell at y=9.
#   T_GROUND_FILL (7,23)   solid brown block   — interior fill for rows
#                                                10..13, gives the floor
#                                                visible thickness.
#   T_PLATFORM_L  (24,1)   wood plank L-end    — 3+-tile wide floating
#   T_PLATFORM_M  (25,1)   wood plank middle     platforms at y=6..8.
#   T_PLATFORM_R  (28,1)   wood plank R-end      X-brace metal in middle.
#
# Dropped vs. earlier builds: brick bookend walls, red gem fire-pit,
# ceiling row at y=0, decor stalactites at y=1. The parallax cave painting
# already provides the overhead atmosphere — no tile ceiling needed.

const SOURCE_TEXTURE: Texture2D = preload("res://assets/realms/realm1_caves/mainlev_build.png")
const ATLAS_TILE_SIZE: Vector2i = Vector2i(32, 32)

# ONE tile per role — uniform palette, no in-row variation.
const T_GROUND_TOP:  Vector2i = Vector2i(4, 20)
const T_GROUND_FILL: Vector2i = Vector2i(7, 23)
const T_PLATFORM_L:  Vector2i = Vector2i(24, 1)
const T_PLATFORM_M:  Vector2i = Vector2i(25, 1)
const T_PLATFORM_R:  Vector2i = Vector2i(28, 1)

const SOLID_TILES: Array[Vector2i] = [
	T_GROUND_TOP, T_GROUND_FILL,
	T_PLATFORM_L, T_PLATFORM_M, T_PLATFORM_R,
]

# World scale: parent Node2D scales TileMapLayers 2x so visual cells
# read as 64x64. Level extents are kept in tile coords below.
const VISUAL_TILE: int = 64

# Level dimensions. 96 tiles wide x 64 = 6144 world px.
# Floor sits at tile_y = 9 so its top edge lands at world y = 576.
const LEVEL_WIDTH_TILES: int = 96
const FLOOR_Y: int = 9
# Sub-floor fills rows 10..13 (4 rows of visible thickness, as requested).
const SUBFLOOR_DEPTH: int = 4

# Reachability: jump_velocity=-240, gravity=350 → ~82px peak ≈ 1 tile
# (with VISUAL_TILE=64). So Curiosity reaches +1 tile vertical per jump.
# That means y=8 is reachable from floor y=9; y=7 needs an intermediate
# y=8 platform; y=6 needs y=7 → y=8 → floor.

# Four gaps in the floor — 4 tiles wide each, evenly distributed.
# Five floor sections separated by gaps: 0-15, 20-35, 40-55, 60-75, 80-95.
const FLOOR_GAPS: Array = [
	[16, 20],   # gap 1 (4 tiles)
	[36, 40],   # gap 2
	[56, 60],   # gap 3
	[76, 80],   # gap 4
]

# Floating platforms — wood planks. [tile_x_left, tile_x_right_inclusive, tile_y].
# 10 platforms total, sized 3 tiles wide. Roles:
#   1-3,5-7,8   — y=8 bridges (one per gap) and step-up intros
#   4           — y=7 CHAIN-UP, requires plat 3 as intermediate (out of
#                 direct reach from floor)
#   8,9,10      — y=8 → y=7 → y=6 ascending victory path before exit
const PLATFORMS: Array = [
	[9, 11, 8],     # 1. intro step-up in section 1
	[17, 19, 8],    # 2. low bridge over gap 1
	[25, 27, 8],    # 3. chain setup in section 2
	[28, 30, 7],    # 4. CHAIN UP — out of direct floor reach
	[37, 39, 8],    # 5. low bridge over gap 2
	[57, 59, 8],    # 6. low bridge over gap 3
	[77, 79, 8],    # 7. low bridge over gap 4
	[84, 86, 8],    # 8. ascending step 1 (victory path)
	[87, 89, 7],    # 9. ascending step 2
	[90, 92, 6],    # 10. ascending step 3 — peak next to exit
]

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
	# errors with physics.size()=0 and every tile ends up non-colliding.
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
	# Floor surface (single ground-top tile) + sub-floor fill (single
	# interior tile), with the 4 gaps cut out completely.
	for x in range(LEVEL_WIDTH_TILES):
		if _x_in_gap(x):
			continue
		_solids.set_cell(Vector2i(x, FLOOR_Y), 0, T_GROUND_TOP)
		for d in range(1, SUBFLOOR_DEPTH + 1):
			_solids.set_cell(Vector2i(x, FLOOR_Y + d), 0, T_GROUND_FILL)

	# Floating wood-plank platforms — L / M.../ R from a single 3-tile palette.
	for p in PLATFORMS:
		var px_left: int = int(p[0])
		var px_right: int = int(p[1])
		var py: int = int(p[2])
		_solids.set_cell(Vector2i(px_left, py), 0, T_PLATFORM_L)
		for mx in range(px_left + 1, px_right):
			_solids.set_cell(Vector2i(mx, py), 0, T_PLATFORM_M)
		_solids.set_cell(Vector2i(px_right, py), 0, T_PLATFORM_R)


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
