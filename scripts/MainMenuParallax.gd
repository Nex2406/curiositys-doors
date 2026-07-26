extends Control
## Main menu — depth parallax + breathing zoom (Step 2). Lives on the Background
## container: its NODE SCALE provides the permanent 3% overscan and the breathing
## (so anything parented under Background later — mist, orbs — breathes with the
## scene), and it drives the parallax shader on the Painting child. Everything is
## meant to be tuned by feel via the exports + the one master intensity.

# --- tunables (inspector) -----------------------------------------------------
## Peak UV shift for the NEAREST pixels at full cursor deflection (~15px @1920).
## Deliberately tiny — start subliminal. Safe ceiling ~0.013 before the 3%
## overscan margin is exceeded.
@export_range(0.0, 0.02, 0.0005) var max_offset: float = 0.008
## How fast the offset chases the cursor. Lower = more lag / more weight.
@export_range(0.5, 12.0, 0.1) var easing_rate: float = 3.0
## How strongly the depth map modulates the shift (1 = as authored).
@export_range(0.0, 2.0, 0.05) var depth_strength: float = 1.0
## Seconds per breath (long, so it never resolves into a rhythm you can count).
@export_range(3.0, 30.0, 0.5) var breathing_period: float = 19.0
## Extra INWARD scale on top of the 3% base — never outward past the base, which
## is our margin. Tiny.
@export_range(0.0, 0.03, 0.001) var breathing_amplitude: float = 0.012
## Fraction of max_offset the autonomous wander uses when the cursor is idle/absent.
@export_range(0.0, 1.0, 0.05) var idle_drift: float = 0.4
## Scales the WHOLE parallax effect (parallax + breathing + drift) without
## touching the individual values above.
@export_range(0.0, 1.0, 0.05) var master_intensity: float = 1.0
## Master over BOTH mist layers (body + veil), matching the per-step master
## pattern. Per-layer mist dials live on each ColorRect's material.
@export_range(0.0, 1.0, 0.05) var mist_master: float = 1.0
## TEMP (Step-3 browser test): show a live FPS readout so the real browser
## frame rate can be read off-screen. Turn off before shipping.
@export var debug_show_fps: bool = false
var _fps_label: Label

const BASE_OVERSCAN := 1.03   # permanent 3% resting zoom == the parallax margin
const IDLE_DELAY := 4.5       # seconds of no pointer movement before drifting
const IDLE_RAMP := 2.0        # seconds to blend fully into the autonomous drift

var _mat: ShaderMaterial
var _mist: Array[ShaderMaterial] = []
var _offset := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _idle_t := 999.0
var _drift_w := 1.0
var _outside := false
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var painting := get_node_or_null("Painting")
	if painting != null and painting.material is ShaderMaterial:
		_mat = painting.material
	for n: String in ["MistBody", "MistVeil"]:
		var layer := get_node_or_null(n)
		if layer != null and layer.material is ShaderMaterial:
			_mist.append(layer.material)
	# know when the pointer leaves the window entirely (drift back to centre)
	var root := get_parent()
	if root is Control:
		(root as Control).mouse_exited.connect(func() -> void: _outside = true)
		(root as Control).mouse_entered.connect(func() -> void: _outside = false)
	_last_mouse = get_viewport().get_mouse_position()
	if debug_show_fps:
		var cl := CanvasLayer.new()
		cl.layer = 200
		add_child(cl)
		_fps_label = Label.new()
		_fps_label.position = Vector2(18, 12)
		_fps_label.add_theme_font_size_override("font_size", 28)
		_fps_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_fps_label.add_theme_constant_override("outline_size", 6)
		cl.add_child(_fps_label)


func _process(delta: float) -> void:
	_time += delta
	if _fps_label != null:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	var vp := get_viewport_rect().size
	pivot_offset = size * 0.5   # scale around the screen centre

	# --- cursor -> normalised target (-1..1 per axis) + idle detection ---
	var mouse := get_viewport().get_mouse_position()
	var moved := mouse.distance_to(_last_mouse) > 0.5
	_last_mouse = mouse
	if moved and not _outside:
		_idle_t = 0.0
	else:
		_idle_t += delta

	var cursor_target := Vector2.ZERO
	if not _outside:
		var half := vp * 0.5
		cursor_target = ((mouse - half) / half).clamp(Vector2(-1, -1), Vector2(1, 1))

	# blend toward the autonomous drift once idle or the pointer is gone
	var want_drift := 1.0 if (_idle_t > IDLE_DELAY or _outside) else 0.0
	_drift_w = move_toward(_drift_w, want_drift, delta / IDLE_RAMP)

	# --- autonomous drift: a lazy wander on incommensurate sines (chosen NOT to
	#     fall into rhythm with the breathing), centred on 0 so leaving the window
	#     eases back toward centre before it starts to wander ---
	var t := _time
	var drift := Vector2(
			0.6 * sin(t * 0.13) + 0.4 * sin(t * 0.29 + 1.7),
			0.6 * sin(t * 0.11 + 2.3) + 0.4 * sin(t * 0.23 + 0.9)) * idle_drift

	var base_target := Vector2.ZERO if _outside else cursor_target
	var target := base_target.lerp(drift, _drift_w) * (max_offset * master_intensity)

	# --- ease toward target with weight (frame-rate independent) ---
	var k := 1.0 - exp(-easing_rate * delta)
	_offset = _offset.lerp(target, k)

	if _mat != null:
		_mat.set_shader_parameter("u_offset", _offset)
		_mat.set_shader_parameter("u_depth_strength", depth_strength)

	# feed the same eased offset to the mist layers (their own `ride` uniform
	# scales how much each one follows) + the mist master
	for mm: ShaderMaterial in _mist:
		mm.set_shader_parameter("u_offset", _offset)
		mm.set_shader_parameter("master", mist_master)

	# --- breathing zoom: inward-only ping-pong from the overscan base ---
	var breath := 0.5 - 0.5 * cos(t * TAU / breathing_period)
	var s := BASE_OVERSCAN + breathing_amplitude * master_intensity * breath
	scale = Vector2(s, s)
