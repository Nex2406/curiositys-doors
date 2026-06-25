# Sketchbook

Rough thoughts, half-ideas, things to come back to. Dated. Not committed to.

Rules:
- Anything Advika says that's idea-shaped but not nailed down lands here.
- New entries go at the top. Don't edit old entries — let them sit as history.
- An idea that gets promoted into INTENT.md or a realm spec can be ticked through here.

---

## 2026-06-25

- **Jade pieces = collectibles on the moving platforms, guarded by golems.**
  Sharpens the 2026-06-22 jade-hunt vision now that moving platforms are live.
  - Jade pieces sit **on the moving platforms** — you ride a platform to reach
    one and collect it (walk/jump into it). Count tracked + saved (SaveManager).
  - **Golems guard them** — the realm's first real enemy. Advika has golem
    sprites (and will provide the jade art). This is M2's enemy framework landing
    *inside* Realm 1: build a reusable `Enemy` base on the golem (patrol / detect /
    attack / take damage / die), reusing the slash/dash combat already on
    Curiosity.
  - Still feeds the long arc: collected jade → assembles the key → unlocks Door 2.
  - Open: how many jade total? golem behaviour (stationary sentinel vs patrol)?
    does a golem block the jade until killed, or just threaten? — settle when the
    art's in and we prototype.

## 2026-06-22

- **Realm 1 becomes a real platformer (the full vision).** Advika nailed down
  what the Crimson Hollow actually *is* to play, not just walk through:
  - **Core loop:** a platforming course ("obby") where Curiosity collects
    **scattered jade pieces**. The pieces assemble into a **key** that unlocks
    **Door 2** in the hub. (Closes the long-open "jade key = Realm 1 closer"
    thread from 2026-05-17.)
  - **Platforming:** real challenge — **moving platforms**, vertical/lateral
    traversal, not a flat stroll.
  - **Combat:** small **black creatures/enemies** that attack Curiosity;
    Curiosity kills them with the **slash / dash** moves (the attack/dash
    sprites we already have but never wired — this is M2's combat brick landing
    *inside* Realm 1).
  - **Hazard (debating, not committed):** **shooting stars** raining onto the
    course that damage Curiosity / knock them off, raising difficulty. Advika
    is undecided — hold as optional polish layer, add only if the base obby
    feels too easy.
  - **Length target:** current run is **~14 seconds** door-to-door (Advika
    timed it) — way too short. Target **~90 seconds** of engaged play. The jade
    hunt + platforming + enemies are what fill that time, not just a longer
    hallway.
  - Pronoun note for any lore/prose: Curiosity is they/them.

## 2026-06-09

- **Realm 1 mood: cold → warm.** Tried a cool blue-grey ambient `(0.34,0.36,0.44)`
  for "moody dark cave." Advika didn't connect with it. A throwaway debug test
  cranked the tint hard red — Advika immediately loved it. Because
  `CanvasModulate` *multiplies* the teal cave art, even a bold red reads as a
  warm **ember** glow, not alarm: rocks go orange, the water stays cold teal,
  Curiosity glows like a coal in the split. Landed on `(0.9,0.2,0.2)`. This
  pulls Realm 1 back to its canon name — **The Crimson Hollow** — which the
  cool blue had quietly drifted away from. Lesson: the warm accent wants a warm
  *world* to live in here, not a cold one to fight. Lantern also now breathes
  (cast-light energy flicker on two out-of-phase sines) so the pool feels alive.

## 2026-06-08

- **Combat & bosses are in scope.** Advika: each realm is its own dimension,
  and they want *new characters / bosses* that Curiosity fights inside these
  levels. Goal stated as "a fully playable, innovative 2D platformer." This
  promotes the currently-unwired attack1/attack2/hurt/dash/charged animations
  from dormant to needed. Combat verb is now part of the game's identity, not
  just traversal + puzzles.
- **Milestone-driven build model.** One milestone at a time; do not proceed
  to the next until the current is *ready*. Ultimate v1 = a publishable game
  with 3 full levels (Hub + Doors 1/2/3, each a complete realm). After v1
  ships, keep adding levels. Always keep the project + Advika aware of which
  milestone is active.
- **v1 must-haves (Advika):** save/load, Curiosity textboxes, per-realm
  ambient audio, title/menu screen, per-realm distinct theme ("separate
  dimension"), and boss/enemy encounters.
- **Realm 2 & 3:** no concepts yet — design each *with* Advika as its own
  gate before building.

## 2026-05-17

- **Realm 2: open.** Advika doesn't have the concept yet. Don't push. Come back to it next time something sparks.
- **Jade key, Realm 1 closer:** open question — what does jade *mean* to Curiosity? Is it a familiar material? Is it the first hint of their origin? Lore not yet written.
- **Cave vs. jade color clash:** Realm 1 is currently "The Crimson Hollow" (red-brown cave). Jade is green. Worth checking if the contrast reads as intentional (jade glows against red rock = striking focal points) or accidental (palette feels confused). Visual A/B once jade-piece art exists.
- **Variety-per-realm is the differentiator.** "What makes the game different from any other basic platformer" — each realm is its own concept, its own play feel. Carry this rule forward when proposing future realms; don't propose realm-2 as "same loop with different art."
