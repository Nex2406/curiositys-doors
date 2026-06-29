extends Node2D

# Randomized accuracy fuzz: hundreds of scenarios with the REAL GolemBall fired at the
# faithful Curiosity-sized hitbox, run in parallel lanes for speed. Each scenario randomises
# distance, side, height (platforms/pits) and the target's constant velocity (walk/run, both
# ways, some vertical). A scenario PASSES if the ball strikes the moving target. Prints the
# overall hit rate and lists any failures with their params. Run:
#   godot --headless res://tools/GolemFuzz.tscn

const BALL := preload("res://scenes/GolemBall.tscn")
const TARGET := preload("res://tools/TestTarget.gd")

const LANES := 80           # scenarios per batch (parallel)
const BATCHES := 16         # → LANES*BATCHES total scenarios
const LANE_DX := 3200.0     # horizontal spacing so lanes never interfere
const FLOOR_Y := 600.0
const BATCH_T := 1.5        # seconds to let each batch of shots resolve

var _rng := RandomNumberGenerator.new()
var _batch := -1
var _t := 0.0
var _lanes: Array = []      # [{target, scenario}] for the active batch
var _total := 0
var _hits := 0
var _fails: Array = []


func _ready() -> void:
	_rng.randomize()
	print("--- GOLEM FUZZ: ", LANES * BATCHES, " randomized scenarios (seed ", _rng.seed, ") ---")


func _rand_scenario() -> Dictionary:
	var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
	var dist: float = _rng.randf_range(80.0, 490.0)
	var oy: float = _rng.randf_range(-190.0, 90.0)             # above (platform) .. below (pit)
	var vx: float = _rng.randf_range(-450.0, 450.0)
	var vy: float = 0.0
	if _rng.randf() < 0.25:
		vy = _rng.randf_range(-260.0, 60.0)                    # jumping / falling
	# A quarter of scenarios are dead-still (the must-always-hit baseline).
	if _rng.randf() < 0.25:
		vx = 0.0
		vy = 0.0
	return {"ox": side * dist, "oy": oy, "vx": vx, "vy": vy}


func _start_batch() -> void:
	for i in range(LANES):
		var sc := _rand_scenario()
		var gx: float = float(i) * LANE_DX
		var launch := Vector2(gx, FLOOR_Y - 234.0)
		var t: CharacterBody2D = TARGET.new()
		t.global_position = Vector2(gx + sc.ox, FLOOR_Y - 60.0 + sc.oy)
		t.move_vel = Vector2(sc.vx, sc.vy)
		add_child(t)
		t.velocity = Vector2(sc.vx, sc.vy)   # ready for the ball's leading this frame
		var b: Area2D = BALL.instantiate()
		b.setup(launch, t, FLOOR_Y + 4000.0) # floor far below so only the target matters
		add_child(b)
		_lanes.append({"target": t, "sc": sc})


func _finish_batch() -> void:
	for lane in _lanes:
		_total += 1
		var t: CharacterBody2D = lane.target
		if t != null and is_instance_valid(t) and t.hits > 0:
			_hits += 1
		elif _fails.size() < 25:
			_fails.append(lane.sc)
	for c in get_children():
		c.queue_free()
	_lanes.clear()


func _process(delta: float) -> void:
	if _batch >= 0 and _t < BATCH_T:
		_t += delta
		return
	if _batch >= 0:
		_finish_batch()
	_batch += 1
	if _batch >= BATCHES:
		_report()
		get_tree().quit()
		return
	_start_batch()
	_t = 0.0


func _report() -> void:
	var rate: float = 0.0 if _total == 0 else 100.0 * float(_hits) / float(_total)
	print("\n=== FUZZ: %d / %d hit  (%.1f%%) ===" % [_hits, _total, rate])
	if _fails.is_empty():
		print("ALL GREEN")
	else:
		print("sample failures (ox, oy, vx, vy):")
		for f in _fails:
			print("  ox=%.0f oy=%.0f vx=%.0f vy=%.0f" % [f.ox, f.oy, f.vx, f.vy])
