"""Synthesise the menu's two UI sounds. No pack, no licence, no credit line.

    python tools/make_menu_sfx.py

Writes assets/audio/ui/menu_move.wav and menu_select.wav (mono 44.1k, 16-bit).

Design notes, because these are easy to get wrong and impossible to argue about later:

* MOVE is heard on every arrow press, so it has to survive being triggered ten times in two
  seconds. It is short (70ms), soft, and has NO strong fundamental — a pure tone repeated
  quickly turns into a melody the player did not ask for. A struck-glass tap with an
  inharmonic partial reads as "cursor" and vanishes from memory immediately.
* SELECT is heard once, so it can afford to be pretty: a soft two-note rise, the second note
  a fifth above, both decaying together.

Both start with a 4ms fade-in. Without it the waveform begins at full amplitude and every
sound card in the world reproduces that as a click.
"""

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/audio/ui"
RATE = 44100


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(0.0001, max(abs(s) for s in samples))
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s / peak * 0.92)) * 32767))
            for s in samples
        )
        w.writeframes(frames)
    print(f"wrote {path.name}  {len(samples) / RATE * 1000:.0f}ms")


def env(i: int, n: int, decay: float, attack_ms: float = 4.0) -> float:
    t = i / RATE
    a = min(1.0, t / (attack_ms / 1000.0))
    return a * math.exp(-t / decay)


def move() -> list[float]:
    """Softened on Advika's note — the first pass was too sharp and too present.

    Three things make a tick sharp: a high fundamental, a loud upper partial, and a fast
    attack. All three moved. 1180Hz -> 760Hz puts it under the music rather than over it,
    the inharmonic partial drops from 0.45 to 0.14 (still there, so repeats do not form a
    tune, but no longer the thing you hear), and a 9ms attack rounds the leading edge into
    a tap instead of a click.
    """
    n = int(RATE * 0.09)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.026, attack_ms=9.0)
        s = math.sin(TAU * 760.0 * t) * 0.86 + math.sin(TAU * 760.0 * 2.4 * t) * 0.14
        out.append(s * e)
    return out


def select() -> list[float]:
    n = int(RATE * 0.42)
    out = []
    for i in range(n):
        t = i / RATE
        # dropped an octave alongside the move tick, and both notes get a slower attack so
        # the pair reads as a chime rather than a beep
        low = math.sin(TAU * 588.0 * t) * env(i, n, 0.18, attack_ms=8.0)
        # the fifth enters a beat later, so it reads as a rise rather than a chord
        d = t - 0.055
        high = 0.0
        if d > 0:
            high = math.sin(TAU * 880.0 * d) * math.exp(-d / 0.15) * min(1.0, d / 0.008)
        out.append(low * 0.72 + high * 0.5)
    return out


TAU = math.tau

if __name__ == "__main__":
    write_wav(OUT / "menu_move.wav", move())
    write_wav(OUT / "menu_select.wav", select())
