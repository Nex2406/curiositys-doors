extends Node2D
class_name Realm3Gateway

## THE DOORWAY FROM REALM 2 INTO REALM 3.
##
## Built to the SAME RECIPE as the Realm 1 -> Realm 2 doorway (`_r2_doorway` in
## `Realm1PlatformTest.gd`), which is the one that landed. Advika: *"keep in mind
## how we built r2s doorway — instead of leaves use vines, and use moss and
## mushrooms; rocks should only be at the bottom or top."*
##
## That recipe, in full:
##
##   1. HAND-PLACED, NOT STACKED. Every piece sits at a coordinate chosen for it.
##      An earlier pass built the piers by looping rocks up a column with jitter
##      and it came back as COURSES — a ladder of horizontal shelves with a hole
##      in it. There is no while-loop in the frame any more.
##   2. THE DOORWAY IS BUILT OUT OF THE REALM IT LEADS TO — mushrooms, fungal
##      fronds, Realm 3's teal. Realm 2's vines and moss carry it, so the object
##      reads as the seam between the two realms rather than as either one.
##   3. NOTHING ENDS ON A STRAIGHT EDGE, AND NO CUT END IS VISIBLE. Only closed
##      painted shapes are used — clumps, caps, trunks. Strip-sliced moss was
##      tried as bulk in BOTH doorways and thrown out both times: those paintings
##      are full-width bands, so every slice lands as a visible rectangle. Every
##      trunk top is capped by a cluster planted over it; every hanging piece
##      starts inside the mass it hangs from.
##   4. ROCK AT THE BOTTOM AND THE TOP ONLY. It is the pile the posts are bedded
##      in and the weight the crown is carrying — never the wall itself.
##   5. THE FAR SIDE IS PHOTOGRAPHED, NOT MOCKED UP. `r3_gateway_view.png` is a
##      real capture of the built Realm 3, cropped to this opening's aspect so
##      nothing is stretched (`tools/bake_r3_gateway_view.py`).
##
## All coordinates are door-local: (0,0) is the centre of the opening and +FLOOR
## is the contact row, so the whole assembly grows about its own base.

## EVERY SPRITE IN THE DOORWAY COMES OUT OF THIS ONE FOLDER. The frame used to
## borrow Realm 2's vines, moss and hanging curls as its bulk; all of them are
## painted violet, and a teal multiply only ever made them duller violet. The
## last of them went when Advika circled the hem.
const BASE := "res://assets/realms/realm3_fungal/"
const VIEW := BASE + "r3_gateway_view.png"
const PORTAL_SHADER := "res://shaders/portal_window.gdshader"

## the contact row — where every standing piece is bedded
const FLOOR := 150.0
## Half-width of the clear passage. It has to be wider than the material framing
## it, or the frame closes the door.
const OPEN_HALF := 132.0
## The crown's underside. The opening must be clearly TALLER than it is wide —
## a letterbox full of forest reads as a window you look through rather than a
## way you walk through.
const OPEN_TOP := -292.0
## how far out the crown reaches past the passage
const SPAN := OPEN_HALF + 150.0

## THE INTERIOR THE FAR REALM HAS TO FILL — much bigger than the hole it is seen
## through. A feathered mask's solid core is `radius * (1 - feather)`, so an
## undersized view fades out INSIDE the opening and leaves dark voids in the top
## corners (Advika circled exactly that). Sized so the core covers the opening
## plus margin at the looser of the two feathers.
const VIEW_W := 408.0
const VIEW_H := 600.0
const VIEW_Y := (FLOOR + OPEN_TOP) * 0.5     # the opening's actual centre

## Realm 3's own palette, so the doorway reads as a piece of that realm standing
## in this one.
const FUNGAL_TEAL := Color(0.62, 1.06, 0.96)
const FUNGAL_DARK := Color(0.30, 0.46, 0.44)
const GLOW_WARM := Color(1.0, 0.84, 0.52)
## Realm 2's violet vine and moss multiplied into this realm's teal, the same
## correction the level's own floor uses
const R2_TEAL := Color(0.52, 1.12, 0.94)
## THE MASS IS FUNGAL HILLS (Advika: *"i hate this — use fungal hills from the
## asset instead of leaves"*). Realm 2's tufts were carrying the bulk and every
## one of them is a leafy rosette: thirty of those across a doorway made of
## mushrooms read as a hedge from the wrong realm. `fungalhill1..5` are Realm 3's
## own closed painted masses, which is the property the tufts were being used for
## and the only one that mattered.
## ONE LEVER FOR THE WHOLE FRAME'S EXPOSURE.
##
## Darkening the caps and the stone to kill the pale-plate look pulled the entire
## crown down with them, and the doorway went back to reading as a shadow with a
## green stripe in it. Rather than re-tune thirty tints and risk finding the
## plates again, every frame piece is lifted by the same factor at the point it
## is drawn — the RELATIONSHIPS between the values are what was hard to get
## right, and this leaves all of them exactly where they are.
##
## It is applied in `_piece`/`_hang` only, so the far side never touches it: the
## view through the passage has its own exposure in the portal shader.
const FRAME_LIFT := 1.28

var _portal_parts: Array = []      # {node, mat, radius}
var _sway_specs: Array = []
var _sway_started := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20260807


## SCALE A COLOUR'S BRIGHTNESS WITHOUT TOUCHING ITS ALPHA.
##
## THE BUG THIS EXISTS TO KILL: in Godot, `Color * float` multiplies ALL FOUR
## components, alpha included. So `R2_TEAL * 0.40` — written to mean "this moss
## is 40% as bright" — actually produced alpha 0.40, and every sprite tinted that
## way rendered at forty percent opacity. Advika saw the symptom first: "the
## decorated terrain renders as an unreadable semi-transparent mass, you can see
## overlapping sprite rectangles ghosting through each other."
func _dim(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func build() -> void:
	_threshold()
	_posts()
	_crown()
	_curtain()
	_base()
	_front_growth()
	_lights()


# ---------- the far side ----------

## Two layers: a flat membrane that stops Realm 2's sky showing through the gap,
## and over it Realm 3 itself, masked so it dissolves into the frame.
func _threshold() -> void:
	# FLAT, not a radial gradient. A gradient behind a uniformly-filled view
	# reads as an oval bruise through the gaps in the growth.
	var body := Sprite2D.new()
	body.name = "Threshold"
	body.texture = _flat_tex(Color(0.035, 0.075, 0.070))
	body.position = Vector2(0.0, VIEW_Y)
	body.scale = Vector2((VIEW_W + 26.0) / 8.0, (VIEW_H + 26.0) / 8.0)
	body.z_index = 0
	var bmat := ShaderMaterial.new()
	bmat.shader = load(PORTAL_SHADER)
	bmat.set_shader_parameter("centre", Vector2(0.5, 0.5))
	bmat.set_shader_parameter("radius", Vector2(0.5, 0.5))
	bmat.set_shader_parameter("feather", 0.20)
	bmat.set_shader_parameter("brightness", 1.0)
	bmat.set_shader_parameter("boxiness", 1.0)
	# the membrane is the OUTER edge, so its rim is the one that must never be a
	# straight line — coarser and deeper than the view's
	bmat.set_shader_parameter("edge_noise", 0.34)
	bmat.set_shader_parameter("noise_scale", 3.6)
	bmat.set_shader_parameter("uv_pan", Vector2.ZERO)
	body.material = bmat
	_portal_parts.append({"node": body, "mat": bmat, "radius": Vector2(0.5, 0.5),
			"feather": 0.20})
	add_child(body)

	var win := Sprite2D.new()
	win.name = "PortalWindow"
	win.texture = load(VIEW)
	# scaled to COVER the interior on width; it overhangs top and bottom and the
	# mask crops it, so the forest is never stretched to fit the hole
	var ws: float = VIEW_W / float(win.texture.get_width())
	var drawn_h: float = float(win.texture.get_height()) * ws
	win.scale = Vector2(ws, ws)
	win.position = Vector2(0.0, VIEW_Y)
	win.z_index = 1
	var mat := ShaderMaterial.new()
	mat.shader = load(PORTAL_SHADER)
	mat.set_shader_parameter("centre", Vector2(0.5, 0.5))
	var win_radius := Vector2(0.5, (VIEW_H / drawn_h) * 0.5)
	mat.set_shader_parameter("radius", win_radius)
	mat.set_shader_parameter("feather", 0.16)
	mat.set_shader_parameter("brightness", 1.18)
	mat.set_shader_parameter("boxiness", 1.0)
	# finer than the membrane's, so the two rims break at different frequencies
	mat.set_shader_parameter("edge_noise", 0.30)
	mat.set_shader_parameter("noise_scale", 6.2)
	# the far forest drifts inside a mask that stays put
	mat.set_shader_parameter("uv_pan", Vector2(0.004, 0.0))
	win.material = mat
	_portal_parts.append({"node": win, "mat": mat, "radius": win_radius,
			"feather": 0.16})
	add_child(win)


# ---------- the frame ----------

## THE POSTS — a COLUMN OF FUNGAL HILLS climbing each side of the passage, with
## a dimmer, narrower column set back behind it so the jamb has thickness.
##
## Advika, on the vine bundles that stood here: *"replace these leaves on the
## side with [fungalhill1 and fungalhill4] — just shift them vertically and
## attach them."* `vine_dark` flipped to climb reads as a tall dark FERN: a leaf
## shape, from the wrong realm, and four a side made a hedge either side of the
## door rather than a doorpost. The two she circled are the wide low mound and
## the asymmetric one — the same masses the crown is built of, so the jambs and
## the span are finally the same object.
##
## STACKED AND ATTACHED, which is the whole trick. Every hill is painted as a
## fringe sitting on a flat dark base, so the pitch is barely half a hill's
## height and the column is added TOP FIRST: each hill lands in FRONT of the one
## above it and its fringe swallows that one's base line. Nothing in the column
## shows a straight edge but the topmost, and a cap is planted over that.
## COUNT IS THE WHOLE PROBLEM, NOT THE JITTER. Two passes stacked these small —
## nine a side at a fixed step, then fourteen with the step, width, squeeze and
## value all re-rolled per row — and BOTH came back as a ladder. They had to:
## every one of these hills is a horizontal arch, so any vertical run of them is
## rungs, and jitter only makes the rungs untidy. So there is no run. TWO hills
## carry each jamb, blown up to doorpost height and squeezed narrow, overlapping
## by more than half — two shapes cannot form a rhythm.
##
## AND THE SEAM GOES DEEP, NOT HALFWAY. Seated at -60 the upper hill's flat base
## landed in the top THIRD of the lower one, which is all fringe tips — the black
## base simply showed between the fronds as a slab with a ruled bottom edge.
## These hills are painted solid for roughly their bottom half (`JAMB_SOLID`), so
## the seam has to sit inside THAT, and the upper hill grows tall enough to still
## reach the crown from down there.
##
## AND THE UPPER HILL IS THE NARROWER OF THE TWO. Sized by height alone it came
## out WIDER than the one it is seated in — because it has to be taller to reach
## the lintel — so its base stuck out past the lower hill on both sides and the
## ruled edge came back at the ends. Each is given a drawn WIDTH, and the jamb
## tapers as it climbs, which is what growth does anyway.
const JAMB_H := 330.0        # the lower hill, blown up to half the jamb
const JAMB_W := 300.0        # ...and pulled in narrow, so it reads as a column
const JAMB_SOLID := 0.52     # fraction of a hill's height that is solid mass
## where a jamb stops — deep inside the crown row's solid body, never above it
const JAMB_TOP := -336.0
## the jambs' own centres, which the crown row has to reach to bury them
const JAMB_X := OPEN_HALF + 108.0


func _posts() -> void:
	for side in [-1.0, 1.0]:
		var cx: float = side * JAMB_X
		# the set-back pair first — dimmer, narrower, seam at a different height,
		# so the jamb has depth and the two seams never line up
		_column(cx + side * 40.0, FLOOR + 34.0, JAMB_H * 0.86, JAMB_W * 0.83,
				26.0, 2, 0.44)
		var top: float = _column(cx, FLOOR + 14.0, JAMB_H, JAMB_W, 10.0, 4, 0.80)
		# the upper hill's base is buried by the lower one; its TOP is the only
		# edge left, and a cap planted over it buries that the same way the vine
		# bundle's cut tops used to be buried
		_piece("mushroomcap%d.png" % (1 + _rng.randi() % 10), 128.0,
				Vector2(cx, top + 18.0), 6,
				_dim(FUNGAL_TEAL.lerp(FUNGAL_DARK, 0.78), 0.86), side > 0.0, true)
	# moss packed down the passage's own edges, so what you brush past on the way
	# through is growth and not timber
	# only at the foot of each jamb, where the pile gives them something to rest
	# on — a hill halfway up a post has nothing under it and floats
	for m: Array in [[-OPEN_HALF - 26.0, 104.0], [OPEN_HALF + 24.0, 96.0]]:
		_moss(float(m[0]), FLOOR + 16.0, float(m[1]), 5,
				_rng.randf_range(0.62, 0.86))


## ONE JAMB: `fungalhill4` bedded at `y0` and `fungalhill1` seated at `seam`
## above it — the two Advika circled. The upper one is added FIRST so the lower
## one draws in front of it and its fringe swallows the upper's flat base; the
## seam therefore has to sit INSIDE the lower hill's body, not above its top.
## Returns the drawn top of the upper hill, the one edge still in open air.
func _column(x: float, y0: float, h: float, w: float, seam: float,
		z: int, bright: float) -> float:
	# TALL ENOUGH TO REACH THE CROWN, NOT TO CLEAR IT. Advika circled the top of
	# the left jamb: *"remove that hedge on the top."* At 380px the upper hill's
	# fringe finished at -371, well above the lintel and past the end of the
	# crown's own row — so each jamb topped out as a separate bush sitting above
	# the doorway with nothing over it. It now ends at JAMB_TOP, which is inside
	# the SOLID body of the crown row that runs out to meet it.
	# Narrow enough, too, that the hill below covers its base from end to end.
	var upper := _hill(4, x + 10.0, seam, seam - JAMB_TOP, w * 0.84,
			z, bright * 0.92)
	_hill(1, x, y0, h, w, z, bright)
	return upper


## one blown-up, narrowed hill, fitted to a drawn height AND width. Returns its
## drawn top.
func _hill(id: int, x: float, y: float, h: float, w: float, z: int,
		bright: float) -> float:
	var s := _piece("fungalhill%d.png" % id, h, Vector2(x, y), z,
			_dim(FUNGAL_TEAL, bright), false, false)
	# SQUEEZED, NOT CROPPED. These are painted more than twice as wide as they
	# are tall; at doorpost height an unsqueezed one is a mound six hundred
	# pixels across lying beside the door. Pulled in, the same fronds read as a
	# dense vertical clump, which is what a jamb of this stuff should be.
	var sx: float = w / float(s.texture.get_width())
	s.scale.x = -sx if _rng.randf() < 0.5 else sx
	s.rotation_degrees = _rng.randf_range(-3.0, 3.0)
	_sway(s, "b", 0.009, _rng.randf_range(6.2, 8.6))
	return y - h
	# moss packed down the passage's own edges, so what you brush past on the way
	# through is growth and not timber
	# only at the foot of each jamb, where the pile gives them something to rest
	# on — a hill halfway up a post has nothing under it and floats
	for m: Array in [[-OPEN_HALF - 26.0, 104.0], [OPEN_HALF + 24.0, 96.0]]:
		_moss(float(m[0]), FLOOR + 16.0, float(m[1]), 5,
				_rng.randf_range(0.62, 0.86))


## THE CROWN — one continuous mass laid along a shallow dome, each clump
## overlapping its neighbours by roughly half, sizes and heights jittered so
## neither the top edge nor the underside ever forms a straight line.
##
## Three depths: a dim back row for bulk (so nothing shows through the middle of
## it), the body of mushroom caps and moss, and a small front fringe that breaks
## the underside. The only rock in the whole span is bedded into its TOP, where
## it reads as the weight the doorway is carrying.
func _crown() -> void:
	# the dim back mass first — bulk, and bulk that sways reads as cloth, so it
	# barely moves
	# RESTING ON THE LINTEL ROW, not floating at a centre. Hung by their middles
	# these four sat with their flat painted bases hanging BELOW the opening's
	# top, which is where the black bars across the passage came from.
	# and NOT all on the same row: four flat bases resting at the same height add
	# up to one long straight line under the crown, which is the same bar again
	# just moved. Every base sits at a different depth into the mass.
	# and SHORT ENOUGH TO STAY UNDER THE CAPS. Flipping only helps if the flat
	# edge lands inside something: at 180-210px tall these poked out above the cap
	# row and the straight edge simply reappeared at the top of the crown, which
	# is worse — up there it has open air behind it.
	for b: Array in [[-152.0, -330.0, 112.0], [-56.0, -308.0, 124.0],
			[48.0, -320.0, 118.0], [146.0, -312.0, 104.0]]:
		var n := _piece("fungalhill%d.png" % (1 + _rng.randi() % 5), float(b[2]),
				Vector2(float(b[0]), float(b[1])), 1,
				_dim(FUNGAL_DARK, 0.72), _rng.randf() < 0.5, false)
		# NOT FLIPPED. Turning a hill over was tried and it is worse: the body of
		# this art is a dark mass with the fringe along its TOP, so upside down it
		# draws as a black band with a fringe under it — two of them across the
		# crown at once. A hill only ever works the way it is painted: fringe up,
		# sitting on something, with its flat base covered by the row below.
		n.rotation_degrees = _rng.randf_range(-9.0, 9.0)
		_sway(n, "c", 0.010, _rng.randf_range(6.4, 8.6))
	# ROCK, BEDDED IN THE TOP. Sunk into the back mass so no face of it stands
	# free in the air.
	#
	# DARK, AND BEHIND THE GROWTH. At 0.46-0.62 brightness and z=2 these came out
	# as pale flat plates stacked on the crown's top, reading as slabs laid on a
	# roof rather than as stone sunk into a mass. Stone is the FURTHEST thing back
	# in the doorway, so it goes behind the bulk and only its top edge shows.
	for r: Array in [[-122.0, -418.0, 118.0], [10.0, -448.0, 138.0],
			[128.0, -420.0, 112.0], [-46.0, -404.0, 92.0]]:
		var s := _piece("fungalstone%d.png" % (1 + _rng.randi() % 29), float(r[2]),
				Vector2(float(r[0]), float(r[1])), 0,
				_dim(R2_TEAL, _rng.randf_range(0.26, 0.38)), _rng.randf() < 0.5,
				true)
		s.rotation_degrees = _rng.randf_range(-26.0, 26.0)
	# the body: caps and moss clustered, not spaced — the size range is
	# deliberately extreme so no rhythm forms
	# THE CROWN IS MUSHROOM, NOT MOSS (Advika: *"remove excess moss, this just
	# looks messy — esp from the top"*). Seventeen clumps up here, most of them
	# moss, buried the shape under fringe: every rosette added its own outline and
	# the dome stopped having one silhouette. Twelve pieces now, and only two of
	# them are moss — the caps carry the mass and the moss just softens where the
	# span meets the jambs.
	# EVERY PIECE OVER MASS (Advika: *"i dont want any moss peices in air where
	# theres a gap"*). The span used to reach ±262 while the mass behind it only
	# reached ±196, so the outermost pieces hung past the edge of everything and
	# their painted undersides read as slabs stuck to the background. Nothing now
	# sits further out than the bulk it is resting on.
	var spots: Array = [
		# ALL HILLS, NO CAPS IN THE SPAN. `mushroomcap` is painted with a wide dark
		# underside, and at crown scale that underside is a black bar wherever the
		# growth in front of it does not happen to cover it — which is the gap she
		# keeps circling. Three attempts to seat them (hill row beneath, tighter
		# span, darker tint) each moved the bar rather than removing it. The caps
		# stay where they read against sky and their underside never faces the
		# camera: the towers flaring off the ends.
		[-198.0, -318.0, 126.0, 3, 0], [-158.0, -344.0, 152.0, 5, 0],
		# the hill row sits at the lintel, right under the cap row, so every cap's
		# dark painted underside lands on growth instead of on background — the
		# black bars were never the hills, they were the caps' own undersides
		[-176.0, -318.0, 122.0, 7, 0], [-92.0, -312.0, 116.0, 7, 0],
		[8.0, -320.0, 124.0, 7, 0], [96.0, -310.0, 118.0, 7, 0],
		[178.0, -316.0, 120.0, 7, 0],
		[-78.0, -372.0, 138.0, 3, 0],
		[-36.0, -340.0, 108.0, 7, 0], [-6.0, -386.0, 162.0, 5, 0],
		[38.0, -346.0, 92.0, 7, 0], [74.0, -372.0, 130.0, 3, 0],
		[150.0, -352.0, 148.0, 5, 0],
		# NOT a second cap level with the one at -46: two dark caps the same size
		# side by side across the middle of the crown read as a pair of eyes, and
		# nothing in this doorway is allowed to look back.
		[190.0, -318.0, 112.0, 3, 0], [66.0, -308.0, 74.0, 7, 0],
	]
	for sp: Array in spots:
		var k: float = _rng.randf_range(0.62, 1.0)
		if int(sp[4]) == 1:
			# TILTED AND DARK. A cap drawn near-level at full teal is a flat plate,
			# and a dome built of plates has no depth in it. They lean, they sit
			# down in the mass's own value range, and the moss overlaps them.
			var c := _piece("mushroomcap%d.png" % (1 + _rng.randi() % 10),
					float(sp[2]), Vector2(float(sp[0]), float(sp[1])), int(sp[3]),
					_dim(FUNGAL_TEAL.lerp(FUNGAL_DARK,
					_rng.randf_range(0.70, 0.94)), 0.86), _rng.randf() < 0.5, true)
			# ±38° was too much: a wide flat cap tilted that far stops reading as
			# part of the dome and starts reading as a tongue jutting out of it.
			c.rotation_degrees = _rng.randf_range(-18.0, 18.0)
			_sway(c, "c", 0.018, _rng.randf_range(4.6, 7.4))
		else:
			_sway(_moss(float(sp[0]), float(sp[1]), float(sp[2]), int(sp[3]), k),
					"c", 0.024, _rng.randf_range(4.4, 7.0))
	_edge_towers()


## THE MUSHROOMS TOWER FROM THE CROWN'S ENDS, up and OUTWARD, leaning away from
## the passage — so the doorway opens like a V above the lintel instead of being
## capped flat. They are what makes the whole object read as Realm 3 from across
## the deck.
func _edge_towers() -> void:
	for side in [-1.0, 1.0]:
		for k in 3:
			var h: float = [258.0, 190.0, 136.0][k] * _rng.randf_range(0.9, 1.12)
			var id: int = [5, 1, 7, 8, 2][(k + int(side) + 2) % 5]
			# their feet are planted INSIDE the crown, not out past its edge —
			# a tower rising off bare air is the same floating piece by another
			# name
			var t := _piece("mushroomcap%d.png" % id, h,
					Vector2(side * (156.0 + float(k) * 26.0),
					OPEN_TOP - 62.0), 8,
					FUNGAL_TEAL.lerp(FUNGAL_DARK, 0.15 + float(k) * 0.22),
					side > 0.0)
			t.rotation_degrees = side * (8.0 + float(k) * 13.0)
			_sway(t, "b", 0.014, 5.6 + float(k) * 1.4 + (0.0 if side < 0.0 else 0.7))
		# their feet are already inside the crown's own mass; a hill out here would
		# be resting on nothing but air


## THE CURTAIN — vines, beards and fronds hanging out of the crown's underside.
## Every strand starts at a different height and runs to a different length, so
## there is no row: the fringe the eye follows is ragged.
##
## Lengths are deliberately asymmetric about the middle. The strands over the
## PASSAGE are the SHORTEST of the set, so the way through stays open and the eye
## reads a gap, not a thicket — an even hem across a tall opening cuts the
## doorway in half, which is what the last pass did.
## NOT ONE PIECE OF REALM 2 IN IT (Advika circled every violet curl in the hem:
## *"remove ... these purple leaves"*). `hang_curl`, `hang_beard` and `hang_fern`
## are painted in Realm 2's violet, and multiplying violet by teal does not make
## it teal — it makes it a duller violet, which is exactly what they read as:
## purple leaves stuck under a teal doorway. Realm 3's own fronds only.
##
## AND TWICE AS MANY, because the hem has a job. The crown's front row is
## bottom-anchored, and its contact line is the one edge in the whole doorway
## with open passage under it — twelve strands left gaps for it to show through.
## Same twelve strands, same anchors, same lengths as the pass that landed — the
## only change is WHICH art hangs on them.
func _curtain() -> void:
	var strands: Array = [
		# x, anchor row, length. The `r2:` hangers that used to fill eight of
		# these twelve slots are gone: `hang_curl`, `hang_beard`, `hang_fern` and
		# `vine_dark` are all painted in Realm 2's violet, and multiplying violet
		# by teal does not make it teal, it makes it a duller violet. They read
		# as purple leaves stuck under a teal doorway, which is what Advika
		# circled. Realm 3's own fronds stand in at the same sizes.
		["fungalfrond11.png", -212.0, -306.0, 158.0],
		["fungalfrond3.png", -176.0, -292.0, 122.0],
		["fungalfrond16.png", -140.0, -308.0, 172.0],
		["fungalfrond3.png", -104.0, -296.0, 92.0],
		["fungalfrond2.png", -66.0, -300.0, 62.0],
		["fungalfrond10.png", -26.0, -304.0, 48.0],
		["fungalfrond10.png", 14.0, -298.0, 54.0],
		["fungalfrond2.png", 52.0, -302.0, 66.0],
		["fungalfrond11.png", 92.0, -290.0, 108.0],
		["fungalfrond11.png", 132.0, -304.0, 146.0],
		["fungalfrond16.png", 172.0, -294.0, 130.0],
		["fungalfrond3.png", 210.0, -306.0, 164.0],
	]
	for s: Array in strands:
		# hung from ABOVE the hill row's flat bases (-310..-320), not from the
		# lintel: these are the pieces painted to end raggedly, so they are what
		# covers the one straight edge the hills cannot lose
		var n := _hang(String(s[0]), float(s[3]),
				Vector2(float(s[1]), float(s[2]) - 34.0), 4,
				FUNGAL_DARK.lerp(FUNGAL_TEAL, 0.42))
		_sway(n, "t", 0.030, _rng.randf_range(4.6, 7.8))


## THE BASE — the rock pile the posts are bedded in, with moss and small growth
## packed over the joins. This and the crown's top are the only rock in the
## doorway.
func _base() -> void:
	for r: Array in [[-352.0, 96.0, 4], [-268.0, 118.0, 4], [-196.0, 88.0, 6],
			[-118.0, 132.0, 4], [-42.0, 84.0, 6], [46.0, 104.0, 6],
			[126.0, 138.0, 4], [204.0, 92.0, 6], [286.0, 120.0, 4],
			[364.0, 86.0, 4]]:
		var s := _piece("fungalstone%d.png" % (1 + _rng.randi() % 29),
				float(r[1]), Vector2(float(r[0]), FLOOR + 20.0), int(r[2]),
				_dim(R2_TEAL, _rng.randf_range(0.50, 0.70)), _rng.randf() < 0.5)
		s.rotation_degrees = _rng.randf_range(-18.0, 18.0)
	# five clumps along the pile, not eleven — enough to bed the stones, not so
	# many that the base turns into a hedge
	for m: Array in [[-330.0, 96.0], [-176.0, 112.0], [-24.0, 88.0],
			[142.0, 106.0], [312.0, 92.0]]:
		_sway(_moss(float(m[0]), FLOOR + 18.0, float(m[1]), 7,
				_rng.randf_range(0.64, 0.92)), "b", 0.016,
				_rng.randf_range(5.2, 8.0))
	# a few stalagmites bedded through the pile, so the bottom has verticals too
	for g: Array in [[-238.0, 118.0], [-64.0, 96.0], [148.0, 126.0], [292.0, 88.0]]:
		_piece("stalagmite%d.png" % (1 + _rng.randi() % 16), float(g[1]),
				Vector2(float(g[0]), FLOOR + 16.0), 6,
				_dim(FUNGAL_DARK, 1.1), _rng.randf() < 0.5)


## THE FRONT — growth crossing BETWEEN the camera and the doorway, so she walks
## into it rather than up to a flat facade.
func _front_growth() -> void:
	for spec: Array in [[-146.0, 128.0], [152.0, 112.0], [-72.0, 78.0],
			[84.0, 70.0], [-244.0, 96.0], [258.0, 88.0]]:
		var f := _piece("fungalfrond%d.png" % [16, 3, 11, 4][_rng.randi() % 4],
				float(spec[1]), Vector2(float(spec[0]), FLOOR + 16.0), 9,
				FUNGAL_DARK.lerp(FUNGAL_TEAL, 0.28), _rng.randf() < 0.5)
		f.rotation_degrees = _rng.randf_range(-14.0, 14.0)
		_sway(f, "b", 0.022, _rng.randf_range(5.2, 8.4))


## THE LIGHTS ARE REALM 3'S OWN — its amber glowers, unpaired on purpose so no
## two ever sit level with each other and read as a pair of eyes.
func _lights() -> void:
	for spec: Array in [[-186.0, 62.0, 5], [178.0, 44.0, 1], [-96.0, 34.0, 12],
			[276.0, 52.0, 5], [-318.0, 38.0, 1]]:
		var g := _piece("mushroomglow%d.png" % int(spec[2]), float(spec[1]),
				Vector2(float(spec[0]), FLOOR + 6.0), 8, GLOW_WARM)
		var l := PointLight2D.new()
		l.texture = load("res://assets/effects/lantern_halo.png")
		l.color = GLOW_WARM
		l.energy = 0.66
		l.texture_scale = 2.6
		g.add_child(l)


# ---------- little builders ----------

## a clump of moss — Realm 2's tufts, tinted into this realm's teal.
##
## NOT a slice of a moss strip. That was tried as bulk in BOTH doorways and
## thrown out both times: the strip paintings are continuous full-width bands, so
## every region_rect slice of one lands as a visible rectangle with three cut
## edges. A tuft is a closed painted shape and has none.
## EIGHT SHAPES, NOT THREE. Three tufts placed thirty times came back as the same
## dark rosette repeating across the crown at the same size — a rhythm, which is
## the one thing the clustering is supposed to prevent. Realm 3's own hills join
## the vocabulary, the size jitters by a third either way, and the tilt is wide
## enough that two of the same shape never sit the same way up.
func _moss(x: float, y: float, h: float, z: int, k: float) -> Sprite2D:
	var s := _piece("fungalhill%d.png" % (1 + _rng.randi() % 5),
			h * _rng.randf_range(0.68, 1.34), Vector2(x, y), z,
			_dim(FUNGAL_TEAL, k * _rng.randf_range(0.8, 1.1)),
			_rng.randf() < 0.5, false, BASE)
	# MOSS SITS STRAIGHT. Advika circled four clumps lying over at 30-40°: moss
	# grows UP off whatever it is on, so a tilted tuft does not read as a tilted
	# tuft, it reads as a sprite someone rotated. The variety has to come from
	# shape and size, which is what the eight-file vocabulary above is for — the
	# tilt was doing nothing but making the crown look scattered.
	# BOTTOM-ANCHORED, ALWAYS. A hill is painted as a mound resting on ground: its
	# base is a straight line, and hung by its middle in mid-air that line shows —
	# the first pass with these put black flat-bottomed slabs across the crown.
	# `y` is therefore the row it RESTS on, and every caller passes a row that is
	# already covered by something.
	s.rotation_degrees = _rng.randf_range(-8.0, 8.0)
	return s


## a bottom-anchored piece, fitted to a drawn height in door-local units.
## `centred` beds it by its middle instead (the crown, which is not standing on
## anything — it is carried).
func _piece(file: String, h: float, pos: Vector2, z: int, tint: Color,
		flip := false, centred := false, dir := BASE) -> Sprite2D:
	var tex: Texture2D = load(dir + file)
	var s := Sprite2D.new()
	var sc: float = h / float(tex.get_height())
	s.texture = tex
	s.scale = Vector2(-sc if flip else sc, sc)
	s.position = Vector2(pos.x, pos.y if centred else pos.y - h * 0.5)
	s.z_index = z
	s.modulate = _dim(tint, FRAME_LIFT)
	add_child(s)
	return s


## a top-anchored piece, for anything that hangs
func _hang(file: String, h: float, pos: Vector2, z: int, tint: Color,
		dir := BASE) -> Sprite2D:
	var tex: Texture2D = load(dir + file)
	var s := Sprite2D.new()
	var sc: float = h / float(tex.get_height())
	s.texture = tex
	s.scale = Vector2(sc, sc)
	s.flip_v = true
	s.position = Vector2(pos.x, pos.y + h * 0.5)
	s.z_index = z
	s.modulate = _dim(tint, FRAME_LIFT)
	add_child(s)
	return s


## GENTLE SWAY, the Realm 1 doorway's rule verbatim: a piece rotated about its
## own centre SHEARS — a hanging frond would swing its anchor through the crown
## it grows out of. So the sprite is slipped under a pivot placed at the end it
## is attached by ("t" hangs, "b" stands, "c" is carried free) and the PIVOT
## turns. Nothing shares a period, or the whole doorway breathes in unison.
func _sway(sp: Sprite2D, pivot: String, amp: float, period: float) -> void:
	if sp == null:
		return
	var drawn_h: float = float(sp.texture.get_height()) * absf(sp.scale.y)
	var off := 0.0
	if pivot == "t":
		off = -drawn_h * 0.5
	elif pivot == "b":
		off = drawn_h * 0.5
	var piv := Node2D.new()
	piv.position = sp.position + Vector2(0.0, off)
	piv.rotation_degrees = sp.rotation_degrees
	sp.rotation_degrees = 0.0
	var idx := sp.get_index()
	remove_child(sp)
	add_child(piv)
	move_child(piv, idx)
	piv.add_child(sp)
	sp.position = Vector2(0.0, -off)
	_sway_specs.append({"piv": piv, "amp": amp, "period": period,
			"base": piv.rotation})


## THE SAME SPAWN AS REALM 1's DOORWAY (Advika: "the gateway follows the same
## spawn animation as r1s").
##
## It does not inflate and nothing climbs out of the ground. The doorway WRITES
## ITSELF DOWNWARD: every piece appears exactly where it belongs, ordered by its
## final Y — crown first, then the posts, the curtain, the base pile last — each
## dropping ~45px into place so the sweep has weight. An earlier version had the
## fragments materialise scattered in the air and fly home; it was built, shot,
## and rejected.
##
## The far side is NOT a piece of the frame. Threshold and PortalWindow are
## full-bleed planes filling the opening; they never move, and they open as an
## APERTURE afterwards (`open_portal`) — Realm 3 shows through only once there is
## something for it to show through.
# 1.2, halved. The wizard falls, his own death beat plays, and only then does the
# doorway begin writing itself downward -- so a 2.4s sweep landed the last piece the
# best part of five seconds after the kill, long enough that it read as unrelated to
# it (Advika: *"the door appears like 5 or 7seconds after the wizard dies"*). The beat
# is the same beat, crown first, one piece at a time; it just is not waited through.
const ASM_SWEEP := 1.2        # how long the top-to-bottom sweep takes
const ASM_LAND := 0.42        # one piece's drop
const ASM_DROP := 45.0        # how far above its place it starts

signal assembled


func assemble() -> void:
	var kids: Array = []
	for c in get_children():
		var n2 := c as Node2D
		if n2 != null:
			kids.append(n2)
	# topmost first: the sweep runs DOWN the doorway
	kids.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return a.position.y < b.position.y)
	var n: int = kids.size()
	var last: float = float(maxi(n - 1, 1))
	for i in range(n):
		var node: Node2D = kids[i]
		var f_pos: Vector2 = node.position
		var f_scl: Vector2 = node.scale
		var f_a: float = node.modulate.a
		if node.name == "Threshold" or node.name == "PortalWindow":
			node.modulate.a = 0.0
			continue
		var at: float = ASM_SWEEP * float(i) / last
		node.position = f_pos - Vector2(_rng.randf_range(-7.0, 7.0),
				ASM_DROP * _rng.randf_range(0.7, 1.3))
		node.scale = f_scl * _rng.randf_range(0.86, 0.95)
		node.modulate.a = 0.0
		# the drop and the fade are two tweens on purpose: chaining a parallel
		# block onto an interval binds the first parallel tweener to the WAIT,
		# so the piece would start moving during its own delay
		var ft := create_tween()
		ft.tween_interval(at)
		ft.tween_property(node, "modulate:a", f_a, ASM_LAND * 0.8) \
				.set_trans(Tween.TRANS_SINE)
		var mt := create_tween()
		mt.tween_interval(at)
		mt.chain().tween_property(node, "position", f_pos, ASM_LAND) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# BACK overshoots a hair and settles, so each piece seats itself
		mt.parallel().tween_property(node, "scale", f_scl, ASM_LAND) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# once the base rock has actually landed, the air starts moving and the
	# passage opens — never both at once
	var done := create_tween()
	done.tween_interval(ASM_SWEEP + ASM_LAND + 0.15)
	done.tween_callback(func() -> void:
		start_sway()
		open_portal(3.2)
		assembled.emit())


func start_sway() -> void:
	if _sway_started:
		return
	_sway_started = true
	for spec: Dictionary in _sway_specs:
		var piv: Node2D = spec.piv
		if not is_instance_valid(piv):
			continue
		var amp: float = spec.amp
		var base: float = spec.base
		var period: float = spec.period
		piv.rotation = base + _rng.randf_range(-amp, amp)
		var t := create_tween().set_loops()
		t.tween_property(piv, "rotation", base + amp, period * 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(piv, "rotation", base - amp, period * 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## THE PASSAGE OPENS AS AN APERTURE, NOT AS A FADE.
##
## Realm 1 learned this the expensive way: three attempts faded the far side in
## on alpha and every one of them read as a translucent rectangle, because a
## rectangle at 20% opacity is still a rectangle. What opens is the MASK — a
## small soft chink at the centre widening to fill the passage, with the feather
## blooming from 0.85 down to its real value (it is a FRACTION of radius, so at
## 12% size the normal value is a few pixels and the chink comes out as a hard
## little box).
func open_portal(dur: float = 3.0) -> void:
	for p: Dictionary in _portal_parts:
		var node: Node2D = p["node"]
		# `assemble()` parks these at zero alpha; the aperture is the mask, but
		# they still have to be present for the mask to reveal anything
		if is_instance_valid(node):
			node.modulate.a = 1.0
		var mat: ShaderMaterial = p["mat"]
		var full: Vector2 = p["radius"]
		mat.set_shader_parameter("radius", full * 0.12)
		mat.set_shader_parameter("feather", 0.85)
		var t := create_tween().set_parallel(true)
		t.tween_method(func(v: float) -> void:
				mat.set_shader_parameter("radius", full * v), 0.12, 1.0, dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_method(func(v: float) -> void:
				mat.set_shader_parameter("feather", v), 0.85, 0.30, dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _flat_tex(c: Color) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)
