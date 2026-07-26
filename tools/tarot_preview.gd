extends Node2D
## The EXACT Realm 2 card (TarotReading) with only its colour + content changed:
## - colour: the dim overlay (which shows through the card's see-through centre) is
##   set warm, and a subtle warm modulate shifts the frame — NO added panels/shapes,
##   so the structure is byte-for-byte L2.
## - content: numeral I / THE HOLLOW / golem portrait / jade foot / Realm 1 verses.
##
## Isolated review window: it plays the WHOLE in-game beat hands-off — rises, flips,
## types the six verses at real speed, holds so you can read, fades out — then does
## it again, forever. Nothing to press. CARD_SHOT=<path> screenshots the reveal
## instead; LOOP_HOLD=<seconds> changes how long the finished card sits there.

const TarotReadingScript := preload("res://scripts/TarotReading.gd")

var _hold := 4.5      # seconds the finished card holds before it fades
var _gap := 1.2       # seconds of dark between plays
var _plays := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("LOOP_HOLD") != "":
		_hold = float(OS.get_environment("LOOP_HOLD"))
	var bg := CanvasLayer.new()
	bg.layer = -10
	var rect := ColorRect.new()
	rect.color = Color(0.05, 0.04, 0.03)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(rect)
	add_child(bg)
	_play_once()


## One full showing of the card, start to finish, then queue the next one.
func _play_once() -> void:
	_plays += 1
	print("TAROT LOOP: play ", _plays)
	var card := build_r1_card()
	add_child(card)

	if OS.get_environment("CARD_SHOT") != "":
		return   # TarotReading's own CARD_SHOT path flips + screenshots + quits

	# the card rises out of the deck, then turns
	await get_tree().create_timer(1.4).timeout
	if not is_instance_valid(card):
		return
	card._flip()

	# let the typewriter run at its real speed — that IS the beat
	while is_instance_valid(card) and not card._done:
		await get_tree().create_timer(0.15).timeout

	# hold on the finished verses, then dismiss it the way a player would
	await get_tree().create_timer(_hold).timeout
	if is_instance_valid(card):
		card.closed.connect(_on_card_closed)
		card._begin()
	else:
		_on_card_closed()


func _on_card_closed() -> void:
	await get_tree().create_timer(_gap).timeout
	_play_once()


## The Realm 1 card — its content and colour live in `scripts/Realm1Card.gd`,
## which the LEVEL builds from too, so this rig can never show a card the game
## doesn't have.
static func build_r1_card() -> TarotReading:
	return Realm1Card.build()
