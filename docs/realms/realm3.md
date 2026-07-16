# Realm 3 — The Bloom (fungal forest)

> Promoted from `docs/SKETCHBOOK.md` (2026-07-15) + design decisions with
> Advika (2026-07-16) + canon threads mined from *Written by Silence*
> (the book is the source — see `docs/VOICE.md`). Environment shell is
> LIVE on main (`Realm3FungalTest.tscn`): teal mood + ref pebble-rim
> grammar, set-pieces kept rare. This doc is the realm's *content* spec.

## The arc in one breath

Descend into dread → wake the heart by accident → ride the bloom out.
Rhymes with Realm 2 but flipped: R2 rises into a fight; R3 sinks into a
memory. Two play-feels inside one door.

## Decisions (locked 2026-07-16, Advika)

- **Act 2 is a ritual wake, not a boss.** No health bar. Approach, touch,
  witness. Keeps R3 distinct from R2's wizard fight.
- **Curiosity wakes her by accident.** They can't help but look/touch —
  curiosity IS the trigger. No villain anywhere in this realm.
- **Act 3 pressure = all three:** the rising light wave below (the bloom
  itself as kill-plane), mushrooms detonating around them on timers, AND
  a pursuer.
- **Build order: bounce prototype first** (isolated rig, RuneOrbTest
  style) — riskiest feel in the concept; if bouncing isn't fun, Act 3
  changes shape.

## Canon grounding (from the book — these are quotes/laws, not inventions)

- **The floor gives way.** Grief, in the Chapel: "Come. It's time you saw
  what you started" — and the floor drops Curiosity into the Hollow.
  Act 1 opens with the same grammar: a low hum through the ground, then
  the split. Slow, deliberate. Never a jump-scare.
- **The Mother = remembering that learned how to stand.** The book's
  recurring engine: Joy is "the accumulation of Grief's mistakes"; the
  Girl exists because "he remembered too deeply, and the remembering
  learned how to stand." The Mother is the forest's accumulated memory
  of everything it ever consumed — vast, dormant, unwitnessed. Not a
  god. Not a monster. An archive that grew a heartbeat.
- **The wake is recognition, not conquest.** The Tower card under
  Curiosity's touch: "lit up like it had been waiting for them — not to
  be claimed, but to be REMEMBERED." The Mother wakes the same way.
- **The Bloom = the archive releasing.** The Hollow's law: "You don't
  take from the Hollow. You become part of it." Waking the Mother
  releases everything the forest kept — an eruption of remembered light,
  racing upward. Beautiful violent release; the realm's theme word.
- **The pursuer is a Remembered One.** A consumed traveler's memory,
  given shape by the waking (Girl-logic). It doesn't hate Curiosity —
  it wants them to STAY. Everything in this universe that loves you
  tries to keep you. Grabbing, reaching, mournful. Never armed.
- **Cloak-eyes react to the vast** (book: they go still when something
  immense watches; they vanish in the void). LivesHUD eyes: still in
  the Heart chamber, one closed beat at the wake.
- **Amber = buried joy.** Joy's threads sleep "curled tight and hidden"
  inside people. Travelers flicker amber under the lantern (GLOW_WARM).

## The three acts

### Act 1 — THE DESCENT
Quiet fungal forest (the shipped shell) → the floor gives way →
Curiosity sinks INTO the mycelium. Tighter, darker, stranger downward;
the lantern is the only warmth. In the spore-glow: the travelers the
forest consumed — overgrown silhouettes, half-swallowed. They flicker
amber as the lantern passes, then dim. One of them hums.
Play-feel: careful, lantern-lit, dread that accumulates.

### Act 2 — THE HEART
The bottom. The Mother: a vast dormant mass fused into the cavern
(layered illustration, wake staged in light/modulate, no frame anim).
Heartbeat audio + a half-remembered hummed lullaby. Curiosity's
approach/charged animations (imported, unwired — this is their moment)
carry the touch. She lights up like she had been waiting to be
remembered. The HUD eyes close for one beat.

### Act 3 — THE BLOOM
The forest detonates into light. Flee upward: bounce-launch off
mushrooms that burst and grow underfoot, racing the rising wave of
remembered light. Mushrooms detonate around them; the Remembered One
climbs after them, reaching. Caught = kept (absorbed, respawn beat).
Play-feel: fast, reactive, momentum. The realm exhales them out the
exit door as the light settles back down into the dark.

## Asset needs (who makes what)

**Advika:**
- Traveler / Remembered One silhouettes (ONE design serves both — 2-4
  still poses for Act 1 flickers; the pursuer variant animates in-code)
- The Mother: big layered illustration (body mass + eye/glow layers,
  2-3 wake stages)
- Audio: descent ambient (drips, deep hum), Mother heartbeat + hummed
  lullaby (Advika could record the hum herself), the wake sound, the
  eruption roar, escalating escape music (trailer material)

**In-code (no new art):**
- Floor collapse, descent shaft (fungal pack + deepening grade)
- Bounce mushrooms (existing caps + squash/stretch/grow tweens + spore
  particles), the light wave (shader + particles + existing glow hues),
  wake staging, eye-HUD beats

## Parked / later

- The jade key contradiction: in the book the key "isn't for opening
  anything" — but the game plan says jade key unlocks Door 2. Possible
  reconciliation: the key doesn't unlock; the door WAKES when
  remembered, like everything else. Decide with Advika before Door 2's
  key beat ships.
- Does the Mother almost-speak Curiosity's other name (the one Silence
  knows)? Endgame material — R3 could tease it at most. Advika's call.
- Any spoken/written lines: Advika writes them (no-added-text law;
  Claude may draft in voice for approval only).
