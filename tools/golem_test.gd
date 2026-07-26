extends Node2D
## Golem test bench. GOLEM_STATE=dormant|waking|rolling|recovery|retreat|defeat
## forces a state; GOLEM_SHOT=<path> screenshots after it settles and quits.
## A dummy "player" sits to the right so facing/detection resolve.

const BoulderGolem := preload("res://scripts/BoulderGolem.gd")
const CUT := "res://assets/realms/realm1_cut/"

var _golem: CharacterBody2D
var _cam: Camera2D


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.55, 0.5, 0.45)     # light so the dark golem reads as a silhouette
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = -10
	cl.add_child(bg)
	add_child(cl)

	_floor()
	if OS.get_environment("GOLEM_DEBRIS") != "":
		_debris()

	var ceiling := OS.get_environment("GOLEM_CEILING") != ""
	# dummy player (group only — the golem reads its position)
	var p := Node2D.new()
	p.add_to_group("player")
	p.position = Vector2(0, 40) if ceiling else Vector2(360, 0)
	add_child(p)

	_golem = BoulderGolem.new()
	_golem.body_tint = Color(1.3, 1.02, 0.66)
	_golem.ceiling_spawner = ceiling
	_golem.position = Vector2(0, -320) if ceiling else Vector2(0, 0)
	add_child(_golem)

	var st := OS.get_environment("GOLEM_STATE")
	if st != "":
		await get_tree().process_frame
		_force(st)

	_cam = Camera2D.new()
	_cam.position = Vector2(40, -50)
	_cam.zoom = Vector2(1.6, 1.6)
	add_child(_cam)
	_cam.make_current()

	if OS.get_environment("GOLEM_SHOT") != "":
		_shot(OS.get_environment("GOLEM_SHOT"))
	elif ceiling:
		_loop_ceiling_drop()


# replay the ceiling drop on a loop so it can be watched
func _loop_ceiling_drop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(4.5).timeout
		if is_instance_valid(_golem):
			_golem.global_position = Vector2(0, -320)
			_golem.velocity = Vector2.ZERO
			_golem._enter(BoulderGolem.S.CLING)


func _force(st: String) -> void:
	var m := {
		"dormant": BoulderGolem.S.DORMANT, "waking": BoulderGolem.S.WAKING,
		"rolling": BoulderGolem.S.ROLLING, "retreat": BoulderGolem.S.RETREAT,
		"recovery": BoulderGolem.S.RECOVERY, "defeat": BoulderGolem.S.DYING,
		"landing": BoulderGolem.S.LANDING,
	}
	if m.has(st):
		_golem._enter(m[st])


# floor top at y=0 (golem stands at y=0)
func _floor() -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(2000, 200)
	cs.shape = r
	cs.position = Vector2(0, 100)
	b.add_child(cs)
	add_child(b)
	var band := ColorRect.new()
	band.position = Vector2(-1000, 0)
	band.size = Vector2(2000, 200)
	band.color = Color(0.32, 0.28, 0.24)
	band.z_index = 2
	add_child(band)


# scattered dark rocks around the golem's spot, to judge dormant camouflage
func _debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var pool := ["combo_08.png", "combo_10.png", "rock_08.png", "rock_10.png",
			"combo_05.png", "rock_03.png"]
	for i in 9:
		var t := load(CUT + pool[rng.randi() % pool.size()]) as Texture2D
		var s := Sprite2D.new()
		s.texture = t
		var sc := rng.randf_range(0.12, 0.26)
		s.scale = Vector2(-sc if rng.randf() < 0.5 else sc, sc)
		s.position = Vector2(rng.randf_range(-160, 160), rng.randf_range(-8, 6))
		s.modulate = Color(0.5, 0.45, 0.4)
		s.z_index = 3
		add_child(s)


func _shot(path: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
