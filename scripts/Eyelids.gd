extends CanvasLayer
class_name Eyelids

## THE EYE CLOSING. Two full-screen quads whose covered edge BULGES in the middle, so
## what shuts reads as an eyelid rather than a letterbox bar, and whose edge is
## feathered so it never draws a hard line across the frame.
##
## This was `Realm3Epilogue`'s private furniture until Realm 2's death beat needed the
## identical thing (Advika: *"when curiosity dies in lvl 2 i want that blink thing that
## we had in the end of r3 before epilouge to happen before the entire level resets"*).
## Rather than a second lid shader with its own curve, feather and easing that would
## quietly drift from the one she approved, the implementation moved here and both
## drive it. The game's eye closes the same way wherever it closes.
##
## It draws and animates through a PAUSED tree on purpose: a death beat and an ending
## both freeze what is behind them, and a lid that stops halfway down is worse than no
## lid at all.

const LID_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;   // 0 open, 1 shut
uniform float flip = 0.0;     // 0 top lid, 1 bottom lid
uniform float curve = 0.26;   // how far the middle of the lid hangs past its edges
uniform float feather = 0.055;
void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = mix(UV.y, 1.0 - UV.y, flip);
	float edge = amount * (1.0 + curve) - curve * (1.0 - x * x);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(edge + feather, edge - feather, y));
}
"""

## Above everything the realms draw, below nothing. The epilogue sat at 250 and that
## is the number the ending was judged at, so it stays the default.
@export var lid_layer := 250
## Blocks input while shut. A death beat wants this; a purely decorative blink would not.
@export var swallow_input := true

var _lids: Array[ColorRect] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = lid_layer
	for i in 2:
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = (Control.MOUSE_FILTER_STOP if swallow_input
				else Control.MOUSE_FILTER_IGNORE)
		var sh := Shader.new()
		sh.code = LID_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("amount", 0.0)
		m.set_shader_parameter("flip", float(i))
		r.material = m
		add_child(r)
		_lids.append(r)


## Shut. Eases IN, because an eye closing gathers speed.
func close(secs := 2.5) -> void:
	await _lids_to(1.0, secs, Tween.EASE_IN)


## Open. Eases OUT, because an eye opening arrives and settles.
func open(secs := 0.7) -> void:
	await _lids_to(0.0, secs, Tween.EASE_OUT)


## Shut with no animation — for handing a scene over already-closed.
func snap_shut() -> void:
	for r in _lids:
		(r.material as ShaderMaterial).set_shader_parameter("amount", 1.0)


func _lids_to(amount: float, secs: float, ease_: int) -> void:
	var t := create_tween().set_parallel(true)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for r in _lids:
		var m: ShaderMaterial = r.material
		t.tween_method(func(v: float) -> void: m.set_shader_parameter("amount", v),
				m.get_shader_parameter("amount"), amount, secs) \
				.set_trans(Tween.TRANS_SINE).set_ease(ease_)
	await t.finished
