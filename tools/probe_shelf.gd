extends Node2D

## WHAT IS ACTUALLY DRAWN ON THE SPAWN SHELF.
##
## Advika circled a black band under the spawn and pointed at a bush to its left.
## Two guesses at which builder owned them were both wrong (a scatter tuft moved
## 197px and changed nothing; a field clump moved 346px and took her cover with
## it). So: print every sprite that overlaps the window, with its art and its box,
## and stop guessing. Throwaway.
func _ready() -> void:
	var realm: Node = load("res://scenes/realms/Realm3FungalTest.tscn").instantiate()
	add_child(realm)
	await get_tree().create_timer(2.0).timeout
	var rows: Array[String] = []
	for n in _walk(realm):
		var sp := n as Sprite2D
		if sp == null or sp.texture == null:
			continue
		var w: float = sp.texture.get_width() * absf(sp.scale.x)
		var h: float = sp.texture.get_height() * absf(sp.scale.y)
		var x0: float = sp.global_position.x - w * 0.5
		var x1: float = sp.global_position.x + w * 0.5
		var y0: float = sp.global_position.y - h * 0.5
		var y1: float = sp.global_position.y + h * 0.5
		if x1 < -200.0 or x0 > 1100.0 or y1 < 330.0 or y0 > 760.0:
			continue
		rows.append("%-26s x %7.0f..%-7.0f y %7.0f..%-7.0f  z=%-3d  a=%.2f" % [
				sp.texture.resource_path.get_file(), x0, x1, y0, y1,
				sp.z_index, sp.modulate.a])
	rows.sort()
	for r in rows:
		print("SHELF ", r)
	print("SHELF total ", rows.size())
	get_tree().quit()


func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out
