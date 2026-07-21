extends Node2D
## Realm 1 PLATFORM GALLERY — small/medium/large floating platform
## assemblies over the locked parallax background. Ref: cave_ref_04's
## chunky dark blocks with fog-lit cap stones — deliberately NOT the
## mossy-overhang look Realm 2 uses. Every platform is ONE Node2D assembly
## (nothing floats); two variants per size so nothing reads copy-pasted.
## Hold LEFT/RIGHT to pan. PLAT_SHOT=<path> screenshots and quits.

const Realm1Bg := preload("res://scripts/Realm1Bg.gd")
const CUT := "res://assets/realms/realm1_cut/"
const PLANTS := "res://assets/realms/realm1_plants/"
const CAM_SPEED := 700.0

const BLOCK := Color(0.17, 0.15, 0.135)     # main platform body
const BLOCK_DIM := Color(0.13, 0.115, 0.105)
const UNDER := Color(0.07, 0.062, 0.058)    # undersides + teeth

var _cache := {}
var _cam: Camera2D


func _ready() -> void:
	Realm1Bg.build(self)
	# gallery layout, ref-frame-ish: L / S / M scattered like a route
	_large_a(Vector2(-620, -60))
	_small_a(Vector2(-140, 40))
	_medium_a(Vector2(350, 180))
	_small_b(Vector2(540, -150))
	_medium_b(Vector2(60, 380))
	_large_b(Vector2(830, 300))
	_cam = Camera2D.new()
	_cam.position = Vector2.ZERO
	add_child(_cam)
	_cam.make_current()
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var l := Label.new()
	l.text = "REALM 1 PLATFORMS — S/M/L gallery      hold LEFT / RIGHT to pan"
	l.position = Vector2(24, 18)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	cl.add_child(l)
	if OS.get_environment("PLAT_CAM_X") != "":
		_cam.position.x = float(OS.get_environment("PLAT_CAM_X"))
	if OS.get_environment("PLAT_SHOT") != "":
		_shot(OS.get_environment("PLAT_SHOT"))


func _process(delta: float) -> void:
	if _cam != null:
		_cam.position.x += Input.get_axis("ui_left", "ui_right") * CAM_SPEED * delta


func _tex(dir: String, tex_name: String) -> Texture2D:
	var key := dir + tex_name
	if not _cache.has(key):
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir + tex_name))
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


func _p(parent: Node2D, tex_name: String, pos: Vector2, sc: float,
		tint: Color, z: int, fh := false, dir := CUT) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(dir, tex_name)
	s.position = pos
	s.scale = Vector2(-sc if fh else sc, sc)
	s.modulate = tint
	s.z_index = z
	parent.add_child(s)
	return s


## fog-lit cap stone (glows softly toward the light)
func _cap(parent: Node2D, tex_name: String, pos: Vector2, sc: float,
		fh := false) -> Sprite2D:
	var s := _p(parent, tex_name, pos, sc, Color.WHITE, -1, fh)
	s.material = Realm1Bg.mass_mat(0.95, 0.6, Vector3(1.08, 0.95, 0.82))
	return s


## platform body: dark but TEXTURED — fog-lit so the stone surface reads
## and the block sits in the scene's light instead of flat black
func _body(parent: Node2D, tex_name: String, pos: Vector2, sc: float,
		z: int, fh := false, lift := 0.25) -> Sprite2D:
	var s := _p(parent, tex_name, pos, sc, Color.WHITE, z, fh)
	s.material = Realm1Bg.mass_mat(lift, 0.70, Vector3(1.05, 0.90, 0.80))
	return s


func _assembly(pos: Vector2) -> Node2D:
	var a := Node2D.new()
	a.position = pos
	a.z_index = 5
	add_child(a)
	return a


# ---------- SMALL: one chunky block ----------

func _small_a(pos: Vector2) -> void:
	var a := _assembly(pos)
	_cap(a, "combo_04.png", Vector2(6, -58), 0.16)
	_body(a, "plat_02.png", Vector2.ZERO, 0.50, 0)
	_p(a, "rock_14.png", Vector2(34, 48), 0.14, UNDER, 1)


func _small_b(pos: Vector2) -> void:
	var a := _assembly(pos)
	_cap(a, "bigrock_08.png", Vector2(-8, -44), 0.13, true)
	_body(a, "plat_05.png", Vector2.ZERO, 0.34, 0, false, 0.22)


# ---------- MEDIUM: slab + under-block ----------

func _medium_a(pos: Vector2) -> void:
	var a := _assembly(pos)
	_cap(a, "combo_05.png", Vector2(-52, -54), 0.20)
	_body(a, "plat_08.png", Vector2(0, -34), 0.75, 0)
	_body(a, "plat_02.png", Vector2(12, 30), 0.55, -1, false, 0.18)
	_p(a, "rock_13.png", Vector2(66, 74), 0.17, UNDER, 1)
	_p(a, "Grass2_00000.png", Vector2(96, -60), 0.22, Color(0.16, 0.17, 0.11), 1,
			false, PLANTS)


func _medium_b(pos: Vector2) -> void:
	var a := _assembly(pos)
	_cap(a, "combo_07.png", Vector2(-14, -62), 0.20, true)
	_body(a, "plat_02.png", Vector2(-40, 0), 0.62, 0)
	_body(a, "plat_02.png", Vector2(84, 44), 0.44, -1, true, 0.18)
	_p(a, "rock_14.png", Vector2(-70, 56), 0.15, UNDER, 1)


# ---------- LARGE: ledge island / column isle ----------

func _large_a(pos: Vector2) -> void:
	var a := _assembly(pos)
	_cap(a, "combo_10.png", Vector2(-20, -64), 0.26)
	_body(a, "plat_08.png", Vector2(0, -30), 1.0, 0, false, 0.28)
	_body(a, "floor_07.png", Vector2(-96, 46), 0.80, -1, false, 0.18)
	_body(a, "plat_02.png", Vector2(96, 42), 0.62, -1, false, 0.18)
	_p(a, "rock_20.png", Vector2(-20, 96), 0.40, UNDER, 1)
	_p(a, "PlantSmall_00000.png", Vector2(158, -58), 0.24, Color(0.14, 0.15, 0.10),
			1, false, PLANTS)


func _large_b(pos: Vector2) -> void:
	var a := _assembly(pos)
	_cap(a, "combo_04.png", Vector2(-30, -104), 0.22, true)
	_body(a, "plat_08.png", Vector2(0, -76), 0.8, 0, false, 0.28)
	_body(a, "floor_08.png", Vector2(0, 44), 0.80, -1, false, 0.16)
	_p(a, "rock_13.png", Vector2(-88, -18), 0.18, UNDER, 1)
	_p(a, "Grass2_00000.png", Vector2(84, -108), 0.2, Color(0.15, 0.16, 0.10), 1,
			true, PLANTS)


func _shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
