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

var _cam: Camera2D
var _at_exit: bool = false


# How far to zoom (the camera inherits Curiosity's 0.4 scale, so this is the
# counter-zoom). Lower = more of the world on screen. Tuned by eye.
const CAMERA_ZOOM: float = 1.6

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
	_make_painted_tiles_solid()
	_place_curiosity_on_floor()
	_place_exit_door()
	_wire_exit_door()
	_setup_camera_limits()


func _align_background() -> void:
	var pbg: Node = get_node_or_null("ParallaxBackground")
	if pbg == null:
		return
	for layer in pbg.get_children():
		var spr: Node2D = (layer as Node).get_node_or_null("Sprite") as Node2D
		if spr != null:
			spr.scale = Vector2(BG_SCALE, BG_SCALE)
			spr.position.y = BG_Y_OFFSET
		# Keep horizontal tiling matched to the new art width so there are no
		# seams as the camera scrolls.
		if layer is ParallaxLayer:
			(layer as ParallaxLayer).motion_mirroring = Vector2(BG_IMG_WIDTH * BG_SCALE, 0)


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
	for cell in _tiles.get_used_cells():
		var cs: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = tsize
		cs.shape = rect
		# Cell center in TileMapLayer-local space.
		cs.position = (Vector2(cell) + Vector2(0.5, 0.5)) * tsize
		body.add_child(cs)


# ─── placement ───────────────────────────────────────────────────────────
func _place_curiosity_on_floor() -> void:
	if _curiosity == null or _tiles == null or _tiles.tile_set == null:
		return
	var ur: Rect2i = _tiles.get_used_rect()
	var tsize: Vector2 = Vector2(_tiles.tile_set.tile_size)
	# Top edge of the painted area, in world space.
	var floor_top: float = _tiles.to_global(Vector2(ur.position) * tsize).y
	var left_x: float = _tiles.to_global(Vector2(ur.position) * tsize).x
	_curiosity.position = Vector2(
		left_x + tsize.x * 6.0,                       # a few tiles in from the left
		floor_top - _curiosity_half_height()          # feet rest on the floor top
	)


func _curiosity_half_height() -> float:
	var shape_node: CollisionShape2D = _curiosity.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size.y * 0.5 * _curiosity.scale.y
	return 100.0 * _curiosity.scale.y


func _place_exit_door() -> void:
	var door: Node2D = get_node_or_null("ExitDoor") as Node2D
	if door == null or _tiles == null or _tiles.tile_set == null:
		return
	var ur: Rect2i = _tiles.get_used_rect()
	var tsize: Vector2 = Vector2(_tiles.tile_set.tile_size)
	var right_x: float = _tiles.to_global(Vector2(ur.position + ur.size) * tsize).x
	var floor_top: float = _tiles.to_global(Vector2(ur.position) * tsize).y
	# Anchor just inside the right edge, lifted so the door's Area2D overlaps
	# Curiosity standing on the floor.
	door.position = Vector2(right_x - tsize.x * 4.0, floor_top - 100.0)


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
	# Curiosity (and so the camera) is scaled 0.4. Counter most of that so the
	# view frames the cave nicely without being right up in her face.
	cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	# How much world the camera shows vertically at this zoom.
	var view_h: float = get_viewport().get_visible_rect().size.y / (CAMERA_ZOOM * absf(cam.global_scale.y))
	# Horizontal: clamp to the painted level width.
	cam.limit_left = int(top_left.x)
	cam.limit_right = int(bot_right.x)
	# Vertical: LOCK it. Setting the limit band exactly equal to the view height
	# pins the camera's Y — it can only scroll sideways. Jumping never reveals
	# anything below the floor, so the dark void can't appear. Floor sits at the
	# bottom of the frame.
	cam.limit_bottom = int(bot_right.y)
	cam.limit_top = int(bot_right.y - view_h)
	cam.position_smoothing_enabled = true
	_cam = cam


func _process(_delta: float) -> void:
	if _at_exit and Input.is_action_just_pressed("interact"):
		_exit_door.trigger()
	# Keep the ceiling-mote emitter pinned just above the top of the view so
	# falling motes always fill the screen as the camera travels.
	if _cam != null and _motes != null:
		var center: Vector2 = _cam.get_screen_center_position()
		_motes.global_position = Vector2(center.x, center.y - MOTE_SPAWN_ABOVE_CENTER)
