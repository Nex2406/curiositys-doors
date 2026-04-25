---
name: Feature
about: A new system, mechanic, scene, or capability
title: "feat: "
labels: ["feat"]
---

## What
<!-- One or two sentences describing the feature. -->

## Why (which North Star pillar this serves)
<!-- Visual / Technical / Narrative bar — see CLAUDE.md North Star. Name the pillar(s). -->

## Behavior
<!-- How it should feel and act in-game. Animation, sound, lighting, cadence. Match the vibe in docs/VIBE.md. -->

## Files likely touched
<!-- Best guess at the scenes/scripts/assets in scope. -->

## Acceptance criteria
- [ ] `godot --headless --import` passes
- [ ] `godot --headless --export-release "Web" build/index.html` passes
- [ ] Visually verified in browser on the live site (or local equivalent)
- [ ] No regression in feel or performance
- [ ] Adheres to docs/ART_DIRECTION.md and docs/VIBE.md
- [ ] CLAUDE.md / docs/ updated if conventions changed

## Visual / audio references (optional)
<!-- Mood-board fragments, color refs, sound refs, or a short prose description. -->
