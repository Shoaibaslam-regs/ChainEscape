# Chain Escape: earning phase plan (Phase 2: UX and architecture)

Based on the Phase 1 monetization research in `CLAUDE.md` (verdict PIVOT)
and on the game's code as it is today (25 Nov 2026). Nothing here is built
yet; it starts after Checkpoint 1 is approved.

## 1. What the game already has (checked in the repo)

| Research assumed | Reality in the code |
|---|---|
| Unknown whether hints exist | **No hint system.** The tutorial hand already finds a playable arrow (`GameScreen.hint_arrow`), so the core of a hint exists. |
| Unknown whether lives / retries exist | **No lives.** Each generated level allows 3 wrong moves; when they run out the player chooses **free restart** or **watch an ad for +1 move**. The ad is a development stand-in (`scripts/ads/rewarded_ads.gd`); no ad SDK yet. |
| Unknown whether daily rewards exist | Daily and Weekly challenges exist, with streaks and seals, but **no daily reward** to double. |
| Cosmetics | **Arrow themes already exist**, unlocked free with points (Emerald 500 … Rose gold 15,000). Not sold. |
| Ads / purchases / consent | None. The game is fully offline. Settings says "Your progress is saved only on this device. Nothing is sent anywhere." which **stops being true** once ads ship. |

What this means for the research's open items:
- **A2 (rewarded ad for an extra attempt):** it already exists as "+1 move". It is
  never forced (free restart is always offered), so it avoids the "watch an ad
  to resume" complaint. Recommendation: **keep it**, same rules as hint ads.
- **A3 (double a daily reward):** still deferred; there is no daily reward.
- **E3 (cosmetics):** themes exist and stay free. A paid theme pack remains a
  v1.2 test, as the research suggests.

## 2. v1.0 scope (research section 8, applied to this game)

| Item | Plan |
|---|---|
| Free hints | **2 starter hints** (your answer), plus **1 free hint every 5 levels cleared** so the game stays winnable offline (research suggestion, to confirm). |
| Rewarded ad → 1 hint | Optional "+1 hint" button when hints run out; reward only on a completed view; daily cap ~10. |
| Rewarded ad → +1 move | Kept (already built), shares the daily cap and cool-downs with hint ads. |
| Interstitial after level complete | Research rules 1–6: none before 5 levels cleared; at most 1 per 3 levels; ≥3 min apart; none within 2 min of a rewarded ad; none in the first 60 s or on resume; skipped silently if not loaded. Shown after **Next** on Level complete, never at level start, never on Home. |
| Remove Ads (one-time) | USD 3.99 base, regional prices; removes interstitials only (rewarded ads stay optional); **Restore Purchases** in Settings; re-checked with the store on launch. |
| Consent | Google UMP consent form (EEA/UK) before ads load; iOS App Tracking Transparency later with the iOS build. |
| Not in v1.0 | App-open ads, banners, coins, paid cosmetics, paid hint packs (v1.1 candidate). |

## 3. How it fits the game (UX)

- **Hint button** in the level's top bar (between Pause and Restart), showing
  the hints left. Tap: one playable arrow glows for ~2 s (the tutorial hand's
  logic, updated for the new "chains block" rule). Hints never solve the
  level for you, one arrow per hint.
- **No hints left:** a small sheet "Get 1 hint: watch a short video" with a
  clear "No video available right now" state offline. Never a frozen button.
- **Interstitial moment:** Level complete shows fully first (stars, lock
  animation); the ad appears only after the player taps **Next level**, and
  only when the rules allow. Achievements still show before it.
- **Settings:** "Remove ads: USD 3.99" (local price from the store),
  "Restore purchases", "Privacy options" (reopens the consent form), and the
  privacy line rewritten to be honest about ads.
- **Remove Ads owners:** no interstitials ever; a small thank-you mark in
  Settings. Rewarded videos stay available as their own choice.

## 4. Architecture (fits the existing code)

All game code talks to small interfaces; the real SDKs plug in behind them,
exactly like today's `RewardedAds` stand-in.

| Piece | Role | Testable without a phone |
|---|---|---|
| `AdService` (replaces `RewardedAds`) | load/show rewarded and interstitial ads; signals for reward / closed / failed | Yes (fake service) |
| `AdMobAdService` | real implementation via a Godot AdMob Android plugin; Google's **test ad IDs** until your real IDs exist | Device only |
| `InterstitialPolicy` | pure rules 1–6 (level counts, timers, cool-downs, Remove Ads) | Yes, fully unit-tested |
| `HintStore` | hints left, starter grant, every-5-levels grant, daily ad cap; saved like the other stores | Yes |
| `HintFinder` | which arrow to glow (solver order, respects chains, locks, black holes) | Yes |
| `PurchaseService` | Remove Ads purchase, restore, verify on launch via Google Play Billing (Godot plugin); caches the result locally but trusts the store | Fake in tests, device for real |
| `ConsentService` | Google UMP consent before any ad request | Device only |

Main stays the composition root and hands these to the screens, as it does
now with `Feedback`, `Music` and the stores.

## 5. Build order (each step tested, previewed on your phone before installing)

1. **Hints, offline** (no SDK): HintStore, HintFinder, hint button, glow, free
   allowance. Useful immediately: it fixes "I'm stuck" without any ads.
2. **Ad layer with a fake service:** AdService, InterstitialPolicy, the
   "+1 hint" sheet, interstitial after Next. Everything works in debug builds.
3. **Real ads:** Godot AdMob plugin, Google test IDs, then your AdMob app ID
   and ad unit IDs; consent form.
4. **Remove Ads:** Google Play Billing plugin, product `remove_ads`, restore,
   launch check.
5. **Honesty and compliance:** new privacy text in Settings, privacy policy
   update, Play Console Data safety answers (ads collect device identifiers),
   "Contains ads" and "In-app purchases" labels.
6. **Phone testing** with test ads and a Play internal-testing purchase.

## 6. What only you can do

- Create an **AdMob account** and the app in it (gives the app ID and ad unit
  IDs). Until then I use Google's public test IDs.
- **Google Play Console** developer account and the `remove_ads` product with
  regional prices (needed for real purchases; testing uses Play's licence
  testers).
- Decide where the **privacy policy** will be hosted.

## 7. Checkpoint 1: decisions needed

1. Approve the PIVOT v1.0 scope above (or name what to add or drop).
2. Remove Ads price: USD 3.99 base with regional prices?
3. Hints: 2 starter hints + 1 per rewarded ad (your answer), **plus** 1 free
   every 5 levels cleared for offline players: yes or no?
4. Keep the existing "+1 move" rewarded ad (with free restart always
   offered)?
5. OK to start with **step 1 (hints, offline)** right away, since it needs no
   accounts or SDKs?
