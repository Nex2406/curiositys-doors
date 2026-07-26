extends SceneTree
## STEP 6 (Advika's spec): bake the PlantsAnimated pack into packed sprite
## sheets so the web build never stalls decoding 205 loose PNGs at runtime.
## Reads the raw pack (folder names are authoritative — the file prefixes
## inside are scrambled, so frames are taken by SORTED order, not by name),
## downscales the heavy Grass5 sequence to 40% (1024->410), and writes ONE
## grid sheet per sequence to assets/realms/realm1_plants/sheets/<name>.png.
##
## GRID, not a single horizontal row: a 40-frame 410px strip would be
## 16400px wide and exceed the web GPU max texture size (4096). Every sheet
## here is capped <= 4096px per side. Columns per sheet are mirrored in
## Realm1Bg.VEG_SPEC — keep the two in sync.
##
## Run: godot --headless --script tools/pack_plant_sheets.gd
## Source override: PLANT_PACK_SRC=<abs path to .../Vegetation>
## Repeatable: safe to re-run; overwrites the sheets.

const OUT := "res://assets/realms/realm1_plants/sheets/"
const DEFAULT_SRC := "C:/Users/advik/Downloads/PlantsAnimated_extract/Vegetation"

# name -> [pack_folder, frame_count, cols, resize_to (0 = keep native)]
const SEQS := {
	"comp1":      ["Comp 1",      30, 16, 0],
	"grass2":     ["Grass2",      30, 16, 0],
	"grass3":     ["Grass3",      30, 16, 0],
	"grass4":     ["Grass4",      30, 16, 0],
	"grass5":     ["Grass5",      40,  8, 410],
	"groupplant": ["Group Plant", 45,  8, 0],
}


func _init() -> void:
	var src := OS.get_environment("PLANT_PACK_SRC")
	if src == "":
		src = DEFAULT_SRC
	if not DirAccess.dir_exists_absolute(src):
		push_error("plant pack not found: %s" % src)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for name: String in SEQS:
		var spec: Array = SEQS[name]
		_pack(name, src.path_join(spec[0]), spec[1], spec[2], spec[3])
	quit()


func _pack(name: String, folder: String, count: int, cols: int,
		resize_to: int) -> void:
	# frames by SORTED filename (zero-padded => numeric order)
	var files := PackedStringArray()
	var d := DirAccess.open(folder)
	if d == null:
		push_error("cannot open %s" % folder)
		return
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			files.append(f)
	var sorted := Array(files)
	sorted.sort()
	if sorted.size() != count:
		print("  WARN %s: expected %d frames, found %d" % [name, count, sorted.size()])
	count = mini(count, sorted.size())
	# frame size from the first frame (post-resize)
	var first := Image.load_from_file(folder.path_join(sorted[0]))
	var fw := first.get_width()
	var fh := first.get_height()
	if resize_to > 0:
		fw = resize_to
		fh = resize_to
	var rows := int(ceil(float(count) / float(cols)))
	var sheet := Image.create(cols * fw, rows * fh, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in range(count):
		var img := Image.load_from_file(folder.path_join(sorted[i]))
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if resize_to > 0:
			img.resize(resize_to, resize_to, Image.INTERPOLATE_LANCZOS)
		var col := i % cols
		var row := i / cols
		sheet.blit_rect(img, Rect2i(0, 0, fw, fh), Vector2i(col * fw, row * fh))
	var out_path := ProjectSettings.globalize_path(OUT + name + ".png")
	sheet.save_png(out_path)
	print("  %s: %dx%d grid (%d cols x %d rows), frame %dx%d, %d frames -> %s"
			% [name, sheet.get_width(), sheet.get_height(), cols, rows,
			fw, fh, count, name + ".png"])
