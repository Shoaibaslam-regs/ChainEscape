#!/usr/bin/env python3
"""Writes the profile avatar glyphs to assets/avatars/<id>.svg.

Each glyph is drawn in the game's style: gold (or steel) gradient fill with a
dark #0B0C10 outline, centred in a 128x128 box. The coloured circle behind
the glyph and the frame around it are drawn in code (AvatarBadge).

Run from the project root:  python3 tools/generate_avatars.py
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "avatars"
INK = "#0B0C10"
DEFS = """<defs>
<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF0BF"/><stop offset="0.45" stop-color="#E8B04A"/><stop offset="1" stop-color="#9C6B1C"/></linearGradient>
<linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F4F7FB"/><stop offset="0.5" stop-color="#A9B3C4"/><stop offset="1" stop-color="#5A6375"/></linearGradient>
</defs>"""
STROKE = f'stroke="{INK}" stroke-width="6" stroke-linejoin="round" stroke-linecap="round"'

GLYPHS = {
    # Arrow escaping up and to the right.
    "arrow": f'<path d="M28 100 L74 54" stroke="{INK}" stroke-width="24" stroke-linecap="round"/>'
             f'<path d="M28 100 L74 54" stroke="url(#g)" stroke-width="13" stroke-linecap="round"/>'
             f'<path d="M54 36 L102 26 L92 74 Z" fill="url(#g)" {STROKE}/>',
    # Key: round bow, shaft, two teeth.
    "key": f'<circle cx="40" cy="64" r="20" fill="url(#g)" {STROKE}/><circle cx="40" cy="64" r="8" fill="{INK}"/>'
           f'<path d="M58 58 H104 V70 H96 V82 H86 V70 H78 V80 H68 V70 H58 Z" fill="url(#g)" {STROKE}/>',
    # Padlock, shut.
    "padlock": f'<path d="M44 60 V44 a20 20 0 0 1 40 0 V60" fill="none" stroke="{INK}" stroke-width="20" stroke-linecap="round"/>'
               f'<path d="M44 60 V44 a20 20 0 0 1 40 0 V60" fill="none" stroke="url(#s)" stroke-width="10" stroke-linecap="round"/>'
               f'<rect x="30" y="56" width="68" height="52" rx="12" fill="url(#g)" {STROKE}/>'
               f'<circle cx="64" cy="78" r="7" fill="{INK}"/><rect x="61" y="80" width="6" height="16" rx="3" fill="{INK}"/>',
    # Two interlocked chain links (steel).
    "chain": f'<rect x="18" y="44" width="56" height="34" rx="17" fill="none" stroke="{INK}" stroke-width="20" transform="rotate(-30 46 61)"/>'
             f'<rect x="18" y="44" width="56" height="34" rx="17" fill="none" stroke="url(#s)" stroke-width="10" transform="rotate(-30 46 61)"/>'
             f'<rect x="54" y="50" width="56" height="34" rx="17" fill="none" stroke="{INK}" stroke-width="20" transform="rotate(-30 82 67)"/>'
             f'<rect x="54" y="50" width="56" height="34" rx="17" fill="none" stroke="url(#s)" stroke-width="10" transform="rotate(-30 82 67)"/>',
    # Compass: ring and needle.
    "compass": f'<circle cx="64" cy="64" r="38" fill="#1A1E27" stroke="url(#g)" stroke-width="10"/>'
               f'<circle cx="64" cy="64" r="44" fill="none" stroke="{INK}" stroke-width="3"/>'
               f'<path d="M64 32 L74 64 L64 96 L54 64 Z" fill="url(#g)" {STROKE.replace("6", "4", 1)}/>'
               f'<path d="M64 64 L74 64 L64 96 L54 64 Z" fill="url(#s)" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
               f'<circle cx="64" cy="64" r="5" fill="{INK}"/>',
    # Gem.
    "gem": f'<path d="M64 20 L104 52 L64 108 L24 52 Z" fill="url(#g)" {STROKE}/>'
           f'<path d="M24 52 H104 M44 52 L64 108 L84 52 M44 52 L64 20 L84 52" fill="none" stroke="{INK}" stroke-opacity="0.55" stroke-width="3.5" stroke-linejoin="round"/>',
    # Hourglass.
    "hourglass": f'<path d="M38 24 H90 V34 C90 52 70 58 70 64 C70 70 90 76 90 94 V104 H38 V94 C38 76 58 70 58 64 C58 58 38 52 38 34 Z" fill="#1A1E27" {STROKE}/>'
                 f'<path d="M46 34 H82 C80 46 66 52 64 58 C62 52 48 46 46 34 Z M64 72 C68 80 82 84 82 96 H46 C46 84 60 80 64 72 Z" fill="url(#g)"/>'
                 f'<rect x="32" y="18" width="64" height="12" rx="5" fill="url(#s)" {STROKE.replace("6", "4", 1)}/>'
                 f'<rect x="32" y="98" width="64" height="12" rx="5" fill="url(#s)" {STROKE.replace("6", "4", 1)}/>',
    # Lightning bolt.
    "bolt": f'<path d="M72 16 L34 72 H60 L52 112 L94 52 H68 Z" fill="url(#g)" {STROKE}/>',
    # Vault door: ring, spokes, hub.
    "vault": f'<circle cx="64" cy="64" r="42" fill="url(#s)" {STROKE}/>'
             f'<circle cx="64" cy="64" r="30" fill="#1A1E27" stroke="{INK}" stroke-width="4"/>'
             f'<path d="M64 40 V88 M40 64 H88 M47 47 L81 81 M81 47 L47 81" stroke="url(#g)" stroke-width="8" stroke-linecap="round"/>'
             f'<circle cx="64" cy="64" r="11" fill="url(#g)" {STROKE.replace("6", "4", 1)}/>',
    # Crown.
    "crown": f'<path d="M22 50 L44 70 L64 34 L84 70 L106 50 L96 98 H32 Z" fill="url(#g)" {STROKE}/>'
             f'<rect x="30" y="96" width="68" height="12" rx="4" fill="url(#g)" {STROKE.replace("6", "4", 1)}/>'
             f'<circle cx="64" cy="76" r="7" fill="#45C2B1" stroke="{INK}" stroke-width="3"/>',
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, body in GLYPHS.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">{DEFS}{body}</svg>\n'
        (OUT / f"{name}.svg").write_text(svg)
    print(f"wrote {len(GLYPHS)} avatars to {OUT}")


if __name__ == "__main__":
    main()
