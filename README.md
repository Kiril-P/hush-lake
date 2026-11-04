# Hush Lake (cozy incrementals prototype)

A first-person cozy ice-fishing incremental in Godot 4.7. Feed the Eye under the ice: drill, fish, push your catch across the ice into the Eye, and build machines that do it for you.

## Play
`tools/run.sh` (or open the project in Godot 4.7 and press F5). Click to start; Esc pauses and has mouse / volume / FOV settings.

| Key | Does |
|---|---|
| WASD | walk (walk into fish to push them) |
| 1-7 | tools: drill, rod, auto-rod, smoker, gut table, belt, build |
| click | use the tool / buy / feed |
| right mouse or F | kick (hold to charge) |
| E | pick up fish near you |
| H | ask Olga what to do next |
| Q | (build tool) switch what you build |
| V | snowmobile once bought |
| Tab | field journal |
| R | refreeze (after clearing sectors) |
| M | mute |

Notes for playtesters are in `PLAYTEST.md` (what to look for, what to write down).

## Checks (no human needed)
`tools/run_yard.sh` (fish physics) · `run_safety.sh` (saves, offline, pause) · `run_guide.sh` (onboarding) · `run_audio.sh` (sound levels) · `run_smoke.sh` (everything, several minutes) · `first10.sh` (a bot plays the first 10 minutes) · `play_bot.sh` (windowed, real input) · `perf_render.sh` (rendered frame times) · `shot.sh` / `showroom.sh` (screenshots).

## Docs
`docs/STYLE.md` (the look), `docs/DECISIONS.md` (why things are the way they are), `docs/BALANCE.md`, `docs/ROADMAP.md`.
