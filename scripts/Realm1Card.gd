extends RefCounted
class_name Realm1Card

## Realm 1's instructions card — the single source of truth for its content and
## colour. The level shows it 3s after Curiosity arrives; `tools/TarotPreview.tscn`
## loops it for review and `tools/TarotCompare.tscn` stands it next to Realm 2's,
## so all three always show the SAME card (the compare rig used to carry a stale
## copy of its own).
##
## It is Realm 2's painted `TarotReading` with only colour + content changed — the
## frame, the flip, the typewriter and the dismissal are byte-for-byte L2.
## Verses picked line-by-line by Advika (2026-07-26). Her rules: witty but they
## must MAKE SENSE, and the ceiling warning stays PLURAL — golems hang in several
## roofs, not one.


static func build() -> TarotReading:
	var card := TarotReading.new()
	# content
	card.numeral = "I"
	card.card_title = "THE HOLLOW"
	card.portrait = load("res://assets/enemies/golem/boulder/golemidle1.png")
	card.second_art = load("res://assets/collectables/jade/jade_1.png")
	card.verses = [
		"Gather all the jade; the way opens itself",
		"One jump is never enough — space, twice",
		"Strike a golem while it wakes — J",
		"Never attack a rolling stone — dash — K",
		"Mind your head — not all the roof is rock",
	]
	# colour only — same card, recoloured warm for the cave
	card.overlay_color = Color(0.03, 0.022, 0.015, 0.88)   # warm dark surround
	# semi-transparent dark-brown wash = the body; the frame's eyes/hairlines/crest
	# read through it as lighter marks (Advika: keep the structure, make them lighter)
	card.body_color = Color(0.22, 0.14, 0.07, 0.22)
	card.face_tint = Color(1.15, 1.0, 0.72)                # lift the lines/eyes lighter + warm
	card.art_tint = Color(0.72, 0.72, 0.72)                # muted, but the jade still reads
	# the jade at the foot gives up room so the verses can be read (Advika), and sits
	# centred in the space above the hairline rather than tucked under the last verse
	card.foot_art_scale = 0.78
	card.verse_scale = 1.35
	return card
