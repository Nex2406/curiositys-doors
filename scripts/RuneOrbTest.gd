extends Node2D

# Isolation test for the rune-orb hazard chain + the wizard's teleport-cast
# trial (boot straight into it): a floating plank sways side to side like the
# Realm 2 islands (AnimatableBody2D + sync_to_physics), real Curiosity stands
# on it, the wizard stands at the far end.
#
# ORBS (on by default — O toggles): the chain keeps orbs conjured on deck.
# They roll, ride the plank, SHOVE her (no damage, invulnerable to her swing),
# and fall off edges; the keeper conjures replacements.
#
# WIZARD TRIAL (T toggles, never auto-starts): idle beat -> tp_disappear
# (blink smear + fade) -> reappears at a random spot ON the moving plank
# (plank-local space) -> tp_appear -> cast flourish -> cast_committed prints
# the conjure position. No orbs from HIM yet — the spawner hookup is next.
#
# DIFFICULTY (Advika, 2026-07-12: NOT easy): 3 orbs, faster + more erratic
# rolls, stronger shoves. Her jump is boosted for this level so clearing an
# orb stays honest but doable. Fall off and you're blinked back on.
# ORB_SHOT env: screenshot at 3.5s + quit. ORB_TRIAL env: auto-start trial.

const CURIOSITY := preload("res://scenes/Curiosity.tscn")
const WIZARD := preload("res://scenes/Wizard.tscn")

const PLANK_SIZE := Vector2(980.0, 44.0)
const PLANK_BASE := Vector2(0.0, 260.0)
const PLANK_AMP := 240.0     # side-to-side sweep, Realm-2-island-ish
const PLANK_PERIOD := 6.0
const ORB_SCALE := 0.42      # ball ~88px next to the ~125px hero

# The level's difficulty dials (Advika: hard, movement is the only counterplay).
const ORB_POPULATION := 3
const ORB_ROLL_SPEED := 195.0
const ORB_REVERSE_MIN := 1.0     # more erratic than the defaults
const ORB_REVERSE_MAX := 2.4
const ORB_PUSH_FORCE := 460.0
const JUMP_BOOST := 1.15         # this level only: -356 -> ~-410, apex ~138px -> ~183px

const WIZARD_SCALE := 0.48
const KILL_Y := PLANK_BASE.y + 900.0

var _plank: AnimatableBody2D
var _hero: CharacterBody2D
var _wizard: Wizard
var _t := 0.0
var _pending := 0   # conjures in flight (so the keeper doesn't over-spawn)
var _keeper_cd := 0.0
var _orbs_on := true

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
	_hero.position = PLANK_BASE + Vector2(-120.0, -140.0)
	add_child(_hero)
	# This level jumps slightly higher (Advika) — orbs must be clearable.
	_hero.jump_velocity *= JUMP_BOOST
	var hcam: Camera2D = _hero.get_node_or_null("Camera")
	if hcam != null:
		hcam.enabled = false

	# The wizard, standing ON the plank (its child, so the sway carries him and
	# every teleport lands in plank-local space).
	_wizard = WIZARD.instantiate()
	_wizard.scale = Vector2(WIZARD_SCALE, WIZARD_SCALE)
	_wizard.position = Vector2(PLANK_SIZE.x * 0.5 - 160.0,
			-PLANK_SIZE.y * 0.5 - Wizard.FEET_Y * WIZARD_SCALE)
	_plank.add_child(_wizard)
	_wizard.watch(_hero)
	_wizard.appear_instant()
	_wizard.configure_trial(PLANK_SIZE.x * 0.5,
			-PLANK_SIZE.y * 0.5 - Wizard.FEET_Y * WIZARD_SCALE)
	_wizard.cast_committed.connect(func(pos: Vector2) -> void:
		print("[WizardTrial] cast_committed at ", pos, "  (plank at ", _plank.global_position, ")"))

	var cam := Camera2D.new()
	cam.position = PLANK_BASE + Vector2(0.0, -170.0)
	cam.zoom = Vector2(0.75, 0.75)
	add_child(cam)
	cam.make_current()

	var label := Label.new()
	label.text = "RUNE ORB TEST — A/D or arrows move, SPACE jump (boosted this level).\n" \
		+ "3 orbs on deck: fast, erratic, INVULNERABLE — your swing does nothing; jump/slip past. They shove, never damage.\n" \
		+ "T start/stop the wizard's teleport-cast trial (casts print, no orbs from him yet)   O orbs on/off   R restart   ESC quit"
	label.position = Vector2(-620, PLANK_BASE.y - 620.0)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.92))
	add_child(label)

	if OS.get_environment("ORB_TRIAL") != "":
		_wizard.start_trial()
	if OS.get_environment("ORB_SHOT") != "":
		_self_screenshot(OS.get_environment("ORB_SHOT"))


func _physics_process(delta: float) -> void:
	_t += delta
	# The plank sways like a Realm 2 island: sine sweep, sync_to_physics carries
	# every rider (hero, orbs, and wizard alike).
	_plank.position = PLANK_BASE + Vector2(sin(_t * TAU / PLANK_PERIOD) * PLANK_AMP, 0.0)

	# Population keeper: count live orbs, conjure replacements onto the deck.
	_keeper_cd -= delta
	if _orbs_on and _keeper_cd <= 0.0:
		_keeper_cd = 0.9
		var alive := get_tree().get_nodes_in_group("hazards").size()
		if alive + _pending < ORB_POPULATION:
			_pending += 1
			var local_x := randf_range(-PLANK_SIZE.x * 0.5 + 130.0, PLANK_SIZE.x * 0.5 - 130.0)
			var fx := OrbSpawner.conjure_orb(_plank,
					Vector2(local_x, -PLANK_SIZE.y * 0.5), self, ORB_SCALE, 0, KILL_Y)
			fx.orb_ready.connect(func(_p: Vector2) -> void: _pending -= 1)

	# The difficulty dials ride on every live orb (the scene defaults stay gentle).
	for orb in get_tree().get_nodes_in_group("hazards"):
		orb.roll_speed = ORB_ROLL_SPEED
		orb.reverse_time_min = ORB_REVERSE_MIN
		orb.reverse_time_max = ORB_REVERSE_MAX
		orb.push_force = ORB_PUSH_FORCE

	# Fell off the plank: blink back on deck (test loop, not a death beat).
	if _hero.global_position.y > KILL_Y:
		_hero.global_position = _plank.global_position + Vector2(0.0, -140.0)
		_hero.velocity = Vector2.ZERO


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_T:
			if _wizard._trial == Wizard.Trial.OFF:
				_wizard.start_trial()
				print("[WizardTrial] START")
			else:
				_wizard.stop_trial()
				print("[WizardTrial] STOP")
		KEY_O:
			_orbs_on = not _orbs_on
			print("[OrbKeeper] ", "ON" if _orbs_on else "OFF")
		KEY_R:
			get_tree().reload_current_scene()
		KEY_ESCAPE:
			get_tree().quit()


func _self_screenshot(path: String) -> void:
	# Trial runs need longer: idle beat + vanish + appear + cast ≈ up to ~4s.
	var delay := 6.5 if OS.get_environment("ORB_TRIAL") != "" else 3.5
	await get_tree().create_timer(delay).timeout
	var orbs := get_tree().get_nodes_in_group("hazards")
	print("SHOT orbs=", orbs.size(), " hero=", _hero.global_position,
			" plank=", _plank.global_position, " wizard=", _wizard.global_position)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
