extends Node
func _ready() -> void:
	var realm = load("res://assets/realms/realm1_caves/Realm1.tscn").instantiate()
	add_child(realm)
	for i in range(40): await get_tree().physics_frame
	var cur = get_tree().get_first_node_in_group("player")
	var golems = get_tree().get_nodes_in_group("enemies")
	print("curiosity_ok=", cur != null, " golems=", golems.size())
	# hit a golem -> boss bar path + golem health/death
	var g = golems[0]
	var gh0 = g.health
	g.take_damage(40)
	await get_tree().physics_frame
	print("golem hp %d->%d (boss bar fed)" % [gh0, g.health])
	g.take_damage(200)  # kill it
	for i in range(20): await get_tree().physics_frame
	print("golem after kill valid=", is_instance_valid(g))
	# curiosity death -> respawn path (1 eye)
	var p0 = cur.position
	cur.take_damage(500)   # lethal
	for i in range(60): await get_tree().physics_frame
	print("curiosity valid=", is_instance_valid(cur), " moved_on_respawn=", cur.position != p0, " health=", cur.health)
	print("COMBAT_TEST_DONE")
	get_tree().quit()
