extends Node2D

# Hub controller. One node owns "did the player press interact?" so we
# don't have N doors all polling Input each frame. Each Door joins the
# "doors" group on _ready and emits near_door / left_door as the player
# enters/exits its Area2D; Hub tracks the latest active door and, on
# "interact", calls trigger() on it.
#
# The unconditional print is a deliberate breadcrumb for the live web
# build — if it never appears in the JS console, the action isn't
# reaching the game (focus / binding). If it prints with door=<none>,
# the overlap signal is broken. If it prints with a door but nothing
# visibly changes, trigger()'s feedback is the bug.

const _CURIOSITY_FLOOR_Y: float = 580.0

var _current_door: Node = null


func _ready() -> void:
	# If returning from a realm, snap Curiosity to the entry door before reveal.
	if Transition.last_door_id != "":
		_respawn_at_door(Transition.last_door_id)
		Transition.last_door_id = ""
	for door in get_tree().get_nodes_in_group("doors"):
		_connect_door(door)


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
	# Park her one step to the side of the door so she isn't standing in it.
	var anchor_x: float = (door_root as Node2D).position.x + 90.0
	curiosity.position = Vector2(anchor_x, _CURIOSITY_FLOOR_Y)


func _connect_door(door: Node) -> void:
	if door.has_signal("near_door") and not door.near_door.is_connected(_on_door_entered):
		door.near_door.connect(_on_door_entered)
	if door.has_signal("left_door") and not door.left_door.is_connected(_on_door_exited):
		door.left_door.connect(_on_door_exited)


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var door_label: String = "<none>"
	if _current_door and "door_id" in _current_door:
		door_label = String(_current_door.door_id)
	print("[Hub] interact pressed (current_door=", door_label, ")")
	if _current_door and _current_door.has_method("trigger"):
		_current_door.trigger()


func _on_door_entered(door: Node) -> void:
	_current_door = door


func _on_door_exited(door: Node) -> void:
	if _current_door == door:
		_current_door = null
