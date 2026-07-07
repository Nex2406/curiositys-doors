# Milestones — Curiosity's Doors

> The build plan. One milestone at a time. We do not advance until the current
> milestone is **ready**. Foundation-first: we spend time now building a reusable
> engine so every later level is ~10x cheaper to author.
>
> Living doc. Created 2026-06-08. The active milestone is always marked ▶.

---

## How we build (the operating model)

- **One milestone at a time.** No starting the next until the current is *ready*.
- **Foundation compounds.** Shared systems (combat, dialogue, save, audio, realm
  template) are built **once**, early. Every realm reuses them. The first realm is
  expensive; the third is cheap.
- **Every session ships something real.** Each milestone is cut into
  session-sized tasks. A session picks the next task → branch → PR → merge on
  green → updates `STATE.md`.
- **"Ready" has a fixed meaning** (see below). We don't move the goalposts.
- **No skipping the bones.** We don't fake a system to look done. If the
  foundation isn't right, the milestone isn't ready.

### Definition of "ready" (the gate every milestone passes)

A milestone is ready only when **all** of these are true:

1. `godot --headless --import` passes clean.
2. `godot --headless --export-release "Web" build/index.html` passes clean.
3. No regression — A/B against the prior live build (visuals, performance, feel).
4. Every PR referenced an issue (`Closes #N`).
5. The milestone's own **Done-when** checklist is fully ticked.

---

## The engine we are compounding

These are the reusable systems. Built once, reused by every realm forever. This is
the "10x later" investment.

- **RealmBase** — a scene/script template every realm inherits (entry, exit, lore
  hook, audio hook, save hook, camera). New realm = inherit + fill in.
- **Combat system** — Curiosity's attack moveset wired to the state machine;
  reusable `Enemy` base; reusable `Boss` base (health, phases, telegraphs);
  hurt / death / respawn.
- **Dialogue / textbox system** — Curiosity speaks (Advika writes the lines).
  Generalizes the existing one-line LoreMoment into a full sequenced system.
- **Save / load** — progress, doors opened, items held; survives a refresh.
- **Audio manager** — per-realm ambient bus + SFX hooks.
- **Door / unlock framework** — generalizes Realm 1's jade-key idea so each realm
  can define its own lock-and-key without rewriting plumbing.
- **Front-end** — title / menu / pause screens.
- **Art systems** — painterly lantern falloff, cloak / eye-blink / fog shaders
  (polish layer, applied per realm).

---

## The milestones

### ✅ M1 — Core engine foundations  _(complete 2026-06-12)_
*The compounding layer. Build the systems every realm reuses, proven on a throwaway test room — not on a real realm yet.*

- **Why now:** these get used by all 3 realms. Building them first means Realms
  1–3 are authoring, not engineering.
- **Scope:**
  - Save / load singleton (autoload). → `SaveManager` (#102)
  - Dialogue / textbox system (generalize LoreMoment → sequenced, Curiosity voice).
    → `Dialogue` service over existing `DialogueBox` (#104)
  - Audio manager (ambient bus + SFX hooks). → `AudioManager` (#106)
  - RealmBase template. → `RealmBase` + `TestRealm` (#108)
- **Done-when:**
  - [x] A throwaway `TestRealm` can be entered/exited via RealmBase.
  - [x] It can save state and restore it after a page refresh (per-realm state
        persists; restored on re-entry — proven in-realm via TestRealm).
  - [x] Curiosity can speak a multi-line sequence in the textbox system.
  - [x] It plays an ambient track on enter (placeholder drone until real tracks).
  - [x] All four "ready" gates pass.
- **Deferred (intentional, not gaps):** generalized Door/unlock framework folded
  into M3's jade-key loop (build it on the real realm, not abstractly); a
  title-screen "continue / resume on boot" flow is M6 front-end; retrofitting
  Realm 1 onto RealmBase is M3. Real ambient tracks + canonical dialogue lines
  are content (Advika), slot into the finished engine anytime.

### ▶ M2 — Combat & enemy/boss framework
*Curiosity learns to fight. Reusable enemy + boss bases, proven in a test arena.*

- **Why now:** combat is core to the game's identity and shared by every realm's
  boss. Build the framework once.
- **Scope:**
  - Wire Curiosity's attack / hurt / dash / charged animations into the state
    machine.
  - Reusable `Enemy` base (patrol, detect, attack, take damage, die).
  - Reusable `Boss` base (health bar, phases, telegraphed attacks, defeat beat).
  - Damage / knockback / hurt / death / respawn loop.
- **Done-when:**
  - [ ] Curiosity can attack and take damage in a test arena.
  - [ ] A placeholder enemy can be fought and defeated.
  - [ ] A placeholder boss runs at least 2 phases and a defeat beat.
  - [ ] All four "ready" gates pass.

### M3 — Realm 1 to ship-quality
*Apply the engine to the realm that already exists. First full vertical slice at the bar.*

- **Why now:** proves the engine on real content and sets the quality bar the
  other realms must match.
- **Scope:**
  - Jade pickups → jade key → Door 2 unlock loop (uses Door framework).
  - A Realm 1 boss (uses Boss base).
  - Lore beats (entry + jade-forging moment) in Curiosity's voice (Advika writes).
  - Per-realm ambient audio; painterly lantern; save integration.
- **Done-when:**
  - [ ] Realm 1 is fully playable end-to-end: traverse → fight → collect → exit →
        forge key → unlock Door 2.
  - [ ] Looks at the bar; A/B'd clean against prior build.
  - [ ] All four "ready" gates pass.

### M4 — Realm 2 (design + build)
*Its own dimension, its own verb, its own boss. Design locked with Advika before building.*

> Realm 2 turned out technical enough to get its own phase ladder — see
> [`docs/realms/realm2.md`](realms/realm2.md) (R2-M0 … R2-M8). Note: it started
> ahead of M2/M3 in practice; the combat framework (M2) lands *inside* Realm 2
> as phases R2-M2/R2-M3, built reusable as always.

- **Why now:** with the engine + bar set, this is mostly authoring.
- **Scope:**
  - **Gate A — Design:** interview Advika; lock theme, palette, puzzle/verb, boss,
    lore beat, unlock method, what carries forward. Write the realm spec. *No
    building until this is locked.*
  - **Gate B — Build:** build using RealmBase + combat + dialogue + audio + door
    framework. Distinct from Realm 1's loop.
- **Done-when:**
  - [ ] Realm 2 spec written and approved.
  - [ ] Realm 2 fully playable end-to-end at the bar.
  - [ ] All four "ready" gates pass.

### M5 — Realm 3 (design + build)
*Same shape as M4. Should be the cheapest realm yet — the engine has paid off.*

- **Scope:** Design gate (interview → spec) then Build gate (author on the engine).
- **Done-when:**
  - [ ] Realm 3 spec written and approved.
  - [ ] Realm 3 fully playable end-to-end at the bar.
  - [ ] All four "ready" gates pass.

### M6 — Publish v1
*Wrap the 3-level game into something that feels published.*

- **Scope:**
  - Title / menu / pause screens.
  - Save flow verified across all 3 realms + hub.
  - Full polish pass (audio mix, transitions, shader pass, edge cases).
  - Publish the playable 3-level build.
- **Done-when:**
  - [ ] Title → play → 3 realms → return loop works start to finish.
  - [ ] Published build is live and A/B clean.
  - [ ] All four "ready" gates pass.

---

## After v1

The engine is built. New levels become a repeat of the M4/M5 shape:
**design gate → build gate**, each cheaper than the last. v1 is the foundation;
every realm after it compounds on this base.

---

## See also

- [`CLAUDE.md`](../CLAUDE.md) — engineering guide; Quality Gate; Session Start Protocol
- [`docs/STATE.md`](STATE.md) — what's wired right now
- [`docs/INTENT.md`](../INTENT.md) — the spine: what the game is
- [`docs/SKETCHBOOK.md`](SKETCHBOOK.md) — rough ideas, dated
- [`docs/VOICE.md`](VOICE.md) — how Curiosity speaks (from the book)
