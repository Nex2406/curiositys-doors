extends Node2D

# Diagnose the "stuck horizontal (air pose)" bug: settle Curiosity, then report
# its state machine + floor detection over several frames, and again while we
# push it sideways (simulating a walk) to catch is_on_floor() flicker.

const REALM := "res://assets/realms/realm1_caves/Realm1.tscn"


func _ready() -> void:
	var realm: Node = load(REALM).instantiate()
	add_child(realm)
	await get_tree().create_timer(2.6).timeout
	var hero: CharacterBody2D = realm.get_node("Curiosity")
	var col: CollisionShape2D = hero.get_node_or_null("CollisionShape2D")
	print("=== settled ===")
	print("hero.scale=", hero.scale, "  hero.rotation=", hero.rotation)
	if col:
		print("CollisionShape2D pos=", col.position, " shape=", col.shape, " disabled=", col.disabled)
		if col.shape is RectangleShape2D:
			print("  rect size=", (col.shape as RectangleShape2D).size, " scaled=", (col.shape as RectangleShape2D).size * hero.scale)
	for i in range(6):
		await get_tree().physics_frame
		print("frame %d: state=%s on_floor=%s vel=%s pos=%s" % [
			i, hero.get("_state"), hero.is_on_floor(), hero.velocity, hero.global_position])
	print("=== simulate walk right (3 pushes) ===")
	for i in range(18):
		hero.velocity.x = 200.0
		await get_tree().physics_frame
		if i % 3 == 0:
			print("walk %d: state=%s on_floor=%s vel.y=%.1f y=%.1f" % [
				i, hero.get("_state"), hero.is_on_floor(), hero.velocity.y, hero.global_position.y])
	print("DIAG_DONE")
	get_tree().quit()
