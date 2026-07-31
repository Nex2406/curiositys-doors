extends SceneTree

## Headless proof that the inline pause tokens never reach the screen and that the pauses
## they carry stay attached to the character they were authored against after the token
## itself is gone. Run:
##   godot --headless --script tests/test_prologue_parse.gd

const Prologue := preload("res://scripts/Prologue.gd")
## Preloaded by PATH, not by its `class_name`: `--headless --script` runs without the editor
## having registered global classes, so `Typewriter` as a bare identifier is not in scope
## here. Named ...Script so it cannot shadow the global class either.
const TypewriterScript := preload("res://scripts/Typewriter.gd")

var _pass := 0
var _fail := 0


func _init() -> void:
	# The parser moved to Typewriter (2026-07-31) so the prologue and the Realm 1 quote card
	# share one implementation. It is static, so no instance is needed to exercise it — but
	# `Prologue.STANZAS` is still read below, because the authored script is the thing most
	# likely to grow a typo, and this is the only test that ever looks at it.
	var p := TypewriterScript

	# A token on the LAST character of a line — the hardest index to get right, and the one
	# an off-by-one silently swallows. (Authored in the first draft's stanza V; the twenty-
	# second rewrite dropped that stanza, so the case is pinned here as a literal instead of
	# borrowed from STANZAS, where it would vanish the next time the script is rewritten.)
	var v4: Dictionary = p.parse("You’ll open all of them—{0.6}")
	_eq(String(v4.text), "You’ll open all of them—", "V.4 clean string")
	_eq(String(v4.text).length(), 24, "V.4 length")
	_eq(v4.pauses, {23: 0.6}, "V.4 pause on the em-dash, index 23")
	_is_true(not String(v4.text).contains("{") and not String(v4.text).contains("}"),
			"V.4 carries no braces")

	# Mid-line token: the pause belongs to the character BEFORE it, not after.
	var i1: Dictionary = p.parse("Oh{0.5}—look.")
	_eq(String(i1.text), "Oh—look.", "I.1 clean string")
	_eq(i1.pauses, {1: 0.5}, "I.1 pause on the 'h', not the em-dash")

	# Two tokens in one line: indices must survive the first strip.
	var two: Dictionary = p.parse("a{0.2}bc{0.3}d")
	_eq(String(two.text), "abcd", "two-token clean string")
	_eq(two.pauses, {0: 0.2, 2: 0.3}, "two-token indices")

	# A token before any character is a pause before the line, keyed -1.
	var pre: Dictionary = p.parse("{0.4}word")
	_eq(String(pre.text), "word", "leading token stripped")
	_eq(pre.pauses, {-1: 0.4}, "leading token keyed -1")

	# Malformed and unclosed tokens are stripped, never printed.
	var bad: Dictionary = p.parse("no{oops}braces{")
	_eq(String(bad.text), "nobraces", "malformed token stripped")
	_eq(bad.pauses, {}, "malformed token buys no time")

	# Every authored line round-trips without a brace reaching the display string.
	for s in Prologue.STANZAS:
		for line in s.lines:
			var r: Dictionary = p.parse(String(line))
			_is_true(not String(r.text).contains("{"), "no stray brace: %s" % line)

	# Realm 1's opening card shares this parser, and its one authored token sits on a COMMA
	# rather than an em-dash — the comma's own 0.12 stacks on top of the 0.5, and an
	# off-by-one here would attach the half-second to the space instead. Held as a literal
	# rather than imported from Realm1PlatformTest.gd, which touches autoloads that
	# `--headless --script` does not register.
	var card: Dictionary = p.parse("And before I could argue,{0.5}")
	_eq(String(card.text), "And before I could argue,", "card line 1 clean string")
	_eq(card.pauses, {24: 0.5}, "card pause on the comma, index 24")

	print("prologue parse: %d/%d pass" % [_pass, _pass + _fail])
	quit(1 if _fail > 0 else 0)


func _eq(got: Variant, want: Variant, what: String) -> void:
	_is_true(got == want, "%s (got %s, want %s)" % [what, got, want])


func _is_true(ok: bool, what: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		printerr("FAIL: %s" % what)
