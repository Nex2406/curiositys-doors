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
	# NOTHING is claimed at boot any more. `scenes/UI/BootGate.tscn` asks the player for
	# fullscreen and waits, which is the only way the WEB can ever get there (browsers grant
	# it inside a user gesture and refuse a page that asks on load) — and once a gate exists
	# for the web, the desktop using the same one means one flow instead of two. Auto-claiming
	# on desktop was also actively wrong with a gate in front: F would toggle it back OFF.


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
	# Belt and braces on the web: ask the DOM directly as well. The engine's request leaves a
	# frame after the browser event, which a browser is entitled to refuse; calling
	# requestFullscreen ourselves while the gesture is still fresh is the form that lands.
	if on and OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function () {
				var el = document.querySelector('canvas') || document.documentElement;
				if (!document.fullscreenElement && el.requestFullscreen) {
					el.requestFullscreen().catch(function () {});
				}
			})();
		""", true)


func toggle() -> void:
	set_fullscreen(not is_fullscreen())
