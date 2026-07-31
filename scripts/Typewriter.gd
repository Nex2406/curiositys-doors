extends RefCounted
class_name Typewriter

## ONE typewriter, for every screen in the game that types.
##
## Lifted out of `Prologue.gd` (2026-07-31) when the Realm 1 quote card needed the same
## behaviour — the float accumulator, the punctuation pauses, and the inline `{0.5}` pause
## tokens. Two copies of this would have drifted within a session: the parser is fiddly
## enough that the second copy would have been "close enough" and then subtly not.
##
## It is deliberately NOT a Node. It owns no label, adds nothing to the tree, and draws
## nothing. The caller owns the RichTextLabel and asks this object one question per frame —
## "how many characters are visible now?" — which is what lets the prologue drive a
## centred block that reflows and the quote card drive a static one, off the same code.
##
## THE FLOAT ACCUMULATOR is the whole reason this exists as state rather than a tween. At
## 26 cps a 60fps frame is worth 0.43 characters; an int cursor would round that to 0 and
## type nothing, or to 1 and type at 60 cps. `_accum` keeps the fraction, so the authored
## speed is the speed you get on any framerate.
##
## Callers: `scripts/Prologue.gd`, `scripts/QuoteCard.gd`.

## Punctuation buys its own breath, so authored tokens only have to supply the hesitations
## the punctuation cannot explain. Authored and automatic pauses STACK — that is how the
## longest silences in the prologue are built.
##
## Em-dash is U+2014 and ellipsis is the single character U+2026. This table keys off those
## exact code points, so an ASCII substitution in authored text silently costs the line its
## longest hesitation.
const PUNCT_PAUSE: Dictionary = {
	",": 0.12, ";": 0.12, ":": 0.12,
	".": 0.34, "?": 0.34, "!": 0.34,
	"—": 0.42,   # U+2014
	"…": 0.5,    # U+2026
}

var cps := 26.0

var _display := ""              # the accumulated plain text, tokens already stripped
var _pauses: Dictionary = {}    # absolute index into _display -> extra seconds owed after it
var _accum := 0.0               # fractional character cursor
var _pause_timer := 0.0
var _typing := false


## The clean text currently on screen, tokens stripped. The caller writes this into its
## label; it never changes except when a line is appended.
func display() -> String:
	return _display


func visible_count() -> int:
	return int(_accum)


func is_typing() -> bool:
	return _typing


## Back to an empty screen. Called between stanzas.
func reset() -> void:
	_display = ""
	_pauses.clear()
	_accum = 0.0
	_pause_timer = 0.0
	_typing = false


## Append one authored line to the block. Everything already typed stays exactly where it
## is and does not re-animate — the cursor simply keeps counting up through the longer
## string. Returns the new display text.
##
## A newline costs no typing time: it is a layout fact, not a keystroke, so the cursor is
## jumped past it rather than made to type it.
func append_line(raw: String, needs_newline: bool) -> String:
	var parsed := parse(raw)
	var base := _display.length()
	if needs_newline:
		_display += "\n"
		base += 1
	_display += String(parsed.text)
	_accum = maxf(_accum, float(base))

	for local_idx in parsed.pauses:
		if int(local_idx) >= 0:
			_pauses[base + int(local_idx)] = parsed.pauses[local_idx]
	# A token authored before the first character of a line is a pause BEFORE the line.
	if parsed.pauses.has(-1):
		_pause_timer += float(parsed.pauses[-1])

	_typing = not String(parsed.text).is_empty()
	return _display


## Advance one frame. Returns the half-open range of character indices that landed THIS
## frame, as Vector2i(before, after) — empty when the cursor is paused or finished. The
## caller iterates it to play a keystroke sound per character, or ignores it entirely.
##
## Nothing in here can reveal a line in one go: the cursor moves by `delta * cps` and by
## nothing else, which is what makes "it only types" a structural guarantee rather than a
## promise. (Prologue had a skip that snapped a line to full, and a latched keypress made
## it fire on lines the player never touched.)
func tick(delta: float) -> Vector2i:
	if not _typing:
		return Vector2i.ZERO
	if _pause_timer > 0.0:
		_pause_timer = maxf(0.0, _pause_timer - delta)
		return Vector2i.ZERO

	var before := int(_accum)
	_accum = minf(_accum + delta * cps, float(_display.length()))
	var after := int(_accum)
	if after == before:
		return Vector2i.ZERO
	# Every character that just landed pays its own debt, authored plus automatic.
	for i in range(before, after):
		_pause_timer += pause_after(i)
	if after >= _display.length():
		_typing = false
	return Vector2i(before, after)


## Reveal everything immediately and clear any debt. This is the QUOTE CARD's skip — a
## card the player has already read should not be held hostage. The prologue does NOT use
## it; see the note on `tick`.
func finish() -> void:
	_accum = float(_display.length())
	_pause_timer = 0.0
	_typing = false


## Seconds owed after the character at `idx`, authored plus automatic.
func pause_after(idx: int) -> float:
	var total: float = _pauses.get(idx, 0.0)
	var c := _display[idx]
	if PUNCT_PAUSE.has(c):
		total += float(PUNCT_PAUSE[c])
	return total


## One left-to-right pass produces both halves at once: the clean string that goes on
## screen, and a map from clean-string index to the seconds owed after that character.
## Doing it in one pass is the whole trick — strip first and the indices no longer point at
## the characters they were authored against.
##
## Returns {"text": String, "pauses": Dictionary}. Index -1 means "before the line began".
## Static so tests can exercise it without building a typewriter.
static func parse(raw: String) -> Dictionary:
	var clean := ""
	var pauses := {}
	var i := 0
	while i < raw.length():
		var c := raw[i]
		if c != "{":
			clean += c
			i += 1
			continue
		var close := raw.find("}", i + 1)
		if close == -1:
			push_warning("[Typewriter] unclosed pause token in %s — brace dropped" % raw)
			i += 1   # eat the brace, keep the text; never print a brace
			continue
		var body := raw.substr(i + 1, close - i - 1)
		if body.is_valid_float():
			var key := clean.length() - 1   # attaches to the last character emitted
			pauses[key] = float(pauses.get(key, 0.0)) + float(body)
		else:
			push_warning("[Typewriter] malformed pause token {%s} in %s — stripped" % [body, raw])
		i = close + 1
	return {"text": clean, "pauses": pauses}
