extends Node2D

# Labelled jade/placement map generator for Realm 1.
# Boot straight into it:
#   Godot ... --path . res://tools/JadeMap.tscn
#
# Renders the whole level in SLICES horizontal slices (_map_0.png .. _map_N.png),
# overlaying three label layers so any spot is addressable:
#   yellow 1..45  = jades (sorted left-to-right)
#   green  P0..   = moving-plank platforms (MovingPiece<index>)
#   blue   x-grid = vertical lines every 500px, labelled every 1000px
#
# Then stack the slices into one map with PIL (run from project root):
#   python -c "
#   from PIL import Image, ImageDraw
#   crop=(0,352,1920,742); rows=[Image.open('_map_%d.png'%i).convert('RGB').crop(crop) for i in range(4)]
#   w,h=rows[0].size; s=0.82; w2,h2=int(w*s),int(h*s); rows=[r.resize((w2,h2)) for r in rows]
#   pad=30; out=Image.new('RGB',(w2,(h2+pad)*4),(10,10,12)); d=ImageDraw.Draw(out)
#   [ (out.paste(r,(0,i*(h2+pad)+pad)), d.text((10,i*(h2+pad)+8),'SECTION %d'%(i+1),fill=(150,210,255))) for i,r in enumerate(rows) ]
#   out.save('_jademap.png')"
# Current durable output: assets/_reference/jade_map_labelled_2026-06-29.png

const SLICES := 4
const X0 := 300.0
const X1 := 14800.0
const CAM_Y := 430.0
var _cam: Camera2D

func _ready() -> void:
	var lvl: Node = load("res://assets/realms/realm1_caves/Realm1.tscn").instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout

	# x-coordinate grid
	var gx := 0
	while gx <= 15000:
		var major := (gx % 1000 == 0)
		var ln := Line2D.new()
		ln.add_point(Vector2(gx, 150)); ln.add_point(Vector2(gx, 690))
		ln.width = 3.0 if major else 1.0
		ln.default_color = Color(0.45, 0.7, 0.9, 0.55 if major else 0.22)
		ln.z_index = 4000
		add_child(ln)
		if major:
			add_child(_label("%d" % gx, Vector2(gx + 6, 150), 60, Color(0.55, 0.8, 1.0), 12, 4100))
		gx += 500

	_label_planks(lvl)

	var jades: Array = []
	_collect(lvl, jades)
	jades.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	for i in range(jades.size()):
		var p: Vector2 = jades[i].global_position
		add_child(_label(str(i + 1), p + Vector2(-26, -150), 88, Color(1, 0.95, 0.35), 16, 4200))

	_cam = Camera2D.new(); add_child(_cam); _cam.make_current()
	var sw := (X1 - X0) / SLICES
	_cam.zoom = Vector2(1920.0 / sw, 1920.0 / sw)
	for i in range(SLICES):
		_cam.position = Vector2(X0 + sw * (i + 0.5), CAM_Y)
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://_map_%d.png" % i)
	get_tree().quit()


func _label(text: String, pos: Vector2, size: int, col: Color, outline: int, z: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", outline)
	l.z_index = z
	l.position = pos
	return l


func _label_planks(n: Node) -> void:
	if n is AnimatableBody2D and n.name.begins_with("MovingPiece"):
		var top := 1e9; var xmn := 1e9; var xmx := -1e9
		for ch in n.get_children():
			if ch is CollisionShape2D and ch.shape is RectangleShape2D:
				var sz: Vector2 = (ch.shape as RectangleShape2D).size
				var gp: Vector2 = ch.global_position
				top = min(top, gp.y - sz.y * 0.5)
				xmn = min(xmn, gp.x - sz.x * 0.5); xmx = max(xmx, gp.x + sz.x * 0.5)
		if top < 1e9:
			var idx := str(n.name).replace("MovingPiece", "")
			add_child(_label("P" + idx, Vector2((xmn + xmx) * 0.5 - 30, top + 6), 52, Color(0.55, 1.0, 0.7), 12, 4150))
	for c in n.get_children():
		_label_planks(c)


func _collect(n: Node, out: Array) -> void:
	if n is Jade:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
