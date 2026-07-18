extends Node2D

# Void Moth isolation rig (Advika 2026-07-17: "lets isolate the void moth and
# curiosity rn and ill tell u what all changes"). Boots straight into ONE
# moth + Curiosity on a flat deck — no island, no wizard, no waiting.
# The invisible "island" the moth steers around is a phantom volume under
# the deck, placed with the same geometry the real island has, so its roam,
# dives, and deck-clearance all behave exactly as in the trial.
#
#   T      force a turn (throws its roam to the other side)
#   D      force a dive right now
#   [ / ]  turn-anim FPS down / up (live; shown top-left)
#   S      slow-motion toggle (0.25x) to study the wings
#   L      (hold) the real burn mechanic — the light kills it
#   R      restart          ESC  quit

const FLOOR_Y := 420.0
const MOTH_SCALE := 0.78   # same read as the trial

var _curi: CharacterBody2D
var _moth: VoidMoth
var _anchor: Node2D
var _label: Label
var _slow := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.045, 0.11)
	bg.position = Vector2(-2400, -1600)
	bg.size = Vector2(4800, 3200)
	bg.z_index = -50
	add_child(bg)

	var ground := StaticBody2D.new()
	var gcol := CollisionShape2D.new()
	var gshape := RectangleShape2D.new()
	gshape.size = Vector2(3200, 120)
	gcol.shape = gshape
	ground.add_child(gcol)
	ground.position = Vector2(0, FLOOR_Y + 60)
	add_child(ground)
	var gvis := ColorRect.new()
	gvis.color = Color(0.09, 0.07, 0.16)
	gvis.position = Vector2(-1600, -60)
	gvis.size = Vector2(3200, 700)
	ground.add_child(gvis)

	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = Vector2(-220, FLOOR_Y - 120)
	_curi.scale = Vector2(0.24, 0.24)
	add_child(_curi)

	# phantom island: deck top = anchor.y - 120, matching the trial's geometry
	_anchor = Node2D.new()
	_anchor.position = Vector2(0, FLOOR_Y + 120)
	add_child(_anchor)

	var cam := Camera2D.new()
	cam.position = Vector2(0, -40)
	cam.zoom = Vector2(0.85, 0.85)
	add_child(cam)
	cam.make_current()

	_label = Label.new()
	_label.position = Vector2(18, 12)
	_label.z_index = 60
	add_child(_label)

	_spawn_moth()
	_update_label()


func _spawn_moth() -> void:
	_moth = load("res://scenes/VoidMoth.tscn").instantiate()
	_moth.scale = Vector2(MOTH_SCALE, MOTH_SCALE)
	add_child(_moth)
	var side := 1.0 if randf() < 0.5 else -1.0
	_moth.enter_from(Vector2(side * 1300.0, -500.0), _anchor,
			Vector2(-side * 200.0, -420.0), _curi)
	var respawn := func() -> void:
		await get_tree().create_timer(1.2).timeout
		if is_inside_tree():
			_spawn_moth()
			_update_label()
	_moth.died_to_light.connect(respawn)
	_moth.burst_on_strike.connect(respawn)


func _update_label() -> void:
	_label.text = "VOID MOTH RIG    turn fps %.0f%s\nT turn   D dive   [ ] fps   S slow-mo   L burn   R restart" \
			% [_moth.turn_fps, "   (SLOW-MO)" if _slow else ""]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_T:
			if is_instance_valid(_moth):
				_moth._roam_offset = Vector2(-signf(_moth._vel.x if _moth._vel.x != 0.0 else 1.0)
						* randf_range(500.0, 800.0), randf_range(-520.0, -250.0))
				_moth._roam_timer = 3.0
		KEY_D:
			if is_instance_valid(_moth) and _moth.state == VoidMoth.State.STALK:
				_moth._begin_dive()
		KEY_BRACKETLEFT:
			_nudge_turn_fps(-2.0)
		KEY_BRACKETRIGHT:
			_nudge_turn_fps(2.0)
		KEY_S:
			_slow = not _slow
			Engine.time_scale = 0.25 if _slow else 1.0
			_update_label()
		KEY_R:
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
		KEY_ESCAPE:
			Engine.time_scale = 1.0
			get_tree().quit()


func _nudge_turn_fps(d: float) -> void:
	if not is_instance_valid(_moth):
		return
	_moth.turn_fps = clampf(_moth.turn_fps + d, 4.0, 40.0)
	_moth._visual.sprite_frames.set_animation_speed(&"turn", _moth.turn_fps)
	print("[rig] turn fps -> %.0f" % _moth.turn_fps)
	_update_label()
