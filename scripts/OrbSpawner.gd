extends Node
class_name OrbSpawner

# The rune-orb spawn chain, wrapped: conjure effect ON the plank -> its
# orb_ready beat -> a live RuneOrb at that ground position. This is the stub
# the wizard's real spawner logic (cadence, caps, dialogue beats) builds on
# later — for now it's just the chain done right:
#
#   OrbSpawner.conjure_orb(plank, Vector2(x, top_y), scene_root)
#
# The conjure is parented to the ANCHOR (the moving plank/island) so the smoke
# ring rides it; the orb is parented to ORB_PARENT (the scene root, never a
# physics body) and spawns at the conjure's global position at the ready beat.

const CONJURE_SCENE := preload("res://scenes/OrbConjure.tscn")
const ORB_SCENE := preload("res://scenes/RuneOrb.tscn")


# anchor: the plank the ring sits on (effect becomes its child, at local_pos).
# orb_parent: who owns the spawned orb (scene root).
# scale: shared by effect + orb so the materialized ball matches the conjured one.
# dir: opening roll direction (-1 / 1), 0 = random.
# Returns the conjure effect node (it frees itself when done).
static func conjure_orb(anchor: Node2D, local_pos: Vector2, orb_parent: Node,
		scale := 1.0, dir := 0, kill_y := 100000.0) -> OrbConjure:
	var fx: OrbConjure = CONJURE_SCENE.instantiate()
	fx.position = local_pos
	fx.scale = Vector2(scale, scale)
	anchor.add_child(fx)
	fx.orb_ready.connect(func(ground_pos: Vector2) -> void:
		var orb: RuneOrb = ORB_SCENE.instantiate()
		orb.scale = Vector2(scale, scale)
		orb.kill_y = kill_y
		orb_parent.add_child(orb)
		# Ball center sits one radius above the ground point it was conjured on.
		orb.global_position = ground_pos + Vector2(0.0, -RuneOrb.BALL_RADIUS * scale)
		orb.set_direction(dir)
	)
	return fx
