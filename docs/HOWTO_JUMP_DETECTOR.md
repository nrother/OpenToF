# Writing a detection algorithm

An algorithm is a class derived from `JumpDetector` (`firmware/OpenToF_Firmware/core/JumpDetector.h`); start from
an existing algorithm. `onSample()` gets every IMU sample (acceleration in g, rotation rate in deg/s,
timestamp in µs). It reports with:

| Call | Meaning |
|---|---|
| `takeoff(timeUs)` / `landing(timeUs)` | Simple form: one final event, no extras |
| `takeoff(timeUs, stage, info)` / `landing(timeUs, stage, info)` | `STAGE_PROVISIONAL` or `STAGE_FINAL`, with an optional `EventInfo` |
| `retractTakeoff()` / `retractLanding()` | Withdraw the current provisional event |

- `timeUs` is when it physically happened on the sample clock: backdate it if you notice late, or put it slightly
  ahead for a predicted takeoff.
- `EventInfo` holds `confidence` (0–100), `reasons` (bit mask) and custom fields added with
  `addU8()`/`addI16()`/… in the order declared in `fieldsJson()`.
- Optional overrides: `name()` (shown as Software Revision), `imuProfile()` (416 Hz / ±8 g or 833 Hz / ±16 g),
  `fieldsJson()`, `reasonsJson()`, `confidenceKind()`.
- `onSample()` runs a few hundred times per second: no `delay()`, no serial printing.

How to select and build an algorithm is in [`firmware/README.md`](../firmware/README.md).

Rules of the game
 - Report events in order: takeoff, landing, takeoff, landing, ...
   (A landing without an earlier takeoff, and a takeoff while already airborne, are
    ignored and logged by the firmware, so it is fine to start "in the middle".)
 - Flight time = landing time - takeoff time; contact time = takeoff time - previous landing.
   The precision of those times is the precision of the timestamps you pass in.
 - onSample() runs 416 times per second. Keep it fast: no delay(), no
   Serial printing, no long loops. Plain float maths is fine.
 - Keep any state (filters, timers, flags) in the private members below.
 - See what the data looks like first: set IMU_SERIAL_LOG 1 in FirmwareConfig.h and watch the
   Serial Monitor / Serial Plotter while someone bounces.