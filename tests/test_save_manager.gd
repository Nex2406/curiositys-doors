extends SceneTree

# Headless round-trip check for the SaveManager foundation.
#   godot --headless --script res://tests/test_save_manager.gd
# Exercises a fresh instance (not the autoload) so it can wipe + rebuild the
# real save file and confirm state survives a simulated "reopen".

const SaveManagerScript := preload("res://scripts/SaveManager.gd")


func _initialize() -> void:
	var fails: int = 0
	var sm: Node = SaveManagerScript.new()

	# Clean slate.
	sm.reset()
	fails += _check("fresh: no save file", not sm.has_save())
	fails += _check("fresh: door not opened", not sm.is_door_opened("Door1"))
	fails += _check("fresh: item count 0", sm.item_count("jade") == 0)

	# Mutate + auto-persist.
	sm.mark_door_opened("Door1")
	sm.add_item("jade", 3)
	sm.set_flag("met_the_moon", true)
	fails += _check("write: save file exists", sm.has_save())

	# Simulate a reopen: a brand-new instance loading from disk.
	var sm2: Node = SaveManagerScript.new()
	sm2.load_game()
	fails += _check("reload: door persisted", sm2.is_door_opened("Door1"))
	fails += _check("reload: item persisted", sm2.item_count("jade") == 3)
	fails += _check("reload: flag persisted", sm2.get_flag("met_the_moon") == true)
	fails += _check("reload: unknown door false", not sm2.is_door_opened("Door9"))

	# Idempotent door marking.
	sm2.mark_door_opened("Door1")
	sm2.mark_door_opened("Door1")
	var sm3: Node = SaveManagerScript.new()
	sm3.load_game()
	fails += _check("dedupe: no duplicate door entry", sm3.is_door_opened("Door1"))

	# Cleanup so a real game boots fresh.
	sm.reset()

	if fails == 0:
		print("[test_save_manager] ALL PASSED")
		quit(0)
	else:
		print("[test_save_manager] FAILED: %d check(s)" % fails)
		quit(1)


func _check(label: String, ok: bool) -> int:
	print(("  PASS " if ok else "  FAIL ") + label)
	return 0 if ok else 1
