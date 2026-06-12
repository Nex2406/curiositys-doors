extends SceneTree

# Headless check for the Dialogue service.
#   godot --headless --script res://tests/test_dialogue.gd
# Drives a full multi-line sequence through the autoload script deterministically
# (advancing the box programmatically rather than via real input/timing), and
# confirms it opens, steps every line, resolves the awaitable, and tears down.

const DialogueScript := preload("res://scripts/Dialogue.gd")


func _initialize() -> void:
	# Defer one frame so root exists, then run the async body.
	_run.call_deferred()


func _run() -> void:
	var fails: int = 0
	var dlg: Node = DialogueScript.new()
	root.add_child(dlg)

	var closed_count: Array = [0]
	var started_count: Array = [0]
	dlg.closed.connect(func() -> void: closed_count[0] += 1)
	dlg.started.connect(func() -> void: started_count[0] += 1)

	fails += _check("idle before say()", not dlg.is_active())

	var lines: Array = ["Test line one.", "Test line two.", "Test line three."]
	dlg.say(lines)   # fire-and-forget coroutine

	fails += _check("active after say()", dlg.is_active())
	fails += _check("started emitted once", started_count[0] == 1)

	# Track that every line gets surfaced.
	var lines_seen: Array = [0]
	var box: CanvasLayer = dlg._box
	if box != null:
		box.line_changed.connect(func(_i: int) -> void: lines_seen[0] += 1)

	# Drive: each _on_advance_pressed() either finishes typing or advances; two
	# presses retire one line. Re-fetch the box each step since it frees itself
	# the instant the final line is dismissed.
	var safety: int = 0
	while dlg.is_active() and safety < 64:
		var active_box: CanvasLayer = dlg._box
		if active_box == null:
			break
		active_box._on_advance_pressed()
		await process_frame
		safety += 1

	fails += _check("idle after sequence", not dlg.is_active())
	fails += _check("closed emitted once", closed_count[0] == 1)
	# line_changed(0) fires inside start() before our connect, so we observe the
	# two later lines being entered (>=2 proves it stepped past the first).
	fails += _check("stepped through later lines", lines_seen[0] >= 2)
	fails += _check("did not run away", safety < 64)

	# Empty input is a no-op, not a crash.
	dlg.say([])
	fails += _check("empty say() stays idle", not dlg.is_active())

	if fails == 0:
		print("[test_dialogue] ALL PASSED")
		quit(0)
	else:
		print("[test_dialogue] FAILED: %d check(s)" % fails)
		quit(1)


func _check(label: String, ok: bool) -> int:
	print(("  PASS " if ok else "  FAIL ") + label)
	return 0 if ok else 1
