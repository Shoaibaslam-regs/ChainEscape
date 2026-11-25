#!/usr/bin/env python3
"""Synthesises Chain Escape's sound effects as small 16-bit mono WAV files.

Original sounds made from sine waves and noise, so there is no licensing
question. Run from the project root:  python3 tools/generate_sounds.py
Re-run after changing a recipe; Godot re-imports the files automatically.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


def envelope(t, attack, decay):
    """Fast attack, exponential decay."""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


FADE_OUT_SECONDS = 0.02


def render(duration, sample):
    """Samples [sample] over [duration], with a short fade-out so a sound
    that is still ringing never ends in a click."""
    count = int(duration * RATE)
    fade = int(FADE_OUT_SECONDS * RATE)
    out = []
    for i in range(count):
        gain = min(1.0, (count - i) / fade)
        out.append(max(-1.0, min(1.0, sample(i / RATE))) * gain)
    return out


def save(name, samples, volume):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(s * volume * 32767)) for s in samples))
    print("wrote", name)


def tone(freq, t):
    return math.sin(2 * math.pi * freq * t)


def pluck(freq, duration, damping, rng):
    """Karplus-Strong plucked string: a noise burst circulating in a delay
    line with averaging, which rings like a string at [freq]."""
    period = max(int(RATE / freq), 2)
    line = [rng.uniform(-1, 1) for _ in range(period)]
    out = []
    for index in range(int(duration * RATE) + 1):
        value = line[index % period]
        following = line[(index + 1) % period]
        line[index % period] = damping * 0.5 * (value + following)
        out.append(value)
    return out


def band_noise(duration, low_hz, high_hz, rng):
    """White noise band-passed between two one-pole filters, with the band
    sliding downward over time (air moving away)."""
    out = []
    slow = fast = 0.0
    count = int(duration * RATE) + 1
    for index in range(count):
        progress = index / count
        high = high_hz * (1.0 - 0.6 * progress)
        low = low_hz * (1.0 - 0.5 * progress)
        fast += (1 - math.exp(-2 * math.pi * high / RATE)) * (rng.uniform(-1, 1) - fast)
        slow += (1 - math.exp(-2 * math.pi * low / RATE)) * (fast - slow)
        out.append((fast - slow) * 2.5)
    return out


def main():
    noise = random.Random(7)

    # Exit (arrow release) is NOT synthesised: assets/audio/exit.wav is a real
    # recorded soft whoosh ("swish-9", Swishes Sound Pack, CC0, OpenGameArt;
    # see docs/audio_previews/MUSIC_SOURCES.md). The game still raises its
    # pitch along a pentatonic scale during quick release streaks.

    # Praise: a bright two-note sparkle under the "NICE!" / "SWEET!" words.
    def praise_sample(t):
        total = 0.0
        for start, freq in ((0.0, 1567.98), (0.08, 2093.0)):
            if t >= start:
                local = t - start
                total += (tone(freq, local) + 0.3 * tone(freq * 2.0, local)) * envelope(local, 0.002, 0.12)
        return total * 0.45
    save("praise", render(0.45, praise_sample), 0.5)

    # Level start: soft whooshes as the arrows fly in, then a gentle metallic
    # "lock-in" chime as the board settles.
    # Timed to BoardView's fly-in: arrivals over ~0.4 s, last arrow lands ~0.75 s.
    arrivals = (0.0, 0.07, 0.14, 0.21, 0.28, 0.35)
    chime_at = 0.74
    flight = band_noise(1.15, 700.0, 2600.0, noise)

    def level_start_sample(t):
        index = int(t * RATE)
        swish = 0.0
        for number, start in enumerate(arrivals):
            if t >= start:
                swish += flight[index] * envelope(t - start, 0.03, 0.06) * (0.55 + 0.08 * number)
        chime = 0.0
        if t >= chime_at:
            local = t - chime_at
            chime = (tone(1318.5, local) + 0.6 * tone(1975.5, local) + 0.25 * tone(3951.0, local)) * envelope(local, 0.002, 0.16)
            chime += noise.uniform(-1, 1) * envelope(local, 0.0005, 0.004) * 0.5
        return 0.38 * swish + 0.32 * chime
    save("level_start", render(1.15, level_start_sample), 0.6)

    # Link join (splash): two metal links snapping together. A sharp click,
    # a short low thunk and a bright inharmonic ring that dies away fast.
    def link_join_sample(t):
        click = noise.uniform(-1, 1) * envelope(t, 0.0003, 0.003) * 0.7
        thunk = tone(140.0, t) * envelope(t, 0.002, 0.03) * 0.5
        ring = 0.0
        for freq, weight in ((1850.0, 1.0), (2710.0, 0.7), (4130.0, 0.45), (5560.0, 0.25)):
            ring += tone(freq, t) * weight
        ring *= envelope(t, 0.001, 0.07) * 0.32
        return click + thunk + ring
    save("link_join", render(0.35, link_join_sample), 0.6)

    # Splash: the arrow grows out of the centre. A soft swell of air with a
    # warm tone rising underneath (no sharp edges).
    swell_rng = random.Random("chain-escape-splash-rise")
    swell_air = band_noise(0.6, 300, 2400, swell_rng)
    def splash_rise_sample(t):
        shape = math.sin(math.pi * min(t / 0.6, 1.0)) ** 1.5
        freq = 196.0 + 196.0 * (t / 0.6) ** 1.4
        warm = 0.55 * tone(freq, t) + 0.2 * tone(freq * 2.0, t)
        air = swell_air[min(int(t * RATE), len(swell_air) - 1)] * 0.35
        return (warm + air) * shape
    save("splash_rise", render(0.6, splash_rise_sample), 0.45)

    # Splash: a chain sliding in. A quick run of small, bright link ticks
    # that speed up, like links tumbling over each other.
    ticks = [0.0, 0.07, 0.125, 0.17, 0.205, 0.235]
    def chain_slide_sample(t):
        value = 0.0
        for i, start in enumerate(ticks):
            dt = t - start
            if dt < 0 or dt > 0.06:
                continue
            ring = tone(2900.0 + 230.0 * i, dt) * 0.6 + tone(4300.0 + 170.0 * i, dt) * 0.35
            value += ring * math.exp(-dt / 0.012) * (0.55 + 0.08 * i)
        return value
    save("chain_slide", render(0.3, chain_slide_sample), 0.32)

    # Splash padlock snap: NOT generated here. assets/audio/lock_snap.wav is
    # option "D" (latch slide + bright snap), chosen by the user; its recipe
    # lives with the previews (docs/audio_previews/lock_D_padlock_snap.wav).

    # Splash: the title appears. A warm, quiet D-major chime (D5 F#5 A5),
    # notes rolled gently one after another.
    def title_chime_sample(t):
        value = 0.0
        for delay, freq in ((0.0, 587.33), (0.06, 739.99), (0.12, 880.0)):
            dt = t - delay
            if dt < 0:
                continue
            bell = tone(freq, dt) + 0.3 * tone(freq * 2.0, dt) * math.exp(-dt / 0.25)
            value += bell * envelope(dt, 0.01, 0.55) * 0.33
        return value
    save("title_chime", render(1.4, title_chime_sample), 0.42)

    # Blocked: a soft, low wooden knock.
    def blocked_sample(t):
        return (tone(150, t) + 0.5 * tone(230, t)) * envelope(t, 0.003, 0.035)
    save("blocked", render(0.16, blocked_sample), 0.6)

    # Chain break: bright metallic clinks, three quick hits.
    def chain_sample(t):
        total = 0.0
        for start, base in ((0.0, 2350), (0.045, 2780), (0.09, 2120)):
            if t >= start:
                local = t - start
                total += (tone(base, local) + 0.6 * tone(base * 2.76, local) + 0.3 * tone(base * 5.4, local)) * envelope(local, 0.001, 0.05)
        return total * 0.35
    save("chain_break", render(0.32, chain_sample), 0.55)

    # Unlock: a padlock click with a short metallic tail.
    def unlock_sample(t):
        click = noise.uniform(-1, 1) * envelope(t, 0.0005, 0.006)
        ring = (tone(1650, t) + 0.5 * tone(3300, t)) * envelope(t, 0.002, 0.06) * 0.4
        return click * 0.6 + ring
    save("unlock", render(0.2, unlock_sample), 0.5)

    # Level complete: a warm rising major arpeggio.
    def complete_sample(t):
        total = 0.0
        for index, freq in enumerate((523.25, 659.25, 783.99, 1046.5)):
            start = index * 0.09
            if t >= start:
                local = t - start
                total += (tone(freq, local) + 0.25 * tone(freq * 2, local)) * envelope(local, 0.005, 0.35)
        return total * 0.28
    save("level_complete", render(1.0, complete_sample), 0.6)

    # Button: a tiny tick.
    def button_sample(t):
        return tone(1200, t) * envelope(t, 0.001, 0.012)
    save("button", render(0.06, button_sample), 0.35)


if __name__ == "__main__":
    main()
