"""Synthesise the prologue's typing tick. No pack, no licence, no credit line.

    python tools/make_typing_sfx.py

Writes assets/audio/ui/type_tick.wav (mono 44.1k, 16-bit).

This one is harder than the menu's two sounds, because it is heard TWENTY TIMES A SECOND.
Anything with a pitch becomes a drone; anything with a sharp edge becomes a machine gun.
So the tick is built to be almost nothing:

* NOISE, not a tone. A seeded noise burst has no fundamental, so a hundred of them in a row
  can never form a note or a rhythm the ear starts following instead of the words.
* BAND-LIMITED to roughly 500-1600Hz — two one-pole lowpasses subtracted from each other.
  Below that it thumps under the music; above it, it hisses and reads as static.
* 55ms long with a 6ms attack. The slow-ish attack is the whole difference between a soft
  tap and a click; at 20 per second a click is unbearable within about two lines.
* A weak 300Hz body under the noise gives it just enough substance to survive being played
  at -22dB, which is where it belongs — under the words, not over them.

Pitch variation is NOT baked in. The Prologue jitters `pitch_scale` per keystroke, which is
one file instead of eight and never repeats the same tick twice in a row anyway.
"""

import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/audio/ui"
RATE = 44100
TAU = math.tau


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(0.0001, max(abs(s) for s in samples))
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s / peak * 0.9)) * 32767))
            for s in samples
        )
        w.writeframes(frames)
    print(f"wrote {path.name}  {len(samples) / RATE * 1000:.0f}ms")


def one_pole(src: list[float], cutoff: float) -> list[float]:
    """Textbook one-pole lowpass. Two of these, subtracted, make a usable bandpass."""
    a = 1.0 - math.exp(-TAU * cutoff / RATE)
    out = []
    y = 0.0
    for s in src:
        y += a * (s - y)
        out.append(y)
    return out


def tick() -> list[float]:
    n = int(RATE * 0.055)
    rng = random.Random(20260731)          # seeded: the file is reproducible byte for byte
    raw = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    hi = one_pole(raw, 1600.0)
    lo = one_pole(raw, 500.0)
    out = []
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.006)
        decay = math.exp(-t / 0.013)
        e = attack * decay
        body = math.sin(TAU * 300.0 * t) * math.exp(-t / 0.009) * 0.22
        out.append(((hi[i] - lo[i]) * 0.9 + body) * e)
    return out


if __name__ == "__main__":
    write_wav(OUT / "type_tick.wav", tick())
