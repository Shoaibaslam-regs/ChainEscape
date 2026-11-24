# Chain Escape — Architecture

Godot 4.7, GDScript (statically typed), portrait mobile (Android/iOS), offline-first.

## Folder layout

Folders are created only when they get real content. Entries marked *(planned)*
do not exist yet; they document where things go when their phase starts.

```
res://
├── project.godot
├── icon.svg
├── docs/                    Design and architecture notes (not exported)
├── tests/                   Headless tests: run_tests.gd + test_*.gd suites (not exported)
├── tools/                   check.sh; generate_brand_assets.gd (boot_splash.png);
│                            generate_sounds.py (synthesises assets/audio/*.wav)
├── scenes/                  Scenes, each with its script beside it
│   ├── main/                App root: one screen at a time + Settings overlay,
│   │                        Android back routing, owns the shared services
│   ├── screens/             Splash, Home, Daily, Gameplay (state machine: intro,
│   │                        playing, paused, complete, achievement, error;
│   │                        campaign or daily mode)
│   ├── board/               BoardView (grid dots, taps, level-start fly-in),
│   │                        ArrowView (tile-less metal arrow, padlock, key ring, animations),
│   │                        ChainLayer (metal links), ChainBreakEffect (links popping apart),
│   │                        MasterRippleEffect (master release)
│   └── ui/                  Panels (Pause, Complete, Achievement, Settings) and
│                            widgets (MetalLabel, ScreenBackground, DialRings)
├── scripts/                 Code not tied to a scene
│   ├── core/                Pure puzzle logic: Arrow, BoardState (rules),
│   │                        BoardSolver (solvability). No Nodes, fully testable.
│   ├── levels/              LevelData (format + validation), LevelCatalog (hand-made
│   │                        order), LevelGenerator (endless levels), LevelSequence
│   │                        (level number -> LevelData)
│   ├── progress/            ProgressStore (offline save: highest completed level)
│   ├── settings/            SettingsStore (sound, vibration, reduced motion)
│   ├── achievements/        AchievementTracker (definitions, stats, unlocks)
│   ├── feedback/            Feedback (sound effects + vibration, follows settings),
│   │                        ReleaseStreak (quick-release notes and praise words)
│   ├── daily/               DailyDate (local-date helpers), DailyChallenge (today's
│   │                        puzzle), DailyStore (results and streaks)
│   └── ui/                  Palette (all colours) and GameTheme (fonts, label and
│                            button styles as theme type variations)
├── levels/                  Hand-made levels: level_NN.tres + level_catalog.tres
└── assets/                  fonts/ (Cairo, OFL), brand/ (logo parts, boot image,
                             illustrations), icons/, audio/ (synthesised SFX),
                             shaders/ (metal_text)
```

## Key rules

- **Logic vs. view.** Puzzle rules (can this arrow exit? are its dependencies
  cleared? is the level solved?) live in `scripts/core` as plain `RefCounted`
  classes that know nothing about nodes or animation. Board/arrow scenes only
  render state and forward taps. This keeps rules unit-testable headless and
  reusable later for the solvability validator and level generator.
- **Main owns navigation.** `Main.show_title()` / `show_game()` swap screens. Screens emit
  signals (e.g. `play_requested`) instead of reaching into other screens.
- **Signals up, calls down.** Children never call into parents directly.
- **No autoloads.** `Main` is the composition root: it creates ProgressStore,
  SettingsStore, AchievementTracker, Feedback and LevelSequence and hands them
  to screens (`GameScreen.setup(...)`). No "GameManager".
- **Android back** (`quit_on_go_back=false`): Main closes Settings if open,
  else calls the current screen's `handle_back()`; if that returns false
  (Home), the app exits. Game: playing → pause, paused → resume.
- **Saves** (all ConfigFile, versioned, corrupt/missing = defaults):
  `user://progress.cfg`, `user://settings.cfg`, `user://achievements.cfg`,
  `user://daily.cfg`.
- **Daily challenge**: the puzzle is generated from the device's local date
  (`chain-escape-daily-v1:YYYY-MM-DD`, its own seed space, never a copy of a
  numbered level), difficulty 0.7, with a twist on some weekdays. Results keep
  the fewest wrong taps per day; the streak counts consecutive solved days and
  stays alive until midnight. Offline means the device clock is trusted; that
  only matters once leaderboards exist (later online update).
- **Levels are data.** Each level is a `LevelData` resource:
  - `title`: optional display name (generated levels have none).
  - `layout`: text grid, one line per row, `^ v < >` arrows, `.` empty
    (spaces ignored).
  - `dependencies`: `Vector4i(x, y, z, w)` = arrow at (x, y) waits for the
    arrow at (z, w). Cells, not ids, so edits to the layout don't shift them.
  `build_board()` returns a fresh BoardState or null plus readable errors.
- **Endless levels.** Levels are numbered from 1. `LevelSequence` serves the
  hand-made catalog first (tutorial), then `LevelGenerator` output forever.
  - Deterministic: seed = hash(`SEED_SALT` + level number). Changing the salt or
    algorithm changes every generated level — do it deliberately.
  - Solvable by construction (arrows placed in reverse removal order; each new
    arrow's path must be clear of earlier ones; dependencies only make an
    earlier arrow wait for a newer neighbour) and verified with BoardSolver.
  - Difficulty ramps over `LevelSequence.DIFFICULTY_RAMP_LEVELS` levels, then
    holds: size 6→8 columns (max 8×10), fill 55→75 %, more dependencies,
    5→10 solution rounds, ≤30→18 % of arrows free at start. Several candidates
    are built per level and the closest to target wins.
- **Twists and Vault challenges** (`LevelSequence`, all seeded):
  - Vault challenges: first at level 27, then every 20–30 levels; +0.2
    difficulty and a Vault seal. Challenges 0–3 each *debut* one twist
    (double locks → walls → long chains → hidden links); from the fifth on
    they merge two twists.
  - Practice: the 2 levels after a debut use that twist alone.
  - First merge: the level after the second twist's practice (both twists).
  - Ordinary levels then roll one known twist (25 %) or, after the first
    merge, two (1 in 6). Outside debuts/practice no twist repeats on two
    consecutive levels.
  - The premium `TwistPopup` appears over the board after the fly-in for a
    debut, the first merge and the first master level; play starts on GOT IT.
    Twists are never labelled again after that (user decision).
- **Gameplay status row**: one calm centred row under the title, icons
  instead of words: arrows left · locked arrows · wrong moves left (gold keys,
  spent keys fade to an outline). Groups that don't apply are hidden.
  - Walls: `#` in layouts; `BoardState` treats them as permanent path blocks.
  - Hidden links: presentation only (`BoardView.hide_links`); tapping a lock
    reveals its chains for 1.6 s.
  - Twist logic in the generator runs only when requested, so ordinary levels
    are byte-identical to before (checked by fingerprint when it was added).
- **Hardness** (`LevelSequence.hardness_for`, 0..1, on top of difficulty):
  Vault challenge k gets 0.2 + 0.07·k (cap 1); ordinary levels rise slowly
  after the ramp (to 0.6 by ~level 690). It raises the solve-length target,
  dependency chance and walls, lowers the allowed free-arrow share and adds a
  few generator candidates. Board size stays capped at 8×10. Hardness 0 leaves
  generation unchanged (ordinary levels 9–89 verified identical).
- **Wrong-move limit** (`WrongMoveBudget`, user decision 2026-11-24): 3 wrong
  moves (taps on blocked/locked arrows) per attempt on generated levels; not on
  tutorial levels 1–8 or the Daily challenge; padlock taps on hidden-links
  levels are free. Out of moves → `OutOfMovesPanel`: Restart (free, unlimited)
  or watch a rewarded ad for +1 move.
- **Rewarded ads** go through `RewardedAds` only. The current class is the
  development stand-in (debug builds simulate a watched ad; release builds
  report none, so the button is hidden). A real network (SDK + consent +
  privacy disclosures) replaces it in the monetisation phase.
- **Master arrow**: every 50th generated level. `BoardState.try_exit(master)`
  removes every arrow. The generator picks an arrow that frees between 40 % and
  75 % of the solve, double-locks it to neighbours that leave earlier (never one
  already in its path) and re-verifies with `BoardSolver`.
- **Hand-made level order is explicit.** `levels/level_catalog.tres` (no
  directory scanning — unreliable in exported builds). Inserting a hand-made
  level shifts later level numbers, and with them players' progress meaning.
- **Progress.** `user://progress.cfg` (ConfigFile, `version` = 2) stores only
  `highest_completed_level`, since unlocks are strictly in order. Version 1
  saves (list of `level_NN` ids) migrate automatically to the longest unbroken
  run from level 1. Missing/corrupt/invalid file = fresh start. Tests use
  throwaway `user://test_*.cfg` paths.
- **Exit rule.** Each arrow occupies one cell and may leave when every cell
  between it and the edge, in its direction, is empty. Removal is applied to
  BoardState immediately; the slide-out animation is purely visual.
- **Animations never gate the rules.** BoardState changes the instant a tap is
  accepted; exits, chain breaks, unlocks and the fly-in are visual only. A tap
  during the level-start fly-in just finishes it (it never counts as a move).
- **Chains read padlock ➜ links ➜ key ring.** Badges sit where the chain meets
  each arrow (direction from the chain geometry), and the chain layer draws
  under the arrows so links hang from the badges.
- **Dependencies are logical.** An arrow lists the ids of arrows that must have
  exited first (`Arrow.requires`); while any is still on the board the arrow is
  locked. Pending requirements are computed from the board, never stored, so
  they can't go stale. `add_dependency` rejects self, duplicate, unknown and
  cyclic links. Path + dependency deadlocks are *not* rejected there; that is
  the solvability validator's job (Phase 6) — tests use a greedy solve, which is
  exact here because an exit never blocks or locks anything.
- **Level design note.** Keep dependencies short-range (neighbours/diagonals);
  long chains across the board cross each other and become unreadable.

## Look and feel

- **One theme.** `Main` applies `GameTheme.get_theme()`; every screen inherits it.
  Labels pick a style with `theme_type_variation` (DisplayLabel, TitleLabel,
  HeadingLabel, CaptionLabel, OverlineLabel); buttons use the default style or
  `PrimaryButton`. Avoid per-node font/colour overrides.
- **Colours only from `Palette`.**
- **Brand art is SVG** (`assets/brand`), imported at `svg/scale=8` so it stays
  sharp at full size. The boot image is generated from code to match the first
  frame of the splash intro; re-run `tools/generate_brand_assets.gd` if either changes.
- **Font:** Cairo variable font (Latin + Arabic), weights via `FontVariation`.
  Licence: `assets/fonts/OFL.txt` (must ship with the game's credits).

## Rendering / mobile settings

- Renderer: GL Compatibility (widest device support, incl. low-end Android).
- Base resolution 720×1280 portrait, stretch `canvas_items` + `expand`.
- Low-processor mode on: redraws only when something changes (battery).
- Mouse emulates touch so desktop testing matches device input.

## Checks

```
tools/check.sh            # import + parse check, all tests, 30-frame boot
                          # fails on any SCRIPT ERROR / ERROR: in output
```
