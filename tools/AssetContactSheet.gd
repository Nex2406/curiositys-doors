extends Node2D
## Contact sheet of every Maaot slice in assets/realms/realm1_cavern/ —
## labeled grid so Advika can call out pieces by name while directing a
## composition. SHEET_PAGE=<n> picks the page (0-based, 40 per page);
## SHEET_OUT=<path> screenshots at 1s and quits.

const DIR := "res://assets/realms/realm1_cavern/"
const COLS := 8
const ROWS := 5
const CELL_W := 240.0
const CELL_H := 212.0
const ART_H := 168.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.36, 0.36, 0.39))
	var files: Array[String] = []
	var d := DirAccess.open(DIR)
	for f: String in d.get_files():
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	var page := 0
	if OS.get_environment("SHEET_PAGE") != "":
		page = int(OS.get_environment("SHEET_PAGE"))
	var start := page * COLS * ROWS
	for i in range(start, mini(start + COLS * ROWS, files.size())):
		var k := i - start
		var cx := (k % COLS) * CELL_W + CELL_W * 0.5
		var cy := float(k / COLS) * CELL_H + 12.0
		var tex: Texture2D = load(DIR + files[i])
		var s := Sprite2D.new()
		s.texture = tex
		var fit := minf(minf((CELL_W - 20.0) / tex.get_width(),
				ART_H / tex.get_height()), 1.0)
		s.scale = Vector2(fit, fit)
		s.position = Vector2(cx, cy + ART_H * 0.5)
		add_child(s)
		var l := Label.new()
		l.text = files[i].trim_suffix(".png")
		l.position = Vector2(cx - CELL_W * 0.5, cy + ART_H + 6.0)
		l.size = Vector2(CELL_W, 30.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(1, 1, 1))
		add_child(l)
	if OS.get_environment("SHEET_OUT") != "":
		_shot(OS.get_environment("SHEET_OUT"))


func _shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
