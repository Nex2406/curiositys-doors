---
# Curiosity's Doors — Session Prompt
Paste this at the start of every Claude Code session.

Follow CLAUDE.md "Session Start Protocol."
Pick item 1 from docs/STATE.md "Next 3 safe candidates."
Build it:
  - NEW REALM → use realm.md template. Interview Advika
    for all 5 fields before building. Do not invent
    answers.
  - FEAT / BUG / ART / STORY / RESEARCH → use the
    matching template. Fill every field including Kill
    criteria.
Ship one PR closing the issue. Acceptance:
  - godot --headless --import passes
  - godot --headless --export-release "Web" build passes
  - Played on live build
  - No regression
  - docs/STATE.md updated
  - docs/SESSIONS.md appended (shipped / didn't work /
    next 3)
End-of-session report (3 lines):
  1. Shipped (PR # + live link)
  2. Didn't (and why)
  3. Top of Next 3 now
---
