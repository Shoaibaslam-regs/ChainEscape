class_name Palette
extends RefCounted
## The game's colours, in one place. Values come from the approved Phase 2
## design (docs/phase2_design.md); everything that draws or styles UI reads
## them from here.

# Backgrounds, darkest first.
const OBSIDIAN := Color("0B0C10")
const SPOTLIGHT := Color("1B1710")
const SURFACE := Color("14161C")
const WORKBENCH := Color("1A1E27")
const CELL := Color("222835")
const TILE := Color("2E3546")

# Metals.
const GOLD := Color("E8B04A")
const GOLD_LIGHT := Color("FFF0BF")
const GOLD_DARK := Color("9C6B1C")
const GOLD_INK := Color("2A1D05")
const STEEL := Color("8C97AB")
const STEEL_LIGHT := Color("E6EBF2")
const STEEL_DARK := Color("4E5666")
const CHAIN := Color("B9C2D3")

# Signals.
const KEY := Color("45C2B1")
const CORAL := Color("E8695C")

# Text.
const TEXT := Color("EEF1F6")
const TEXT_SECONDARY := Color("A3ACBD")
const TEXT_TERTIARY := Color("7D879A")

# Thin gold outline used on secondary buttons and cards.
const GOLD_OUTLINE := Color(0.91, 0.69, 0.29, 0.3)
