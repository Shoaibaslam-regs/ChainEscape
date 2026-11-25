# Chain Escape — Phase 2: Branding, UI/UX & MVP Architecture

Prepared 2026-11-24 after Phase 1 was approved with **Pivot A** (chains at the core).
**Status: awaiting your approval (checkpoint).** Nothing here is built yet.

Visual proposal (private design canvas): https://claude.ai/artifact/5bcsCG3M3ZTxVwRJrSSynp
It contains the brand and visual system sheet plus five MVP screens.

---

## 1. Identity

- **Name:** Chain Escape. Unchanged; it now describes the core idea.
- **Line:** "Every lock has a key." (Store subtitle candidate: "Every lock has a key. Find the order.")
- **Direction:** *a locksmith's puzzle box.* A dark slate workbench, warm brass arrows, cold steel locks, and chains the player breaks. Calm, tactile and readable, deliberately unlike the bright, multicoloured arrow games on the charts.
- **Positioning promise (on Home):** "No lives. No timers. Plays offline."

## 2. Visual system

| Token | Hex | Use |
|---|---|---|
| Ink | `#12151C` | App background |
| Workbench | `#1A1E27` | Board, cards, secondary buttons |
| Cell | `#222835` | Empty cell |
| Tile | `#2E3546` | Arrow tile |
| Brass | `#E8B04A` | Free arrow, primary button (text on it `#2A1D05`) |
| Steel | `#8C97AB` | Locked arrow (tile `#262C39`) |
| Chain | `#B9C2D3` | Chain links |
| Key | `#45C2B1` | Key marker, success |
| Coral | `#E8695C` | Blocked feedback, destructive text `#F08A7F` |
| Text | `#EEF1F6` / `#A3ACBD` / `#7D879A` | Primary / secondary / tertiary |

- **Type:** **Cairo** (SIL Open Font License; Latin and Arabic in one family). Weights 400/600/700/800. Display 40–44, title 22–26, body 16–17, label 13 in uppercase with tracking.
- **Shape:** 11 px tile radius, 14–20 px button radius, 48 px minimum touch target, 76 px primary button.
- **Icons:** simple stroked line icons in the palette. No emoji, no gradients, no glow.
- **Logo mark:** two interlocked chain links, steel and brass, with a brass arrow breaking out of the brass link (your change on the canvas).
- **App icon (decided):** built from the logo mark (two interlocked links with the breakout arrow), so the icon, splash and logo match.

## 3. Pivot A: what changes in gameplay

The rules engine stays the same. The changes make chains the thing players read and plan around.

1. **Key marker (new visual):** an arrow that other arrows wait for gets a teal ring, so players can see at a glance "clearing this unlocks something".
2. **Locked keys (already supported by the rules):** an arrow can be both locked and a key, forming longer chains (A waits for B, which waits for C).
3. **Chain-break animation (signature moment):** when a key leaves, its links pop apart toward the lock, the padlock springs open, and the arrow warms from steel to brass. This is also the moment to show in store videos.
4. **Locks counter:** gameplay shows "Arrows N" and "Locks N"; locks remaining is a second progress measure.
5. **Generator emphasis on chains:**
   - more dependencies at every difficulty level;
   - one key may unlock up to two locks;
   - chains up to three or four arrows long at higher difficulty;
   - each generated level includes at least one chain whose key is itself blocked, so chains require planning.
   - Neighbour-only links stay, for readability.
6. **Tutorial rework (levels 1–8):** one short line of coaching on levels 1, 2 and 4, for example "Locked arrows wait for the key at the other end of their chain." Then teach a locked key and a double lock by level 8.
7. **Blocked feedback softened:** a nudge plus a coral edge instead of a full red flash.

## 4. MVP scope

**In:**
- Home, Gameplay, Pause sheet, Level complete, Achievement unlocked, Settings.
- **Achievements** (your request): an "Achievement unlocked" screen after Level complete, shown only when something unlocks. It shows the badge, progress to the next tier, nearby achievements and Continue. Chain-themed set, for example First Key, Locksmith (100 chains, tiers 250/1000), Clean Hands (10 levels in a row with no wrong taps), Escape Artist (50 levels), Chain Reaction (3 chains in one level with no wrong tap). Stored offline alongside progress. The exact list and tiers are to be finalised.
- **No level select** (your decision on the canvas): play only moves forward. Home's Play button continues at the next level, and the total number of levels is never shown. "Replay" on Level complete replays only the level just cleared.
- Chain visual language and animations (section 3).
- Generator and tutorial changes (section 3).
- Sound effects: tap, exit, blocked, chain break, level clear. Original or properly licensed, sources recorded.
- Vibration feedback (settings toggle).
- Android back button: game → pause; pause → resume; Settings → back; Home → exit.
- Screen transitions: short fade or slide, 150–200 ms.
- Settings: sound, vibration, language (English only at MVP, but text kept in translation files), privacy policy link, reset progress with confirmation.
- Safe-area handling for notches and gesture bars; layouts checked from 16:9 to 20:9 and on tablets.
- One shared Godot theme resource for all screens (replacing per-scene font sizes).

- **Splash screen, premium "gold and obsidian" (decided):** a static boot image (the two links on a near-black background) hands over to a 1.7 s animated intro:
  - a warm spotlight and faint vault-dial rings;
  - polished steel and gold links that tug once;
  - a gold arrow bursting out with a glow pulse and gold sparks;
  - the title in heavy capitals with a gold glint sweep.
  Cold start only, tap to skip, a static version for reduced motion, built with Tweens and gradients (no video).
- **Vault challenges (decided, style A):** a special, harder level appears at an unpredictable point every 20–30 levels, forever. The spacing and twist come from the level seed, so they're the same for all players.
  - Twist pool: double locks, walls, long chains, hidden links. Each twist gets a one-time intro card; from about level 125 on, two twists can combine.
  - Reward: a Vault seal on the level and progress toward the Vault Breaker achievement.
  - Still solvable by construction, and restart is free.
  - New pieces to build: walls and hidden links. Double locks and long chains already work in the rules.
- **Master arrow (decided, every 50th level):** one larger gold arrow with a halo, held by a double lock and placed so roughly half the board must clear first (solver-verified).
  - Releasing it completes the level: in the rules every arrow escapes at once, and the cascade is pure animation, a gold ripple with arrows launching nearest-first 40 ms apart, about 1.2 s.
  - Then "Master clear", a Master seal and Master Escape achievement progress.
  - Clearing the board normally also completes the level.
- **Level-start animation (decided, every level):** arrows fly in from the side they will leave by, staggered outward from the centre (about 0.9 s), then chains and padlocks snap in. Static for reduced motion.
- **Daily challenge (decided, the "competition" request):** one puzzle a day, the same for every player (seeded by date, works offline), scored by fewest wrong taps, with a day streak. Leaderboards against friends and players worldwide come with the later online update, alongside Facebook.

**Proposed, needs your decision:**
- **Connect with Facebook** (requested on the canvas; shown in Settings as "Keep your progress across devices"). Building it means:
  - Meta's SDK through a Godot plugin, and registering a Meta developer app;
  - a server or cloud service to store synced progress, which breaks the offline-only, no-backend rule;
  - a privacy policy, Google Play Data Safety and Apple privacy disclosures, and in-app account deletion;
  - very likely an equivalent privacy-focused login on iOS (Apple guideline 4.8, e.g. Sign in with Apple).
  **Decided: later update**, not in the MVP. The Settings mockup tags it "Later update".
- **Hint, "Show me a key" (decided):** watch a rewarded ad to get one. It ships with the ads update, **not in the first release**.
- **"No wrong taps" badge:** included; it also drives the Clean Hands achievement.

**Out (post-MVP):** ads and IAP together with the ad-supported hint, Facebook login / cloud save, daily puzzle, music, more languages, undo.

## 5. Technical architecture additions

The existing architecture stays: rules in `scripts/core`, views in `scenes/board`, data in `scripts/levels`, and `Main` as the root that creates and connects everything. New pieces:

| Piece | Responsibility | Notes |
|---|---|---|
| `assets/theme/game_theme.tres` + Cairo font files | Shared Theme (colours, font sizes, button styles) | Replaces per-scene overrides |
| `scripts/ui/palette.gd` | Colour constants used by drawn board pieces | One source of truth with the theme |
| `scripts/achievements/achievement_tracker.gd` + definitions resource | Counts chains broken, clean streaks and levels; reports unlocks after each level | Pure logic, tested headless; saved with a versioned format like progress |
| `scripts/settings/settings_store.gd` | Sound/vibration/language in `user://settings.cfg` | Separate from progress (single responsibility) |
| `AudioPlayer` (autoload) | Plays sound effects, respects settings | The only autoload: audio is genuinely global |
| `scenes/ui/` (button, toggle row, sheet) | Reusable widgets | Theme-driven |
| `GameScreen` state enum | `PLAYING`, `PAUSED`, `COMPLETED` | Blocks taps during pause and after completion |
| `Main` transitions | Fade between screens; ignores input mid-transition | Prevents double navigation |
| `ChainView` (in `scenes/board/`) | Draws chains and plays the break animation | Pulled out of BoardView to keep it focused |
| Translation CSV (`locale/`) | All user-facing text | Arabic later needs a right-to-left layout check |

## 6. Open decisions (please answer)

1. Approve the **visual direction** (palette, type, screens), or name what to change?
2. **App icon:** A, B or C?
3. **Hint:** include it in the MVP, and if so, how is it limited?
4. **"No wrong taps" badge:** in or out?
5. **Monetization timing:** ship the MVP with no ads or purchases and add them after measuring retention, or design ads in now?


## Change log after approval

- 2026-11-24 (user request): per-level limit of 3 wrong moves on generated
  levels; out of moves → free restart or rewarded ad for +1 move. Home footer
  changed from "No lives. No timers. Plays offline." to "No timers. No waiting.
  Plays offline." because a per-level limit is a form of lives. Challenges and
  late ordinary levels get progressively harder ("hardness").
- 2026-11-24 (user request): twist progression — debut pop-up over the board,
  practice levels, random single twists, merges; no paid tier.
- 2026-11-24 (user request): gameplay counters simplified to one calm icon
  row (arrows · locks · keys for wrong moves); the "TWIST · …" chip removed —
  twists are only explained by the pop-up when introduced.
- 2026-11-24 (user decision): Home rewards box shortened to one row.
  Points: 5 per level, counted once (highest level cleared × 5), shown on
  Home; replays and Daily challenges add none; Reset progress clears them.
  Live online ranking (by total points) is a LATER UPDATE — no backend now.
- 2026-11-24 (user approved "go with your suggestion"):
  - Stars per level: 0 wrong moves = 3, 1 = 2, 2+ = 1; best kept; total on
    Home; not for Daily. Points unchanged (5 per level, once).
  - Countdown: Play button "LEVEL n · VAULT IN d" / "VAULT CHALLENGE" /
    "MASTER LEVEL"; Level complete "NEXT VAULT IN d" / "... NEXT".
  - Arrow themes unlocked by points: Gold 0, Emerald 250, Sapphire 750,
    Amethyst 1500, Rose gold 3000 (Steel/Obsidian dropped: they would look
    like locked arrows / vanish on the background; no red, wrong taps flash
    coral). Locked arrows stay steel in every theme. Chosen in Settings.
  - Daily reminder notification: deferred to Phase 4 (Android setup).
- 2026-11-24 (user: "do 3"): first-time guidance on the hand-made levels.
  Tip line above the board on levels 1-5 (one idea each); levels 6-8 none.
  Pointing hand taps a movable arrow (prefers a key arrow): level 1 all 3
  moves, levels 2 and 4 the first move. Static (no tapping) with Reduce
  motion. Home footer line removed in the calm Home pass.
- 2026-11-24 (user): arrow theme costs raised: Emerald 500, Sapphire 1200,
  Amethyst 5000, Rose gold 15000 points (Gold free). Arrows drawn at 85% of the cell.
- 2026-11-25 (user: levels too easy around 100; micro arrows; black holes;
  own ideas; red wrong arrows):
  - Wrong move: the tapped arrow stays red until it can leave; tapping a red
    arrow again costs no move.
  - Difficulty: ramp 80 -> 40 levels; extra hardness from level 20 on a
    square-root curve (0.48 at 100, 0.9 cap at 300); Vaults >= +0.25 above
    the levels around them. New tightening pass chains free-at-start arrows
    to later neighbours (solver-verified): ~10% free at full hardness.
  - Boards grow from level 70 up to 10 x 13 (more, smaller arrows).
  - New twists: Black holes (arrow enters, exits the paired white hole, same
    direction; 1-2 pairs, violet/teal) and Mirrors ("/" "\" turn 90 deg).
    Debut as Vault challenges 5 and 6 (levels 121, 147); merges from 6.
  - Next level is generated in the background (worker thread) while playing.
- 2026-11-25 (user): praise words are small gold words rising from the
  released arrow; Level complete = Next level + Home (+ "Retry for 3 stars"
  link when < 3 stars, replays only the level just finished); status row:
  arrows + locks left, moves right; red wrong arrows carry a white cross
  (colour-blind safe); background music (Settings > Music, starts on Home;
  synthesised placeholder at assets/audio/music.wav, to be replaced by a
  licensed track under the same name); Weekly challenge: 5 shared puzzles
  per Monday-Sunday week (0/1/1/2/2 twists, rising hardness and size), any
  order, no move limit, Weekly seal for all 5; Home shows Daily | Weekly.
- 2026-11-25 (user approved, after previews on the phone):
  - App icon: royal blue, gold arrow under two crossing chains, steel
    padlock hanging on the crossing (assets/brand/app_icon, adaptive layers).
  - Splash: black like Home (gold rays + dust); the icon's picture in the
    game's gold/steel builds up: arrow grows, chains slide in from top and
    bottom, padlock drops and snaps, title rises. Sounds: rise, chain
    rattle + clink, padlock snap (option D), title chime.
  - Home art = the splash picture. Game stays black + gold (no blue tint).
  - Music: "November Snow" by cynicmusic (CC0, OpenGameArt); sources in
    docs/audio_previews/MUSIC_SOURCES.md.
  - Gameplay: chains reach up to 4 cells (never cross, never pass over an
    arrow), more locks/double keys, late boards up to 10 x 15, arrows go on
    finger lift (slide off to cancel).
- 2026-11-25 (installed on the user's phone):
  - Chains block flight paths until their key arrow leaves (not on hidden-
    links levels); tapping an arrow blocked by a chain flashes that chain's
    key. Level 6 teaches it (extra chain + tip). Generator repairs chain
    seals; levels 1-400 verified solvable.
  - Twist pop-up: the twist picture large and animated on a gold-ray stage,
    its name said once, one line on how it works.
  - Hints (earning plan step 1, offline): 2 starter hints, +1 free every 5
    levels cleared (from the research; pending the user's confirmation),
    numbered levels only, glow on the most useful free arrow.
- 2026-11-26 (user, built; install pending): harder from level 9 (difficulty
  starts at 0.5, hardness floor 0.3), EXTREME level every 3-4 levels (from
  11; red label); hints = 2 by default, +1 per rewarded video (max 10/day),
  no free hints for levels; simpler Home (no Achievements/Themes dock; rank
  opens Achievements); icon + splash + Level complete = "padlock escape"
  (concept I, no stars) with a real shackle lift-and-swing; light red screen
  wash on counted wrong moves; wrong moves per level vary: mostly 3, ~1 in 4
  levels 2, ~1 in 10 only 1 (from level 15), Vaults 2, EXTREME/Master 3,
  announced at level start ("Only 1 move!").
- 2026-11-26 (user, built; install pending): polish: music re-encoded to Ogg
  Vorbis (14 MB -> 4.7 MB; debug APK 74.3 -> 65.8 MB); debug-only level
  build timing in the log for on-phone speed checks; languages skipped for
  now (user). Account/Profile: player card on Home (avatar + frame + name,
  rank) opens Profile: name (2-16 chars, cleaned), 10 avatars and 7 frames
  earned by ranks/achievements (no paid cosmetics in v1.0 per CLAUDE.md),
  Achievements moved inside Profile, "Continue with Facebook" via the
  SocialLogin slot (says "coming soon" until the user's OAuth is plugged in).
  Home hero art = padlock-escape emblem (matches the splash).
