extends Node2D

# Automated stress test for the golem detection + shooting systems. Runs headless:
#   godot --headless res://tools/GolemSystemTest.tscn
#
# Part A (synchronous): detection range + facing logic on the real Golem.
# Part B (timed): fires a real GolemBall at a TestTarget across a grid of distances,
#   directions, heights and velocities; a scenario PASSES if the target is struck.
# Prints a PASS/FAIL line per scenario and a final summary, then quits.

const GOLEM := preload("res://scenes/Golem.tscn")
const BALL := preload("res://scenes/GolemBall.tscn")
const TARGET := preload("res://tools/TestTarget.gd")

const FLOOR_Y := 600.0
const GOLEM_POS := Vector2(1000.0, FLOOR_Y - 130.0)
const LAUNCH := Vector2(1000.0, FLOOR_Y - 234.0)  # ~golem head height (matches in-game)
const TARGET_FLOOR_Y := FLOOR_Y - 60.0            # target body centre, ~Curiosity on the floor
const RUN_T := 2.2                                # seconds to let each shot resolve

var _scenarios: Array = []
var _idx: int = -1
var _phase_t: float = 0.0
var _ball: Area2D = null
var _target: CharacterBody2D = null
var _min_dist: float = INF
var _pass: int = 0
var _fail: int = 0


func _ready() -> void:
	_run_detection_tests()
	_build_shooting_scenarios()
	print("\n--- PART B: shooting (", _scenarios.size(), " scenarios) ---")


# ----- PART A: detection ------------------------------------------------------------

func _run_detection_tests() -> void:
	print("--- PART A: detection ---")
	var golem: Node = GOLEM.instantiate()
	golem.ball_scene = BALL
	golem.position = GOLEM_POS
	add_child(golem)
	var dr: float = golem.detect_range

	# A target we can reposition to probe the range boundary + both sides.
	var t: CharacterBody2D = TARGET.new()
	add_child(t)
	golem._player = t  # skip the group lookup timing

	# Range checks: just inside / just outside detect_range on each side.
	t.global_position = GOLEM_POS + Vector2(dr - 20.0, 0)
	_check("detect: just inside (right)", golem._sees_player() == true)
	t.global_position = GOLEM_POS + Vector2(dr + 60.0, 0)
	_check("detect: just outside (right)", golem._sees_player() == false)
	t.global_position = GOLEM_POS + Vector2(-(dr - 20.0), 0)
	_check("detect: just inside (left)", golem._sees_player() == true)
	t.global_position = GOLEM_POS + Vector2(-(dr + 60.0), 0)
	_check("detect: just outside (left)", golem._sees_player() == false)

	# Facing: art faces left by default → flip_h true only when target is to the right.
	t.global_position = GOLEM_POS + Vector2(200.0, 0)
	golem._engaged()
	_check("face: target right → flip_h", golem._visual.flip_h == true)
	t.global_position = GOLEM_POS + Vector2(-200.0, 0)
	golem._engaged()
	_check("face: target left → no flip", golem._visual.flip_h == false)

	# Robustness: nulled reference must not crash; it re-acquires from the group, so move
	# the only target out of range first and expect not-seen.
	t.global_position = GOLEM_POS + Vector2(dr + 200.0, 0)
	golem._player = null
	_check("detect: null player safe", golem._sees_player() == false)

	golem.queue_free()
	t.queue_free()


# ----- PART B: shooting -------------------------------------------------------------

func _build_shooting_scenarios() -> void:
	var walk := 265.0
	var run := 420.0
	# offset is target centre relative to the golem; vel is the target's constant velocity.
	_add("near left  static",    Vector2(-130, 0),    Vector2.ZERO)
	_add("near right static",    Vector2(130, 0),     Vector2.ZERO)
	_add("mid  left  static",    Vector2(-300, 0),    Vector2.ZERO)
	_add("mid  right static",    Vector2(300, 0),     Vector2.ZERO)
	_add("far  left  static",    Vector2(-460, 0),    Vector2.ZERO)
	_add("far  right static",    Vector2(460, 0),     Vector2.ZERO)
	_add("point-blank left",     Vector2(-45, 0),     Vector2.ZERO)
	_add("walk away  (left)",    Vector2(-280, 0),    Vector2(-walk, 0))
	_add("walk toward(from L)",  Vector2(-360, 0),    Vector2(walk, 0))
	_add("walk away  (right)",   Vector2(280, 0),     Vector2(walk, 0))
	_add("run  away  (left)",    Vector2(-280, 0),    Vector2(-run, 0))
	_add("run  toward(from L)",  Vector2(-430, 0),    Vector2(run, 0))
	_add("run  away  (right)",   Vector2(300, 0),     Vector2(run, 0))
	_add("above on platform L",  Vector2(-260, -150), Vector2.ZERO)
	_add("above on platform R",  Vector2(260, -150),  Vector2.ZERO)
	_add("below in a pit  L",    Vector2(-260, 70),   Vector2.ZERO)
	_add("jumping (up vel) L",   Vector2(-250, 0),    Vector2(-walk, -250))


func _add(name: String, offset: Vector2, vel: Vector2) -> void:
	_scenarios.append({"name": name, "offset": offset, "vel": vel})


func _start(sc: Dictionary) -> void:
	_target = TARGET.new()
	_target.global_position = GOLEM_POS + Vector2(sc.offset.x, (TARGET_FLOOR_Y - GOLEM_POS.y) + sc.offset.y)
	_target.move_vel = sc.vel
	add_child(_target)
	# Populate velocity now so the ball's leading reads it this frame (the target's own
	# _physics_process, which normally sets it, hasn't run yet — same as Curiosity in game,
	# whose velocity is already current when the golem fires).
	_target.velocity = sc.vel

	# Fire a ball exactly the way the golem does (setup before entering tree).
	_ball = BALL.instantiate()
	_ball.setup(LAUNCH, _target, FLOOR_Y)
	add_child(_ball)
	_min_dist = INF


func _finish() -> void:
	if _target == null:
		return
	var sc: Dictionary = _scenarios[_idx]
	var hit: bool = _target.hits > 0
	_check("shoot: %s" % sc.name, hit, "minDist=%.0f vel=%v" % [_min_dist, sc.vel])
	if _ball != null and is_instance_valid(_ball):
		_ball.queue_free()
	_ball = null
	_target.queue_free()
	_target = null


func _process(delta: float) -> void:
	if _idx >= 0 and _phase_t < RUN_T:
		_phase_t += delta
		if _ball != null and is_instance_valid(_ball) and _target != null and is_instance_valid(_target):
			_min_dist = minf(_min_dist, _ball.global_position.distance_to(_target.global_position))
		return
	# Advance to the next scenario.
	if _idx >= 0:
		_finish()
	_idx += 1
	if _idx >= _scenarios.size():
		_report()
		get_tree().quit()
		return
	_start(_scenarios[_idx])
	_phase_t = 0.0


# ----- helpers ----------------------------------------------------------------------

func _check(label: String, ok: bool, extra: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	var tag: String = "PASS" if ok else "FAIL"
	print("  [", tag, "] ", label, ("" if extra == "" else "   (" + extra + ")"))


func _report() -> void:
	print("\n=== SUMMARY: ", _pass, " passed, ", _fail, " failed ===")
