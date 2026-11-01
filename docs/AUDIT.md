# Ice Fishing audit (2026-11-01)

Based on reading the code and on `playtest_log.txt` (one session: 8 of 19 sectors cleared in 871 s).

## What works (keep it)
- **First 5 minutes.** A purchase or goal lands every 5-30 s. Hole -> cast -> catch -> hand-in -> bucket is a clear ladder.
- **Finite lake with a visible end.** Shadows thin out as a tile empties, tiles turn pale, sectors turn gold. Counters going down is the best feedback in the game.
- **Walking has a job.** Carry capacity + hatch range makes bucket/boots matter, then the conveyor makes them obsolete. A good arc.
- **Orders** give a repeatable short-term target on top of the long goal.
- Test harness (67 checks incl. a 4000-action fuzz) is solid and cheap.

## Problems found
1. **The economy runs dry by minute ~14.** Every starting upgrade was maxed by ~850 s and the player held 13,891 coins at sector 7 with nothing to spend them on. Full upgrade list costs ~9k coins; the lake pays ~40k+. After that the game plays itself (conveyors) and the tension is gone.
2. **One lake = one run.** ~25 min of content and then nothing. "Repeatable" was missing entirely.
3. **Orders could become impossible.** They asked for species (e.g. Minnow x6) with no regard for what was left in a finite lake; Minnows are ~gone in the Deeps.
4. **Run time was not persisted or shown**, so there was no way to say "I did it faster".
5. Smaller: `roll_fish` / `luck` are dead code outside the tests; starting prompt does not mention the pause/new-game keys prominently; the log has no per-lake summary.

## Changes made in this pass
- **Refreeze loop (the repeatable layer).** Press **R** after clearing 3 sectors (or the whole lake). You bank **pearls** (1 per cleared sector, +5 for emptying the lake), spend them on permanent perks (Warm Pockets, Seed Money, Olga's Favour, Quick Hands), and start a fresh lake with coins/upgrades/stations reset. Costs scale `base * (level+1)`, so ~4 full lakes to max everything.
- **Lake modifiers.** Every lake after the first rolls one: Crowded (+35% fish), Treasure (2x rares, -20% fish), Skittish (slow bites, +40% prices), Glass (fast bites, -20% prices). Shown in the HUD and as a banner.
- **Run clock.** Time is saved, shown on the ending panel with your best, and logged.
- **Orders respect the lake.** Species are only requested while >= 4 remain (lake + hands + stashes); need is capped; an order that becomes impossible is rerolled.
- **Market retune (first guess).** Olga's Deal now has 12 levels at +15% and growth 1.85 (was 8 at +25%, 1.7), roughly 46k coins in total, so coins still matter in the Deeps.

## Not verified
- The market retune is arithmetic, not playtested. Check in the next log whether coins pile up again, and when the last upgrade is bought.
- The Refreeze panel and HUD line were only tested headless (logic + text), never seen on screen. Check layout.
- Pearl and perk numbers are a first guess. Watch for: does lake 2 feel meaningfully faster (good) or trivial (too strong)?

## Next candidates (ranked by value)
1. Playtest lake 2 and 3 with the modifiers: is the variety felt, or is it the same game?
2. Mid-lake dead zone (~7-11 min in the log): little to decide while auto-rods work. Idea: sector-specific hazards/quests ("a thin-ice sector needs boots Lv3").
3. Rare finds are only a journal tick after the first. Idea: rare fish as hand-in "trophies" for pearls.
4. Reuse the refreeze/pearl/modifier layer in Kelp Diver (it lives in `GameState.meta` and the lake model, not in ice-fishing-only code).
