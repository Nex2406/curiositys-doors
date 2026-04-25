---
name: Art
about: A sprite, background, effect, or UI asset request
title: "art: "
labels: ["art"]
---

## Asset type
- [ ] Sprite (character, prop, door, item)
- [ ] Background (parallax layer, full scene paint)
- [ ] Effect (particle texture, light falloff, fog, shader input)
- [ ] UI (text-frame, transition overlay)

## Realm / context
<!-- Which realm or scene does this asset live in? Reference docs/REALMS.md if applicable. -->

## Reference images or descriptions
<!-- Mood-board fragments, links, or prose description of what the asset should evoke. -->

## Palette constraints
<!-- Pin to specific hex codes from docs/ART_DIRECTION.md. List allowed colors and what NOT to use. -->

## Size / format
<!-- Pixel dimensions, aspect ratio, transparent background y/n, file format (PNG / WebP / SVG). -->

## Integration target
<!-- Which scene/node will receive this asset? Path to the .tscn or node, e.g. scenes/Hub.tscn → ParallaxBackground/Far. -->

## Acceptance
- [ ] Matches docs/ART_DIRECTION.md (palette, line treatment, texture, scale)
- [ ] Imports cleanly via `godot --headless --import`
- [ ] Wired into the target scene
- [ ] Web export still passes
- [ ] Looks like a painting in the running game, not a placeholder
