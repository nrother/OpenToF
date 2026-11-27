# Changelog

OpenToF has two parts that are released together: the **sensor firmware** (Arduino, XIAO MG24 Sense) and the
**companion app** (Flutter, Android + iOS). Starting with 0.4.0, both carry the same MAJOR.MINOR version. A
hotfix may bump only one of them (e.g. app 0.4.1 with firmware 0.4.0).

**App and firmware must speak the same BLE protocol.** Protocol 1 was introduced in 0.4.0: app 0.4.x needs
firmware 0.4.x, and older firmware (≤ 0.3.2) no longer works with the new app (and vice versa).

For the reasoning behind individual choices see `docs/DECISIONS.md`; this file only says what changed.

## 0.7.1 — unreleased (2026-11-27)

**Firmware 0.7.1** (same protocol 2); the app version is not bumped yet.

### Sensor firmware
- **Faster `TofNetJumpDetector`:** it now needs about 23 % of the processor time instead of about 83 %, also
  with the app connected, so it keeps up with all 416 samples per second. It detects the same jumps as before.
- **New: device health.** Once per second the sensor reports its sample rate, whether its sample clock (PLL) has
  locked, and the time since it started.

### App
- **New: sensor health** on the sensor page: sample rate, PLL state and time since start, live while connected.
  Older firmware shows "–".
- **New: language setting** under Appearance (System / English / Deutsch). The background notification
  follows it too.
- **New: change to the previous jump** in ms ("+12 ms", "−8 ms") under the last jump and as a "Δ" column in the
  routine table. Longer is blue, shorter red. On by default; switch it off under Jump display.
- **Changed:** in German a routine is now called "Übung".
- **Changed:** shorter texts on the LED signals page.

## 0.7.0 — unreleased (2026-11-24)

**App 0.7.0** (build 6) and **firmware 0.7.0**. New BLE protocol 2: app 0.7.0 needs firmware 0.7.0. Firmware
with protocol 1 no longer works with the new app (and vice versa).

### Sensor firmware
- **New detector `TofNetJumpDetector`** (tof_net, a small neural network) replaces `BedCycleJumpDetector` as
  the built-in algorithm. It reports final events only, up to about 170 ms after the event, without confidence,
  reasons or custom fields. **Known issue:** it needs about 83 % of the processor time, so under Bluetooth load
  samples can be lost.
- **Building** the firmware needs the Seeed Arduino LSM6DS3 library 2.0.8 or newer; older versions read the
  motion sensor at only 12.5 instead of 416 samples per second.
- **Default name:** a new sensor is called `OpenToF` followed by the last four characters of its serial number.
- **Fixed IMU settings:** the sensor always samples at 416 Hz, ±16 g, ±2000 °/s; algorithms can no longer pick
  a profile (`imuProfile()` is gone).
- **Removed:** the sleep command and the Info characteristic (boot counter, device time). The sensor still goes
  to sleep by itself after 1 minute without an app.

### App
- **Removed: "Put sensor to sleep"** and the "Sensor asleep" status, and the protocol version on the sensor page.
- **New warning** when the sensor uses a different protocol: its jumps are ignored, and the app asks you to
  update the sensor firmware or the app.
- **Changed: sensor restarts** are recognised from the jump numbers and event times instead of a boot counter.
  The first jump after a restart has no time on bed.

## 0.6.1 — unreleased (2026-11-24)

**Firmware 0.6.1** (app remains 0.6.0).

### Sensor firmware
- IMU sample timestamps now follow a software PLL that acquires the actual sample rate over its first 5-second sample window, then low-pass filters measurements and tracks slow clock drift.
- Serial replay keeps the PLL rate estimate during pauses, unlocks after one heartbeat without data, and excludes the first second after samples resume from rate estimation.

## 0.6.0 — unreleased (2026-10-14)

**App 0.6.0** (build 5) and **firmware 0.6.0**. Still BLE protocol 1: the new sleep command is optional, so
app 0.6.0 also works with firmware 0.5.0 (just without the sleep button), but it shows the version warning.

### Sensor firmware
- `firmware/README.md` now also explains the red charge LED (charging, full, off).

### App
- **Changed: when a routine starts.** Press Start while jumping: the jump you are in counts as jump 1, so the
  first landing after Start is jump 1. The jump that had already landed no longer counts, and pressing Start
  no longer beeps. The inactivity timeout now runs from the moment you press Start. A 1-jump routine ends on
  the first landing after Start.
- **Changelog in the app:** Settings → Version shows what changed in each release, with separate tabs for the
  app and the sensor firmware.
- **LED help page:** now also explains the red charge LED.

## 0.5.0 — unreleased (2026-10-09)

**App 0.5.0** (build 4) and **firmware 0.5.0**. The BLE protocol is unchanged (still protocol 1), but update
both: the app warns when the sensor still runs 0.4.x.

### Sensor firmware
- **Deep sleep:** the sensor goes to sleep after 1 minute without a connected app and without a jump, and
  uses far less battery while lying around. It never sleeps while an app is connected.
- **Shake or hit it to wake it up.** It reacts within about 4 seconds and then starts like after a reset, so
  the app sees a restarted sensor and reconnects as usual.
- While asleep, the sensor is not visible to the app and an upload from the Arduino IDE can fail: wake it
  first or simply retry the upload.
- **New LED signals:** slow blinking = waiting for the app (previously off), steady on = connected (as before),
  6 quick blinks = going to sleep, off = asleep, 3 short blinks = woken up. Timings and the remaining signals
  are listed in `firmware/README.md`.
- New settings in `config/FirmwareConfig.h`: switch deep sleep on/off, idle time before sleeping, how often
  the sleeping sensor checks for motion, how strong the motion must be, and the waiting blink rhythm.

### App
- **LED help page:** Settings → LED signals explains what the sensor's lights mean (waiting, connected, going
  to sleep, asleep, woken up, error), with a picture of each blink pattern.
- **CSV export without the `total` row:** every row after the header is now a jump (or a marker, see next).
- **Routine markers in time-range exports:** exporting the last 30 s / 1 min / 5 min adds `routine_start` and
  `routine_stop` rows at the right place between the jumps.
- **Fixed:** quitting the app or disconnecting no longer hangs while the sensor is out of reach.

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
