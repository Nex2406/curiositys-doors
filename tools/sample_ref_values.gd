extends SceneTree
## Sample docs/reference/cave_ref_04.png at named anchor points — the
## measured values drive the fog shader + band lifts so the rig matches
## the pack's own promo grammar instead of my eyeballing.

const REF := "res://docs/reference/cave_ref_04.png"
const POINTS := {
	"fog_core (glow upper-left)": Vector2(0.17, 0.22),
	"fog_mid (center)": Vector2(0.50, 0.45),
	"fog_low (center-low mist)": Vector2(0.50, 0.78),
	"dark upper-right": Vector2(0.85, 0.12),
	"billow (left, in glow)": Vector2(0.20, 0.33),
	"spike row (center-right)": Vector2(0.62, 0.68),
	"far spires (right edge)": Vector2(0.90, 0.48),
	"near silhouette (left wall)": Vector2(0.045, 0.50),
	"ground line (bottom)": Vector2(0.40, 0.95),
}


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(REF))
	for label: String in POINTS:
		var uv: Vector2 = POINTS[label]
		var px := img.get_pixel(int(img.get_width() * uv.x),
				int(img.get_height() * uv.y))
		print("%-32s RGB(%3d, %3d, %3d)" % [label,
				int(px.r * 255.0), int(px.g * 255.0), int(px.b * 255.0)])
	quit()
