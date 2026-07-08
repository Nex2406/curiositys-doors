extends Node2D
## THROWAWAY PREVIEW — side-by-side attack-cycle arenas for every enemy under
## assets/enemies/preview/, to evaluate the FlyingForestEnemies pack for the
## R2-M3+ enemy work. Self-contained: no realm, lifeline, or save systems.
##
## Each arena: static Curiosity (her real idle frames) on the left, the enemy
## at attack range on the right wearing the in-game treatment (purple modulate,
## nearest filter, 2x scale), running its full attack cycle on loop:
##   Idle (1s) -> AttackSmashStart -> AttackSmashLoop x2 -> SmashEnd -> Idle
## Frame counts are derived from strip width / 64 — they differ per animation.
##
## Controls: 1-9 zoom one arena fullscreen · 0 back to grid · SPACE pause ·
## ESC quit. EAP_SHOT=<path> env: screenshot after 2s and quit (verification).

const PREVIEW_DIR := "res://assets/enemies/preview/"
const CURI_IDLE_DIR := "res://assets/player/curiosity/idle/"
const FRAME_SIZE := 64
const ENEMY_SCALE := 2.0
const ENEMY_TINT := Color(0.72, 0.55, 0.95)
const BG_COLOR := Color("#1a1230")
const DIVIDER_COLOR := Color(0.45, 0.38, 0.62, 0.5)
const ANIM_FPS := 10.0
const IDLE_HOLD := 1.0
const SMASH_LOOPS := 2
const FLOOR_FRAC := 0.62   # arena floor line as a fraction of viewport height
const HOVER := 26.0        # flying enemies float this far above the floor line

# animation name -> [file suffix, loops]  (matched against actual file names)
const ANIMS := {
	"idle": ["-Idle.png", false],          # non-loop so the cycle can await it
	"attack_start": ["-AttackSmashStart.png", false],
	"attack_loop": ["-AttackSmashLoop.png", false],  # played twice, awaited
	"smash_end": ["-SmashEnd.png", false],
}

var _arenas: Array[Node2D] = []
var _grid_xform: Array[Transform2D] = []
var _zoomed := -1


func _ready() -> void:
	# input must survive the pause: the root stays ALWAYS, arenas are PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var names := _find_enemies()
	print("[EnemyAttackPreview] %d enemies found: %s" % [names.size(), ", ".join(names)])
	if names.is_empty():
		push_error("[EnemyAttackPreview] nothing under " + PREVIEW_DIR)
		return
	var vp := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = vp
	add_child(bg)
	var w := vp.x / names.size()
	for i in names.size():
		var arena := _build_arena(names[i], i, w, vp.y)
		arena.position = Vector2(i * w, 0)
		arena.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(arena)
		_arenas.append(arena)
		_grid_xform.append(arena.transform)
		if i > 0:
			var div := ColorRect.new()
			div.color = DIVIDER_COLOR
			div.position = Vector2(i * w - 1.0, 0)
			div.size = Vector2(2.0, vp.y)
			add_child(div)
	if OS.get_environment("EAP_SHOT") != "":
		_self_screenshot(OS.get_environment("EAP_SHOT"))


func _find_enemies() -> Array[String]:
	var names: Array[String] = []
	for d in DirAccess.get_directories_at(PREVIEW_DIR):
		names.append(d)
	names.sort()
	return names


func _build_arena(enemy_name: String, index: int, w: float, h: float) -> Node2D:
	var arena := Node2D.new()
	arena.name = enemy_name
	var floor_y := h * FLOOR_FRAC
	var cx := w * 0.5

	# Curiosity, standing on the left at her real idle — scaled so she reads
	# at the same height she will against 64px enemies at 2x in-game
	var curi := AnimatedSprite2D.new()
	var curi_frames := SpriteFrames.new()
	curi_frames.remove_animation("default")
	curi_frames.add_animation("idle")
	curi_frames.set_animation_loop("idle", true)
	curi_frames.set_animation_speed("idle", 8.0)
	var idle_files: Array[String] = []
	for f in DirAccess.get_files_at(CURI_IDLE_DIR):
		if f.ends_with(".png"):
			idle_files.append(f)
	idle_files.sort_custom(func(a: String, b: String) -> bool:
		return a.naturalnocasecmp_to(b) < 0)
	var curi_h := 288.0
	for f in idle_files:
		var t: Texture2D = load(CURI_IDLE_DIR + f)
		curi_frames.add_frame("idle", t)
		curi_h = t.get_height()
	curi.sprite_frames = curi_frames
	var curi_scale := (FRAME_SIZE * ENEMY_SCALE) / curi_h
	curi.scale = Vector2(curi_scale, curi_scale)
	curi.position = Vector2(cx - 130.0, floor_y - curi_h * curi_scale * 0.5)
	curi.play("idle")
	arena.add_child(curi)

	# the enemy, at attack range, wearing the in-game treatment
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _build_enemy_frames(enemy_name)
	spr.modulate = ENEMY_TINT
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(ENEMY_SCALE, ENEMY_SCALE)
	spr.flip_h = true  # pack art faces right; the hero is on its left
	spr.position = Vector2(cx + 90.0,
			floor_y - FRAME_SIZE * ENEMY_SCALE * 0.5 - HOVER)
	arena.add_child(spr)
	_run_cycle(spr)

	# label: folder name + zoom key
	var lbl := Label.new()
	lbl.text = "%s   [%d]" % [enemy_name, index + 1]
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.76, 0.95))
	lbl.position = Vector2(18.0, 14.0)
	arena.add_child(lbl)
	return arena


func _build_enemy_frames(enemy_name: String) -> SpriteFrames:
	var dir := PREVIEW_DIR + enemy_name + "/"
	var files := DirAccess.get_files_at(dir)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in ANIMS:
		var suffix: String = ANIMS[anim][0]
		for f in files:
			if not f.ends_with(suffix):
				continue
			# "-SmashEnd" must not also catch "-AttackSmashEnd"-style names,
			# nor "-AttackSmashLoop" catch a bare "-SmashLoop": exact suffix
			# match on the shortest candidate wins — pack names are distinct.
			var tex: Texture2D = load(dir + f)
			var n := tex.get_width() / FRAME_SIZE
			sf.add_animation(anim)
			sf.set_animation_loop(anim, ANIMS[anim][1])
			sf.set_animation_speed(anim, ANIM_FPS)
			for i in n:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
				sf.add_frame(anim, at)
			break
	return sf


# Idle (1s) -> AttackSmashStart -> AttackSmashLoop x2 -> SmashEnd -> repeat.
# Every animation is stored non-looping so animation_finished always fires;
# the idle hold and loop count live here instead.
func _run_cycle(spr: AnimatedSprite2D) -> void:
	while is_instance_valid(spr):
		spr.play("idle")
		# process_always=false so SPACE (tree pause) freezes the hold too
		await get_tree().create_timer(IDLE_HOLD, false).timeout
		if not is_instance_valid(spr):
			return
		spr.play("attack_start")
		await spr.animation_finished
		for i in SMASH_LOOPS:
			spr.play("attack_loop")
			await spr.animation_finished
		spr.play("smash_end")
		await spr.animation_finished


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		get_tree().quit()
	elif key == KEY_SPACE:
		get_tree().paused = not get_tree().paused
	elif key == KEY_0:
		_zoom(-1)
	elif key >= KEY_1 and key <= KEY_9:
		_zoom(key - KEY_1)


func _zoom(index: int) -> void:
	if index >= _arenas.size():
		return
	_zoomed = index
	var vp := get_viewport_rect().size
	var w := vp.x / _arenas.size()
	for i in _arenas.size():
		var a := _arenas[i]
		if index == -1 or i == index:
			a.visible = true
			a.transform = _grid_xform[i]
			if i == index and index != -1:
				var s := vp.x / w
				a.scale = Vector2(s, s)
				# keep the arena's floor-line center in the middle of the screen
				a.position = Vector2(vp.x * 0.5 - (w * 0.5) * s,
						vp.y * 0.5 - (vp.y * FLOOR_FRAC - 60.0) * s)
		else:
			a.visible = false


func _self_screenshot(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
