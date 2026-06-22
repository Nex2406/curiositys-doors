# Realms

Each realm is one door, one theme, one puzzle, one lore fragment. Realms are small, deliberate, and committed. No procedural content. No filler.

---

## Realm Template

```
### [Name]
**STATUS:** drafted | in-design | in-build | shipped
**Door Tag:** realm:slug

- **Theme:**            (one phrase)
- **Emotional core:**   (the feeling the realm leaves on the player)
- **Palette shift:**    (how the base palette drifts here — colors, ratios, mood)
- **Soundscape:**       (ambient bed, instrumentation, sonic motifs)
- **Puzzle mechanic:**  (what the player does — kept abstract until designed)
- **Lore reveal:**      (what fragment of the larger story this realm surfaces)
- **Door appearance:**  (how the door reads in the hub — material, light, sound, posture)

- **Open questions:**   (notes, to be resolved via issues)
```

Use this template for every new realm. Fill it in before writing any scene code.

---

## Drafted Realms

### Realm 1 — The Crimson Hollow
**STATUS:** BUILDING (2026-06-22) — full spec below; first realm to receive a real puzzle/combat loop
**Door Tag:** realm:crimson-hollow

- **Theme:** warm ember cave; the first descent. Patience and footing.
- **Emotional core:** small, alight, and climbing through the dark toward a debt repaid.
- **Play loop (the "obby"):** a ~90-second platforming course (current door-to-door
  is ~14s — far too short). Real platforming: **moving platforms**, vertical and
  lateral traversal, hazards. Curiosity uses **slash / dash** (existing combat
  sprites) to kill **small black creatures** that attack along the route.
- **Collectible:** **jade pieces**, coin-like, scattered across the course
  (target **8** — jade/prosperity number; alt idea: **5** = Confucius's five
  virtues of jade, one per piece). Tracked via SaveManager.
- **The keeper (NPC):** the **smoke/ghost spirit** from the Intro (the one that
  twirls over the cauldron) waits at the **end** of the course. Curiosity gives
  it all the jade; it forms and hands back a **key**.
- **Gating:** the key is carried to the **Hub** and **inserted at Door 2** to open
  it (deliberate unlocking beat, save-backed so it stays open).
- **Damage model:** **health + respawn** — hearts; lose them to creatures/hazards
  and respawn at the last checkpoint.
- **Optional hazard (deferred):** **shooting stars** raining onto the course to
  raise difficulty. Build the base loop first; add only if it plays too easy.
- **Lore reveal:** what jade *means* to Curiosity (origin hint?), surfaced through
  the spirit's exchange. Exit line currently: "The dark grew careful where her
  lantern had been." (Curiosity is they/them in all prose.)
- **Door appearance:** placeholder arch for now; ornate art is a later lift.

### Realm of Forgotten Names
**STATUS:** drafted — gameplay TBD
**Door Tag:** realm:forgotten-names

- **Theme:** memory that has lost its referent
- **Emotional core:** the ache of recognizing something whose name you cannot retrieve. Familiarity without grasp.
- **Palette shift:** cold blue-grey; near-monochrome; lantern gold reads as the only living color. Whisper-pale highlights on stone.
- **Soundscape:** distant murmured voices, never quite words. Soft choral pad in a minor key. Single high bell tone, occasional, irregular. Wind that carries syllables it then drops.
- **Puzzle mechanic:** TBD — leaning toward something about ordering or matching fragments where the *meaning* is obscured. To be resolved via issue.
- **Lore reveal:** Curiosity is not the first traveler. Others came, opened doors, and left their names behind here.
- **Door appearance:** tall, pale, faintly luminous. Names written on the lintel in a script that blurs when looked at directly. Hums at a low choral pitch.
- **Open questions:** Does the hero retain partial names? Do collected fragments persist back in the hub?

### Realm of Quiet Hunger
**STATUS:** drafted — gameplay TBD
**Door Tag:** realm:quiet-hunger

- **Theme:** longing for warmth that stays just out of reach
- **Emotional core:** the slow ache of *almost*. Light visible through a window you cannot enter. The smell of bread without a kitchen.
- **Palette shift:** amber and rust foreground, deep cold blue background. The warm side of the palette dominates the near plane; the world beyond is cold. Inversion of the usual ratio.
- **Soundscape:** distant fire crackle, faint clinking of dishes, a low cello drone, breathing. A door we cannot find creaks open and closed somewhere off-screen.
- **Puzzle mechanic:** TBD — possibly something about the lantern being borrowed, returned, given away. To be resolved via issue.
- **Lore reveal:** the lantern was given, not made. By whom is the question this realm refuses to fully answer.
- **Door appearance:** warm-edged, slightly ajar. Light spills from the seam in a thin honey line. Hums at a frequency that resembles a held breath.
- **Open questions:** Is hunger literal in this realm or only metaphorical? Does the hero's lantern dim while inside?

### Realm of the Folded Hour
**STATUS:** drafted — gameplay TBD
**Door Tag:** realm:folded-hour

- **Theme:** time that loops, repeats, or refuses to advance
- **Emotional core:** the unease of recognizing a moment you have already lived. Déjà vu sustained until it becomes architecture.
- **Palette shift:** desaturated grey-violet. Almost colorless. The lantern gold reads as oversaturated by contrast — too bright, too present.
- **Soundscape:** a clock ticking out of sync with itself. Reversed reverb. A melodic phrase that begins, restarts, begins, restarts. Silence between attempts is unusually long.
- **Puzzle mechanic:** TBD — repetition, layering, or partial-state-carryover are the candidate verbs. To be resolved via issue.
- **Lore reveal:** the hub itself may be a folded hour. Curiosity may have opened these doors before.
- **Door appearance:** identical to itself reflected. Two doors that are one door. The handle is on both sides.
- **Open questions:** Is the loop visible to the player from the start, or does it reveal? Does solving the puzzle mean escaping the loop or accepting it?

---

## Future Realms (placeholders only)
- A realm of weight (gravity, burden, what one carries)
- A realm of mirrors (selfhood, recognition)
- A realm of letters never sent (regret, communication)
- A realm of small things (scale shifts, intimacy)

These are not committed. Open an issue to promote one to drafted.

---

## See also

- [`CLAUDE.md`](../CLAUDE.md) — repo-wide engineering guide; Quality Gate; Session Start Protocol
- [`docs/STATE.md`](STATE.md) — single living snapshot of what's wired right now; updated every session
- [`docs/SESSIONS.md`](SESSIONS.md) — append-only build log: shipped / didn't / next 3 per session
- [`docs/VISION.md`](VISION.md) — north star: hero, hub, realms, the three bars (visual / technical / narrative)
- [`docs/MECHANICS.md`](MECHANICS.md) — engineering reference: implemented vs planned systems
- [`docs/ART_DIRECTION.md`](ART_DIRECTION.md) — painterly bible: palette hexes, lighting model, scale rules
- [`docs/STORY.md`](STORY.md) — narrative scaffolding: plot beats, tonal constraints, voice rules
- [`docs/VIBE.md`](VIBE.md) — tone allow/deny lists; sanity check before naming or writing
