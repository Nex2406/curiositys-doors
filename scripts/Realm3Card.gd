extends RefCounted
class_name Realm3Card

## Realm 3's TWO cards — the single source of truth for their content and colour,
## exactly as `Realm1Card` is for the cave.
##
## Same painted `TarotReading` as Realms 1 and 2 (Advika: *"same card framework
## as last two realms, just change the colour palette and content"*): the frame,
## the flip, the typewriter and the dismissal are byte-for-byte theirs. Only the
## palette and the words are Realm 3's — teal instead of the cave's warm brown,
## because this realm has spent its whole length being teal.
##
## `open()` shows five seconds after she arrives. `mirror()` shows one second
## after the thing in the mirror stands up, once the forest has already gone
## dark — the level explains what she is fighting only after she has seen it.

## NOTHING ELSE IS TOUCHED (Advika: *"the cards spawn and typing sound will
## remain the same, along with the press any key to continue text at the bottom
## — same font, same colour of the font"*). These builders set content and the
## same four colour fields `Realm1Card` sets, and not one thing more: the flip,
## the typewriter, its tick, and the prompt at the foot are all `TarotReading`'s
## and are inherited by leaving them alone.
const TEAL_INK := Color(1.02, 1.18, 1.10)      # lift the frame's lines cool
const SPORE := "res://assets/realms/realm3_fungal/mushroomglow17.png"
## baked from the project's own EB Garamond (`tools/` has no glyph pipeline and
## `Font.draw_char` needs a live canvas a static builder does not have)
const QMARK := "res://assets/realms/realm3_fungal/question_mark.png"


## THE OPENING CARD — a mushroom and a question mark, and nothing else (Advika:
## *"only the mushroom and a question mark as images"*). The realm's whole first
## act is "there are lights in this wood and you do not know why"; naming the
## six, or the thing past them, would spend the only surprise it has.
static func open() -> TarotReading:
	var card := TarotReading.new()
	card.numeral = "III"
	card.card_title = "THE SPORE"
	card.portrait = load(SPORE)
	card.second_art = load(QMARK)
	card.verses = [
		"Six lights are burning in this wood",
		"Put them out — J",
		"They notice; what falls from the roof is theirs",
		"Dash what you cannot outrun — K",
		"Your lantern is your life. Watch it",
	]
	_palette(card)
	card.foot_art_scale = 0.62
	card.verse_scale = 1.35
	return card


## THE MIRROR CARD — shown once the colour has gone and it is standing there.
##
## Advika: *"that card will basically tell the player oh ur fighting urself, and
## its gonna say how curiosity is its biggest enemy."* So the portrait is HER
## OWN idle frame, tinted cold: the card does not describe the boss, it hands
## her back her own picture. Curiosity is genderless — they/them throughout, and
## the verses avoid the pronoun entirely so the line lands as address, not
## description.
static func mirror() -> TarotReading:
	var card := TarotReading.new()
	card.numeral = "?"
	card.card_title = "THE MIRROR"
	card.portrait = load("res://assets/player/curiosity/idle/idle1.png")
	card.second_art = load(QMARK)
	card.verses = [
		"It has been watching how you fight",
		"Everything you did well, it does back",
		"It cannot be out-fought, only out-changed",
		"Curiosity opened every door in this place",
		"This is the one it should not have",
	]
	_palette(card)
	# colder and emptier than the opening card: the forest is drained behind it
	card.overlay_color = Color(0.015, 0.030, 0.030, 0.93)
	card.body_color = Color(0.07, 0.15, 0.16, 0.24)
	card.art_tint = Color(0.52, 0.62, 0.62)
	card.foot_art_scale = 0.52
	card.verse_scale = 1.30
	return card


## the palette both cards share — the cave card recoloured from warm brown to
## this realm's teal, nothing else touched
static func _palette(card: TarotReading) -> void:
	card.overlay_color = Color(0.012, 0.032, 0.030, 0.90)
	card.body_color = Color(0.08, 0.20, 0.19, 0.22)
	card.face_tint = TEAL_INK
	card.art_tint = Color(0.74, 0.80, 0.78)
