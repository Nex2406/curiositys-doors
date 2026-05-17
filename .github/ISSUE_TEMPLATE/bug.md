---
name: Bug
about: Something is broken, regressed, or off-vibe in a way the build can't catch
title: "fix: "
labels: ["bug"]
---

## Steps to reproduce
1.
2.
3.

## Expected
<!-- What should happen. -->

## Actual
<!-- What happens instead. Include console errors, screenshots, or short clips if helpful. -->

## Environment
- **Where:** live site / local export / editor
- **Browser / desktop:**
- **OS:**
- **Godot version:** 4.6.x

## Severity
- [ ] p0 — blocks deploy / makes the game unplayable
- [ ] p1 — visible to anyone who plays
- [ ] p2 — edge case or polish gap
- [ ] p3 — cosmetic, low impact

## Acceptance
- [ ] Root cause identified (not just symptom patched)
- [ ] `godot --headless --import` passes
- [ ] `godot --headless --export-release "Web" build/index.html` passes
- [ ] Verified on the live site after merge
- [ ] docs/STATE.md updated this session
- [ ] docs/SESSIONS.md entry appended this session
