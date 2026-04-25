#!/usr/bin/env bash
# Idempotent label setup for Curiosity's Doors.
# Safe to re-run: --force overwrites existing label color/description.
#
# Usage:  bash .github/scripts/setup-labels.sh
# Requires: gh CLI authed against this repo.

set -euo pipefail

# create_label NAME COLOR DESCRIPTION
create_label() {
  local name="$1"
  local color="$2"
  local desc="$3"
  echo "  - $name"
  gh label create "$name" --color "$color" --description "$desc" --force >/dev/null
}

echo "Categories:"
create_label "feat"     "8a4fff" "New system, mechanic, scene, or capability"
create_label "bug"      "d73a49" "Something broken, regressed, or off-vibe"
create_label "story"    "0a2540" "Narrative beat, lore fragment, or in-world writing"
create_label "art"      "f5b870" "Sprite, background, effect, or UI asset"
create_label "chore"    "9aa0a6" "Tooling, docs, workflow, housekeeping"
create_label "research" "1f8a8a" "Question to answer before committing to a build path"

echo ""
echo "Priority:"
create_label "p0-now"      "ff1f1f" "Blocks deploy or breaks the game — drop everything"
create_label "p1-soon"     "f08500" "Visible to anyone who plays — fix this cycle"
create_label "p2-later"    "f0d000" "Edge case or polish gap — schedule into a sprint"
create_label "p3-someday"  "d0d0d0" "Cosmetic, low impact — pick up when relevant"

echo ""
echo "Realms:"
create_label "realm:hub"             "1c2a3a" "The central hub of doors"
create_label "realm:forgotten-names" "6b7a8c" "Cold blue-grey — memory without referent"
create_label "realm:quiet-hunger"    "c97a4f" "Amber and rust — longing for warmth out of reach"
create_label "realm:folded-hour"     "5c4a6b" "Desaturated grey-violet — time that loops"

echo ""
echo "Status:"
create_label "blocked"          "0d0d0d" "Cannot proceed without an upstream resolution"
create_label "needs-design"     "c8b6e0" "Spec or visual direction must land first"
create_label "ready-for-claude" "2ea043" "Spec is complete enough for Claude Code to execute"

echo ""
echo "Done. Run 'gh label list' to verify."
