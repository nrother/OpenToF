# Prompts for NEW OpenToF logo designs (image generation app)

Goal: explore fresh logo concepts, not redraw the current one (`app/assets/images/OpenToF_logo.png`: trampoline with
sensor box, blue ball, dotted arcs, "OpenToF" wordmark plus subtitle). The old one is only a reference for what the
product is; do not reuse its composition.

## What OpenToF is (context to paste in front of any prompt)

OpenToF is an open-source time-of-flight measurement system for trampoline sports. A small sensor under the
trampoline bed measures how long a jumper is in the air (flight time, in seconds) and sends it to a phone app over
Bluetooth. The app shows the last jump, a chart of recent jumps and a 10-jump routine with a total. Audience:
trampoline gyms, coaches and athletes. Tone: precise, sporty, open, technical but friendly. The name reads
"Open" + "ToF" (ToF = time of flight).

## Design requirements (shared by all concepts)

- App icon first: must stay recognizable at 48x48 px; 1 bold idea, 2 colors max plus white/neutral, no fine detail.
- Works on BOTH white and near-black (#121318) backgrounds: use mid-to-bright colors, no dark navy or pure black
  in the mark; provide a light and a dark lockup only for the wordmark.
- Flat vector look, uniform stroke weights, geometric shapes, no gradients, shadows, glow, 3D or textures.
- Transparent background, centered, artwork inside the central 60% of a square canvas (Android adaptive-icon safe zone).
- Also must reduce to a single-color white silhouette (Android notification icon).
- Color: free to explore. The current brand blue is #0052EE and may be kept, changed or complemented (e.g. one accent);
  say in the result which colors were used.

## Master prompt (copy, then append ONE concept from below)

```
Design a minimal, modern, flat vector logo mark and app icon for "OpenToF", an open-source flight-time measurement
system for trampoline athletes (a sensor measures how many seconds a jumper is airborne). The mark must be a single
bold, simple idea that stays recognizable at 48x48 px, built from geometric shapes with uniform stroke weight and
rounded terminals, using at most two colors plus white, in mid-to-bright tones that stay clearly visible on both a
white and a near-black (#121318) background. Transparent background, centered in a square canvas with generous
padding (artwork within the central 60%), no text unless stated, no gradients, no shadows, no glow, no 3D, no
texture, no photo realism, no people, no fine detail. Crisp vector edges, 2048x2048. Concept:
```

## Concepts to try (each is a different idea; generate several variations per concept)

1. **Airtime arc (parabola as the mark)**
   `A single smooth parabolic arc that rises and falls between two small endpoint dots on a straight baseline, like a jump trajectory; the arc is drawn as a thick rounded stroke, the endpoints are the takeoff and landing points. Nothing else.`

2. **T-monogram that bounces**
   `A bold geometric letter "T" whose horizontal bar is slightly bowed downward like a stretched trampoline bed, with a small circle floating above the stem as the jumper. Letter and dot only.`

3. **Pulse / echo (the time-of-flight principle)**
   `A small solid dot above a horizontal line, with two or three concentric half-circle pulse waves radiating downward from the dot toward the line, like a sonar or time-of-flight signal bouncing off a surface. Simple, symmetric.`

4. **Stopwatch meets bounce**
   `A thick circular ring like a stopwatch dial with a small gap at the top, and a solid dot resting inside the ring on its lower inner edge, as if bouncing off it. Clean, balanced, very few shapes.`

5. **"O" as a jump**
   `The letter "O" drawn as a perfect ring; a solid dot sits above it, and the ring's bottom is flattened slightly like it is compressed by the landing, suggesting elasticity and a bounce. Letterform-driven, playful but precise.`

6. **Spring line**
   `One continuous line that runs flat, rises in a rounded loop-free wave to a peak, and lands back to flat, ending in a solid dot; the line has uniform thickness and looks like a trampoline bed flexing and releasing a jumper. Abstract, no trampoline drawing.`

7. **Ascending "ToF" ligature (wordmark-led)**
   `A wordmark "OpenToF" in a rounded geometric sans-serif, the letters exactly O-p-e-n-T-o-F, where the "T" and "F" are in the accent color and the crossbar of the "T" is extended into a small upward arc; short, compact, no symbol. Provide a version for light backgrounds and one for dark backgrounds.`

## Follow-up prompts (after you pick a direction)

- **Launcher tile:** `Place this exact mark, unchanged, in white, centered on a full-bleed square with a single flat solid color background (no gradient, no rounded corners), artwork within the central 60%.`
- **Monochrome:** `The same mark as a pure white single-color glyph on a transparent background, stroke weight at least 1/12 of the icon height, no gray tones, no gradients.`
- **Horizontal lockup:** `The same mark to the left of the text "OpenToF" in a rounded geometric sans-serif, exactly the letters O-p-e-n-T-o-F, mark height equal to the cap height x 1.5, two versions: for white background and for near-black background.`
- **Refine:** `Same concept, thicker strokes and fewer elements, remove everything that will not be visible at 48 px.`

## Negative prompt (if the app supports one)

`text artifacts, misspelled letters, extra words, tagline, subtitle, gradient, drop shadow, glow, bevel, 3D, realistic photo, people, detailed trampoline net or grid, tiny details, watermark, background pattern, border, dark navy, pure black`

## Checking a result

- Transparent-background PNG at 1024x1024+ (SVG is best; ask the generator or vectorize afterwards).
- View it at 48 px on white (#FFFFFF) and on #121318; it must read on both and as a white silhouette.
- Text: image generators often misspell. Prefer symbol-only output and set the wordmark yourself in a font.
- Then replace the source image, adapt `app/tool/generate_branding.ps1`, rerun it, then
  `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`, and update `#0052EE` in `app/lib/app.dart`
  if the brand color changes.

## Polishing app_icon2 into a large logo (use when image generation is available again)

`app/assets/branding/app_icon2.png` is now the small-size mark (launcher icon, splash, app bar, notification icon).
Its content: a blue stopwatch ring (crown on top, gap at the top), a solid dot (the jumper) with two arcs
beside it (arms/bounce), and a trampoline in perspective with a short stand, all in one flat blue (#1A7EFD).
Keep that concept; only add detail and polish for large sizes. Upload the image as the reference and use:

```
Refine this exact logo into a larger, more detailed and polished version. Keep the concept and the composition
unchanged: stopwatch ring with a crown and a gap at the top, a solid circle (jumper) with two curved arcs at its
sides, and a trampoline in perspective inside the lower half of the ring. Add polish: subtle stopwatch tick
marks around the inside of the ring, a slightly more refined crown and stand, cleaner even stroke weights, a
small sensor box under the trampoline bed, and a light second tone (a lighter blue #7DB6FF) for secondary
details such as the tick marks and the trampoline surface lines, plus a very subtle depth (a thin lighter
edge highlight, no gradients or shadows). Keep it flat vector style, two blues on a transparent background,
centered, generous padding, and readable on both white and near-black (#121318). No text, no people, no
photo realism. 2048x2048.
```

Then, as a second step (wordmark lockup): `The same mark to the left of the text "OpenToF" in a rounded geometric sans-serif, exactly the letters O-p-e-n-T-o-F, "Open" in white (dark background version) or dark blue (light background version), "ToF" in #1A7EFD; two versions.` Set the wordmark in a real font afterwards if the generator misspells it.

Hand back the resulting transparent PNG/SVG and I will wire it into Settings and update the theme color if wanted.
