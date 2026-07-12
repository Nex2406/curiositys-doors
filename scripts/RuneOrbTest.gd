extends Node2D

# Isolation test for the rune-orb hazard chain (boot straight into it):
# a floating plank sways side to side like the Realm 2 islands
# (AnimatableBody2D + sync_to_physics), real Curiosity stands on it, and the
# spawn chain keeps two orbs alive on the deck: conjure smoke -> orb
# materializes -> rolls back and forth riding the plank -> shoves Curiosity on
# contact (no damage) -> eventually rolls off an edge and falls away, and the
# keeper conjures a replacement. Fall off yourself and you're blinked back on.
# ORB_SHOT env: screenshot at 3.5s + quit.

const CURIOSITY := preload("res://scenes/Curiosity.tscn")

const PLANK_SIZE := Vector2(980.0, 44.0)
const PLANK_BASE := Vector2(0.0, 260.0)
const PLANK_AMP := 240.0     # side-to-side sweep, Realm-2-island-ish
const PLANK_PERIOD := 7.0
const ORB_SCALE := 0.42      # ball ~88px next to the ~125px hero
const ORB_POPULATION := 2
const KILL_Y := PLANK_BASE.y + 900.0

var _plank: AnimatableBody2D
var _hero: CharacterBody2D
var _t := 0.0
var _pending := 0   # conjures in flight (so the keeper doesn't over-spawn)
var _keeper_cd := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.055, 0.045, 0.09))

	# The swaying plank — grey-box slab, moved in _physics_process below.
	_plank = AnimatableBody2D.new()
	_plank.sync_to_physics = true
	_plank.position = PLANK_BASE
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = PLANK_SIZE
	col.shape = rect
	_plank.add_child(col)
	var vis := Polygon2D.new()
	var hw := PLANK_SIZE.x * 0.5
	var hh := PLANK_SIZE.y * 0.5
	vis.color = Color(0.16, 0.13, 0.24)
	vis.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	_plank.add_child(vis)
	var lip := Polygon2D.new()
	lip.color = Color(0.34, 0.28, 0.48)
	lip.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, -hh + 6.0), Vector2(-hw, -hh + 6.0)])
	_plank.add_child(lip)
	add_child(_plank)

	# Real Curiosity on the deck (GolemTest conventions: scale 0.28, own cam off).
	_hero = CURIOSITY.instantiate()
	_hero.scale = Vector2(0.28, 0.28)
	_hero.position = PLANK_BASE + Vector2(0.0, -140.0)
	add_child(_hero)
	var hcam: Camera2D = _hero.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false

	var cam := Camera2D.new()
	cam.position = PLANK_BASE + Vector2(0.0, -170.0)
	cam.zoom = Vector2(0.75, 0.75)
	add_child(cam)
	cam.make_current()

	var label := Label.new()
	label.text = "RUNE ORB TEST — A/D or arrows move, SPACE jump. The plank sways; the chain keeps 2 orbs\n" \
		+ "conjured on deck. Orbs roll, ride the plank, SHOVE you (no damage), and fall off edges.\n" \
		+ "Fall off yourself and you blink back on.   R restart · ESC quit"
	label.position = Vector2(-620, PLANK_BASE.y - 620.0)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.92))
	add_child(label)

	if OS.get_environment("ORB_SHOT") != "":
		_self_screenshot(OS.get_environment("ORB_SHOT"))


func _physics_process(delta: float) -> void:
	_t += delta
	# The plank sways like a Realm 2 island: sine sweep, sync_to_physics carries
	# every rider (hero and orbs alike).
	_plank.position = PLANK_BASE + Vector2(sin(_t * TAU / PLANK_PERIOD) * PLANK_AMP, 0.0)

	# Population keeper: count live orbs, conjure replacements onto the deck.
	_keeper_cd -= delta
	if _keeper_cd <= 0.0:
		_keeper_cd = 0.9
		var alive := get_tree().get_nodes_in_group("hazards").size()
		if alive + _pending < ORB_POPULATION:
			_pending += 1
			var local_x := randf_range(-PLANK_SIZE.x * 0.5 + 130.0, PLANK_SIZE.x * 0.5 - 130.0)
			var fx := OrbSpawner.conjure_orb(_plank,
					Vector2(local_x, -PLANK_SIZE.y * 0.5), self, ORB_SCALE, 0, KILL_Y)
			fx.orb_ready.connect(func(_p: Vector2) -> void: _pending -= 1)

	# Fell off the plank: blink back on deck (test loop, not a death beat).
	if _hero.global_position.y > KILL_Y:
		_hero.global_position = _plank.global_position + Vector2(0.0, -140.0)
		_hero.velocity = Vector2.ZERO


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_R: get_tree().reload_current_scene()
		KEY_ESCAPE: get_tree().quit()


func _self_screenshot(path: String) -> void:
	await get_tree().create_timer(3.5).timeout
	var orbs := get_tree().get_nodes_in_group("hazards")
	print("SHOT orbs=", orbs.size(), " hero=", _hero.global_position,
			" plank=", _plank.global_position)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
