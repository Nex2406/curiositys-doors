extends Node2D

## THE LANTERN, ON ITS OWN — the health HUD with nothing else to argue with it.
##
## Advika's law: a feature has to be testable directly, one at a time, booting
## straight into it. So this is not "play Realm 2 until something hits you" —
## it is every flame state standing in a row, at the size they actually render,
## over the realm's own backdrop value.
##
## LIVE KEYS (this rig exists to be argued with):
##   1..5   set the live lantern to the middle of each band
##   H      heal a little  (watch the POUR — droplets, then the flame flares)
##   J      damage a little (watch the flame get knocked FLAT, brass flash)
##   K      hard hit — 25 at once
##   R      reload
##
## LANT_SHOT=<path> captures the row and quits.

const BAND_HP: Array[int] = [100, 63, 38, 17, 4]
const BAND_NAME: Array[String] = ["100-76 full", "75-51 high", "50-26 mid",
		"25-9 low", "below 8 guttering"]

## the live one, driven by the keys
var _live: LanternHUD
var _live_hp := 100
var _row: Array[LanternHUD] = []


func _ready() -> void:
	# Realm 2's own murk, so the glow is judged against the value it ships on
	RenderingServer.set_default_clear_color(Color(0.055, 0.04, 0.10))
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)

	var head := Label.new()
	head.text = "LANTERN HUD — her health, as her lantern.   1..5 bands · H heal · J hit · K hard hit · R reload"
	head.position = Vector2(28, 16)
	head.add_theme_color_override("font_color", Color(0.78, 0.73, 0.92, 0.75))
	ui.add_child(head)

	# ---- the row: every state at once, at true size ----
	for i in BAND_HP.size():
		var l := LanternHUD.new()
		# they are laid out by hand here, so the corner margin is irrelevant
		l.hud_margin = 0.0
		ui.add_child(l)
		l.position = Vector2(60.0 + float(i) * 190.0, 90.0)
		l.set_health(BAND_HP[i], 100)
		_row.append(l)
		var cap := Label.new()
		cap.text = "%d%%\n%s" % [BAND_HP[i], BAND_NAME[i]]
		# well clear of the lantern's own "Health" line, which lands ~y 215
		cap.position = Vector2(52.0 + float(i) * 190.0, 250.0)
		cap.add_theme_font_size_override("font_size", 13)
		cap.add_theme_color_override("font_color", Color(0.70, 0.66, 0.82, 0.55))
		ui.add_child(cap)

	# ---- the live one, larger, for the pour and the knock-flat ----
	var live_cap := Label.new()
	live_cap.text = "LIVE — heal and hit this one"
	live_cap.position = Vector2(60, 300)
	live_cap.add_theme_color_override("font_color", Color(0.78, 0.73, 0.92, 0.6))
	ui.add_child(live_cap)
	_live = LanternHUD.new()
	_live.hud_margin = 0.0
	_live.lantern_size = Vector2(168.0, 220.0)   # 2x, so the oil line is legible
	ui.add_child(_live)
	_live.position = Vector2(60, 330)
	_live.set_health(_live_hp, 100)

	_readout = Label.new()
	_readout.position = Vector2(260, 400)
	_readout.add_theme_font_size_override("font_size", 22)
	_readout.add_theme_color_override("font_color", Color(0.85, 0.80, 0.95, 0.8))
	ui.add_child(_readout)
	_update_readout()

	if OS.get_environment("LANT_SHOT") != "":
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(
				OS.get_environment("LANT_SHOT"))
		get_tree().quit()


var _readout: Label

func _update_readout() -> void:
	_readout.text = "%d / 100" % _live_hp


func _set_live(hp: int) -> void:
	_live_hp = clampi(hp, 0, 100)
	_live.set_health(_live_hp, 100)
	_update_readout()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_1: _set_live(BAND_HP[0])
		KEY_2: _set_live(BAND_HP[1])
		KEY_3: _set_live(BAND_HP[2])
		KEY_4: _set_live(BAND_HP[3])
		KEY_5: _set_live(BAND_HP[4])
		KEY_H: _set_live(_live_hp + 12)
		KEY_J: _set_live(_live_hp - 8)
		KEY_K: _set_live(_live_hp - 25)
		KEY_R: get_tree().reload_current_scene()
