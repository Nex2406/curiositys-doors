extends Node2D

# Repro for the re-entry bug: walk INTO range (should fire), back OUT (patrol), then
# back IN (should fire again). Logs golem state + ball count each half second.

const SCENE := preload("res://scenes/GolemTest.tscn")

var _t := 0.0
var _next := 0.0
var _golem: Node = null
var _hero: Node = null

func _ready() -> void:
	add_child(SCENE.instantiate())

func _find(n: Node) -> Node:
	for c in n.get_children():
		if c is Golem:
			return c
		var r := _find(c)
		if r != null:
			return r
	return null

func _count_balls(n: Node) -> int:
	var total := 0
	for c in n.get_children():
		if c is GolemBall:
			total += 1
		total += _count_balls(c)
	return total

func _process(delta: float) -> void:
	_t += delta
	if _golem == null:
		_golem = _find(self)
		_hero = get_tree().get_first_node_in_group("player")
	# in (0-3s) → out (3-7s) → in (7-12s)
	var act := "move_right"
	if _t >= 3.0 and _t < 7.0:
		act = "move_left"
	for a in ["move_left", "move_right"]:
		if a != act and Input.is_action_pressed(a):
			Input.action_release(a)
	if not Input.is_action_pressed(act):
		Input.action_press(act)

	if _t >= _next:
		_next += 0.5
		var dist := -1.0
		var state := "?"
		if _golem != null and _hero != null:
			dist = _golem.global_position.distance_to(_hero.global_position)
			state = _golem.debug_state()
		print("t=%.1f dir=%s dist=%.0f state=%s balls=%d" % [
			_t, act, dist, state, _count_balls(get_tree().root)])
	if _t > 12.0:
		get_tree().quit()
