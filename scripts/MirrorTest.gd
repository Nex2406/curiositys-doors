extends Node2D

## THE MIRROR FIGHT, ON ITS OWN — the whole phase-3 handoff in thirty seconds.
##
## Nothing about this is the forest. Flat floor, dead air, three mushrooms and
## then her. It exists so the boss can be argued with without walking ten
## minutes to reach it, and so the argument is about the FIGHT rather than
## about fog, parallax or the clock.
##
## It reproduces the real handoff exactly, in miniature:
##   kill the three mushrooms -> the colour drains out of the world -> it is
##   standing there -> it fights you with what you just did to them.
##
## That warm-up is not filler. `PlayerProfile` can only read someone who is
## fighting something, so the three mushrooms ARE the reading: how close you
## stood, how fast you swung, which way you dodged, how much you were in the
## air. Skip them with [B] and the boss has nothing to go on, which is itself
## worth seeing once.
##
## KEYS
##   J / Z  swing      arrows move      SPACE jump      X dash
##   B      skip the warm-up, bring it now
##   1 2 3  force stage: MIMIC / TIME / DECIDE
##   K      hit it for one of her swings (40)      L  hit it for 100
##   TAB    the profile it is being built from
##   R      restart      ESC  quit

## the level itself, loaded only for its numbers — the rig must never invent a
## scale, a mushroom size or anything else the forest already decided
const R3 := preload("res://scripts/Realm3FungalTest.gd")

const FLOOR_Y := 640.0
const SPAN := 2600.0
const SPORE_XS: Array[float] = [420.0, 900.0, 1340.0]

var _curi: CharacterBody2D
var _cam: Camera2D
var _mirror: Mirror
var _kills := 0
var _shifted := false
var _drain: ColorRect
var _drain_mat: ShaderMaterial
var _hud: Label
var _profile_lbl: Label
var _banner: Label
var _sporelings: Array[Sporeling] = []
## which faked profile [F] is currently wearing
var _fake := -1


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.055, 0.105, 0.098))
	_build_ground()
	_build_player()
	_build_camera()
	_build_sporelings()
	_build_drain()
	_build_hud()
	# THE RIG resets — and it is the only thing that does. In the real game the
	# read spans every realm and only BEGIN wipes it; in here a fresh run has
	# to mean a fresh boss or two tests in a row are not the same test.
	PlayerProfile.reset()
	PlayerProfile.begin(_curi)
	# MIRROR_BOOT=<s> — boot it, hold, quit. The gate that proves this scene and
	# Mirror.gd actually compile and assemble; `--headless --import` proves
	# neither.
	if OS.get_environment("MIRROR_BOOT") != "":
		await get_tree().create_timer(float(OS.get_environment("MIRROR_BOOT"))).timeout
		print("[MirrorTest] booted clean")
		get_tree().quit()
	# MIRROR_SOAK=<s> — the whole fight, unattended, against a player who does
	# not fight back: it spawns, closes, swings, takes its eight hits and dies,
	# with a line of state every second. Assembling is not running, and every
	# real bug this fight has had lived in the second one.
	if OS.get_environment("MIRROR_SOAK") != "":
		PlayerProfile.seed_fake(int(OS.get_environment("MIRROR_FAKE")) \
				if OS.get_environment("MIRROR_FAKE") != "" else 0)
		# the warm-up mushrooms are noise in an unattended run — they chew a
		# player who is not fighting back down to nothing and every number in
		# the log then belongs to them instead of the boss
		for s in _sporelings:
			s.queue_free()
		_sporelings.clear()
		_shift()
		await _soak(float(OS.get_environment("MIRROR_SOAK")))


## An unattended player who stands still and swings on a clock. She throws a
## REAL swing — the same call her own input makes — so her hitbox has to
## actually find the boss for it to take damage, and so the stage that reads
## her swings has something to read. A synthetic hit every fourth second keeps
## the run terminating even when the boss is dodging her perfectly, which is
## itself the thing being watched for.
func _soak(secs: float) -> void:
	var t := 0.0
	var swings := 0
	while t < secs:
		await get_tree().create_timer(1.0).timeout
		t += 1.0
		if _mirror == null or not is_instance_valid(_mirror):
			print("[soak %4.1f] no mirror yet (drain running)" % t)
			continue
		print("[soak %4.1f] %s | her hp %d  boss hp %d" % [t, _mirror.debug_state(),
				_curi.health, _mirror.health])
		if not _mirror.live:
			continue
		swings += 1
		if _curi.has_method("_start_attack"):
			_curi._start_attack()
		if swings % 4 == 0:
			_mirror.take_damage(40, Vector2(-200.0, -120.0))
			print("        (a guaranteed hit, so the soak finishes)")
	print("[MirrorTest] soak complete")
	get_tree().quit()


func _build_ground() -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(SPAN, 200.0)
	cs.shape = box
	cs.position = Vector2(SPAN * 0.4, FLOOR_Y + 100.0)
	body.add_child(cs)
	add_child(body)
	# a plain slab, deliberately featureless: nothing in this scene should be
	# arguing with the two figures standing on it
	var slab := ColorRect.new()
	slab.color = Color(0.045, 0.075, 0.07)
	slab.position = Vector2(SPAN * 0.4 - SPAN * 0.5, FLOOR_Y)
	slab.size = Vector2(SPAN, 200.0)
	slab.z_index = -2
	add_child(slab)
	# walls, so nobody walks out of the argument
	for side in [-1.0, 1.0]:
		var w := StaticBody2D.new()
		var wcs := CollisionShape2D.new()
		var wb := RectangleShape2D.new()
		wb.size = Vector2(80.0, 900.0)
		wcs.shape = wb
		wcs.position = Vector2(SPAN * 0.4 + side * SPAN * 0.5, FLOOR_Y - 400.0)
		w.add_child(wcs)
		add_child(w)


func _build_player() -> void:
	_curi = load("res://scenes/Curiosity.tscn").instantiate()
	_curi.position = Vector2(120.0, FLOOR_Y - 140.0)
	# THE FOREST'S OWN SIZE, not this rig's opinion of it — it is read straight
	# off Realm3FungalTest so the fight is judged at the scale it ships at, and
	# so there is one number to change instead of two. The boss takes its scale
	# off her in `build_from`, so both figures move together and stay exactly
	# the same height as each other.
	_curi.scale = Vector2(R3.HERO_SCALE, R3.HERO_SCALE)
	_curi.z_index = 5
	add_child(_curi)
	if _curi.has_signal("died"):
		_curi.died.connect(_on_player_died)


func _build_camera() -> void:
	_cam = Camera2D.new()
	_cam.position = Vector2(500.0, FLOOR_Y - 240.0)
	_cam.zoom = Vector2(0.9, 0.9)
	add_child(_cam)
	_cam.make_current()


## The reading. Three of the real species, same settings the forest gives them,
## so what the profile learns here is what it would have learned out there.
func _build_sporelings() -> void:
	var trig: Array[Node2D] = [_curi]
	var kinds := [["mushroomglow17.png", 0.60, 0.17], ["mushroomglow23.png", 0.63, 0.16],
			["mushroomglow24.png", 0.63, 0.16]]
	var mush_h: float = 86.0 * (R3.HERO_SCALE / 0.24)
	var i := 0
	for sx in SPORE_XS:
		var s := Sporeling.new()
		s.tex_name = kinds[i][0]
		s.eye_y_frac = kinds[i][1]
		s.eye_dx_frac = kinds[i][2]
		s.target_height = mush_h
		s.position = Vector2(sx, FLOOR_Y + 4.0)
		s.phase = float(i) * (s.hop_period / 3.0)
		add_child(s)
		s.triggers = trig
		s.popped.connect(_on_kill)
		_sporelings.append(s)
		i += 1


func _build_drain() -> void:
	_drain = ColorRect.new()
	_drain_mat = ShaderMaterial.new()
	_drain_mat.shader = load("res://shaders/realm_drain.gdshader")
	_drain_mat.set_shader_parameter("sweep", -1.0)
	_drain_mat.set_shader_parameter("amount", 1.0)
	_drain_mat.set_shader_parameter("edge", 0.4)
	_drain.material = _drain_mat
	_drain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drain.z_index = 90
	_drain.top_level = true
	_drain.visible = false
	add_child(_drain)


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)

	_hud = Label.new()
	_hud.position = Vector2(20, 16)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color(0.72, 0.95, 0.9, 0.8))
	_hud.text = "[J] swing  [B] skip to it  [1|2|3] force stage  [K] hit it 40" \
			+ "  [L] hit it 100  [F] fake a player  [TAB] profile  [R] restart"
	cl.add_child(_hud)

	_profile_lbl = Label.new()
	_profile_lbl.position = Vector2(20, 150)
	_profile_lbl.add_theme_font_size_override("font_size", 15)
	_profile_lbl.add_theme_color_override("font_color", Color(0.66, 0.95, 0.88, 0.8))
	_profile_lbl.visible = false
	cl.add_child(_profile_lbl)

	# what the boss is doing, and why — the one readout this rig exists for
	_banner = Label.new()
	_banner.position = Vector2(20, 48)
	_banner.add_theme_font_size_override("font_size", 17)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.62, 0.6, 0.92))
	cl.add_child(_banner)


# ---------- the handoff ----------

func _on_kill() -> void:
	_kills += 1
	if _kills >= _sporelings.size():
		_shift()


func _shift() -> void:
	if _shifted:
		return
	_shifted = true
	_drain.visible = true
	_curi.z_index = 95
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 4s here rather than the level's 9 — this rig is run dozens of times in a
	# row and the beat is not what is being tested
	tw.tween_method(func(v: float) -> void:
			_drain_mat.set_shader_parameter("sweep", v), -0.4, 1.4, 4.0)
	tw.tween_callback(_spawn_mirror)


func _spawn_mirror() -> void:
	if _mirror != null:
		return
	_mirror = Mirror.new()
	add_child(_mirror)
	_mirror.build_from(_curi)
	_mirror.global_position = _curi.global_position + Vector2(760.0, 0.0)
	_mirror.z_index = 94
	_mirror.died.connect(_on_mirror_died)
	_mirror.struck_player.connect(func() -> void:
		print("[MirrorTest] it hit her — her hp ", _curi.health))
	_mirror.stage_changed.connect(func(s: int) -> void:
		print("[MirrorTest] stage -> ", ["MIMIC", "TIME", "DECIDE"][s]))
	_mirror.arrive(2.0)


func _on_mirror_died() -> void:
	# THE FOREST COMES BACK. The drain is run backwards over its body, which is
	# what the shader was written to allow — killing the thing that arrived
	# with the grey takes the grey away with it.
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float) -> void:
			_drain_mat.set_shader_parameter("sweep", v), 1.4, -0.4, 3.0)
	tw.tween_callback(func() -> void: _drain.visible = false)
	print("[MirrorTest] IT DIED — the colour is coming back")


func _on_player_died() -> void:
	if _curi.has_method("hurt"):
		_curi.hurt()
	await get_tree().create_timer(0.5).timeout
	_curi.global_position = Vector2(120.0, FLOOR_Y - 140.0)
	_curi.velocity = Vector2.ZERO
	if _curi.has_method("refill_health"):
		_curi.refill_health()
	if _curi.has_method("grant_invuln"):
		_curi.grant_invuln(1.6)


# ---------- running ----------

func _process(delta: float) -> void:
	if _cam != null and _curi != null:
		var t := Vector2(_curi.global_position.x + 90.0, FLOOR_Y - 240.0)
		_cam.global_position = _cam.global_position.lerp(t, 1.0 - pow(0.002, delta))
	if _drain != null and _cam != null:
		var vs: Vector2 = get_viewport_rect().size / _cam.zoom
		_drain.size = vs
		_drain.global_position = _cam.global_position - vs * 0.5
	if _profile_lbl != null and _profile_lbl.visible:
		_profile_lbl.text = PlayerProfile.summary()
	if _banner != null:
		if _mirror != null and is_instance_valid(_mirror):
			_banner.text = _mirror.debug_state()
		else:
			_banner.text = "warm-up: %d/%d killed — it is reading you" \
					% [_kills, _sporelings.size()]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match (e as InputEventKey).keycode:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_ESCAPE:
			get_tree().quit()
		KEY_B:
			_shift()
		KEY_TAB:
			_profile_lbl.visible = not _profile_lbl.visible
		KEY_K:
			if _mirror != null and is_instance_valid(_mirror):
				_mirror.take_damage(40, Vector2(-200.0, -120.0))
		KEY_L:
			if _mirror != null and is_instance_valid(_mirror):
				_mirror.take_damage(100, Vector2(-200.0, -120.0))
		KEY_1, KEY_2, KEY_3:
			_force_stage((e as InputEventKey).keycode - KEY_1)
		KEY_F:
			# WEAR SOMEBODY ELSE'S HABITS. Cycles a faked profile — rusher,
			# camper, spammer — so all three bosses can be seen back to back
			# instead of played into existence one at a time.
			_fake = (_fake + 1) % 3
			PlayerProfile.seed_fake(_fake)
			print("[MirrorTest] fake profile -> ",
					["rusher", "camper", "spammer"][_fake])


## Jump straight to a stage without having to chew through its health — the
## stages are the thing being judged, and waiting eight swings to see the third
## one is how a tuning pass turns into an afternoon.
func _force_stage(s: int) -> void:
	if _mirror == null or not is_instance_valid(_mirror):
		return
	_mirror.health = int(_mirror.max_health * [0.9, 0.6, 0.3][s])
	_mirror.stage = s
	_mirror.stage_changed.emit(s)
	print("[MirrorTest] forced stage ", ["MIMIC", "TIME", "DECIDE"][s])
