extends SceneTree

## Does EB Garamond actually hand back glyphs at runtime? "Health" rendered as
## tofu boxes in the lantern HUD and the guess was the font; this proves it
## instead of theorising.

func _init() -> void:
	var f: Font = load("res://assets/fonts/eb_garamond.ttf")
	print("loaded=", f, "  class=", f.get_class() if f != null else "NULL")
	if f != null:
		print("has H=", f.has_char("H".unicode_at(0)),
				"  has e=", f.has_char("e".unicode_at(0)))
		print("size(Health,20)=", f.get_string_size("Health",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20))
		print("ascent(20)=", f.get_ascent(20))
		print("face=", f.get_font_name(), " / ", f.get_font_style_name())
	quit()
