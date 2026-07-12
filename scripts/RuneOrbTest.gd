extends Node2D

# Isolation test for the wizard's rune-orb trial (boot straight into it):
# a floating plank sways side to side like the Realm 2 islands
# (AnimatableBody2D + sync_to_physics), real Curiosity on deck, the wizard at
# the far end. THE WIZARD IS THE CONJURER (Advika, 2026-07-12): every orb on
# the plank came out of his cast — the smoke ring appears WHERE HE STANDS.
#
# The trial (T starts it): he conjures max 2 orbs; each rolls the deck for a
# random spell then commits to a direction and rolls off, clearing room for
# his next. He teleports on a whim AND whenever Curiosity closes in — the
# only kill windows are the appear/cast beats, when conjuring commits him.
# WIN: reach him and strike (J/Z) — one blow. Orbs shove, never damage, and
# her swing can't touch them; movement is the whole game.
#
# DIFFICULTY: fast erratic orbs, strong shoves, swaying deck; her jump is
# boosted for this level so clearing an orb stays honest but doable.
# ORB_SHOT env: screenshot + quit. ORB_TRIAL: auto-start. ORB_KILL: debug-
# strike the wizard at 6s (win-beat verification). K key = same, live.

const CURIOSITY := preload("res://scenes/Curiosity.tscn")
const WIZARD := preload("res://scenes/Wizard.tscn")

const PLANK_SIZE := Vector2(980.0, 44.0)
const PLANK_BASE := Vector2(0.0, 260.0)
const PLANK_AMP := 240.0     # side-to-side sweep, Realm-2-island-ish
const PLANK_PERIOD := 6.0
const ORB_SCALE := 0.42      # ball ~88px next to the ~125px hero

# The level's difficulty dials (Advika: hard, movement is the only counterplay).
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
var _won := false
var _status: Label

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
	# THE chain: his cast conjures the smoke ring at his own feet — wherever
	# he lands, that's where the next orb is born.
	_wizard.cast_committed.connect(func(pos: Vector2) -> void:
		print("[WizardTrial] cast at ", pos, "  (plank at ", _plank.global_position, ")")
		OrbSpawner.conjure_orb(_plank, _plank.to_local(pos), self, ORB_SCALE,
				_wizard.facing_dir(), KILL_Y))  # the orb rolls the way it was cast
	_wizard.died.connect(func() -> void:
		_won = true
		_status.text = "the wizard falls — the deck is yours   (R to run it again)"
		print("[WizardTrial] WON"))

	var cam := Camera2D.new()
	cam.position = PLANK_BASE + Vector2(0.0, -170.0)
	cam.zoom = Vector2(0.75, 0.75)
	add_child(cam)
	cam.make_current()

	var label := Label.new()
	label.text = "WIZARD TRIAL — A/D or arrows move, SPACE jump (boosted), J/Z strike.\n" \
		+ "T begins it: HE conjures the orbs (max 2) wherever he lands; they're INVULNERABLE — dodge, don't fight.\n" \
		+ "He teleports when you close in (a breath of grace after each landing). FIVE blows fell him, he flees after each.   R restart   ESC quit"
	label.position = Vector2(-620, PLANK_BASE.y - 620.0)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.92))
	add_child(label)

	_status = Label.new()
	_status.position = Vector2(-620, PLANK_BASE.y - 540.0)
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(_status)

	if OS.get_environment("ORB_TRIAL") != "":
		_wizard.start_trial()
	if OS.get_environment("ORB_KILL") != "":
		for i in range(5):
			get_tree().create_timer(3.5 + i * 0.5).timeout.connect(func() -> void:
				if _wizard != null and is_instance_valid(_wizard):
					_wizard._on_struck())
	if OS.get_environment("ORB_SHOT") != "":
		_self_screenshot(OS.get_environment("ORB_SHOT"))


func _physics_process(delta: float) -> void:
	_t += delta
	# The plank sways like a Realm 2 island: sine sweep, sync_to_physics carries
	# every rider (hero, orbs, and wizard alike).
	_plank.position = PLANK_BASE + Vector2(sin(_t * TAU / PLANK_PERIOD) * PLANK_AMP, 0.0)

	# The difficulty dials ride on every live orb (the scene defaults stay gentle).
	for orb in get_tree().get_nodes_in_group("hazards"):
		if orb is RuneOrb:
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
			if _wizard != null and is_instance_valid(_wizard) and _wizard._trial == Wizard.Trial.OFF:
				_wizard.start_trial()
				print("[WizardTrial] START")
			elif _wizard != null and is_instance_valid(_wizard):
				_wizard.stop_trial()
				print("[WizardTrial] STOP")
		KEY_K:
			# Debug: verify the win beat without earning it.
			if _wizard != null and is_instance_valid(_wizard):
				_wizard._on_struck()
		KEY_R:
			get_tree().reload_current_scene()
		KEY_ESCAPE:
			get_tree().quit()


func _self_screenshot(path: String) -> void:
	# Trial runs need longer: idle beat + vanish + appear + cast ≈ up to ~4s.
	var delay := 6.5 if OS.get_environment("ORB_TRIAL") != "" else 3.5
	await get_tree().create_timer(delay).timeout
	var orbs := get_tree().get_nodes_in_group("hazards")
	var wiz := str(_wizard.global_position) if (_wizard != null and is_instance_valid(_wizard)) else "FELLED"
	print("SHOT orbs=", orbs.size(), " hero=", _hero.global_position,
			" plank=", _plank.global_position, " wizard=", wiz)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
