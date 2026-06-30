extends SceneTree

# Headless functional check: stand Curiosity next to a Golem, swing, and confirm the
# melee hitbox actually damages the golem through real physics frames — and that ~3 blows
# destroy him (freed from the tree). Run:
#   godot --headless --script res://tools/verify_golem_fight.gd

func _init() -> void:
	call_deferred("_run")


func _step_physics(frames: int) -> void:
	for _i in range(frames):
		await physics_frame


func _run() -> void:
	var world := Node2D.new()
	get_root().add_child(world)

	# Flat floor so both settle and is_on_floor() reads true.
	var ground := StaticBody2D.new()
	ground.position = Vector2(0, 320)
	var gs := CollisionShape2D.new()
	var gr := RectangleShape2D.new()
	gr.size = Vector2(4000, 120)
	gs.shape = gr
	gs.position = Vector2(0, 60)
	ground.add_child(gs)
	world.add_child(ground)

	var hero: CharacterBody2D = load("res://scenes/Curiosity.tscn").instantiate()
	hero.scale = Vector2(0.28, 0.28)
	hero.position = Vector2(0, 180)
	world.add_child(hero)

	var golem: CharacterBody2D = load("res://scenes/Golem.tscn").instantiate()
	golem.position = Vector2(90, 190)   # just to Curiosity's right, inside swing reach
	world.add_child(golem)

	await _step_physics(20)   # let both fall onto the floor and settle

	# Face the golem (it's to her right) and confirm a clean start.
	hero._facing_right = true
	hero._apply_facing()
	var full: int = golem.health
	print("golem start HP=", full, "  curiosity facing_right=", hero._facing_right)

	var blows: int = 0
	for _swing in range(5):
		if not is_instance_valid(golem):
			break
		var before: int = golem.health
		hero._start_attack()
		await _step_physics(30)   # whole swing + a margin
		var after: int = (golem.health if is_instance_valid(golem) else 0)
		blows += 1
		print("blow ", blows, ": golem HP ", before, " -> ", after,
			("  (DESTROYED/freed)" if not is_instance_valid(golem) else ""))
		await _step_physics(10)   # recover between swings

	var killed: bool = not is_instance_valid(golem)
	print("RESULT: blows=", blows, " killed=", killed)
	if killed and blows <= 3:
		print("PASS — melee connects and ~", blows, " blows destroy the golem")
	else:
		print("FAIL — golem not destroyed within 3 blows (killed=", killed, ")")
	quit()
