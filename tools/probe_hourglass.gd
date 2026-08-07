extends SceneTree

## Proves the hourglass's frame mapping against the clock, without needing eyes
## on it: every stage boundary, the three states Advika asked to see, and the
## two ends. Frame is 1-based here (the art's own numbering).

const FRAMES := 16
const TOTAL := 600.0


func _frame_for(elapsed: float) -> int:
	return clampi(int(elapsed / TOTAL * float(FRAMES)), 0, FRAMES - 1) + 1


func _init() -> void:
	print("stage length = ", TOTAL / float(FRAMES), "s")
	print("-- the three states asked for --")
	for e in [0.0, 300.0, 590.0]:
		print("  elapsed %6.1fs  remaining %6.1fs  ->  frame %d"
				% [e, TOTAL - e, _frame_for(e)])
	print("-- every stage boundary --")
	var bad := 0
	for i in FRAMES:
		var at: float = float(i) * TOTAL / float(FRAMES)
		var got := _frame_for(at)
		var want := i + 1
		if got != want:
			bad += 1
			print("  MISMATCH at %.1fs: got %d want %d" % [at, got, want])
	print("  boundaries wrong: ", bad)
	print("-- the ends --")
	print("  0.0s        -> frame ", _frame_for(0.0), " (want 1)")
	print("  599.9s      -> frame ", _frame_for(599.9), " (want 16)")
	print("  600.0s      -> frame ", _frame_for(600.0), " (want 16, clamped)")
	print("  just before frame 16: 562.4s -> ", _frame_for(562.4), " (want 15)")
	print("  frame 16 starts at 562.5s -> ", _frame_for(562.5), " (want 16)")
	quit()
