# Roadmap v1: Hush Lake ("Feed the Eye") toward a playable prototype

Reviewed by a two-provider council: GPT-6.1 Sol (Codex) and Claude Opus 5.5, two rounds (independent review, then cross-verification of each other's claims against the code). Both gave the v0 draft 6/10. Their verdicts are folded in below.

Method: Claude (builder) implements; the judges review each level read-only and score it /10; a level ships when automated acceptance checks pass and neither judge holds an open blocker. Feel cannot be judged from code or screenshots, so the human owner's playtest is advisory and comes after Level 2.

## Decisions made by the council
- Safety before feel: lost progress invalidates any pacing evidence. Level 1 starts with save/offline/pause/guidance bugs.
- Belts and rig fish stay **abstract** (they are the upgrade that REMOVES pushing). Only the unbelted Auto-Rod stash is physical.
- **Cut:** second machine tier as a coin sink, fans/magnets/ramps (at most one broom, only if bot data shows pile trouble), physical belt/rig simulation, "60-90 minute" as a target (milestone timestamps instead; 55-90 min is only a sim sanity bound), the offline-income feature (it already exists).
- The scripted bot must not certify shortcuts: the report bot gets only on-screen information, limited turn speed, aim noise, and no progression mutations.
- Judges' >=8/10 is advisory; the gate is automated acceptance checks.

## Level 1 - Safe, readable core loop (in progress)
Batch A, safety [MUST]: fish survive save/load (hooked, airborne, on belts, hand-fed or depot-sent but unpaid); offline progress goes through the shared Eye-stage reward (stage 5 pearls and the awakened bonus exactly once); real pause (simulation and timers freeze) with sensitivity, volume, FOV and invert persisted; N and tithe need confirmation; guidance fixes (bite marker on the biting hole, skip exhausted holes, Auto-Rod goal before emptying a patch, correct fight text, loose-fish count); idle rigs can be picked up and re-placed free.
Batch B, feel [MUST/SHOULD]: the first catch launches toward the Eye; walk-push follows your movement; fish stay inside the real shoreline; combo survives pushing and overflow pays half with no streak; kick target rings, "Kick: N" prompt, near-miss assist, F as an alternate kick key; unbelted Auto-Rod stash spills onto the ice.
Batch C, evidence [MUST]: an honest first-10-minutes bot report (first catch, first feed, Bucket, Auto-Rod; misses, stalls, time stuck); econ sim gets a push-time term and milestone output; yard/guide/smoke/bot suites green.

## Level 2 - Stranger-ready
Export presets (macOS/Windows/Web) smoke-tested, controls card, run_all.sh, audio levels pass, request the owner's playtest. No new systems.

## Level 3 - Look and sound
Fish fins/tails fix and readability on white ice, UI restyle (minimap, plaques, labels), ambient and kick/slide sounds. No trails or decorative effects unless the playtest asks.

## Level 4 - Retention
Fewer clearer goals, an end-of-lake summary, perks that change how you play. Cut: second tier, fans/magnets, physical belts.
