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


func _input(event: InputEvent) -> void:
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
