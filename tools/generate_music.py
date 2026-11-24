#!/usr/bin/env python3
"""Synthesises Chain Escape's placeholder background music: a calm,
seamlessly looping ambient piece (soft chord pads, a low root, and sparse
bell notes with a gentle echo). Original and licence-free; meant to be
replaced by a chosen licensed track later (same file name).

Run from the project root:  python3 tools/generate_music.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
CHORD_SECONDS = 8.0
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "music.wav"

# D major, slow and open: Dmaj9 - Bm9 - Gmaj7 - Asus2 (MIDI note numbers).
CHORDS = [
    [62, 66, 69, 73, 76],
    [59, 62, 66, 69, 73],
    [55, 59, 62, 66, 69],
    [57, 59, 64, 69, 71],
]
ROOTS = [38, 35, 31, 33]
BELL_NOTES = [74, 76, 78, 81, 83, 86]  # D pentatonic, upper octave
PAD_ATTACK = 2.5
PAD_RELEASE = 3.5
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
                # Two slightly detuned sines make the pad breathe.
                value += amp * (math.sin(2 * math.pi * f * t) + 0.6 * math.sin(2 * math.pi * (f + 0.18) * t + 1.3))
            add(start + i, value * env)

    rng = random.Random("chain-escape-music-v1")
    bell_time = 1.5
    total = CHORD_SECONDS * len(CHORDS)
    while bell_time < total:
        note = rng.choice(BELL_NOTES)
        f = freq(note)
        start = int(bell_time * RATE)
        for repeat in range(ECHO_REPEATS + 1):
            gain = 0.09 * (ECHO_FEEDBACK ** repeat)
            offset = start + int(repeat * ECHO_SECONDS * RATE)
            for i in range(int(BELL_DECAY * 3 * RATE)):
                t = i / RATE
                env = min(1.0, t / 0.006) * math.exp(-t / BELL_DECAY)
                value = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-t / 0.4)
                add(offset + i, gain * env * value)
        bell_time += rng.choice([2.75, 3.5, 4.25, 5.0])

    peak = max(abs(v) for v in out) or 1.0
    scale = 0.55 / peak
    with wave.open(str(OUT), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(v * scale * 32767)) for v in out))
    print("wrote", OUT, f"{length / RATE:.0f} s")


if __name__ == "__main__":
    main()
