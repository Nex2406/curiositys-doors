extends Node2D

# Isolation test: real Curiosity on a flat floor with a Golem to her right. Walk
# into the golem's detection range — it plays attack and, on the launch frame,
# erupts a GolemBall that flies at her and bursts. Golem returns to idle and can
# attack again. Boots straight into this scene.

const GOLEM := preload("res://scenes/Golem.tscn")
const CURIOSITY := preload("res://scenes/Curiosity.tscn")
const BALL := preload("res://scenes/GolemBall.tscn")

const FLOOR_Y := 320.0

const GOLEM_SPAWN := Vector2(420, FLOOR_Y - 130)
const GOLEM_RESPAWN_DELAY := 2.0

var _hero: Node2D = null
var _golem: Node2D = null
var _cam: Camera2D = null
var _state_label: Label = null
var _hp_label: Label = null
var _golem_hp_label: Label = null

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.07, 0.10))

	# Flat floor spanning the play area.
	var ground := StaticBody2D.new()
	ground.position = Vector2(0, FLOOR_Y)
	var gshape := CollisionShape2D.new()
	var grect := RectangleShape2D.new()
	grect.size = Vector2(4000, 120)
	gshape.shape = grect
	gshape.position = Vector2(0, 60)
	ground.add_child(gshape)
	var gvis := Polygon2D.new()
	gvis.color = Color(0.12, 0.13, 0.17)
	gvis.polygon = PackedVector2Array([Vector2(-2000, 0), Vector2(2000, 0), Vector2(2000, 120), Vector2(-2000, 120)])
	ground.add_child(gvis)
	add_child(ground)

	# Curiosity (real scene) on the left; she falls onto the floor and walks.
	# Match her in-game scale (0.28) and silence her own camera so the test's
	# fixed framing shows both her and the golem.
	var hero: Node2D = CURIOSITY.instantiate()
	hero.scale = Vector2(0.28, 0.28)
	hero.position = Vector2(-360, FLOOR_Y - 120)
	add_child(hero)
	# Always face right toward the golem on spawn (and so every respawn looks identical).
	hero._facing_right = true
	hero._apply_facing()
	_hero = hero
	var hcam: Camera2D = hero.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false

	# Health read-out — updates each time a ball damages her, so the hit registers visibly.
	_hp_label = Label.new()
	_hp_label.position = Vector2(-560, FLOOR_Y - 430)
	_hp_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	add_child(_hp_label)
	_refresh_hp(hero.health, hero.max_health)
	hero.health_changed.connect(_refresh_hp)
	# Death: the eye closes and the level restarts from the top.
	hero.died.connect(func() -> void:
		_hp_label.text = "Curiosity HP: 0 — the eye closes…"
		Transition.death_restart())

	# Floating state read-out above the golem so the patrol→alert→attack flow is legible.
	_state_label = Label.new()
	_state_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(_state_label)

	# Golem health read-out — updates as Curiosity's swings land, so the kill registers.
	_golem_hp_label = Label.new()
	_golem_hp_label.position = Vector2(-560, FLOOR_Y - 400)
	_golem_hp_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	add_child(_golem_hp_label)

	# Golem on the right, wired with the ball projectile.
	_spawn_golem()

	var cam := Camera2D.new()
	cam.position = Vector2(40, FLOOR_Y - 140)
	cam.zoom = Vector2(0.8, 0.8)
	add_child(cam)
	cam.make_current()
	_cam = cam

	var label := Label.new()
	label.text = "Golem test — A/D or ←/→ to move, J/Z to swing, K/X to dash. Close in and hit the golem (2-3 swings destroys it); it respawns to fight again."
	label.position = Vector2(-560, FLOOR_Y - 460)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	add_child(label)


# Spawn (or respawn) the golem at its post, wired to the ball + the HP read-out.
func _spawn_golem() -> void:
	var golem: Node2D = GOLEM.instantiate()
	golem.ball_scene = BALL
	golem.position = GOLEM_SPAWN
	add_child(golem)
	_golem = golem
	_refresh_golem_hp(golem.max_health, golem.max_health)
	golem.health_changed.connect(_refresh_golem_hp)
	golem.died.connect(_on_golem_died)


func _on_golem_died() -> void:
	_golem_hp_label.text = "Golem HP: 0 — DESTROYED (respawning…)"
	get_tree().create_timer(GOLEM_RESPAWN_DELAY).timeout.connect(_spawn_golem)


func _refresh_golem_hp(h: int, m: int) -> void:
	_golem_hp_label.text = "Golem HP: %d / %d" % [h, m]


func _refresh_hp(h: int, m: int) -> void:
	_hp_label.text = "Curiosity HP: %d / %d" % [h, m]


func _process(_delta: float) -> void:
	# Keep the camera on Curiosity so the chase/kite stays in frame.
	if _hero != null and is_instance_valid(_hero) and _cam != null:
		_cam.position.x = _hero.global_position.x + 120.0
	# State read-out + redraw the detection ring.
	if _golem != null and is_instance_valid(_golem) and _state_label != null:
		_state_label.text = _golem.debug_state()
		_state_label.global_position = _golem.global_position + Vector2(-70, -240)
	queue_redraw()


func _draw() -> void:
	# Show the golem's detection radius so "enters a certain range" is visible.
	if _golem == null or not is_instance_valid(_golem):
		return
	draw_arc(_golem.global_position, _golem.detect_range, 0.0, TAU, 64,
			Color(1.0, 0.85, 0.4, 0.25), 2.0)
