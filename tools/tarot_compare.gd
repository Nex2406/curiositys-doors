extends Node2D
## Side-by-side compare: Level 2's card (left, original) vs Level 1's card (right).
## Both flip to the reveal side and hold, so the INTERIOR structure can be compared.
## CARD_SHOT=<path> screenshots both after they settle.

const TarotReadingScript := preload("res://scripts/TarotReading.gd")
const TarotPreviewScript := preload("res://tools/tarot_preview.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := CanvasLayer.new()
	bg.layer = -10
	var rect := ColorRect.new()
	rect.color = Color(0.05, 0.04, 0.03)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(rect)
	add_child(bg)

	_labels()

	# LEVEL 2 — the original card, untouched (wizard portrait, void moth, cream)
	var l2 := TarotReadingScript.new()
	l2.screen_offset = Vector2(-250, 0)
	# each card lays a full-screen dim over the whole viewport, so whichever is added
	# LAST was greying the other one out. In the compare rig neither dims — the
	# background is already dark, and both cards must be judged in the same light.
	l2.overlay_color = Color(0, 0, 0, 0)
	add_child(l2)

	# LEVEL 1 — the live card, built from tools/tarot_preview.gd so this rig can never
	# drift out of date behind it (it used to carry its own stale copy)
	var l1: Node = TarotPreviewScript.build_r1_card()
	l1.screen_offset = Vector2(250, 0)
	l1.overlay_color = Color(0, 0, 0, 0)
	add_child(l1)

	await get_tree().create_timer(1.2).timeout
	for c in [l2, l1]:
		if is_instance_valid(c):
			c._flip()
	await get_tree().create_timer(1.6).timeout
	for c in [l2, l1]:                       # snap the verses fully in
		if is_instance_valid(c):
			c._typing = false
			for lbl in c._verse_labels:
				lbl.visible_characters = -1

	if OS.get_environment("CARD_SHOT") != "":
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("CARD_SHOT"))
		get_tree().quit()


func _labels() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 200
	add_child(cl)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "serif"])
	for item in [["LEVEL 2  (original)", -250.0], ["LEVEL 1  (new)", 250.0]]:
		var l := Label.new()
		l.text = item[0]
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_CENTER_TOP)
		l.position = Vector2(item[1] - 150.0, 40.0)
		l.size = Vector2(300, 30)
		cl.add_child(l)
