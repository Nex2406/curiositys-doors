extends CanvasLayer
class_name SettingsPanel

## Settings — volume for now, in the menu's own visual language (cream on dark, hairline
## rules, Cinzel caps). Built as its own scene rather than inside MainMenu so the pause
## menu can open the same panel later instead of growing a second one that drifts.
##
##   up / down    pick a slider
##   left / right adjust 5%   (shift: 1%)
##   enter, esc   close
##   drag / click on a bar also sets it
##
## Values persist through SaveManager flags and are applied to the audio buses. Call the
## static `apply_saved()` on boot so a saved mix is in force before anything plays.

signal closed

const CREAM := Color(0.918, 0.902, 0.855)
const DIM := Color(0.918, 0.902, 0.855, 0.45)
const FONT := "res://assets/fonts/cinzel.ttf"

## flag name, label, bus name. Master first — it is the one people reach for.
const CHANNELS := [
	{"flag": "vol_master", "label": "MASTER", "bus": "Master"},
	{"flag": "vol_music", "label": "MUSIC", "bus": "Ambient"},
	{"flag": "vol_sfx", "label": "SOUND", "bus": "SFX"},
]

## Silence is a real 0, not -80dB-and-still-audible: below this the bus is muted outright.
const MIN_DB := -40.0

var _rows: Array[Dictionary] = []     # {name: Label, fill: ColorRect, track: Control, value: float}
var _sel := 0
var _panel: Control


static func volume_of(flag: String) -> float:
	return clampf(float(SaveManager.get_flag(flag, 0.8)), 0.0, 1.0)


## Linear 0..1 to decibels, with 0 meaning silent. A straight linear-to-dB map makes the
## top half of the slider do almost nothing, so this uses the audio-standard curve.
static func to_db(v: float) -> float:
	if v <= 0.001:
		return -80.0
	return linear_to_db(v)


## Push the saved mix onto the buses. Safe to call before any of them exist — a missing bus
## is simply skipped, and AudioManager re-applies nothing, so boot order does not matter.
static func apply_saved() -> void:
	for ch in CHANNELS:
		var idx: int = AudioServer.get_bus_index(String(ch.bus))
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, to_db(volume_of(String(ch.flag))))


func _ready() -> void:
	layer = 80
	_build()
	apply_saved()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.028, 0.04, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# A CenterContainer, not PRESET_CENTER: the preset puts the box's top-left CORNER at the
	# middle of the screen, so the panel hangs down and to the right of centre instead of
	# sitting on it. This centres the box itself, at any window size.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.custom_minimum_size = Vector2(520, 0)
	centre.add_child(box)

	box.add_child(_text("SETTINGS", 30, CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_rule())

	for ch in CHANNELS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		box.add_child(row)

		var head := HBoxContainer.new()
		row.add_child(head)
		var name_label := _text(String(ch.label), 19, DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var pct := _text("", 19, DIM)
		head.add_child(pct)

		# the bar is two rects: an unlit track and the lit part over it, same vocabulary as
		# the menu's selection hairline rather than a themed Slider that would look foreign
		var track := Control.new()
		track.custom_minimum_size = Vector2(0, 3)
		track.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(track)
		var under := ColorRect.new()
		under.color = Color(CREAM, 0.16)
		under.set_anchors_preset(Control.PRESET_FULL_RECT)
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(under)
		var fill := ColorRect.new()
		fill.color = Color(CREAM, 0.75)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)

		var idx := _rows.size()
		track.gui_input.connect(_on_track_input.bind(idx))
		# the fill is sized from the track's width, which is zero until the container has
		# laid out — without this the bars come up empty and only fill on first keypress
		track.resized.connect(_paint)
		_rows.append({"name": name_label, "pct": pct, "fill": fill, "track": track,
				"flag": String(ch.flag), "bus": String(ch.bus),
				"value": volume_of(String(ch.flag))})

	box.add_child(_rule())
	box.add_child(_text("↑↓ pick · ←→ adjust · enter to close", 15, DIM,
			HORIZONTAL_ALIGNMENT_CENTER))
	_paint()


func _text(s: String, size: int, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = s
	var f := FontVariation.new()
	f.base_font = load(FONT)
	f.spacing_glyph = 6
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = align
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(CREAM, 0.22)
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _paint() -> void:
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var lit: bool = i == _sel
		(r.name as Label).add_theme_color_override("font_color", CREAM if lit else DIM)
		(r.pct as Label).add_theme_color_override("font_color", CREAM if lit else DIM)
		(r.pct as Label).text = "%3d%%" % int(round(float(r.value) * 100.0))
		var track: Control = r.track
		var fill: ColorRect = r.fill
		fill.position = Vector2.ZERO
		fill.size = Vector2(track.size.x * float(r.value), track.size.y)
		fill.color = Color(CREAM, 0.85 if lit else 0.45)


## The same tick the menu uses for moving between entries — one vocabulary, and it doubles
## as the audible proof that a volume change took effect.
func _tick() -> void:
	AudioManager.play_sfx(load("res://assets/audio/ui/menu_move.wav"), -23.0)


func _set_value(i: int, v: float) -> void:
	if i < 0 or i >= _rows.size():
		return
	var r: Dictionary = _rows[i]
	r.value = clampf(v, 0.0, 1.0)
	SaveManager.set_flag(String(r.flag), r.value)
	var bus: int = AudioServer.get_bus_index(String(r.bus))
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, to_db(r.value))
	_paint()


func _on_track_input(event: InputEvent, i: int) -> void:
	var track: Control = _rows[i].track
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	var dragging: bool = mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) or dragging:
		_sel = i
		_set_value(i, event.position.x / maxf(1.0, track.size.x))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var step: float = 0.01 if key.shift_pressed else 0.05
	match key.keycode:
		KEY_DOWN, KEY_S:
			_sel = posmod(_sel + 1, _rows.size())
			_paint()
			_tick()
		KEY_UP, KEY_W:
			_sel = posmod(_sel - 1, _rows.size())
			_paint()
			_tick()
		KEY_RIGHT, KEY_D:
			_set_value(_sel, float(_rows[_sel].value) + step)
			_tick()
		KEY_LEFT, KEY_A:
			_set_value(_sel, float(_rows[_sel].value) - step)
			_tick()
		KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE:
			closed.emit()
			queue_free()
	get_viewport().set_input_as_handled()
