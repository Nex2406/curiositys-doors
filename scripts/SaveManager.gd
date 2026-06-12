extends Node

# Autoload "SaveManager" — the single source of persistent game state.
#
# Everything that must survive a scene change OR a page refresh lives here,
# never in a scene. Scenes read/write through the typed accessors below; this
# node owns the on-disk format and the only file I/O in the game.
#
# State shape (all under one versioned dictionary):
#   doors_opened : Array[String]        # door_ids the player has entered
#   inventory    : Dictionary           # item_name -> int count
#   flags        : Dictionary           # arbitrary named bool/value flags
#
# Persistence: JSON at user://. On the HTML5 build user:// is backed by the
# browser's IndexedDB, which Godot 4 flushes on file close — so a save written
# here survives a page refresh, which is the M1 save/restore gate.
#
# Design note: writes are explicit. Accessors mutate in-memory state and call
# save_game() so a caller never has to remember to persist; if that ever proves
# too chatty we can batch, but correctness-first for the foundation layer.

const SAVE_PATH: String = "user://curiosity_save.json"
const SAVE_VERSION: int = 1

var _state: Dictionary = {}


func _ready() -> void:
	load_game()


# ─── lifecycle ─────────────────────────────────────────────────────────────

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> void:
	# Always start from a complete default so missing/older saves still expose
	# every key (forward-compatible: new fields appear with their defaults).
	_state = _default_state()
	if not has_save():
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] could not open save for read: %s" % SAVE_PATH)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveManager] save file unreadable — keeping defaults")
		return
	_merge_into_state(parsed as Dictionary)


func save_game() -> void:
	_state["version"] = SAVE_VERSION
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] could not open save for write: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_state, "\t"))
	file.close()  # close flushes; on web this syncs IndexedDB.


# Wipe persistent state back to a fresh game (used by "new game" / dev reset).
func reset() -> void:
	_state = _default_state()
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ─── doors ─────────────────────────────────────────────────────────────────

func mark_door_opened(door_id: String) -> void:
	if door_id == "":
		return
	var opened: Array = _state["doors_opened"]
	if opened.has(door_id):
		return
	opened.append(door_id)
	save_game()


func is_door_opened(door_id: String) -> bool:
	return (_state["doors_opened"] as Array).has(door_id)


# ─── inventory ─────────────────────────────────────────────────────────────

func add_item(item: String, amount: int = 1) -> void:
	if item == "":
		return
	var inv: Dictionary = _state["inventory"]
	inv[item] = int(inv.get(item, 0)) + amount
	save_game()


func item_count(item: String) -> int:
	return int((_state["inventory"] as Dictionary).get(item, 0))


# ─── flags ─────────────────────────────────────────────────────────────────

func set_flag(name: String, value: Variant = true) -> void:
	if name == "":
		return
	(_state["flags"] as Dictionary)[name] = value
	save_game()


func get_flag(name: String, default_value: Variant = false) -> Variant:
	return (_state["flags"] as Dictionary).get(name, default_value)


# ─── internals ─────────────────────────────────────────────────────────────

func _default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"doors_opened": [],
		"inventory": {},
		"flags": {},
	}


# Copy only known keys from a loaded dictionary over the defaults, coercing to
# the expected container type so a corrupt/foreign value can't poison a getter.
func _merge_into_state(loaded: Dictionary) -> void:
	if loaded.has("doors_opened") and loaded["doors_opened"] is Array:
		var opened: Array = []
		for id in (loaded["doors_opened"] as Array):
			opened.append(String(id))
		_state["doors_opened"] = opened
	if loaded.has("inventory") and loaded["inventory"] is Dictionary:
		_state["inventory"] = (loaded["inventory"] as Dictionary).duplicate()
	if loaded.has("flags") and loaded["flags"] is Dictionary:
		_state["flags"] = (loaded["flags"] as Dictionary).duplicate()
