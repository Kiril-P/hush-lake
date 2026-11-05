# Art pipeline: AI reference images -> Claude rebuilds the scene

The scene is procedural, so images are **mood boards, not blueprints**. The loop:

1. **Shoot** the fixed manifest: `tools/refshots.sh` -> `docs/refs/shots/NN_name.png` (+ `manifest.json`). 20 clean frames (no HUD),
   fixed place, time, weather and Eye stage, so rounds compare like with like. `REF_ONLY=06 tools/refshots.sh` renders one.
   `--out DIR` (after `--`) writes a round somewhere else (used for "after" frames: `docs/refs/after/rN/`).
2. **Fan out** one GPT agent per shot (`delegate_task`, provider `codex`, model `gpt-6.1-terra`, low effort, priority tier).
   Each follows `docs/refs/BRIEF.md`: 3 variants (storybook / nordic / low-poly polish) via the built-in `image_gen` tool, plus
   `notes.md` with a diagnosis and an implementable "wins" list. Output: `docs/refs/gen/<shot>/`.
   (A probe agent took ~40 s per image; 20 agents x 3 images finish in a few minutes.)
3. **Distill** (Claude): read the pictures and notes, merge into `docs/refs/DELTA.md`: the cross-scene wins first, then per-scene
   items. Reject fantasy that a low-poly procedural scene cannot do; keep the amber/teal rule from `docs/STYLE.md`.
4. **Rebuild** (Claude): implement the delta list in the scenery, lighting, sky, props and materials. Perf budget stays ~8 ms/frame.
5. **Verify**: re-shoot the manifest to `docs/refs/after/`, build `tools/contact_sheet.py` before|reference|after sheets, run the
   test suites and `perf_render.sh`.
6. **You choose**: the sheets in `docs/refs/sheets/` are the review artifact. Say which scenes to push further; repeat from 2 on those.

Rules for agents: they edit nothing but their own output dir. Prompts never mention UI. Keep every round's `manifest.json`.

## Capture gotcha (macOS)
A windowed Godot run that is hidden behind other windows stops redrawing: captures come back as one stale frame (byte-identical files) or
black, and a long capture can stall. The capture tools now call `DisplayServer.window_move_to_foreground()` first. If sheets ever show
identical frames, check file sizes and keep the window visible.
