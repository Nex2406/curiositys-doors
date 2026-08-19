# The deck

One unbroken descent through the game: cover → the way in → realm → door →
handover card → realm → door → handover card → realm → the mirror → the last
lines → how it is built → play it.

## Two outputs, one source

**The PDF is what gets emailed.** `sh docs/presentation/pdf.sh` prints the deck
to A4 landscape, one beat to a sheet, and drops it in `build/`. Gmail previews a
PDF inline with one click; it will not preview an HTML attachment, it downloads
it, and most people never open the download. So mail gets the PDF.

**The page is what gets linked.** The deploy workflow copies this folder into
the Pages output, so it is live at `https://nex2406.github.io/curiositys-doors/deck/`
— plain public web, no account and no download.

- **`index.html`** — the source. Edit this. It references `img/*.jpg`.
- **`img/`** — every plate, captured straight out of the running game.
- **`bake.py`** — inlines everything into one self-contained file under `build/`
  (gitignored).
- **`pdf.sh`** — bakes, then prints to A4 landscape via headless Chrome.
- **`?flat`** — appended to the URL, lays the descent out as a normal document
  with the plates inline. Ctrl-P prints the same way.

## How the descent works

There is no per-section sticky backdrop. One `#stage` is fixed to the viewport
holding every realm's art at once, and each `.beat` names the plate it wants in
`data-img`; the stage cross-fades. Sticky was the obvious build and it is wrong
— a sticky element releases when its own section runs out, so the last screen of
every realm would have played against bare black.

Nothing is driven by `IntersectionObserver` either. Beat offsets are measured
once on load and again on resize, and the scroll handler is pure arithmetic — no
layout reads in a scroll frame, and the whole thing can be stepped and asserted
from a script.

Three things move: the lantern follows the pointer, the motes drift on a canvas,
and each block's lines arrive as you reach it. The handover cards type
themselves at **26 characters a second** — the rate in `Prologue.gd`, and the
rate every tarot card in the game types at.

`platePrints()` clones each realm's plate into its own beat before printing,
because the stage is fixed to the viewport and a fixed element cannot paginate.
`?flat` runs the same builder on screen.

## Writing rules

Advika, 2026-08-19: *"the content screams ai … avoid phrases like its not this
its that."* No antithesis. No "X is not Y, it is Z", no "rather than", no "not
because … but because". Say what happens, in order, and stop. Grep the source
for `rather than`, `is not a`, `instead of` before shipping a copy change.

## What the deck is allowed to show

Advika's line, 2026-08-19: **realms, the mirror, and a hint of the end.**

- The prologue is *described*, never quoted. Reading it here would spend the
  first forty seconds of the game.
- The mirror boss is in — it is the hook, and its card is one the player is
  handed anyway.
- The ending gets one paragraph saying a voice speaks and re-frames all three
  realms. **None of its words appear.** An earlier pass printed the whole
  epilogue verse and had to be cut.
- Both between-realm quote cards stay, as they appear in the game.

Audience is both: the world and the hook lead, and one short "how it is built"
section sits near the end for the people who care about that.

## Keeping it true

Every number and every quoted line on the page came out of the code, not out of
a design doc — `docs/REALMS.md` is stale and describes realms that were never
built. When something changes, re-check the claim it supports:

| Claim on the page | Where it lives |
| --- | --- |
| 17 pieces of jade | counted at runtime; the HUD reads `0/17` |
| golems: 3 in platforms, 4 in the ceiling | `Realm1PlatformTest.gd` — `PLAT_GOLEM_COUNT`, `CEILING GOLEMS` log |
| the conjurer appears ~12s into the climb | `Realm2LiftTest.gd` — `WIZARD_APPEAR_DELAY` |
| five blows fell him | `Realm2LiftTest.gd` header |
| the moth burns in four seconds | `VoidMoth.gd` — `burn_time` |
| six lights, seven minutes | `Realm3FungalTest.gd` — `MUSHROOMS_TO_KILL`, `LEVEL_SECONDS` |
| the colour drains over nine seconds | `Realm3FungalTest.gd` — `_begin_shift` |
| the card texts | screenshots of the real cards, in `img/card_*.jpg` |
| the closing verse | `Realm3Epilogue.gd` |
| the handover quotes | `QuoteTransition.gd` default + `Realm2LiftTest.gd` |
| 69 scripts / 27,145 lines / 22 shaders / 0 rigid bodies | `ls scripts/*.gd`, `cat scripts/*.gd \| wc -l`, `ls shaders/*.gdshader`, `grep -r RigidBody2D` |

**The Echo is not in the game.** `Echo.gd` still exists and still works, but
`_build_echo()` returns early unless `R3_ECHO=1` — the read of how you play was
promoted into the mirror boss instead. Any copy that describes something walking
behind you through Realm 3 is describing a switched-off feature.

## Re-capturing the plates

`tools/DeckShot.tscn` boots any realm scene, taps a key so the tarot cards
dismiss themselves, optionally pokes one method on the level, then saves a
frame:

```
R3_BOSS=1 DECK_SCENE=res://scenes/realms/Realm3FungalTest.tscn \
DECK_OUT=C:/tmp/boss.png DECK_AT=20 DECK_TAP_UNTIL=14 \
Godot_v4.6.2-stable_win64.exe --path . --resolution 1920x1080 res://tools/DeckShot.tscn
```

Then resize to 1600px wide and save as progressive JPEG at quality 82 — the
plates have to stay small or the page stops scrolling smoothly.
