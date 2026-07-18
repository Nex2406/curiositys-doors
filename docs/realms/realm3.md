# Realm 3 — The Bloom (the fungal forest / the Hollow's grave)

> Promoted from `docs/SKETCHBOOK.md` (2026-07-15); decisions locked with
> Advika 2026-07-16 (two rounds). Canon: *Written by Silence* — this is
> the FINAL realm of v1 and it is explicitly set in the book's aftermath.
> Environment shell is LIVE on main (`Realm3FungalTest.tscn`).

## What this realm is (the reveal)

**The fungal forest grew over the ruins of the Binding Hollow** — Grief's
collapsed library, the archive of every ended life. Mycelium feeds on
dead matter; this forest feeds on the book's dead. The "travelers" the
forest consumed are names from Grief's ledger, half-grown-over. And at
the bottom, still breathing, is the **Heart of the Hollow** — the
archive's surviving core, swollen with everything Grief made it hold
("I can't hold much more of you, Grief"). It was never malicious. It
was never witnessed. It sleeps because no one ever came down to
remember it.

Waking it is the finale of v1.

## Decisions (locked 2026-07-16, Advika)

- **The sleeper = the Binding Hollow's heart** (was "the Mother" in the
  sketch — name retired).
- **The game's villain = Consciousness.** Revealed here, not fought.
  The ladder: R1 golems (set guardians) → R2 wizard (the storm's
  author, an AGENT) → R3 the author of the authors shows its hand.
- **Act 2 is a ritual wake, not a boss.** Approach, touch, witness.
- **Curiosity wakes it by accident** — curiosity IS the trigger.
- **Act 3 pressure = all three:** rising bloom-light below, bursting
  mushrooms around, a pursuer behind — PLUS the correction above (see
  finale).
- **Ending = defiant tease.** No confrontation scene. One lore line,
  Advika-written ("What happens if we refuse?" energy — her call).
- **Build order: bounce prototype first** (isolated rig; riskiest feel),
  then the float/flip movement rig (Underhollow), then combat wiring.
- **The Underhollow (Act 1.5)** — the fall becomes a floating,
  topsy-turvy traversal-and-combat passage through the ruined archive
  (Advika, 2026-07-16). Low-grav drift + authored gravity-flip beats;
  Remembered Ones as grabbing keepers.
- **Concept frame approved direction:**
  `assets/_reference/bloom_finale_mock_2026-07-16.png` (built from real
  pack + hero art via `tools/BloomMock.tscn`; re-render with
  BLOOM_SHOT=<path>).

## The four acts

### Act 1 — THE DESCENT
Quiet fungal forest (the shipped shell) → a hum through the ground →
the floor gives way (canon echo: the Chapel scene — "It's time you saw
what you started"). Curiosity sinks into the mycelium. Downward the
forest admits what it is: **buried shelves fused into the walls,
book-spines swallowed by fungus, ledger-names** — and the travelers,
overgrown silhouettes that flicker amber under the lantern (Joy's
buried threads). One of them hums Grief's first lullaby.
Play-feel: careful, lantern-lit, accumulating dread.

### Act 1.5 — THE UNDERHOLLOW: the map writes itself
(Advika 2026-07-16, two beats: "topsy turvy — falls in the ground,
floating, has to fight" + "the ground crumbles into bits and pieces and
REARRANGES itself as Curiosity travels — the map is literally making
itself as they go down.")
CANON: the Hollow's shelves "rose and fell with no gravity to guide
them"; "The Hollow shifted. Shelves groaned softly, realigning
themselves with purpose. It was guiding me."; the Tower "doesn't just
collapse. It rearranges."
**The underground has no map — it is a map being written:**
- Ground **crumbles under Curiosity** into the same pebble-pieces the
  masses are built from; behind them the path un-builds — no way back.
- Ahead/below, **debris flies in and assembles**: pebbles snap into
  rim-lines, fills grow between them, shelves slide from walls to
  become platforms exactly when needed. The Hollow authors the level
  around the player in real time.
- **It ESCALATES downward:** near the surface, crumble+rebuild under
  normal gravity → deeper, gravity loosens and pieces AND Curiosity
  drift (low-grav base + authored gravity-flip beats) while the map
  keeps assembling → the Heart.
- **Guiding, then gripping:** on the way DOWN the Hollow builds FOR
  them (it wants to be witnessed). After the wake, the same system
  builds AGAINST them — walls closing, pieces gripping — it wants to
  KEEP them. Same mechanic, flipped intent = the realm's betrayal beat.
- **Combat: the Remembered Ones** — hooded echoes drifting out of the
  dark; they GRAB and pull toward the walls. Curiosity fights free
  with the slash/dash kit. They don't hate; they miss.
Play-feel: the floor is a sentence being written under your feet.
**Prerequisites: the rearrange rig is now the #1 prototype (riskiest,
most load-bearing system), then bounce, then M2 combat wiring — all
REQUIRED by R3.**

### Act 2 — THE HEART
The bottom: the Heart of the Hollow — a vast breathing archive-mass,
pulsing like the crystal chamber did. The HUD cloak-eyes go STILL
(canon: they fix when something immense watches). Curiosity's
approach/charged animations carry the touch. The Heart lights up
"like it had been waiting — not to be claimed, but to be REMEMBERED."
The eyes close for one beat. Heartbeat audio + the hummed lullaby.

### Act 3 — THE BLOOM (the finale of v1)
Every life the Hollow kept erupts UPWARD as light — the Tower made
real ("the top broken open, stone spilling upward instead of down";
Curiosity has carried that card since before the game began).
Flee up on burst-and-grow mushroom bounces. Three pressures:
- **Below:** the rising amber bloom — beautiful, wants to keep you
- **Around:** mushrooms detonating on timers
- **Behind:** the Remembered One — a consumed traveler's memory given
  shape by the waking; it reaches, never strikes; caught = kept
Then the sky tears: **Consciousness notices.** Cold white light falls
in straight lines (book-accurate), unmaking the bloom as it descends —
the correction. The climb becomes a race BETWEEN two vast forces, one
warm and rising, one cold and falling, with one small lantern in
between. Curiosity escapes as the two lights collide behind them.

**Ending beat:** quiet exit, the forest dims, one lore line (Advika
writes it), cut. The villain is revealed by a SKY, not a cutscene.
v1 closes on defiance; later realms inherit the war.

## Asset needs (who makes what)

**Advika:**
- Traveler / Remembered One silhouettes (one design serves both)
- The Heart of the Hollow: big layered illustration (archive-mass +
  eye/glow layers, 2-3 wake stages)
- Audio: descent ambient, heartbeat + hummed lullaby (Advika records
  the hum), the wake sound, the eruption roar, escape music, and the
  correction's sound (cold, clean, wrong — against the warm roar)
- Optional: buried shelf/spine silhouettes for the descent walls (can
  be code-built dark shapes if not)

**In-code (no new art):**
- Floor collapse, descent shaft, ledger-name dressing (silhouette work)
- Bounce mushrooms (existing caps + tweens + particles)
- The bloom wave (shader + particles + existing glow hues)
- The correction (white line-rain shader + time-stutter effect)
- Wake staging, eye-HUD beats (still / close)

## Canon anchors (for future sessions — quotes are from the book)

- The floor gives way beneath Curiosity: Chapel scene, Grief.
- "You don't take from the Hollow. You become part of it."
- The Hollow: "I can't hold much more of you, Grief." / it "has a habit
  of filling empty rooms."
- Wake-by-touch: the Tower card "lit up like it had been waiting for
  them, not to be claimed, but to be remembered."
- Remembering that accumulates "learns how to stand" (Joy, the Girl).
- The Tower: "its top broken open, stone spilling upward instead of
  down"; "it doesn't just collapse. It rearranges… it invites things in."
- The correction: "White flame fell in straight lines. Where it struck,
  time stuttered." / "Return, or be unmade."
- Curiosity's answer — the whole game's thesis: "What happens if we
  refuse?"
- Epilogue: a child before a ruined cathedral, ash, open doors — the
  cathedral ruin is a candidate look for R3's entrance/door dressing.

## Parked / later

- Jade key contradiction (book: the key "isn't for opening anything") —
  possible reconciliation: doors WAKE when remembered, they don't
  unlock. Decide before Door 2's key beat ships.
- Does the Heart almost-speak Curiosity's other name (Silence knows it)?
  Endgame material; R3 teases at most. Advika's call.
- All spoken/written lines: Advika writes them (no-added-text law).
