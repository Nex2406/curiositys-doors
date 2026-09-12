extends CanvasLayer

## THE CREDITS ROLL — what plays after "The End{1.4}…{0.9}?" and before the menu.
##
## `Realm3Epilogue` ends the game with the eye shut and stanza VII spoken. This
## takes the screen from there: the roll comes up out of the black the eye is
## already holding, so there is no cut and no fade between the last word and the
## first name. When it finishes it emits `finished` and hands the screen back —
## the epilogue still owns the eye and still opens it on the menu.
##
## THE CONTENT IS A MIRROR OF `CREDITS.md`, curated for a player rather than an
## admissions reader: names and roles, no licence text, no file paths. When an
## asset lands and CREDITS.md gains a row, this gains a line. The portfolio
## formats the colleges want are a different shape again — see CREDITS.md.
##
## Typography is the game's own: Cinzel caps with open tracking for the role a
## person played, EB Garamond for the person. Same gold as the quote card, the
## prologue and the boot gate — every screen that speaks to the player directly
## speaks in one colour.
##
## Harness:
##   godot scenes/UI/Credits.tscn      boot the roll on its own, from the top
##   CREDITS_SPEED=<x>                 multiply the scroll (4 to review it fast)
##   CREDITS_SHOT=<path>               save one frame and quit
##   CREDITS_AT=<seconds>              when to take it (default 3.0)
##
## Any key skips, as it should — a player who has read it once must not be held
## through it again.

signal finished

const CINZEL := "res://assets/fonts/cinzel.ttf"
const GARAMOND := "res://assets/fonts/eb_garamond.ttf"
const GARAMOND_ITALIC := "res://assets/fonts/eb_garamond_italic.ttf"

const CREAM := Color(0.910, 0.784, 0.541)      # #E8C88A — the quote card's gold
const BLACK := Color(0.02, 0.019, 0.026)       # the boot gate's black

## The track the game opens on. The roll ends by handing the screen to the menu,
## so closing on the menu's own music means the player is already home when the
## eye opens — no cue lands on the transition.
##
## Inside the real ending this is usually a no-op: `Realm3Epilogue` brings the
## same track up under stanza VII, and `play_ambient` returns early when a track
## of the same name is already playing. It matters when the roll is booted on its
## own, which would otherwise run in silence.
const MENU_TRACK := preload("res://assets/audio/menu_starfall_dreams.ogg")
const MUSIC_FADE := 4.0

## Where the roll goes when it is booted on its own. Inside the real ending the
## epilogue owns this handoff instead — see `_end()`.
const MENU_SCENE := "res://scenes/UI/MainMenu.tscn"

## px/sec. Slow enough to read a line without chasing it, and in the art
## direction's register — nothing in this game moves quickly. 46 -> 78 on
## Advika's call: the first pass held every name on screen long enough to read
## it twice, which is how a roll starts feeling like a wait.
@export var scroll_speed := 78.0
## Blank screen before the first line rises, so the roll is not already running
## when the player looks up from the ending.
@export var lead_in := 1.6
## Held on black after the last line clears the top, before `finished`. Five
## seconds on Advika's call — the roll should not snap back to the menu the
## instant the final name leaves the screen; the black is part of the ending.
@export var tail := 5.0

## One entry per block, in the order it rises.
##
##   title    the game, once, at the top
##   section  a department heading — the roll's only structure
##   role     the Cinzel line naming the work (may be empty)
##   names    the Garamond lines naming who did it
##   note     a smaller italic aside under the name — this is where the roll
##            gets specific, and specific is the whole point of a credit
##
## Realm Two is listed by number on purpose: its name in `docs/realms/realm2.md`
## is still marked a working name, and a working name does not belong in a roll.
const ROLL: Array = [
	{"title": "CURIOSITY'S DOORS"},

	{"role": "A GAME BY", "names": ["Advika Kohli"]},

	{"section": "DESIGN"},
	{"role": "GAME DESIGN", "names": ["Advika Kohli"]},
	{"role": "CREATIVE DIRECTION", "names": ["Advika Kohli"]},
	{"role": "ART DIRECTION", "names": ["Advika Kohli"]},
	{"role": "LEVEL DESIGN", "names": ["Advika Kohli"],
		"note": "Realm One · The Crimson Hollow\nRealm Two\nRealm Three · The Bloom"},
	{"role": "ENCOUNTER & PUZZLE DESIGN", "names": ["Advika Kohli"]},
	{"role": "PLAYTESTING & QA", "names": ["Advika Kohli"]},

	{"section": "STORY"},
	{"role": "STORY & MYTHOLOGY", "names": ["Advika Kohli"],
		"note": "from the novel Written by Silence"},
	{"role": "CURIOSITY'S VOICE", "names": ["Advika Kohli"]},
	{"role": "THE PROLOGUE & THE EPILOGUE", "names": ["Advika Kohli"]},

	{"section": "ORIGINAL ART"},
	{"role": "CHARACTER ART", "names": ["Advika Kohli"],
		"note": "Curiosity — idle, walk, run, jump, combat, dash"},
	{"role": "THE MIRROR", "names": ["Advika Kohli"],
		"note": "seventy-six frames, drawn as Curiosity's reflection"},
	{"role": "CREATURE ART", "names": ["Advika Kohli"],
		"note": "The Golems · The Void Moth · The Rune Orb"},
	{"role": "OBJECT ART", "names": ["Advika Kohli"],
		"note": "Jade · The Hourglass · The Tarot Card"},

	{"section": "PROGRAMMING"},
	{"role": "", "names": ["Claude (Anthropic)"],
		"note": "directed by Advika Kohli, via Claude Code"},
	{"role": "SYSTEMS", "names": [],
		"note": "Dynamic 2D lighting · Parallax · Particles\nCombat and boss states · Save and load\nShaders · Scene transitions · Dialogue"},
	{"role": "TOOLING & PIPELINE", "names": [],
		"note": "Asset slicing · Palette baking · Screenshot harness\nContinuous deployment to the web"},

	{"section": "ENVIRONMENT ART"},
	{"role": "", "names": ["Szadi art"],
		"note": "Cave tilemaps and backgrounds — Realm One"},
	{"role": "", "names": ["Maaot"],
		"note": "Cave assets — Realm One\nMossy tileset — Realms Two and Three\nBlueWizard animations — Realm Two"},

	{"section": "MUSIC"},
	{"role": "", "names": ["AlkaKrab"],
		"note": "Starfall Dreams — the menu\nEchoed Blades — Realm One\nMoonlight — Realm Two\nDivine Echo — Realm Three\nWhispers Beyond — the mirror"},

	{"section": "SOUND"},
	{"role": "", "names": ["Olex Mazur"], "note": "Card Game SFX"},
	{"role": "", "names": ["Generated in-engine"],
		"note": "Ambience · The text-box tick"},

	{"section": "TYPE"},
	{"role": "", "names": ["Cinzel · EB Garamond", "Cormorant Garamond · Cormorant Infant"],
		"note": "SIL Open Font License 1.1"},

	{"section": "BUILT WITH"},
	{"role": "", "names": ["Godot 4.6"],
		"note": "GDScript · Forward+ renderer\nHTML5 and WebAssembly · GitHub Actions"},
]

var _col: VBoxContainer = null
var _done := false
var _skipped := false


func _ready() -> void:
	# above everything, including the epilogue's lids at 250 — the roll is the
	# screen now, and the eye stays shut behind it
	layer = 260
	process_mode = Node.PROCESS_MODE_ALWAYS

	var black := ColorRect.new()
	black.color = BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	_col = VBoxContainer.new()
	_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_col.add_theme_constant_override("separation", 0)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# full viewport width so every child centres on the screen's own axis
	_col.size.x = 1920.0
	_col.position = Vector2(0.0, 1080.0)
	add_child(_col)

	_build()
	AudioManager.play_ambient(MENU_TRACK, "menu", MUSIC_FADE)

	if OS.get_environment("CREDITS_SHOT") != "":
		_shot(OS.get_environment("CREDITS_SHOT"))
		return
	_run()


func _build() -> void:
	for block: Dictionary in ROLL:
		if block.has("title"):
			_spacer(110.0)
			_line(block["title"], CINZEL, 78, CREAM, 16.0)
			_spacer(150.0)
			continue
		# A department heading — brighter and wider-tracked than the roles under
		# it, with air above but not below, so it reads as belonging to the block
		# that follows rather than floating between two.
		if block.has("section"):
			_spacer(66.0)
			_line(block["section"], CINZEL, 32, Color(CREAM, 0.88), 14.0)
			_spacer(34.0)
			continue
		if block.get("role", "") != "":
			# the role is the quiet half — it names the work, the name below is
			# the point, so it sits a step down in both size and value
			_line(block["role"], CINZEL, 25, Color(CREAM, 0.60), 8.0)
			_spacer(10.0)
		for n: String in block.get("names", []):
			_line(n, GARAMOND, 44, CREAM, 0.0)
		if block.get("note", "") != "":
			_spacer(6.0)
			_line(block["note"], GARAMOND_ITALIC, 27, Color(CREAM, 0.55), 0.0)
		# 118 -> 54: at the old gap the roll spent more of the screen on nothing
		# than on names, and each block arrived alone with no sense of a list
		_spacer(54.0)
	_spacer(140.0)


func _line(text: String, font_path: String, size: int, col: Color, tracking: float) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := load(font_path)
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("line_spacing", 10)
	if tracking > 0.0:
		# Godot has no letter-spacing constant on Label; the Cinzel caps get it
		# the way the boot gate does — spaces between characters would break
		# word wrapping, so this uses the font's own extra spacing instead
		var fv := FontVariation.new()
		fv.base_font = f
		fv.spacing_glyph = int(tracking)
		l.add_theme_font_override("font", fv)
	_col.add_child(l)


func _spacer(h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(s)


func _run() -> void:
	await _wait(lead_in)
	# the column's real height is only known once the labels have been laid out
	await get_tree().process_frame
	var travel: float = _col.size.y + 1080.0
	var speed := scroll_speed
	var mult := float(OS.get_environment("CREDITS_SPEED"))
	if mult > 0.01:
		speed *= mult
	var secs: float = travel / max(speed, 1.0)

	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_col, "position:y", -_col.size.y, secs).set_trans(Tween.TRANS_LINEAR)
	await t.finished
	if _skipped:
		return
	await _wait(tail)
	_end()


## One frame at CREDITS_AT seconds, for checking type and spacing without
## sitting through the roll.
func _shot(path: String) -> void:
	_run()
	var at := float(OS.get_environment("CREDITS_AT"))
	await _wait(at if at > 0.1 else 3.0)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _done or _skipped:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	_skipped = true
	get_viewport().set_input_as_handled()
	_end()


func _end() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	# BOOTED ON ITS OWN, the roll owns the screen and nothing is waiting on
	# `finished` — so it closes the loop itself and goes back to the start. In the
	# real ending it is parented to the root while the epilogue is the current
	# scene, so this is false and the epilogue's own handoff (menu behind the shut
	# eye, then the eye opens) still runs exactly as it did.
	#
	# The music does not restart across the change: `AudioManager` is an autoload
	# and the menu asks for the same track it has already been playing.
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(MENU_SCENE)
	queue_free()


## timers must not stop with the tree — the ending runs with it paused elsewhere
func _wait(secs: float) -> void:
	var t := get_tree().create_timer(secs, true, false, true)
	await t.timeout
