extends CanvasLayer
class_name QuoteCard

## THE QUOTE CARD — the one template every quote in this game is shown on.
##
## It was `QuoteTransition`'s private furniture until 2026-07-31, when a second quote (the
## one between the prologue and Realm 1) needed the identical treatment. Rather than a
## second implementation, the presentation moved here and `QuoteTransition` now drives it.
## Both cards are literally the same object with different words.
##
## What it draws, centred, on whatever is behind it:
##
##     quote lines        the words, faded in as one block — NEVER typed
##     speaker            "— Fear"; the Label is NOT BUILT AT ALL when empty, so a card
##                        with no speaker closes the gap instead of leaving one
##     attribution        "(Written by Silence – Advika Kohli)"
##     indicator          "Press any key to continue", faded in when the driver says so
##
## It owns NO pacing and NO black. The driver decides when the card appears, how long it
## holds, when the prompt shows and when it leaves — because the hold, the skip grace and
## the scene change are a transition's business, not a card's.

const TypewriterScript := preload("res://scripts/Typewriter.gd")

# -------------------------------------------------------------------------- content ----

## One entry per line. Authored `{0.5}` pause tokens are stripped for display — the card
## does not type, but the tokens are harmless if a line is ever moved here from the
## prologue, and stripping them means a stray brace can never reach the screen.
@export var quote_lines: PackedStringArray = PackedStringArray()
## Optional. Empty means the Label is never created.
@export var speaker := ""
@export var attribution := ""

## The curly typographic pair, not the typewriter double-prime — this is Cormorant
## Garamond Italic and a straight " in it reads as a mistake.
const QUOTE_OPEN := "“"
const QUOTE_CLOSE := "”"
## Every card is a quotation, so every card wears the marks (see `_plain_lines`). Left as
## a knob only so a future card that genuinely is not quoting anyone can say so out loud.
@export var quote_marks := true

# ---------------------------------------------------------------------------- looks ----

@export var quote_font: Font
@export_range(8, 120, 1) var quote_size := 64
## Variable fonts draw at Regular unless told otherwise, which is why every italic reads
## heavy by default. >0 pulls the `wght` axis; 0 leaves the font exactly as loaded.
@export_range(0, 900, 10) var quote_weight := 300
@export var attribution_font: Font
@export_range(8, 80, 1) var attribution_size := 20
@export var text_colour := Color("E8C88A")
@export_range(0.0, 1.0, 0.01) var attribution_alpha := 0.55
@export var quote_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## Speaker and attribution share an edge, right-aligned under the block.
@export var credit_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT
@export_range(0, 120, 1) var speaker_gap := 16

@export_range(0.1, 8.0, 0.1) var block_fade_in := 3.0

# ------------------------------------------------------------------------- indicator ----

## Empty draws nothing.
@export var indicator_text := "Press any key to continue"
@export_range(0.0, 1.0, 0.01) var indicator_alpha := 0.55
@export_range(0, 400, 1) var indicator_gap := 120
@export_range(0.1, 4.0, 0.1) var indicator_fade := 1.0

# ----------------------------------------------------------------------------- state ----

var _block: VBoxContainer
var _indicator: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


# ----------------------------------------------------------------------------- build ----

func _build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_block = VBoxContainer.new()
	_block.add_theme_constant_override("separation", 2)
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.modulate.a = 0.0
	centre.add_child(_block)

	for line in _plain_lines():
		var q := _label(String(line), _face(), quote_size, text_colour)
		q.horizontal_alignment = quote_alignment
		_block.add_child(q)

	# THE OPTIONAL SPEAKER. Not hidden — never built. A hidden Label still occupies its
	# separation in a VBoxContainer, which is exactly the gap that should not be left.
	var credits: Array[Label] = []
	if speaker != "":
		var sp := _label(speaker, _face(), int(quote_size * 0.56), text_colour)
		sp.horizontal_alignment = credit_alignment
		credits.append(sp)
	if attribution != "":
		var col := text_colour
		col.a = attribution_alpha
		var book := _label(attribution, attribution_font, attribution_size, col)
		book.horizontal_alignment = credit_alignment
		credits.append(book)

	if not credits.is_empty():
		_block.add_child(_spacer(speaker_gap))
		for c in credits:
			_block.add_child(c)

	if indicator_text != "":
		var icol := text_colour
		icol.a = indicator_alpha
		_indicator = _label(indicator_text, attribution_font, attribution_size, icol)
		_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_indicator.modulate.a = 0.0
		_block.add_child(_spacer(indicator_gap))
		_block.add_child(_indicator)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _label(text: String, font: Font, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	# NO glow, no hue — cream on black. The words carry it.
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The quote face, with the weight axis pulled down if one was asked for. Cormorant
## Garamond Italic at Light (300) is the hairline, high-contrast italic that makes a title
## card feel cinematic instead of bookish.
func _face() -> Font:
	if quote_font == null or quote_weight <= 0:
		return quote_font
	var v := FontVariation.new()
	v.base_font = quote_font
	v.variation_opentype = {"wght": quote_weight}
	return v


## Authored lines with any pause tokens stripped, wrapped in the card's quote marks.
##
## THE MARKS BELONG TO THE CARD, not to whoever writes the words. They were typed into
## the string by hand for Fear's line and then simply forgotten by every card written
## afterwards — the prologue's, Curiosity's on the way into Realm 3, and the last two
## lines of the game all went out bare (Advika: *"the qoute cards need to have "" these
## in them only lvl2s qoute card has that"*). A card that has to remember its own
## punctuation is a card that will keep losing it, so it is applied here, once, to every
## card there is or ever will be: open on the first line, close on the last.
##
## Already-marked text is left alone, so an authored line that carries its own marks (or
## a nested quotation) is never double-wrapped.
func _plain_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for raw in quote_lines:
		out.append(String(TypewriterScript.parse(String(raw)).text))
	if not quote_marks or out.is_empty():
		return out
	var first := String(out[0])
	if not first.begins_with(QUOTE_OPEN):
		out[0] = QUOTE_OPEN + first
	var last := int(out.size() - 1)
	var tail := String(out[last])
	if not tail.ends_with(QUOTE_CLOSE):
		out[last] = tail + QUOTE_CLOSE
	return out


# ---------------------------------------------------------------------------- driving ----

## The words breathe in. Not awaited by the bridge — its hold is measured from the top of
## the card, exactly as it was when this fade lived in QuoteTransition.
func present() -> void:
	var t := _tw()
	t.tween_property(_block, "modulate:a", 1.0, block_fade_in)
	await t.finished


func reveal_indicator() -> void:
	if _indicator == null:
		return
	var t := _tw()
	t.tween_property(_indicator, "modulate:a", 1.0, indicator_fade)
	await t.finished


## Everything to nothing. Does NOT free — the driver is usually about to change scene
## under the card and wants it alive until the far side is up.
func fade_out(duration: float) -> void:
	var t := _tw().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	t.tween_property(_block, "modulate:a", 0.0, duration)
	if _indicator != null:
		# The prompt leaves slightly ahead of the words — it is furniture, and furniture
		# should not be the last thing on a card. (Shipped behaviour of the bridge card.)
		t.parallel().tween_property(_indicator, "modulate:a", 0.0, duration * 0.6)
	await t.finished


## Tweens must run THROUGH a paused tree: the bridge freezes gameplay behind it, and a
## card whose own fades are frozen simply sits there. (Caught in test 2026-07-26.)
func _tw() -> Tween:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t
