#!/usr/bin/env python3
"""Synthesises Chain Escape's background music: a very calm, seamlessly
looping ambient bed of soft, warm, low chord pads that change slowly. No
bells or high notes (the first version's bells were irritating). Original
and licence-free; replace with a chosen licensed track under the same name
whenever wanted.

Run from the project root:  python3 tools/generate_music.py [output.wav]
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 22050
CHORD_SECONDS = 11.0
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "music.wav"

# D major, low and warm, close voicings: Dmaj7 - Bm7 - Gmaj7 - Asus2.
CHORDS = [
    [50, 54, 57, 61],
    [47, 50, 54, 57],
    [43, 47, 50, 54],
    [45, 47, 52, 57],
]
ROOTS = [38, 35, 31, 33]
BELL_NOTES = [74, 76, 78, 81, 83, 86]  # D pentatonic, upper octave
PAD_ATTACK = 4.0
PAD_RELEASE = 5.0
BELL_DECAY = 1.6
ECHO_SECONDS = 0.42
ECHO_FEEDBACK = 0.38
ECHO_REPEATS = 4


def freq(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def pad_envelope(t):
    """Swells in over PAD_ATTACK, holds for the chord, fades over PAD_RELEASE."""
    if t < 0:
        return 0.0
    if t < PAD_ATTACK:
        return 0.5 - 0.5 * math.cos(math.pi * t / PAD_ATTACK)
    if t < CHORD_SECONDS:
        return 1.0
    tail = t - CHORD_SECONDS
    if tail < PAD_RELEASE:
        return 0.5 + 0.5 * math.cos(math.pi * tail / PAD_RELEASE)
    return 0.0


def main():
    length = int(CHORD_SECONDS * len(CHORDS) * RATE)
    out = [0.0] * length

    def add(index, value):
        out[index % length] += value  # wraps, so the loop is seamless

    span = int((CHORD_SECONDS + PAD_RELEASE) * RATE)
    for chord_index, chord in enumerate(CHORDS):
        start = int(chord_index * CHORD_SECONDS * RATE)
        voices = [(freq(n), 0.11) for n in chord] + [(freq(ROOTS[chord_index]), 0.16)]
        for i in range(span):
            t = i / RATE
            env = pad_envelope(t)
            if env == 0.0:
                continue
            value = 0.0
            for f, amp in voices:
                # Two slightly detuned sines make the pad breathe softly.
                value += amp * (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * (f + 0.12) * t + 1.3))
            # A very slow swell (one breath every ~8 s) keeps it alive.
            breath = 0.85 + 0.15 * math.sin(2 * math.pi * t / 8.0)
            add(start + i, value * env * breath)

    peak = max(abs(v) for v in out) or 1.0
    scale = 0.55 / peak
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    with wave.open(str(target), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(v * scale * 32767)) for v in out))
    print("wrote", target, f"{length / RATE:.0f} s")


if __name__ == "__main__":
    main()
