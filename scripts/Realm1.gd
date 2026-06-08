extends Node2D

# Realm 1 — "The Crimson Hollow".
#
# 120-wide x 30-tall tilemap, 2x visual scale (each tile renders 64x64 px).
# World extents: 7680 x 1920 px.
#
# Five chunks of mechanical placement (no creative deviation):
#   1. Intro Cave            (x=  0..24)  flat floor at y=22 + 2 hop platforms
#   2. Broken Cavern         (x= 25..49)  floor with 3 gaps + bridge platforms
#   3. Red Crystal Chamber   (x= 50..74)  big chasm, crystal platforms + pillars
#   4. Vertical Climb        (x= 75..99)  walled shaft with climbing staircase
#   5. Final Core Chamber    (x=100..119) high floor at y=9, exit door + pillar
#
# Two TileMapLayers:
#   * Solids — colliding. Ground tops/fills, edge walls, crystal blocks/surrounds.
#   * Stalactites — decorative only, NO collision.
#
# Tile palette is mixed within each role for visual variety; selection is
# deterministic from a seeded RNG so the level renders identically every run.

const SOURCE_TEXTURE: Texture2D = preload("res://assets/realms/realm1_caves/mainlev_build.png")
const ATLAS_TILE_SIZE: Vector2i = Vector2i(32, 32)

# ─── palette ─────────────────────────────────────────────────────────────
# STOPGAP (2026-06-08): this tileset is decorative rock chunks, not a seamless
# terrain set, so the previous random per-cell variant mixing read as rubble.
# Each role is collapsed to ONE consistent tile — repetition reads far cleaner
# than randomness. A proper terrain-tileset rebuild is queued for M3 (Realm 1
# to ship-quality). Every coord here must still appear in SOLID_TILES below so
# the floor keeps its collision.
const GROUND_TOP_VARIANTS: Array[Vector2i] = [Vector2i(7, 20)]
const GROUND_FILL_VARIANTS: Array[Vector2i] = [Vector2i(8, 23)]
const LEFT_EDGE_VARIANTS: Array[Vector2i] = [Vector2i(1, 22)]
const RIGHT_EDGE_VARIANTS: Array[Vector2i] = [Vector2i(13, 22)]
const STALACTITE_VARIANTS: Array[Vector2i] = [Vector2i(3, 18), Vector2i(14, 18)]
const CRYSTAL_BLOCK: Vector2i = Vector2i(20, 25)
const CRYSTAL_SURROUND: Vector2i = Vector2i(20, 24)

# Every coord that lives in the colliding Solids layer.
const SOLID_TILES: Array[Vector2i] = [
	Vector2i(3, 20), Vector2i(5, 20), Vector2i(7, 20),
	Vector2i(10, 20), Vector2i(12, 20),
	Vector2i(7, 23), Vector2i(8, 23), Vector2i(9, 23),
	Vector2i(7, 24), Vector2i(8, 24), Vector2i(9, 24),
	Vector2i(7, 25), Vector2i(8, 25),
	Vector2i(1, 20), Vector2i(1, 22),
	Vector2i(13, 20), Vector2i(13, 22),
	Vector2i(20, 24), Vector2i(20, 25),
]

# ─── geometry ────────────────────────────────────────────────────────────
const VISUAL_TILE: int = 64
const LEVEL_WIDTH_TILES: int = 120
const LEVEL_HEIGHT_TILES: int = 30
const MAP_BOTTOM_Y: int = 29  # last fill row before the map edge
const RNG_SEED: int = 0x6c6f7265 # "lore" — deterministic variant picking

const SPAWN_TILE: Vector2i = Vector2i(2, 20)
const EXIT_DOOR_TILE: Vector2i = Vector2i(117, 8)

@onready var _solids: TileMapLayer = $World/Solids
@onready var _stalactites: TileMapLayer = $World/Stalactites
@onready var _curiosity: CharacterBody2D = $Curiosity
@onready var _motes: GPUParticles2D = $CeilingMotes

# Vertical offset from the camera's view-center up to where motes spawn —
# half the 720 viewport plus a margin so they drift in from above the top edge.
const MOTE_SPAWN_ABOVE_CENTER: float = 400.0

var _rng: RandomNumberGenerator
var _cam: Camera2D


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = RNG_SEED
	var ts: TileSet = _build_tileset()
	_solids.tile_set = ts
	_stalactites.tile_set = ts
	_paint_chunk_1_intro_cave()
	_paint_chunk_2_broken_cavern()
	_paint_chunk_3_crystal_chamber()
	_paint_chunk_4_vertical_climb()
	_paint_chunk_5_final_core()
	_position_curiosity()
	_position_exit_door()
	_setup_camera_limits()


# ─── tileset construction ────────────────────────────────────────────────
func _build_tileset() -> TileSet:
	var ts: TileSet = TileSet.new()
	ts.tile_size = ATLAS_TILE_SIZE
	var phys_layer_id: int = ts.get_physics_layers_count()
	ts.add_physics_layer(phys_layer_id)

	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	src.texture = SOURCE_TEXTURE
	src.texture_region_size = ATLAS_TILE_SIZE
	# Source must be attached BEFORE create_tile so the physics layer
	# propagates to per-tile data; otherwise add_collision_polygon
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


# ─── chunk painters ──────────────────────────────────────────────────────
# All coordinates and ranges below are LITERAL from the design spec.

func _paint_chunk_1_intro_cave() -> void:
	# Continuous floor at y=22 from x=0..24.
	_paint_floor_row(0, 24, 22)
	# Floating platform (x=10..13, y=18) — 4 wide.
	_paint_ground_strip(10, 13, 18)
	# Floating platform (x=18..20, y=17) — 3 wide.
	_paint_ground_strip(18, 20, 17)
	# Decorative stalactites.
	_paint_stalactite(5, 12)
	_paint_stalactite(8, 12)
	_paint_stalactite(15, 12)
	_paint_stalactite(22, 12)


func _paint_chunk_2_broken_cavern() -> void:
	# Floor at y=22 from x=25..49 with gaps at 28..31, 37..41, 45..47.
	var gaps: Array = [[28, 31], [37, 41], [45, 47]]
	for x in range(25, 50):
		if _x_in_any_range(x, gaps):
			continue
		_paint_floor_column(x, 22)
	# Bridge platforms above each gap.
	_paint_ground_strip(28, 30, 19)
	_paint_ground_strip(36, 39, 18)
	_paint_ground_strip(44, 46, 18)
	# Stalactites.
	_paint_stalactite(32, 12)
	_paint_stalactite(40, 12)


func _paint_chunk_3_crystal_chamber() -> void:
	# Floor at y=22 from x=50..52, then big chasm 53..62.
	_paint_floor_row(50, 52, 22)
	# Crystal platforms (crystal_surround + crystal_block mix).
	_paint_crystal_strip(54, 55, 20)
	_paint_crystal_strip(57, 58, 18)
	_paint_crystal_strip(60, 61, 20)
	# Floor 63..67.
	_paint_floor_row(63, 67, 22)
	# Mini chasm 68..71; crystal platform 69..70 at y=20.
	_paint_crystal_strip(69, 70, 20)
	# Floor 72..74.
	_paint_floor_row(72, 74, 22)
	# Vertical crystal pillars at x=63 and x=72, y=19..21.
	for py in range(19, 22):
		_solids.set_cell(Vector2i(63, py), 0, CRYSTAL_BLOCK)
		_solids.set_cell(Vector2i(72, py), 0, CRYSTAL_BLOCK)


func _paint_chunk_4_vertical_climb() -> void:
	# Floor 75..79 at y=22.
	_paint_floor_row(75, 79, 22)
	# Left wall column at x=75, y=15..21.
	for wy in range(15, 22):
		_solids.set_cell(Vector2i(75, wy), 0, _pick(LEFT_EDGE_VARIANTS))
	# Right wall column at x=99, y=8..21.
	for wy in range(8, 22):
		_solids.set_cell(Vector2i(99, wy), 0, _pick(RIGHT_EDGE_VARIANTS))
	# Climbing staircase.
	_paint_ground_strip(82, 84, 20)
	_paint_ground_strip(87, 88, 18)
	_paint_ground_strip(85, 86, 15)
	_paint_ground_strip(89, 91, 12)
	_paint_ground_strip(93, 95, 9)
	# Stalactites.
	_paint_stalactite(78, 5)
	_paint_stalactite(88, 4)
	_paint_stalactite(96, 4)


func _paint_chunk_5_final_core() -> void:
	# Floor at y=9 from x=100..119 with gap 107..111.
	for x in range(100, 120):
		if x >= 107 and x <= 111:
			continue
		_paint_floor_column(x, 9)
	# Mid-pit precision platform at (x=109, y=7).
	_paint_ground_strip(109, 109, 7)
	# Crystal pillar at (x=115, y=4..8).
	for py in range(4, 9):
		_solids.set_cell(Vector2i(115, py), 0, CRYSTAL_BLOCK)
	# Stalactites.
	_paint_stalactite(102, 2)
	_paint_stalactite(108, 1)
	_paint_stalactite(113, 2)


# ─── painter helpers ─────────────────────────────────────────────────────

# Paint a horizontal run of ground (top row + sub-floor fill to map bottom).
func _paint_floor_row(x_from: int, x_to_inclusive: int, top_y: int) -> void:
	for x in range(x_from, x_to_inclusive + 1):
		_paint_floor_column(x, top_y)


# Paint a single column of floor: top tile at top_y, fill down to MAP_BOTTOM_Y.
func _paint_floor_column(x: int, top_y: int) -> void:
	_solids.set_cell(Vector2i(x, top_y), 0, _pick(GROUND_TOP_VARIANTS))
	for fy in range(top_y + 1, MAP_BOTTOM_Y + 1):
		_solids.set_cell(Vector2i(x, fy), 0, _pick(GROUND_FILL_VARIANTS))


# Paint a one-tile-tall ground platform (no sub-fill).
func _paint_ground_strip(x_from: int, x_to_inclusive: int, y: int) -> void:
	for x in range(x_from, x_to_inclusive + 1):
		_solids.set_cell(Vector2i(x, y), 0, _pick(GROUND_TOP_VARIANTS))


# Paint a one-tile-tall crystal strip alternating surround / block for variety.
func _paint_crystal_strip(x_from: int, x_to_inclusive: int, y: int) -> void:
	for x in range(x_from, x_to_inclusive + 1):
		var coord: Vector2i = CRYSTAL_SURROUND if ((x - x_from) % 2 == 0) else CRYSTAL_BLOCK
		_solids.set_cell(Vector2i(x, y), 0, coord)


# Place a stalactite on the non-colliding Stalactites layer.
func _paint_stalactite(x: int, y: int) -> void:
	_stalactites.set_cell(Vector2i(x, y), 0, _pick(STALACTITE_VARIANTS))


func _x_in_any_range(x: int, ranges: Array) -> bool:
	for r in ranges:
		if x >= int(r[0]) and x <= int(r[1]):
			return true
	return false


func _pick(variants: Array[Vector2i]) -> Vector2i:
	return variants[_rng.randi() % variants.size()]


# ─── actor placement ─────────────────────────────────────────────────────
func _position_curiosity() -> void:
	# Floor in chunk 1 sits at tile y=22 → top edge at world y=1408.
	# Curiosity body half-height = 108 (rect 88x432 at scene scale 0.5).
	# Place her so the body bottom rests exactly on the floor top.
	var floor_top_world: float = 22.0 * float(VISUAL_TILE)
	_curiosity.position = Vector2(
		float(SPAWN_TILE.x) * float(VISUAL_TILE) + float(VISUAL_TILE) * 0.5,
		floor_top_world - 108.0
	)


func _position_exit_door() -> void:
	var door: Node2D = get_node_or_null("ExitDoor") as Node2D
	if door == null:
		return
	# Anchor at the exit tile center (per spec: pixel coord (7520, 544)).
	# DoorArea collision (120x430, centered, no offset in scene) will then
	# span y=329..759, fully overlapping Curiosity when she stands on the
	# chunk-5 floor at y=9 (body center 468).
	door.position = Vector2(
		float(EXIT_DOOR_TILE.x) * float(VISUAL_TILE) + float(VISUAL_TILE) * 0.5,
		float(EXIT_DOOR_TILE.y) * float(VISUAL_TILE) + float(VISUAL_TILE) * 0.5
	)


func _setup_camera_limits() -> void:
	var cam: Camera2D = _curiosity.get_node_or_null("Camera") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_right = LEVEL_WIDTH_TILES * VISUAL_TILE   # 7680
	cam.limit_top = 0
	cam.limit_bottom = LEVEL_HEIGHT_TILES * VISUAL_TILE # 1920
	cam.position_smoothing_enabled = true
	_cam = cam


# Keep the ceiling-mote emitter pinned just above the top of the current
# view so falling motes always fill the screen as the camera travels.
# local_coords=false means already-spawned motes keep falling in world
# space while the emitter band follows the camera.
func _process(_delta: float) -> void:
	if _cam == null or _motes == null:
		return
	var center: Vector2 = _cam.get_screen_center_position()
	_motes.global_position = Vector2(center.x, center.y - MOTE_SPAWN_ABOVE_CENTER)
