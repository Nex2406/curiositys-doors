# Realm 2 — The Rising Chunk *(working name)*

> Living spec. Last updated: 2026-07-12. Vertical arena setpiece — the storm
> tears the ground loose and Curiosity rides it into the sky. Full pitch:
> [SKETCHBOOK 2026-07-04](../SKETCHBOOK.md).

---

## What it is
The contrast realm. Realm 1 is quiet horizontal cave traversal; Realm 2 is a
loud vertical arena. Curiosity walks in on flat mossy ground, a storm hits, the
storm tears the middle chunk loose and lifts it — Curiosity rides the rising
island, survives everything the storm throws at them, and steps through a door
in the sky.

## The verb
Survive the ascent — fight, dodge, hold on.

## Palette / feel
Purple, low-lit, cloak-colored (settled 2026-07-04) — the realm is made of the
same stuff as the hero. Deep violets, dim base, lantern gold as the one warm
accent. The storm is the realm's engine: it lifts the chunk, throws the
lightning, drives everything.

## Build phases (R2-M#)

Realm 2 is technical enough that it gets its own milestone ladder. Each phase
is one shippable brick: its own branch/PR, directly testable (boot straight
into it), leaves the realm playable end-to-end at whatever depth exists so far.

### ✅ R2-M0 — Living background *(merged 2026-07-04)*
The violet moss canopy in motion: parallax spire bands, swinging strands,
breathing gold pocket, fireflies/spores/fog/storm wisps.
`scenes/realms/Realm2BgTest.tscn`.

### ✅ R2-M1 — Quake + liftoff *(merged 2026-07-07)*
Flat-ground intro → quake → the storm tears the island loose → seamless ascent
with Curiosity planted as a rider. `LevitatingIsland` component, camouflaged
embedded island waking to color at the tear, seamless moss ground body,
fall→eye→blink-respawn death beat. `scenes/realms/Realm2LiftTest.tscn`.

### ✅ R2-M2 — Curiosity learns to fight *(was already shipped — golem work)*
Discovered done on main (2026-07-07): attack1/attack2 combo, dash, hurt,
health/invuln/knockback, `died` signal, eyes-as-lives HUD, death restart —
built during the Realm 1 golem sessions, proven in `GolemTest.tscn`. The
"combat unwired" claim in older docs was stale.

### R2-M3 — Enemy base + the first slime
Reusable `Enemy` base (spawn / approach / attack / take damage / die) proven on
one slime that can reach the flying island. One slime, killable, dangerous.
*Forces the decision: how do enemies reach the chunk — fly, climb, drop from
the storm?*

### R2-M4 — Wave director
Waves of slimes tied to the ascent — the climb IS the difficulty curve.
Spawn timing, escalation, breathing room between waves.
**Pacing DECIDED (Advika, 2026-07-08): continuous rise, boss-gated — the
island keeps climbing until the wizard falls (wired at R2-M7).** The wave
director paces spawns against an open-ended ascent, and the corridor
dressing must generate/recycle procedurally past its hand-tuned span.

### R2-M5 — Storm hazards
Telegraphed lightning strikes on the island — see it coming, dodge it — plus
whatever "other stuff" the storm throws. Screenshake, flash, scorch.

### R2-M6 — Potion orb
Ingredients to gather on the island mid-fight → brew → the **orb**, Curiosity's
first ranged weapon. *Forces the decision: is orb-brewing the realm's "puzzle"
beat, or a side weapon?*

### R2-M7 — The Wizard (boss)
The ascent tops out — and the storm's author is waiting. Boss fight against
the wizard (`BlueWizard Animations` pack, Downloads): a dark mirror of
Curiosity — hooded, hidden face, glowing eyes. Caster boss: the pack only has
idle/walk/jump-dash frames, so attacks are storm magic (projectiles,
lightning), teleport-blinks reuse jump/dash, hurt = flash/knockback, death =
dissolve. First consumer of the reusable `Boss` base (milestone M2).
Small enemies come FIRST (R2-M3/M4) — the waves teach the combat verbs the
boss then tests. *(Advika, 2026-07-08)*

**Groundwork SHIPPED 2026-07-12 (#151):** his look is settled — cloak
purple (measured shift onto the realm violet), eyes RED (Advika: the player
reads evil at a glance). Assets: `assets/enemies/wizard/` (96 frames,
repeatable shift via `tools/tint_wizard_pack.gd`); actor:
`scenes/Wizard.tscn`; review window: `tools/WizardAnimReview.tscn`.

**THE TRIAL SHIPPED 2026-07-12 pt.2 (#155):** the wizard FIGHTS in the
ascent now — the design crystallized in live playtest with Advika:
- He is THE CONJURER: teleport-blinks across the island (blink_a smear
  fwd/back = tp out/in; landings scatter, avoid Curiosity, escape-reflex
  at 340px with a 0.6s per-landing grace), casting RUNE ORBS in front of
  himself — max 2 on deck, in-flight smoke counts.
- Rune orbs (`RuneOrb.tscn` + `OrbConjure.tscn` + `OrbSpawner.gd`):
  INVULNERABLE rolling shove-hazards — real inertia, push (never damage,
  `Curiosity.shove()`), ride the island like she does, overstay 8-14s then
  commit to a direction and roll off the edge. Movement is the only
  counterplay; her jump is +15% this level.
- WIN: five strikes (her normal swing; he panic-teleports per hit;
  EnemyHealthBar) → died → `stop_levitation()` → arrived → DONE — **the
  boss gate is closed**: "the wizard falls — the storm relents".
This trial IS the wizard fight's first playable form; R2-M7 proper deepens
it (real phases, storm magic). Still open: the intro dialogue beat
(DialogueCard vs existing DialogueBox — Advika decides) + instructions
window that should gate `start_trial()`.

### R2-M8 — Sky door finale
Defeating the wizard calms the storm; the door in the sky reveals itself.
Arrival beat, one-line exit lore (needs the realm's emotional word — Advika),
hub return, save/persistence (RealmBase).

### R2-M9 — Sound + polish
Storm ambience + SFX (thunder, slime, orb, lightning), particle/feel pass,
A/B against `assets/_reference/realm2_bg_target_2026-07-04.png`, full
end-to-end playthrough on the live web build.

## Open questions
- Enemy design: slimes settled as the wave creature? What do they look like —
  and how do they reach a floating island? *(forced by R2-M3; candidate
  answer since the wizard became the boss: he conjures them / drops them
  from the storm)*
- ~~Chunk pacing: continuous rise, or rise-between-waves?~~ **Answered
  2026-07-08: continuous, boss-gated — the island rises until the wizard
  is defeated.**
- Is orb-brewing the realm's puzzle beat? *(forced by R2-M6)*
- The realm's emotional word — palette is set, the *feeling* is unnamed.
  *(needed before the R2-M7 lore line)*
- What does Curiosity carry OUT of Realm 2? (Realm 1 = jade key → Door 2.
  Later realms riff on "what you carry out matters", not repeat it — the orb?)
- Which door in the hub leads here, and how does it unlock? (Currently: jade
  key unlocks Door 2.)
