# OpenToF housing (CAD)

Sensor housing for the XIAO MG24 Sense + FE602045 LiPo, with a trampoline clip copied from the Veriflite
mount (`Veriflite.stl`, reference only).

`Veriflite.stl` is not in the repository (third-party model, git-ignored). Get it from
[Printables: Veriflite trampoline clip](https://www.printables.com/model/637716-veriflite-trampoline-clip) and save it
as `cad/Veriflite.stl` if you want to re-measure the clip; `opentof_housing.py` only uses the profile already copied
into it.

- `opentof_housing.py` — **the source of truth.** Parametric FreeCAD script; all dimensions are in its
  `PARAMETERS` block. Re-run it after changing anything:
  `"C:\Program Files\FreeCAD 1.0\bin\freecadcmd.exe" cad/opentof_housing.py` (from the repo root), or run it
  as a macro in the FreeCAD GUI. It checks that the lid, battery and board don't intersect the body.
- `OpenToF_Housing.FCStd` — generated: body, lid, and battery/board reference dummies (don't print those).
- `stl/OpenToF_Housing_Body.stl`, `stl/OpenToF_Housing_Lid.stl` — generated, already in print orientation.

## Orientation
The clip's straight arm carries the box. Mounted, the open (flared) end of the clip grips the trampoline,
the closed end points away from it, the box hangs underneath with the board parallel to the arm, USB-C
towards the closed end and the component/LED side facing the floor (same as the taped test setup).

## Print
- Body: as exported (clip flat on the bed, lid side up), no supports. PETG preferred for the clip (springs
  better than PLA). 100 % infill or ≥ 4 perimeters in the clip.
- Lid: as exported (flat side down), no supports.
- Default clearances are 0.3 mm per side; tune `CLR` / `NUT_AF` for your printer.

## Parts (per sensor)
- 3 × M2×8 socket head screw, ISO 4762 / DIN 912, A2 stainless
- 3 × M2 hex nut, ISO 4032 / DIN 934 (4 mm across flats, 1.6 mm high)

## Assembly
1. Push the three nuts into their side slots (just below the rim; two in the end block, one in the boss
   in front of the board). They drop in from the cavity side.
2. Solder the battery to the board's BAT pads. Slide the battery in on its long edge, against the clip side,
   tabs towards the USB end.
3. Slide the board in, component side facing away from the battery, USB-C towards the end wall; its bottom
   edge goes into the floor groove.
4. Put the lid on (the fork grips the board's top edge) and tighten the screws.

## Reference data (collected 2026-09-24)

### Battery — FE602045 LiPo (`docs/hardware/AKKU_SOLD333278_DB-EN.pdf`, drawing on page 5)
Some PDF tools report this file as password-protected; `pypdf` reads it without a password.
- Cell: length L1 45 ±0.5 (max 45.5), width W1 20 ±0.2 (max 20.2), thickness T max 6.1 mm.
- Two tabs on one short side: width 2 mm, length 10 ±1 mm, tab spacing (centre to centre) 10 ±1.5 mm;
  top seal 2.4–3.8 mm (included in L1). The user confirmed these dimensions match the pack in use.
- 500 mAh, 3.7 V nominal, charge cut-off 4.25 V, standard charge 250 mA (the XIAO charges at 200 mA).

### Board — Seeed XIAO MG24 Sense
No mechanical drawing in `docs/hardware/` (the KiCad PDF is schematics only), and none found online.
- PCB 21 × 17.8 mm (standard XIAO outline). **Assumed, not measured:** PCB thickness 1.2 mm, tallest
  part 3.3 mm (the USB-C receptacle, ~8.94 × 3.26 mm), receptacle sticks out ~1.2 mm past the PCB edge.
- From the schematic: one button (K1, reset), a red/yellow dual LED (D2: charge LED + user LED), chip
  antenna + U.FL option, IMU LSM6DS3TR-C at I2C 0x6A. The battery goes to the BAT pads (charger SGM40567).

### Veriflite mount (`Veriflite.stl`), as measured from the mesh
- Bounding box 24.9 × 63.5 × 20.0 mm; a 2D hairpin profile extruded 20 mm (Z in the STL).
- One arm is straight (outer face flat, ~48.5 mm long, tilted 5.1° in the STL's frame, ~2.6 mm thick);
  the other arm is angled and ~3.5 mm thick. The closed end is a loop (outer R ≈ 7.6 mm) with a
  keyhole-shaped stress relief (R ≈ 4.2 mm).
- The gap narrows from ~12 mm near the loop to a **~1 mm pinch** about 3–4 mm from the open end,
  then opens into a flared lead-in (the straight arm bends outwards ~5 mm). So the clip snaps over
  something and holds it behind the pinch, rather than clamping it.
- Veriflite-specific features in the straight arm, **not copied**: a Ø7 mm hole ~13 mm from the open
  end, and a Ø~3.6 mm hole with a ~1.5 mm deep recess (16 mm tall) ~40 mm from the open end, probably
  where their sensor attaches.
- The profile in `opentof_housing.py` (`CLIP_PROFILE`) is the STL section at z = 3, simplified to 0.025 mm
  tolerance and rotated by −5.1° so the straight arm's outer face is x = 0 (y 0…48.6). The loop starts
  at y = 48.6, the pinch is at y ≈ −3, and the flare ends at y ≈ −8.3.

## Design decisions
- **Mounting orientation** (confirmed by the user, same as the taped test setup): the board lies parallel
  to the straight arm, USB-C towards the closed end (away from the trampoline), LED/component side facing
  the floor. Flipping the board would also be fine; the detection algorithm's axes would then need updating.
- **One piece:** clip and box are printed together. The clip is kept at the Veriflite's 20 mm height
  (stiffness unchanged); the box is 22.4 mm + 2 mm lid.
- **Print orientation drives the layout:** the clip must print flat (its loop is the spring and would be
  loaded across layer lines otherwise), so the box opens towards +z and the lid is on the side. The battery
  and board are therefore slid in edge-first from the top.
- **No heat-set inserts** (user preference: too small and error-prone at this size). M2 screws go into
  captive hex nuts in side slots, so the threads are steel on steel and the case can be opened repeatedly.
  M2 was chosen by the user; the screws and nuts are standard in Europe.
- The box is fused to the straight arm only up to y = 46.6 and leaves a 0.6 mm gap from there on, so the
  loop (the hinge) can still flex. It adds a bit of stiffness to the straight arm, as the Veriflite
  sensor's own attachment does.
- The battery fills the cavity up to the rim on the clip side, so the lid's locating lip only runs along
  the +x wall and the USB end wall.

## Open questions
- **Extra screw at the open end to lock the clip** (user idea, not implemented yet): a screw straight
  across the opening would block what the clip grips. Still to decide: clamp the arm tips together just
  past the pinch, or add a gate at a height where nothing passes through. This needs to know what exactly
  the clip grips on the trampoline.

## Things to verify on the first print
- `PCB_T`, `USB_OVERHANG`: USB-C plug must seat fully through the end wall.
- `LED_WIN_*`: the LED window position is an estimate (next to the USB-C receptacle).
- Clip grip: the profile is the Veriflite one 1:1; the housing stiffens the straight arm somewhat.
