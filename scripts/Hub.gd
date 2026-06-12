extends Node2D

# Hub controller. Owns three responsibilities for the door-selection scene:
#
#  1. LEVITATION BOB — the doors float HIGH in the sky, out of physical reach,
#     so the whole door root bobs here (not just its art) which means the
#     "[Y] Enter" label and the interaction collision — both descendants of
#     the door root — ride the bob with it. Sine, ~18px amplitude, 3.5s cycle,
#     phase-offset per door so they don't pulse in unison.
#
#  2. X-PROXIMITY ENTRY — because the player stands on the floor BENEATH the
#     doors and can't touch them, the active door is whichever one the player
#     is horizontally aligned under (nearest door X within _DOOR_X_RANGE).
#     That door highlights + shows its prompt via Door.set_active(true).
#
#  3. INTERACT — on the "interact" action, trigger() the active door.
#
# The unconditional print is a deliberate breadcrumb for the live web build.

const _CURIOSITY_FLOOR_Y: float = 540.0

const _BOB_AMPLITUDE: float = 18.0
const _BOB_PERIOD: float = 3.5
# How close in X (world units) the player must be to a door to stand "beneath"
# it. Doors are ~288px wide and ~440px apart, so 160 keeps activation under the
# door without bleeding into its neighbour.
const _DOOR_X_RANGE: float = 160.0

var _current_door: Node = null
var _door_roots: Array[Node2D] = []
var _door_base_y: Array[float] = []
var _door_phase: Array[float] = []
var _bob_time: float = 0.0


func _ready() -> void:
	# Ambient bed for the hub. Placeholder drone until a real hub track lands;
	# crossfades from a realm's ambient on return. (AudioManager M1 foundation.)
	AudioManager.play_placeholder("hub")
	# If returning from a realm, snap Curiosity to the entry door before reveal.
	if Transition.last_door_id != "":
		_respawn_at_door(Transition.last_door_id)
		Transition.last_door_id = ""
	# Cache each door root, its resting Y, and a phase offset for the bob.
	var doors_root: Node = get_node_or_null("Doors")
	if doors_root:
		var index: int = 0
		for child in doors_root.get_children():
			if child is Node2D:
				_door_roots.append(child)
				_door_base_y.append((child as Node2D).position.y)
				# Spread phases evenly around the cycle: 0, 120deg, 240deg, ...
				_door_phase.append(float(index) * TAU / 3.0)
				index += 1


func _respawn_at_door(door_id: String) -> void:
	var doors_root: Node = get_node_or_null("Doors")
	if doors_root == null:
		return
	var door_root: Node = doors_root.get_node_or_null(door_id)
	if door_root == null or not (door_root is Node2D):
		return
	var curiosity: Node2D = get_node_or_null("Curiosity") as Node2D
	if curiosity == null:
		return
	# Park her one step to the side of the door's column so she reads as
	# "just stepped out from beneath it".
	var anchor_x: float = (door_root as Node2D).position.x + 90.0
	curiosity.position = Vector2(anchor_x, _CURIOSITY_FLOOR_Y)


func _process(delta: float) -> void:
	_animate_bob(delta)
	_update_active_door()

	if not Input.is_action_just_pressed("interact"):
		return
	var door_label: String = "<none>"
	if _current_door and "door_id" in _current_door:
		door_label = String(_current_door.door_id)
	print("[Hub] interact pressed (current_door=", door_label, ")")
	if _current_door and _current_door.has_method("trigger"):
		_current_door.trigger()


# TEMP (testing): press T to jump into the throwaway TestRealm, so the M1
# save/restore loop is reachable on the live build without a shipped door.
# Invisible (no art/text). Remove once M2 has its own test arena. See issue #110.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_T:
		Transition.transition_to("res://scenes/realms/TestRealm.tscn")


func _animate_bob(delta: float) -> void:
	_bob_time += delta
	for i in _door_roots.size():
		# Upward-only bob: remap sin's -1..1 to 0..1 so the door floats between
		# its resting Y (lowest, on the floor) and base_y - amplitude (highest).
		# It never crosses below base_y, so the bases never clip into the floor.
		var rise: float = (sin(_bob_time * TAU / _BOB_PERIOD + _door_phase[i]) * 0.5 + 0.5) * _BOB_AMPLITUDE
		_door_roots[i].position.y = _door_base_y[i] - rise


func _update_active_door() -> void:
	# Active door = the one the player is standing horizontally beneath.
	var curiosity: Node2D = get_node_or_null("Curiosity") as Node2D
	if curiosity == null:
		return
	var player_x: float = curiosity.global_position.x
	var nearest: Node = null
	var nearest_dx: float = _DOOR_X_RANGE
	for door in get_tree().get_nodes_in_group("doors"):
		var dx: float = absf(door.global_position.x - player_x)
		if dx < nearest_dx:
			nearest_dx = dx
			nearest = door
	if nearest == _current_door:
		return
	if _current_door and _current_door.has_method("set_active"):
		_current_door.set_active(false)
	_current_door = nearest
	if _current_door and _current_door.has_method("set_active"):
		_current_door.set_active(true)
