extends Node2D

# Faithful accuracy test: the REAL Golem firing at the REAL Curiosity (real collider +
# real input-driven movement), scripted through movement phases. Reports shots vs hits
# per phase so we can see exactly which motions the aim misses. Run:
#   godot --headless res://tools/GolemLiveTest.tscn

const GOLEM := preload("res://scenes/Golem.tscn")
const CURIOSITY := preload("res://scenes/Curiosity.tscn")
const BALL := preload("res://scenes/GolemBall.tscn")

const FLOOR_Y := 600.0

var _hero: Node2D = null
var _phase: int = -1
var _phase_t: float = 0.0
var _hp_events: int = 0
# Per-phase tallies, attributed by the phase a ball was LAUNCHED in (so balls that resolve
# after a phase boundary still count for the motion that was happening when they fired).
var _shot_in: Array = []
var _hit_in: Array = []

# name, duration, held action (or ""), and whether to start the phase by moving the hero
# back into a known spot so phases stay in range.
var _phases: Array = [
	{"name": "stand still         ", "dur": 3.0, "act": ""},
	{"name": "walk left           ", "dur": 3.0, "act": "move_left"},
	{"name": "walk right          ", "dur": 3.0, "act": "move_right"},
	{"name": "back-and-forth juke  ", "dur": 4.0, "act": "juke"},
	{"name": "jumping (hold left)  ", "dur": 4.0, "act": "jump_left"},
]


func _ready() -> void:
	# Wide floor so movement never leaves the arena.
	var ground := StaticBody2D.new()
	ground.position = Vector2(0, FLOOR_Y)
	var gshape := CollisionShape2D.new()
	var grect := RectangleShape2D.new()
	grect.size = Vector2(12000, 200)
	gshape.shape = grect
	gshape.position = Vector2(0, 100)
	ground.add_child(gshape)
	add_child(ground)

	_hero = CURIOSITY.instantiate()
	_hero.scale = Vector2(0.28, 0.28)
	_hero.position = Vector2(0, FLOOR_Y - 140)
	add_child(_hero)
	var hcam: Camera2D = _hero.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false
	_hero.health_changed.connect(func(_h: int, _m: int) -> void: _hp_events += 1)

	var golem: Node = GOLEM.instantiate()
	golem.ball_scene = BALL
	golem.debug_balls = true
	golem.detect_range = 6000.0     # always engaged so every phase fires
	golem.shoot_interval = 0.9
	golem.position = Vector2(360, FLOOR_Y - 130)
	add_child(golem)

	_shot_in.resize(_phases.size())
	_hit_in.resize(_phases.size())
	_shot_in.fill(0)
	_hit_in.fill(0)

	# Count every ball the golem spawns (they're parented to this run scene) and whether
	# it lands on her — attributed to the phase it was launched in.
	child_entered_tree.connect(_on_child_added)

	print("--- GOLEM LIVE ACCURACY (real Curiosity) ---")


func _on_child_added(node: Node) -> void:
	if node is GolemBall:
		var launched_in: int = _phase
		if launched_in < 0 or launched_in >= _phases.size():
			return
		_shot_in[launched_in] += 1
		node.hit_player.connect(func(body: Node) -> void:
			if body != null:
				_hit_in[launched_in] += 1)


func _process(delta: float) -> void:
	# Advance phases.
	if _phase < 0 or _phase_t >= _phases[_phase].dur:
		_release_all()
		_phase += 1
		if _phase >= _phases.size():
			# Let balls in flight resolve before tallying.
			await get_tree().create_timer(1.5).timeout
			_report()
			get_tree().quit()
			return
		_phase_t = 0.0
		return
	_phase_t += delta
	_drive(_phases[_phase].act)


func _report() -> void:
	print("--- results (attributed to launch phase) ---")
	var th: int = 0
	var ts: int = 0
	for i in range(_phases.size()):
		var s: int = _shot_in[i]
		var h: int = _hit_in[i]
		th += h
		ts += s
		var rate: float = 0.0 if s == 0 else 100.0 * float(h) / float(s)
		print("  %s  hits %d / %d  (%.0f%%)" % [_phases[i].name, h, s, rate])
	var total: float = 0.0 if ts == 0 else 100.0 * float(th) / float(ts)
	print("=== TOTAL: %d / %d  (%.0f%%)  hp_events=%d ===" % [th, ts, total, _hp_events])


func _release_all() -> void:
	for a in ["move_left", "move_right", "jump"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func _drive(act: String) -> void:
	match act:
		"move_left":
			_press_only("move_left")
		"move_right":
			_press_only("move_right")
		"juke":
			# Flip direction roughly twice a second.
			var left: bool = int(_phase_t * 2.0) % 2 == 0
			_press_only("move_left" if left else "move_right")
		"jump_left":
			_press_only("move_left")
			if _hero != null and _hero.is_on_floor() and not Input.is_action_pressed("jump"):
				Input.action_press("jump")
			elif Input.is_action_pressed("jump"):
				Input.action_release("jump")
		_:
			_release_all()


func _press_only(action: String) -> void:
	for a in ["move_left", "move_right"]:
		if a != action and Input.is_action_pressed(a):
			Input.action_release(a)
	if not Input.is_action_pressed(action):
		Input.action_press(action)
