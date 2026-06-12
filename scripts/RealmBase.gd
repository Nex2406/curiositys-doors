extends Node2D
class_name RealmBase

# The template every realm builds on. It owns the cross-cutting plumbing common
# to all realms — ambient audio on enter, marking the realm visited, restoring
# saved realm state, lore-on-exit, and the trip back to the hub — so a concrete
# realm only fills in its own content through the three hooks below.
#
# A realm = a Node2D scene whose root script `extends RealmBase`, with:
#   realm_id        set (its save namespace + default ambient key)
#   _on_realm_ready() overridden for scene setup (runs after audio + restore)
#   capture_state() / apply_state() overridden to persist its own progress
# and calling exit_to_hub() when the player leaves.
#
# Realm 1 predates this and is intentionally NOT retrofitted here (that's M3);
# this template is for realms 2/3 and the throwaway TestRealm.

@export var realm_id: String = ""
## AudioManager track key. Defaults to realm_id when left blank.
@export var ambient_name: String = ""
## Optional real ambient stream. Null → AudioManager's placeholder drone.
@export var ambient_track: AudioStream = null
## Optional single line shown before the fade home (see LoreMoment).
@export_multiline var exit_lore_line: String = ""
@export var return_scene: String = "res://scenes/Hub.tscn"

var _exiting: bool = false


func _ready() -> void:
	var key: String = ambient_name if ambient_name != "" else realm_id
	AudioManager.play_ambient(ambient_track, key)
	if realm_id != "":
		SaveManager.set_flag("visited_%s" % realm_id, true)
	_apply_saved_state()
	_on_realm_ready()


# ─── hooks for subclasses ──────────────────────────────────────────────────

# Scene setup, after ambient has started and saved state has been applied.
func _on_realm_ready() -> void:
	pass


# Return this realm's persistable progress. Shape is the realm's own business.
func capture_state() -> Dictionary:
	return {}


# Restore from a dictionary previously returned by capture_state().
func apply_state(_data: Dictionary) -> void:
	pass


# ─── save plumbing ─────────────────────────────────────────────────────────

# Persist the realm's current state. Call whenever progress changes.
func save_realm() -> void:
	if realm_id == "":
		return
	SaveManager.set_realm_state(realm_id, capture_state())


func _apply_saved_state() -> void:
	if realm_id == "":
		return
	var data: Dictionary = SaveManager.get_realm_state(realm_id)
	if not data.is_empty():
		apply_state(data)


# ─── exit ──────────────────────────────────────────────────────────────────

func exit_to_hub() -> void:
	if _exiting:
		return
	_exiting = true
	save_realm()
	if exit_lore_line.strip_edges() != "":
		await _play_lore(exit_lore_line)
	await Transition.transition_to(return_scene)


func _play_lore(text: String) -> void:
	var lore_scene: PackedScene = load("res://scenes/UI/LoreMoment.tscn")
	if lore_scene == null:
		push_warning("[RealmBase] LoreMoment scene missing — skipping exit lore")
		return
	var lore: Node = lore_scene.instantiate()
	add_child(lore)
	if lore.has_method("play_line"):
		await lore.play_line(text)
