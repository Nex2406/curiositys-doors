---
name: Realm
about: Queue a new realm for design + build
title: "realm: "
labels: ["realm"]
---

## Theme word
<!-- One word or two-word phrase. The emotional/symbolic spine of the realm.
     e.g. "forgotten names", "quiet hunger", "folded hour". -->

## Palette refs (3 colors min)
<!-- Pin hex codes from docs/ART_DIRECTION.md OR new palette drifts.
     Name what dominates and what stays the lantern's accent.
     e.g.
     - Dominant: #2d1b4e (purple-violet)
     - Mid:      #1c2a3a (slate grey-blue)
     - Accent:   #f5b870 (lantern gold — unchanged) -->

## Puzzle premise (one sentence)
<!-- What does the player DO to pass through? Verb-shaped, not noun-shaped.
     e.g. "Curiosity collects jade fragments scattered through a cave." -->

## Lore beat on exit (one line)
<!-- The single line of voice-text Curiosity speaks as the realm fades.
     Match the tone in docs/VOICE.md. Advika writes this — don't invent. -->

## What player carries forward into the hub
<!-- Item, memory, key-fragment, visible change to the cloak, etc.
     This is what makes the realm matter back at the hub. -->

## Files likely touched
<!-- Best guess at scenes/scripts/assets in scope. -->

## Acceptance criteria
- [ ] `godot --headless --import` passes
- [ ] `godot --headless --export-release "Web" build/index.html` passes
- [ ] Visually verified in browser on the live site (or local equivalent)
- [ ] No regression in feel or performance
- [ ] Adheres to docs/ART_DIRECTION.md and docs/VIBE.md
- [ ] Realm entry registered in `Door.gd::_resolve_scene_path`
- [ ] docs/STATE.md "Live loop" and "What is wired" updated
- [ ] docs/REALMS.md entry promoted from drafted → in-build or shipped

## Kill criteria
<!-- Revert if X by Y. One bullet. Forces the "what would make me
     pull this back" question UP FRONT, not after merge. -->
- [ ] Revert if:

## Visual / audio references (optional)
<!-- Mood-board fragments, color refs, sound refs, or a short prose description. -->
