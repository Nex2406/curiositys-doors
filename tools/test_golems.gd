extends Node
# Headless soak test: run Realm1, track every golem's motion, flag anomalies.
func _ready() -> void:
	var realm = load("res://assets/realms/realm1_caves/Realm1.tscn").instantiate()
	add_child(realm)
	for i in range(30): await get_tree().physics_frame
	var golems = get_tree().get_nodes_in_group("enemies")
	golems.sort_custom(func(a,b): return a.global_position.x < b.global_position.x)
	var data = {}
	for i in range(golems.size()):
		var g = golems[i]
		data[g] = {"i": i, "spawnx": g.global_position.x, "minx": 1e9, "maxx": -1e9, "miny": 1e9, "maxy": -1e9}
	# soak ~16s
	for step in range(960):
		await get_tree().physics_frame
		for g in golems:
			if not is_instance_valid(g): continue
			var d = data[g]
			d.minx = minf(d.minx, g.global_position.x); d.maxx = maxf(d.maxx, g.global_position.x)
			d.miny = minf(d.miny, g.global_position.y); d.maxy = maxf(d.maxy, g.global_position.y)
	print("=== GOLEM SOAK RESULTS (16s) ===")
	for g in golems:
		if not is_instance_valid(g):
			print("  FREED golem!"); continue
		var d = data[g]
		var xr = d.maxx - d.minx
		var yr = d.maxy - d.miny
		var flag = ""
		if xr < 15.0: flag += " <STUCK-no-xpatrol>"
		if d.maxy > 1400.0: flag += " <FELL>"
		print("  G%-2d spawnx=%d  x_range=%.0f  y_range=%.0f  final=(%d,%d)%s" % [d.i, d.spawnx, xr, yr, g.global_position.x, g.global_position.y, flag])
	print("=== DONE ===")
	get_tree().quit()
