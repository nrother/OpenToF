# Changelog

OpenToF has two parts that are released together: the **sensor firmware** (Arduino, XIAO MG24 Sense) and the
**companion app** (Flutter, Android + iOS). Starting with 0.4.0, both carry the same MAJOR.MINOR version. A
hotfix may bump only one of them (e.g. app 0.4.1 with firmware 0.4.0).

**App and firmware must speak the same BLE protocol.** Protocol 1 was introduced in 0.4.0: app 0.4.x needs
firmware 0.4.x, and older firmware (≤ 0.3.2) no longer works with the new app (and vice versa).

For the reasoning behind individual choices see `docs/DECISIONS.md`; this file only says what changed.

## 0.4.0 — unreleased (2026-09-26)

Versions are aligned: **app 0.4.0** (build 3, previously 1.1.0) and **firmware 0.4.0** (previously 0.3.2). The
app's version number goes *down*; that's intentional. The build number keeps increasing, so Android still
installs it as an update.

### Sensor ↔ app protocol (breaking)
- The sensor now reports **takeoff and landing events with a timestamp** (sensor clock, ms since start) instead
  of ready-made flight and contact times. The app calculates flight time, time on the bed and height from them.
- **Fast first, precise later:** an algorithm can send a quick estimate right away and a refined one shortly
  after (within 200 ms). The app beeps and shows the jump on the quick estimate and quietly replaces the numbers
  when the refined one arrives.
- An algorithm can **withdraw** a quick estimate that turned out wrong (e.g. a false landing); the app removes
  that jump again.
- Optional per event: a **confidence** (0–100), **reasons** why it is uncertain, and **custom values** such as
  landing or push-off intensity. The algorithm describes these values itself, so the app shows new ones
  without an app update.
- The sensor counts its restarts, so the app notices when the sensor rebooted.
- Missed jumps are detected from gaps in the jump numbering.

### App
- **New logo and wordmark:** a stopwatch with a jumper above a trampoline (blue with a red bed marking) for the
  launcher icon, splash screen, notification icon and app bar; Settings shows the new "OPENT◯F" wordmark with the
  logo as its second O. The app's theme colour follows the logo blue.
- **Sensor page:** tap the sensor in Settings to see its battery, device information, and what its detection
  algorithm reports (confidence type, reasons, extra values per jump). Settings itself got shorter.
- **Version warning:** Settings and the sensor page warn when the sensor firmware's MAJOR.MINOR differs from
  the app's.
- **Time on bed and total jump time** (bed + flight) can be switched on in Settings → Jump display. They
  appear under the last jump and as extra columns in the routine table.
- **More jump details** (Settings → Jump display): shows the sensor's extra values (confidence, landing and
  push-off intensity, …) as a line under the last jump and as table columns; you pick which ones. Tap the last
  jump, a table row or a chart bar to see everything about that jump.
- **Export more than routines:** the export button now offers the recorded routine or all jumps of the last
  30 s / 1 min / 5 min.
- Jumps the sensor is unsure about get a "?" icon in the routine table; tap/hold shows the confidence and the
  reasons.
- CSV export: new columns `total_time_s` (after `contact_time_s`), `provisional`, `confidence`, `reasons`, plus
  one column per custom value at the end.
- Chart: markers for routine start and stop.
- Implausibly long "jumps" (flight time over 2.5 s, almost always a sensor glitch) are left out of the
  routine, the last-jump display, the chart and the CSV, and shown as a warning marker on the chart instead.
- Debug-only simulated sensor: speaks the new protocol, including quick/precise estimates and withdrawn
  landings; "Drop next landing" is now "Drop next jump".

### Firmware
- New algorithm interface for jump detectors (quick/precise estimates, withdraw, confidence, reasons, custom
  values). Existing detectors keep working unchanged: their reports count as precise estimates.
- New detector `BedCycleJumpDetector` (from the algorithm research), selected by default.
- Demo mode (`DEMO_MODE 1`) sends quick and precise estimates, confidence, intensities and the occasional
  withdrawn false landing, to test the app without a trampoline.
- Reports that break the event order (e.g. a landing without a takeoff) are dropped and logged over Serial.

### Known limitations
- Not yet tested end-to-end on real hardware (firmware compiles; app tested against the simulated sensor).
- BLE UUIDs are still placeholders.
- Events that happen while the app is disconnected are lost (no buffering on the sensor).

## Before 0.4.0 — app 1.1.0 (build 2) + firmware 0.3.2 (2026-09-23)

The first combined state, when the app joined the firmware repository. Here the versions still ran
independently: app 1.x and firmware 0.x.

### App 1.1.0
- Connects to one OpenToF sensor over Bluetooth, reconnects automatically, keeps the connection alive in the
  background on Android.
- Main screen: last jump's flight time and (beta) height, a bar chart of recent jumps (30 s / 1 min / 5 min
  window, pause, clear, connect/disconnect markers).
- Routine: start counts the jump you just made as #1, runs to a configurable number of jumps (default 10) with a
  beep per jump and a final sound, cancels after inactivity (default 4 s), and exports a CSV via the share sheet.
- Settings: scan and pair, rename the sensor, battery level and remaining time estimate, sensor device info
  (firmware version, active algorithm, …), sounds, chart window, inactivity timeout, theme, exit (Android).
- English and German.

### Firmware 0.3.2 (and the 0.1–0.3 line)
- 0.1: a separate demo sketch that sent simulated jumps (later folded into the main sketch).
- 0.2: one sketch with a plug-in interface for jump-detection algorithms, plus `DEMO_MODE`.
- 0.3: split into `config/`, `algorithms/`, `core/`; standard Bluetooth device information (manufacturer,
  model, serial, hardware/firmware version, active algorithm) and battery level; detectors StaLta, AzPipeline
  (plain and buffered) and a commented template.
- 0.3.x: fix for reading the IMU on real hardware (before, no sensor data arrived at all), diagnostic Serial logging.
- Protocol 0: separate Landing (flight time) and Takeoff (contact time) notifications, each with a counter.
