"""Synthesise candidate 'jade collected' sounds.

Six characters, all built from scratch (no licensing, no attribution) and all
aimed at Realm 1's voice: muted, resonant, never cute and never loud. Struck
crystal rather than an arcade coin.

Run:  python tools/make_jade_sfx.py
Out:  assets/audio/jade/jade_pickup_<n>_<name>.wav
Audition them with tools/SfxPicker.tscn (keys 1-6).
"""
import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "jade")


def env(n, attack, decay, curve=2.5):
	"""Percussive envelope: near-instant attack, long exponential tail."""
	a = int(SR * attack)
	e = np.zeros(n)
	if a > 0:
		e[:a] = np.linspace(0.0, 1.0, a) ** 0.6
	tail = np.arange(n - a)
	e[a:] = np.exp(-tail / (SR * decay)) ** curve
	return e


def partials(n, freq, ratios, gains, decays, detune=0.0):
	"""A struck-body tone: inharmonic partials, each with its own decay."""
	t = np.arange(n) / SR
	out = np.zeros(n)
	for r, g, d in zip(ratios, gains, decays):
		f = freq * r * (1.0 + detune * (r - 1.0))
		out += g * np.sin(2 * np.pi * f * t) * np.exp(-t / d)
	return out


def shimmer(n, lo, hi, decay):
	"""Filtered noise sweeping down — air, dust, the room around the note."""
	rng = np.random.default_rng(7)
	noise = rng.standard_normal(n)
	# cheap one-pole lowpass with a falling cutoff
	cut = np.linspace(hi, lo, n) / (SR * 0.5)
	out = np.zeros(n)
	z = 0.0
	for i in range(n):
		a = min(max(cut[i], 0.001), 0.99)
		z += a * (noise[i] - z)
		out[i] = z
	t = np.arange(n) / SR
	return out * np.exp(-t / decay)


def tail_reverb(sig, delay=0.055, feedback=0.34, taps=6):
	"""A few decaying echoes — the cave answering, without a reverb library."""
	out = sig.copy()
	d = int(SR * delay)
	g = feedback
	for k in range(1, taps + 1):
		shift = d * k
		if shift >= len(sig):
			break
		out[shift:] += sig[:-shift] * (g ** k)
	return out


def write(name, sig, peak=0.72):
	os.makedirs(OUT, exist_ok=True)
	sig = np.nan_to_num(sig)
	m = np.max(np.abs(sig))
	if m > 0:
		sig = sig / m * peak
	# gentle fade at both ends so nothing clicks
	f = int(SR * 0.004)
	sig[:f] *= np.linspace(0, 1, f)
	sig[-f:] *= np.linspace(1, 0, f)
	data = (sig * 32767).astype("<i2")
	path = os.path.join(OUT, name)
	with wave.open(path, "w") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(data.tobytes())
	print("wrote", os.path.relpath(path, ROOT), "%.2fs" % (len(sig) / SR))


def main():
	# 1. STRUCK CRYSTAL — one clean chime, inharmonic partials, long tail
	n = int(SR * 1.6)
	s = partials(n, 1244.5, [1, 2.76, 5.4, 8.9], [1.0, 0.42, 0.18, 0.08],
			[0.55, 0.30, 0.16, 0.09])
	write("jade_pickup_1_crystal.wav", tail_reverb(s * env(n, 0.001, 0.42)))

	# 2. SOFT GLASS — rounder, quieter partials, no bite
	n = int(SR * 1.5)
	s = partials(n, 987.8, [1, 2.0, 3.01, 4.7], [1.0, 0.30, 0.12, 0.05],
			[0.7, 0.35, 0.2, 0.12])
	s += 0.10 * shimmer(n, 1200, 6000, 0.16)
	write("jade_pickup_2_glass.wav", tail_reverb(s * env(n, 0.004, 0.55, 2.0), 0.07, 0.3))

	# 3. TWO NOTES — a small rise, the only one that reads as "reward"
	n = int(SR * 1.5)
	a = partials(n, 880.0, [1, 2.7, 5.1], [1.0, 0.35, 0.14], [0.35, 0.2, 0.12])
	a *= env(n, 0.001, 0.28)
	b = partials(n, 1318.5, [1, 2.7, 5.1], [1.0, 0.35, 0.14], [0.45, 0.25, 0.14])
	b *= env(n, 0.001, 0.40)
	off = int(SR * 0.10)
	s = a.copy()
	s[off:] += b[:-off] * 0.9
	write("jade_pickup_3_two_notes.wav", tail_reverb(s))

	# 4. BREATH — mostly air, the note only implied. The most restrained.
	n = int(SR * 1.7)
	s = 0.9 * shimmer(n, 700, 9000, 0.22)
	s += 0.35 * partials(n, 1174.7, [1, 3.1], [1.0, 0.2], [0.5, 0.25]) * env(n, 0.02, 0.5, 1.6)
	write("jade_pickup_4_breath.wav", tail_reverb(s, 0.08, 0.28), 0.6)

	# 5. DEEP + SPARK — a low resonance under a small bright tick: cave-sized
	n = int(SR * 1.9)
	low = partials(n, 146.8, [1, 2.02, 3.1], [1.0, 0.3, 0.12], [0.9, 0.5, 0.3])
	low *= env(n, 0.006, 0.75, 1.4)
	tick = partials(n, 2093.0, [1, 2.4], [1.0, 0.3], [0.09, 0.05]) * env(n, 0.0005, 0.07)
	write("jade_pickup_5_deep_spark.wav", tail_reverb(low * 0.85 + tick * 0.5, 0.09, 0.32))

	# 6. STONE — a dry knock with just a hint of ring, least musical of the six
	n = int(SR * 0.9)
	rng = np.random.default_rng(3)
	knock = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * 0.010))
	ring = partials(n, 523.25, [1, 2.9, 4.8], [1.0, 0.25, 0.1], [0.22, 0.12, 0.07])
	s = knock * 0.5 + ring * env(n, 0.001, 0.2) * 0.8
	write("jade_pickup_6_stone.wav", tail_reverb(s, 0.045, 0.25))

	# --- Advika picked 5 ("deep spark") and wants it better. Three refinements of
	# the same idea: the low body stays, the top end is where they differ. ---

	# 5a. CLEANER — the low tightened so it stops muddying, the tick given a
	# crystal ring instead of a click, and the whole thing a touch shorter.
	n = int(SR * 1.7)
	low = partials(n, 155.6, [1, 2.01, 3.02], [1.0, 0.22, 0.08], [0.62, 0.34, 0.2])
	low *= env(n, 0.004, 0.55, 1.5)
	spark = partials(n, 2349.3, [1, 2.76, 5.4], [1.0, 0.30, 0.12], [0.22, 0.12, 0.07])
	spark *= env(n, 0.0005, 0.18)
	write("jade_pickup_5a_cleaner.wav", tail_reverb(low * 0.8 + spark * 0.55, 0.075, 0.30))

	# 5b. WARMER — same shape, the spark an octave down and rounder, more hum than
	# glint. The quietest of the three.
	n = int(SR * 1.9)
	low = partials(n, 146.8, [1, 2.0, 2.98], [1.0, 0.26, 0.1], [0.85, 0.45, 0.26])
	low *= env(n, 0.008, 0.72, 1.3)
	spark = partials(n, 1174.7, [1, 2.4, 4.1], [1.0, 0.26, 0.1], [0.3, 0.16, 0.1])
	spark *= env(n, 0.002, 0.24, 1.8)
	air = 0.12 * shimmer(n, 900, 5200, 0.2)
	write("jade_pickup_5b_warmer.wav", tail_reverb(low * 0.85 + spark * 0.42 + air, 0.085, 0.30))

	# 5c. BRIGHTER — the low kept short and low in the mix so the glint leads: the
	# most "gem" of the three without becoming a coin.
	n = int(SR * 1.6)
	low = partials(n, 164.8, [1, 2.02], [1.0, 0.18], [0.4, 0.22]) * env(n, 0.003, 0.4, 1.6)
	spark = partials(n, 2637.0, [1, 2.76, 5.4, 8.2], [1.0, 0.34, 0.16, 0.07],
			[0.3, 0.17, 0.1, 0.06])
	spark *= env(n, 0.0004, 0.26)
	write("jade_pickup_5c_brighter.wav", tail_reverb(low * 0.5 + spark * 0.8, 0.065, 0.34))


if __name__ == "__main__":
	main()
