extends Node

## Autoload "ScreenMode". One job: let the player throw the game fullscreen from
## anywhere (Advika 2026-07-27 — in a browser tab the chrome eats the top of the
## frame and the cave stops feeling like a place you are inside).
##
## F or F11 toggles; ESC leaves fullscreen without touching anything else, so the
## key still means "back" inside the realms. On the web this only works because a
## key press IS the user gesture browsers require for fullscreen — which is why it
## is a hotkey and not something the game does to you on load.

const KEYS := [KEY_F, KEY_F11]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# DEFAULT TO FULLSCREEN (Advika 2026-07-29). On desktop that is simply the boot state.
	# On the web it CANNOT be: browsers only grant fullscreen inside a user gesture, and a
	# page that tries on load is refused — so there the first keypress or click takes it,
	# once, and the hotkey stays for afterwards.
	if OS.has_feature("web"):
		return
	# ...and a run that asked for a specific window size means to have it — that is how the
	# screenshot harnesses run, and they are useless framed to the monitor instead.
	if OS.get_cmdline_args().has("--resolution"):
		return
	set_fullscreen(true)


## On web, take the first real interaction as the gesture that grants fullscreen. Only once
## — if the player leaves fullscreen deliberately, we do not drag them back in.
var _web_claimed := false


func _claim_web_fullscreen(event: InputEvent) -> void:
	if _web_claimed or not OS.has_feature("web"):
		return
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.is_echo()
	var clicked: bool = event is InputEventMouseButton and event.pressed
	if not (pressed_key or clicked):
		return
	_web_claimed = true
	if not is_fullscreen():
		set_fullscreen(true)


func _input(event: InputEvent) -> void:
	_claim_web_fullscreen(event)
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode in KEYS:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and is_fullscreen():
		set_fullscreen(false)   # leave fullscreen; ESC keeps its in-game meaning


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on
			else DisplayServer.WINDOW_MODE_WINDOWED)


func toggle() -> void:
	set_fullscreen(not is_fullscreen())
