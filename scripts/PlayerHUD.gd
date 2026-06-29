extends CanvasLayer
class_name PlayerHUD

## Top-right HUD. For now just the jade counter — a jade crystal followed by the count
## in an elegant serif, matching the reference. The health bar is intentionally absent;
## a bespoke design is coming. set_health() is kept as a stub so the realm can stay
## wired to it without change.
##
## NOTE: uses a system serif (Georgia/Times) so it reads right on desktop. The web
## export has no system fonts — bundle an open serif (e.g. EB Garamond) and swap it in
## before deploy. [[reference_screenshot_harness]]

const JADE_ICON: Texture2D = preload("res://assets/collectables/jade/jade_1.png")
const IVORY := Color(0.96, 0.93, 0.84)

const ICON_SIZE := 60.0
const NUM_FONT_SIZE := 48
const RIGHT_MARGIN := 60.0
const TOP := 36.0          # crystal/number sit on roughly the eyes' line

var _jade_text: Label
var _got: int = 0


func _ready() -> void:
	layer = 50
	var a := Control.new()                       # anchored to the top-right corner
	a.anchor_left = 1.0
	a.anchor_right = 1.0
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(a)

	var num_w := 140.0
	var num_x := -RIGHT_MARGIN - num_w           # number block, right-aligned to the margin
	var icon_x := num_x - 14.0 - ICON_SIZE       # crystal just left of the number

	var icon := TextureRect.new()
	icon.texture = JADE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.position = Vector2(icon_x, TOP)
	a.add_child(icon)

	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])

	_jade_text = Label.new()
	_jade_text.add_theme_font_override("font", serif)
	_jade_text.add_theme_font_size_override("font_size", NUM_FONT_SIZE)
	_jade_text.add_theme_color_override("font_color", IVORY)
	_jade_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_jade_text.add_theme_constant_override("outline_size", 5)
	_jade_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_jade_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_jade_text.size = Vector2(num_w, ICON_SIZE)
	_jade_text.position = Vector2(num_x, TOP - 8.0)
	a.add_child(_jade_text)

	set_jade(0, 0)


func set_jade(got: int, _total: int) -> void:
	_got = got
	if _jade_text != null:
		_jade_text.text = str(got)


# Stub — the health bar is being redesigned; keep the realm's connection valid.
func set_health(_health: int, _max_health: int) -> void:
	pass
