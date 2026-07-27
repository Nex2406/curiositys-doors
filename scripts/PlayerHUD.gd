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
# Advika 2026-07-26: shoved right into the corner (was 60/36, which floated it
# well inside the frame), and the count reads "collected / total".
const RIGHT_MARGIN := 26.0
const TOP := 22.0          # crystal/number sit on roughly the eyes' line

var _jade_text: Label
var _got: int = 0
var _total: int = 0


func _ready() -> void:
	layer = 50
	var a := Control.new()                       # anchored to the top-right corner
	a.anchor_left = 1.0
	a.anchor_right = 1.0
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(a)

	var num_w := 130.0        # fits "17/17" at NUM_FONT_SIZE
	var num_x := -RIGHT_MARGIN - num_w           # number block, right-aligned to the margin
	var icon_x := num_x - 14.0 - ICON_SIZE       # crystal just left of the number

	# a soft green bloom behind the shard so it reads as lit rather than pasted on
	# (Advika 2026-07-27: "add a hue to it or make it glow")
	var halo := TextureRect.new()
	halo.texture = _glow_tex()
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# tight to the shard — light coming FROM INSIDE it, not a lamp behind it
	# (Advika 2026-07-27: "the glow is too big, it should look like the jade glows
	# from within")
	halo.custom_minimum_size = Vector2(ICON_SIZE * 1.15, ICON_SIZE * 1.15)
	halo.size = halo.custom_minimum_size
	halo.position = Vector2(icon_x + ICON_SIZE * 0.075, TOP + ICON_SIZE * 0.075)
	halo.modulate = Color(0.42, 1.0, 0.58, 0.62)
	var halo_mat := CanvasItemMaterial.new()
	halo_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = halo_mat
	a.add_child(halo)
	# and it breathes, so the corner has a pulse to it
	var pulse := create_tween().set_loops()
	pulse.tween_property(halo, "modulate:a", 0.34, 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(halo, "modulate:a", 0.62, 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var icon := TextureRect.new()
	icon.texture = JADE_ICON
	icon.modulate = Color(1.25, 1.5, 1.28)   # lift the shard's own green
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.position = Vector2(icon_x, TOP)
	a.add_child(icon)

	# EB Garamond, BUNDLED — the old system-serif (Georgia/Times) resolved on desktop
	# and fell back to a plain sans in the browser, which is the ugly counter Advika
	# saw on the live build (2026-07-27). Same serif as the cards and the door prompt.
	var serif: Font = load("res://assets/fonts/eb_garamond.ttf")

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


## A soft radial, built in code so the HUD carries no extra art dependency.
func _glow_tex() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.85))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.45, Color(1, 1, 1, 0.30))
	var t := GradientTexture2D.new()
	t.gradient = grad
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t


func set_jade(got: int, total: int) -> void:
	_got = got
	_total = total
	if _jade_text != null:
		# "3/17" — the player should always know how much of the realm is left
		_jade_text.text = "%d/%d" % [got, total] if total > 0 else str(got)


# Stub — the health bar is being redesigned; keep the realm's connection valid.
func set_health(_health: int, _max_health: int) -> void:
	pass
