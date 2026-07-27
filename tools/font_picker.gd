extends Node2D

## Font picker for the quote card (Advika 2026-07-27: "open a window with font
## samples so I can pick"). Every candidate in assets/fonts/candidates renders the
## REAL card — same gold on black, same sizes, same right-aligned attribution — so
## the choice is made on the thing itself, not on a specimen sheet.
##
## UP/DOWN or W/S — page through. Each sample is numbered; say the number.

const QUOTE := "“You will not fall, nor rise.”"
const FEAR := "— Fear"
const BOOK := "(Written by Silence – Advika Kohli)"
const GOLD := Color("E8C88A")
const DIR := "res://assets/fonts/candidates/"
const CREDIT_FONT := "res://assets/fonts/eb_garamond_italic.ttf"
const PER_PAGE := 3

var _fonts: Array = []       # [display name, Font]
var _page := 0
var _root: VBoxContainer
var _pager: Label


func _ready() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(rect)
	add_child(bg)

	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".ttf"):
			continue
		var font: Font = load(DIR + f)
		if font != null:
			_fonts.append([f.get_basename().replace("_", " "), font])
	_fonts.sort_custom(func(a, b): return String(a[0]) < String(b[0]))

	var ui := CanvasLayer.new()
	add_child(ui)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	ui.add_child(margin)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 34)
	margin.add_child(_root)

	_pager = Label.new()
	_pager.add_theme_color_override("font_color", Color(0.45, 0.75, 0.85))
	_pager.add_theme_font_size_override("font_size", 18)
	ui.add_child(_pager)
	_pager.position = Vector2(60, 8)

	_draw_page()


func _draw_page() -> void:
	for c in _root.get_children():
		c.queue_free()
	var start: int = _page * PER_PAGE
	for i in range(start, mini(start + PER_PAGE, _fonts.size())):
		_root.add_child(_sample(i + 1, _fonts[i][0], _fonts[i][1]))
	_pager.text = "%d-%d of %d   ·   UP/DOWN to page   ·   tell me the number" % [
		start + 1, mini(start + PER_PAGE, _fonts.size()), _fonts.size()]


## One card's worth: the number and family name in cyan, then the quote exactly as
## the transition draws it.
func _sample(idx: int, fname: String, font: Font) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var tag := Label.new()
	tag.text = "%d.  %s" % [idx, fname]
	tag.add_theme_color_override("font_color", Color(0.40, 0.72, 0.82))
	tag.add_theme_font_size_override("font_size", 16)
	box.add_child(tag)

	var quote := Label.new()
	quote.text = QUOTE
	quote.add_theme_font_override("font", font)
	quote.add_theme_font_size_override("font_size", 52)
	quote.add_theme_color_override("font_color", GOLD)
	box.add_child(quote)

	var fear := Label.new()
	fear.text = FEAR
	fear.add_theme_font_override("font", font)
	fear.add_theme_font_size_override("font_size", 30)
	fear.add_theme_color_override("font_color", GOLD)
	fear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(fear)

	var book := Label.new()
	book.text = BOOK
	book.add_theme_font_override("font", load(CREDIT_FONT))
	book.add_theme_font_size_override("font_size", 19)
	book.add_theme_color_override("font_color", Color(GOLD.r, GOLD.g, GOLD.b, 0.55))
	book.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(book)
	return box


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	var pages: int = int(ceil(float(_fonts.size()) / float(PER_PAGE)))
	if k == KEY_DOWN or k == KEY_S or k == KEY_RIGHT:
		_page = (_page + 1) % pages
		_draw_page()
	elif k == KEY_UP or k == KEY_W or k == KEY_LEFT:
		_page = (_page - 1 + pages) % pages
		_draw_page()
	elif k == KEY_ESCAPE:
		get_tree().quit()
