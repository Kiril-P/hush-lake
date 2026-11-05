# Brief for reference-image agents (Hush Lake)

You are a concept artist for **Hush Lake**, a first-person cozy ice-fishing incremental. You get ONE screenshot of the real game.
The game is a procedural low-poly scene built from primitives (boxes, cones, cylinders, flat-shaded) with simple lights, fog and
a few shaders. A programmer will rebuild the scene to match your pictures, so be concrete and keep it buildable.

## House style (do not break)
- Cold teal/blue world; ONE warm amber for anything lit, owned or interactive (lanterns, windows, the Eye's thin ring).
- The Eye (a glowing aqua hole in the ice with a black pupil) is the heart of the scene; it should always read.
- Mood: quiet, melancholy, cozy, a little eerie. Not cartoon-bright, not grimdark.
- Stylised low-poly with soft light, NOT photoreal. Chunky readable silhouettes, gentle gradients, atmospheric depth.

## Task
1. Open your screenshot (path in your task). Note the camera and composition.
2. Using your image generation tool (`image_gen`), make **3 variants** of "how this exact view should look when polished":
   - `v1_storybook`: warm, hand-painted storybook light, cosy props and life
   - `v2_nordic`: moodier, desaturated Nordic dusk feel, stronger atmosphere and light shafts
   - `v3_lowpoly`: crisp stylised low-poly polish (still flat-shaded facets), best lighting and colour grading a real-time engine could do
   Keep the **same camera, framing and layout** as the screenshot. Do NOT add UI. No text except what is already on signs.
   Add what would make it better: props, silhouettes, lighting, atmosphere, colour, small stories.
3. Save as `<outdir>/v1_storybook.png`, `v2_nordic.png`, `v3_lowpoly.png`. If a generation fails, retry once, then say so.
4. Write `<outdir>/notes.md` (max 25 lines) with: (a) **Diagnosis**: 5 specific things the screenshot gets wrong or lacks, in terms of
   game scene elements (sky, fog, light colour, ice, props, silhouettes, composition); (b) **Wins**: the 3-5 changes that appear in
   your variants that would help MOST, ordered by impact, each phrased as something a programmer can implement (e.g. "add a warm
   rim light on snow facing the hut", "string lights along the stall roofs", "make fog bluer at the horizon with a peach band").
   Be honest about which parts of the variants are unbuildable fantasy.
5. Final answer: one line listing the files written. Edit nothing else in the repository.
