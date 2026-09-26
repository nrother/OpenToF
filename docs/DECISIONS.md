# OpenToF App — Resolved Decisions

Authoritative answers from the product owner (2026-09-21). **Where this file conflicts with
`app/OpenToF-App-Specification-v0.1.md`, this file wins.** Anything not covered by either file is
an open question: ask the user, never assume.

## Project identity / platform
- Display name `OpenToF`, Dart package `opentof_app`, application/bundle ID `com.opentof.app`.
- Flutter, iOS + Android. Min OS: **Android 10 (API 29) / iOS 15**.
- UI languages: **English + German** (Flutter localization, follows device language).
- Metric units only. No accounts/cloud. Single sensor, but device-selection code stays multi-sensor friendly.

## Scope changes vs. spec
- **Jump height: IN v1 as beta** (h = g·t²/8, "beta" tag). Spec §7/§8 mentions of it are outdated.
- **Raw data stream: OUT of v1 entirely.** No Raw Data Mode toggle, no Raw Sample characteristic,
  no raw export (hardware doesn't support it yet). Remove from §5.3 settings. Keep code structure open to add later.
- Debug-only **MockSensor** (fake jumps, battery drain, disconnects) behind the same interface as the BLE sensor.

## BLE protocol 1 (decided 2026-09-26; placeholder UUIDs in ONE file: `app/lib/data/ble/ble_protocol.dart`)
Replaces the earlier Landing/Takeoff characteristics (flight/contact time + own sequence counters). The
interface for algorithm authors is written up in the "Agreed interface v1" tab of the shared doc
https://claude.ai/code/artifact/59d98f08-6d4f-4f13-aa63-a004c582f621; firmware side: `config/BleUuids.h`,
`core/JumpDetector.h`, `core/JumpEventPublisher.h`.
- All multi-byte values **little-endian**. UUIDs are placeholders until firmware agrees.
- Figure: `docs/figures/jump_timing.svg` (source `jump_timing.typ`, Typst + CeTZ) shows takeoff/landing, ToF, ToB,
  total time and the provisional/final reports for a jump N.
- The sensor reports **events** (takeoff, landing) with a **device timestamp** (ms since boot, uint32); the app
  derives flight time (ToF = landing − takeoff of the same jump), contact time (ToB = takeoff N − landing N−1),
  height and totals. **No UTC / wall clock** on the device: the app uses phone receive times for routine timing.
- Jump Service:
  | Characteristic | Props | Payload |
  |---|---|---|
  | Event (`…0005…`) | Notify | `proto u8` (1), `jump_id u16`, `kind u8` (bit 0: 0 takeoff / 1 landing; bits 1–2: 0 provisional / 1 final / 2 retracted), `t_ms u32`, `confidence u8` (0–100, 255 = none), `reasons u8` (bitmask), then ≤ 10 bytes of custom fields |
  | Info (`…0006…`) | Read | `proto u8`, `boot_count u16`, `device_time_ms u32` (fresh per read) |
  | Fields (`…0007…`) | Read | JSON array describing the custom fields (`id`, `name`, `t`, `on`, optional `desc`, `unit`, `scale`, `rel`, `na`) |
  | Reasons (`…0008…`) | Read | JSON array naming the reason bits |
  | Confidence kind (`…0009…`) | Read | `none` / `heuristic` / `calibrated` |
  | Device Name (`…0004…`) | Read/Write | UTF-8 string |
  The algorithm name stays in the Device Information service (Software Revision String). UUIDs `…0002…`/`…0003…`
  (old Landing/Takeoff) are retired, not reused. Each metadata string ≤ 512 bytes (BLE attribute limit).
- **Two stages:** an event may come as provisional (fast estimate) and then final (≤ 200 ms after the event), or
  final only. The app **beeps, counts and shows ToF on the provisional landing** and replaces the values in place
  when a final arrives (last jump, chart, routine table/total, CSV); no second beep. A **retracted landing**
  removes the jump again (from a running routine too, except the routine's first jump); a retracted takeoff
  voids the jump before it appears.
- Everything beyond the timestamps is **optional**: without confidence, reasons or custom fields the app just
  shows ToF/ToB.
- **Boot counter:** a changed `boot_count` on (re)connect ⇒ the app forgets its jump bookkeeping (device clock and
  jump ids restarted).
- Missed jumps: a `jump_id` gap, or a previous jump id that never became a complete jump ⇒ **count/continue,
  show a warning** on the affected row + routine, and a `missed_event` flag column in the CSV. Never fabricate a
  jump. **No replay buffer**: the connection is assumed to stay up; events while disconnected are lost.
- Dropped from the algorithm team's proposal: live-state characteristic (provisional events cover it), device
  health, commands, debug stream, replay buffer. Later: landing position / landing type (as custom fields).
- BLE library: flutter_blue_plus 2.x with `License.nonprofit` (`License.free` is deprecated in the package). The product owner confirmed OpenToF qualifies as non-profit under the package's license terms (2026-09-21). If that ever stops being true (e.g. commercial distribution), change the license in `ble_sensor.dart` or switch libraries.
- Scan filter: by Jump Service UUID (names are user-assignable). Flag for firmware confirmation.

## Routine state machine
- States: Idle → Running → Complete | Cancelled. Complete/Cancelled **stay on screen (table, total, export) until Start is pressed**; there is no user-triggered "return to Idle" action.
- **Start** is enabled only if the last jump landed ≤ inactivity timeout (default 4 s) ago; otherwise disabled greyed out, with a hint. That jump becomes #1; the inactivity timer runs from its landing time and resets on every new landing.
- Inactivity timeout → Cancelled (progress retained, exportable). Cancel button always available while Running.
- Jump #10 → Complete: final beep, table + total, export control.
- **Disconnect:** routine pauses (no jumps can arrive; progress retained), app tries to reconnect. The inactivity timer **keeps running** — a disconnect longer than the timeout cancels the routine. Reconnect within the timeout resumes it.
- No manual jump correction. Every detected jump counts.

## Feedback / Export / Settings
- Audio: per-jump beep (toggle) plays on jumps **#1–#9, including #1 at the moment Start is pressed**; jump **#10 plays only the distinct final sound** (own separate toggle; muting it = silence on #10, independent of the per-jump toggle). Sounds are synthetic tones generated by script and bundled in `app/assets/sounds/`. No connection-error sound.
- Chart: **bar chart, one bar per jump** (height = flight time) over a time-based rolling window (30 s / 1 min default / 5 min; Settings). Clear button empties it.
- Export: CSV via OS share sheet only; columns jump number, flight time, contact time, total time (contact + flight), (beta) height, missed_event flag, provisional flag, confidence, reasons, then one column per custom algorithm field (by `id`); total as footer row. Works for Complete and Cancelled routines, and for the last 30 s / 1 min / 5 min of jumps (see below). No history browser.
- Settings: scan/select device, rename device, unpair, battery time remaining (phone-side extrapolation of recent battery readings), inactivity timeout (default 4 s), per-jump beep toggle, final-jump sound toggle, window length. **The start screen is always the main screen** (changed 2026-09-22; overrides the earlier "first launch opens on Settings/Pairing"). With no paired sensor the main screen shows a tappable "Pair your OpenToF sensor to get started." card that opens Settings.
- Android: foreground service keeps BLE alive. iOS background BLE best-effort.

## Implementation choices (engineering, not product decisions — change freely)
- Jump height uses g = 9.81 m/s². CSV in seconds/meters, 3 decimals, `.` separator, CRLF; header names are English (not localized); empty cell = unknown contact.
- Jump-id handling (`JumpAssembler`): first id = baseline; an id more than 1 ahead = gap; an id far behind (≥ 0x8000 back, mod 2^16) = sensor restart (new baseline, no warning); a lone landing right after (re)connecting (connected mid-flight) is no warning. Contact time skips ids voided by a retracted takeoff. A stale provisional after its final is ignored.
- Uncertain jump = the sensor set a reason bit, or confidence < 50 (`lowConfidenceThreshold` in `jump.dart`): a `help_outline` icon on the routine row with confidence + reason texts as tooltip (reason texts come from the sensor, English only). If a final makes a jump implausible (> 2.5 s) it is removed and marked like any implausible jump.
- Routine timing uses phone-side receive time of the landing event as "landing time".
- Battery estimate: least-squares slope over recent readings (max 200); needs ≥ 5 min span and ≥ 1 % drop; a rising level clears history. In-memory only (not persisted across app restarts).
- Inactivity timeout setting range in UI: 1–30 s (step 1).
- Riverpod 3 for state; the bar chart is a custom `CustomPainter` (time-proportional x axis, which fl_chart's bar chart can't do); audioplayers, share_plus, shared_preferences, flutter_blue_plus, flutter_foreground_task, permission_handler.
- `permission_handler` is pinned to ^12.0.1: 13.x needs compileSdk 37, but the current Android Gradle plugin (9.1.0) supports at most 36. Revisit when Flutter's default AGP/compileSdk moves to 37.
- Routine/Start-eligibility time uses `clockProvider` (injectable) so tests can control time.
- Android BLE permissions: BLUETOOTH_SCAN (neverForLocation) + BLUETOOTH_CONNECT on 12+, legacy BLUETOOTH/ADMIN + location (maxSdk 30) on Android 10/11. Foreground service type `connectedDevice`, started while a sensor is paired.
- Android permissions at runtime: `permission_handler` requests only BLUETOOTH_SCAN + BLUETOOTH_CONNECT (location is left to flutter_blue_plus on Android 10/11; requesting it on 12+ only logged "No permissions found in manifest"). Before scanning, `ensureBluetoothOn()` shows the system enable-Bluetooth prompt if the adapter is off.
- iOS: `NSBluetoothAlwaysUsageDescription` + `UIBackgroundModes: bluetooth-central` (English text only for now).

## Routine length, chart pause, event markers, theme (decided 2026-09-22)
- **Jumps per routine** is a setting (integer text field in Settings > Routine, default 10, **minimum 1, no product maximum**; technical cap 999 so the table/input stay sane). Fixed when a routine starts (changing it mid-routine affects the next one). The last jump plays only the final sound; a 1-jump routine completes at Start (Start's jump is #1).
- **Chart Pause = freeze the view only**: the window stops at the pause time (axis label "paused"); jumps and sensor events keep being recorded and appear after Resume. A running routine is not affected. Clear keeps the pause state. Not persisted.
- **Sensor event markers are automatic and always visible** on the chart: a vertical line + Bluetooth icon for "connected" and "disconnected" (plus a legend for the types in view). Only real transitions are marked: reaching connected, and losing an established connection (not each failed reconnect attempt). Events are pruned with the 5-min history and cleared by Clear. No manual markers.
- **Theme**: light and dark themes already existed (following the device). Settings > Appearance now has System (default) / Light / Dark.

## Chart: routine start/stop markers, implausible-jump filtering (decided 2026-09-24)
- **Routine start/stop are chart events**, same mechanism as connect/disconnect: `routineStarted` when a routine successfully starts (`SessionController.startRoutine`), `routineStopped` when it stops for any reason (10th jump reached, user Cancel, or inactivity timeout) — **one marker regardless of why it stopped**, no separate "completed" vs "cancelled" marker. A 1-jump routine (completes immediately at Start) gets both markers at the same instant.
- **Implausible jump filtering**: a jump with flight time **> 2.5 s** (`maxPlausibleFlightSeconds` in `app/lib/domain/jump.dart`) is almost certainly a sensor glitch, not a real trampoline jump. It is **excluded from the routine (doesn't consume one of the N jump slots), the last-jump display, the chart's jump bars, `history`, and CSV export** — but a distinct `implausibleJump` chart marker (warning-triangle icon) is still added, so it's visible while debugging the firmware rather than silently vanishing. The threshold is a hardcoded constant, not a Settings option, for now.
- Engineering: filtering happens in `SessionController._onLanding` (checks `Jump.isImplausible`), after `JumpAssembler` has already updated its sequence-gap bookkeeping — a filtered-out jump still correctly contributes to missed-notification detection for the *next* jump, it just never becomes a `Jump` the rest of the app sees.

## Exiting the app (Android, decided 2026-09-21)
- The foreground service kept the app alive with no way to quit, so three exits exist: **(1)** an "Exit" button on the foreground-service notification, **(2)** "Exit app" in Settings (Android only) with a confirmation dialog, **(3)** pressing Back twice **on the main screen only** (in Settings Back just returns; first press shows "Press back again to exit", second within 2 s exits).
- Exit = disconnect sensor, stop the foreground service, close the activity (`SystemNavigator.pop`). Pairing is kept; a running routine is lost. The notification button exits immediately (no dialog possible from a notification; if the UI is already gone it just stops the service). iOS has no exit option (not allowed by the platform).
- Engineering: `exitAppProvider` (overridden in tests), `ForegroundService` relays the button press from the service isolate to the main isolate (`initCommunicationPort` in `main()`).

## Branding & version (decided 2026-09-21, logo replaced 2026-09-26)
- **Sources live in the repo root `img/`** (shared by app, docs and README; the app only holds derived copies):
  - `opentof-logo.svg` / `opentof-logo.png`: the logo (stopwatch, jumper, trampoline), blue `#0153E3`, red `#DE2237`
    bed marking, transparent background with an opaque white bed.
  - `OpenToF_Wordmark.png`: the "OPENTOF" lettering, black on transparent.
  - Built from those by `img/make_wordmark.py` (Pillow): `OpenToF_Wordmark_color.png` ("OPEN" dark blue `#0B2A6F`,
    "TOF" logo blue) and `OpenToF_Wordmark_logo.png` (same, second O replaced by the logo at 2x the letter height,
    the lower edge of its white trampoline bed on the letters' baseline).
  - **Dark-theme versions** (same script; rendering the recoloured SVG needs `typst` on PATH): `opentof-logo-dark.svg` /
    `.png` (blue lightened to `#5B9BFF`, white bed and red marking kept) and `OpenToF_Wordmark_color_dark.png` /
    `OpenToF_Wordmark_logo_dark.png` ("OPEN" `#E8EEFA`, "TOF" `#5B9BFF`). Contrast on the app's dark surface `#121318`:
    ≥ 6.7:1 instead of 3.0:1 (logo blue) / 1.4:1 (dark blue). The app picks them by theme brightness (`BrandMark`,
    `BrandLogo`: `OpenToF_mark_dark.png`, `OpenToF_wordmark_dark.png`) and the dark native splash uses them
    (`image_dark`). The launcher icon stays the light version (it sits on white).
- Replaced (removed): the old wordmark logo `app/assets/images/OpenToF_logo.png` (+ derived `OpenToF_logo_wordmark.png`),
  the interim mark `app/assets/branding/app_icon2.png`, and `img/OpenToF_logo.png`.
- `app/tool/generate_branding.ps1` derives the app images from `img/`: `assets/images/OpenToF_wordmark.png` (logo
  wordmark, Settings header), `assets/images/OpenToF_mark.png` (logo, app bar) and `assets/branding/` (launcher icon:
  iOS + Android adaptive on white, Android 13 themed/monochrome layer; native splash: transparent logo on white light /
  `#121318` dark; Android notification status-bar icon `ic_stat_opentof`). White/monochrome variants knock the white
  bed out as a hole. Then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
- Theme seed and notification accent colour: the logo blue `#0153E3` (Material 3 derives a tonal palette from it, so
  the exact primary differs slightly).
- In-app: `BrandMark` (logo) in the main-screen app bar next to the title; `BrandLogo` (logo wordmark, transparent,
  light/dark version by theme; scales down to fit narrow phones) at the top of Settings. Not in an About section.
- Settings shows the app version (`version` from `app/pubspec.yaml`, as "0.4.0 (3)") in an About section.
- Web target files (`app/web/`) are not branded (not a v1 target).

## Firmware (`firmware/OpenToF_Firmware/OpenToF_Firmware.ino`, decided 2026-09-21)
- Silicon Labs Arduino core, protocol stack **"BLE (Arduino)"** (ArduinoBLE API); IMU via Seeed_Arduino_LSM6DS3 (I2C 0x6A, IMU powered from PD5); battery via PD3 (enable) / PD4 (ADC, ½ divider), mapped to % with a rough single-cell LiPo curve.
- **Device name max length: 20 UTF-8 bytes.** Firmware validates writes (length, valid UTF-8, no control chars) and restores the old value on invalid writes (ArduinoBLE cannot return an ATT error). Name persisted in flash (EEPROM library). Default name `OpenToF`.
- **One firmware sketch** (`firmware/OpenToF_Firmware/OpenToF_Firmware.ino`, v0.2.0+): **plug-in detector interface**. The user writes their algorithm in `MyJumpDetector::onSample(const ImuData&)`, which receives real IMU data as floats (accel in g, gyro in deg/s, timestamp, dt) and reports events by calling `takeoff(timeUs)` / `landing(timeUs)`. `DEMO_MODE` defaults to 0 (real IMU); setting it to 1 in `config/FirmwareConfig.h` sends **simulated jumps** instead, no real detection — use that to test the app/BLE link without hardware. `IMU_SERIAL_LOG` (default 0) prints samples as CSV over Serial for looking at real data.
  - **Removed 2026-09-22**: the separate `firmware/OpenToF_Firmware_Dummy/` sketch (single-file, v0.1.0, always `DEMO_MODE 1`) has been deleted; `DEMO_MODE 1` in the one remaining sketch is a superset (also gets the Device Information Service and every later change) and there is no reason to maintain two sketches. Any doc or script that still points at `OpenToF_Firmware_Dummy` is stale.
- The detector itself is still not implemented (empty template with a commented illustration, not a tested algorithm). Raw streaming over BLE is not implemented (out of v1).
- **Both IMU profiles are implemented**: 416 Hz / ±8 g and 833 Hz / ±16 g. A detector states its own preference by overriding `imuProfile()`; the default follows the compile-time toggle `IMU_USE_HIGH_RATE_PROFILE`. (Interpretation of "create a toggle": compile-time, not a BLE-writable setting, because the app protocol has no config characteristic.)
- IMU is read as six separate 2-byte register reads (gyro X,Y,Z then accel X,Y,Z; see the bug below for why, not one 12-byte burst) at 400 kHz, paced by `micros()`; not yet using the data-ready interrupt/FIFO (timing jitter of a few ms possible). Effective rate ends up below the nominal ODR (~285 Hz measured against the 833 Hz profile) because of the extra per-read I2C overhead — comfortably fine for jump detection, but a ceiling to keep in mind if a future algorithm wants closer to the nominal rate.
- **"No IMU data" on real hardware, found and fixed (2026-09-22, confirmed against two physical boards).** First attempt (reordering `Wire.setClock(400000)` to run before `_imu.begin()`, reasoning it was silently not taking effect) compiled and looked plausible but **did not fix it** — verified live over serial (background-job listener draining the actual COM port while reflashing, since USB-CDC buffers held stale data across quick open/close cycles and made a couple of earlier reads misleading). Root cause, found by direct experimentation on live hardware: our 12-byte single-transaction burst read (gyro X..Z + accel X..Z in one continuous I2C transaction from register 0x22) failed 100% of the time, while the Seeed library's own `readFloatAccelX()`/`readFloatGyroX()` etc. (six independent 2-byte reads, never one combined burst — confirmed by reading the library source) succeeded with real, gravity-consistent values, **running concurrently on the same bus at the same moment** our burst read kept failing. BLE was ruled out first (identical failure with `BLE.begin()`/advertising/connection entirely removed from a test build); a raw address scan's "112 addresses ACK" result was a false lead (a zero-data-byte `endTransmission()` isn't a reliable presence probe on this Wire driver — real transactions with an actual register byte work fine). Fix in `core/ImuSource.h`: `readSample()` now calls `_imu.readRegisterInt16()` six times (one per axis register pair: `0x22/0x24/0x26` gyro, `0x28/0x2A/0x2C` accel) instead of one 12-byte burst; `Wire.setClock()` before `_imu.begin()` was kept since it's harmless and matches `firmware/datalogger/datalogger.ino` (a minimal, confirmed-working reference sketch for this exact board).
- **`firmware/datalogger.ino` moved to `firmware/datalogger/datalogger.ino`** (2026-09-22): it was a loose file directly in `firmware/`, which the Arduino IDE/`arduino-cli` cannot open or compile at all — a sketch's folder name must match its main `.ino` filename (confirmed: `arduino-cli compile` on the old path failed with "Hauptdatei fehlt im Sketch" / main file missing). Companion files the sketch's own comments expect next to it (`capture_serial.py`, a `README.md`) do not exist yet — out of scope here, belongs to whoever owns the data-analysis side. After the move, compiled and flashed to a real board and functionally verified: `s` starts a recording, real CSV rows come out with physically plausible accel/gyro values (confirms its read approach, the same six-small-reads pattern as the fix above, genuinely works on this hardware). Observed nearly every row flagged `status=1` (late) at an effective ~160 Hz against the 416 Hz nominal rate during that test — likely an artifact of the slow (150 ms-interval) polling script used to read it rather than a firmware bug, since a real terminal drains continuously; not fixed or investigated further, flag if it reproduces with a real serial terminal.
- **Diagnostic serial logging** (2026-09-22, all compiled out when `DEBUG_SERIAL` is 0): `ImuSource` prints an "IMU: N samples in 2 s (~Hz), M I2C failures" heartbeat every `IMU_HEARTBEAT_MS` (`config/FirmwareConfig.h`); `JumpEventPublisher` logs every transition the algorithm reports, including ones the firmware ignores (duplicate takeoff, landing before any takeoff); `BleService` logs when an event is sent but no app is subscribed. This is what surfaced the bug above — read it top to bottom when a detector reports nothing: no `IMU:` lines at all → check `DEBUG_SERIAL`/baud; `0 samples ... NO DATA` → I2C read is failing (see the bug above for the fix already applied — if it recurs, add a live I2C scan and cross-check against the library's own accessor before assuming it's the same cause); healthy sample rate but never a takeoff/landing line → the algorithm itself isn't firing; "ignored" lines → algorithm state-machine bug; normal lines but the app sees nothing → check for "no app subscribed".
- Arduino IDE pitfall: free functions must not use sketch-defined types in signatures (auto-generated prototypes sit above the type definitions).
- Protocol 1 (firmware v0.4.0, 2026-09-26): `jump_id` increments per new jump even while disconnected. The first takeoff after boot is sent like any other (the app shows its contact time as unknown). `JumpEventPublisher` enforces the provisional/final/retract rules and drops + logs (`event ignored: …`) calls that break them. Boot counter in EEPROM at offset 32 (magic `0x42 0x43` + u16), incremented in `setup()`. Metadata strings whose length is an exact multiple of 22 get a trailing space (ArduinoBLE answers a read blob at offset == length with an error). `DEMO_MODE 1` sends two-stage events with confidence, a reason bit, the two intensity fields and occasional retracted false landings.
- Unverified engineering choices: gyro range ±500 dps, connection interval 7.5–15 ms, advertising interval 100 ms, onboard antenna selected (PB5 high, PB4 low, as in Seeed's BLE example).
- **Firmware v0.3.0 is multi-file** (2026-09-21): `OpenToF_Firmware.ino` holds only `setup()/loop()`; everything else is a header in one of three subfolders: `config/` (`FirmwareConfig.h` settings + identity strings, `BleUuids.h` all UUIDs + protocol text), `algorithms/` (one header per algorithm — `MyJumpDetector.h`, `StaLtaJumpDetector.h`, `AzPipelineJumpDetector.h`; `BatteryCurve.h` voltage→%), `core/` (plumbing, normally not edited). Includes are relative to the including file (`../core/X.h`); the sketch root is NOT on the include path. Note: the Arduino IDE 2 only shows root-level files as tabs, so files in the subfolders have to be opened in another editor (compiling is unaffected).
- **Algorithm selection lives at the top of the `.ino`** (2026-09-22, at the user's request, revised same day to a plain comment-toggle after an intermediate numeric-macro version felt overbuilt): an "Algorithm selection" block right under the file header comment has one `#include "algorithms/X.h"` + `typedef X ActiveJumpDetector;` pair per algorithm; exactly one pair is uncommented. No `Algorithms.h` dispatcher file. To add an algorithm: copy `MyJumpDetector.h`, rename the class, and add a new commented-out pair to the block (or uncomment it to make it active). Uncommenting zero or more than one pair is a normal-looking compiler error (`ActiveJumpDetector` undeclared, or redefinition) rather than a custom check.
- **Standard BLE fields exposed (v0.3.0)**, all Bluetooth SIG assigned 16-bit UUIDs (verified against the SIG list as mirrored by Nordic's bluetooth-numbers-database, Zephyr and bleak):
  | Service | Characteristic | UUID | Value |
  |---|---|---|---|
  | Battery `180F` | Battery Level | `2A19` | uint8 0–100, Read/Notify (unchanged) |
  | Device Information `180A` | Manufacturer Name String | `2A29` | `OpenToF` |
  | | Model Number String | `2A24` | `OpenToF Sensor` |
  | | Serial Number String | `2A25` | BLE device address (unique per chip) |
  | | Hardware Revision String | `2A27` | `HARDWARE_REVISION` in `FirmwareConfig.h`, placeholder `1.0` |
  | | Firmware Revision String | `2A26` | `FIRMWARE_VERSION`, `0.3.0` |
  | | Software Revision String | `2A28` | name of the active jump detector (`JumpDetector::name()`, e.g. `MyJumpDetector`; `Demo (simulated jumps)` in demo mode), cut to 32 bytes |
  | Generic Access `1800` | Appearance | `2A01` | `0x0540` Generic Sensor |
  All DIS values are UTF-8, Read only, ≤ 32 bytes. Not exposed but listed in `BleUuids.h` as candidates: System ID `2A23`, PnP ID `2A50`, Battery Time Status `2BEE` / Critical Status `2BE9` / Power State `2A1A`, Temperature `2A6E`.
- **Descriptions for the custom characteristics**: every custom characteristic (Event, Info, Fields, Reasons, Confidence kind, Name) carries a GATT *Characteristic User Description* descriptor (`0x2901`, texts `DESC_*` in `BleUuids.h`) so scanners show what they are. Services cannot carry descriptions.
- **No charging flag** (decided 2026-09-22): the Battery Level Status characteristic (`2BED`) is not exposed. The XIAO MG24's charger only drives the red charge LED; the Seeed wiki says the charge state is not available to the MCU and the Silicon Labs core defines no charge/VBUS pin. The product owner does not want inferred data (e.g. a voltage guess), so the red LED is the charging indicator. Do not add a guessed charge state.
## App: Device Information Service (decided 2026-09-22)
- The app now reads all six fields above once per connection (`Sensor.readDeviceInfo()` / `BleSensor` reads them from the already-discovered services; `MockSensor` returns fixed placeholder values) and shows them read-only in **Settings → Device info** (below Battery, only while a sensor is paired): Manufacturer, Model, Serial number, Hardware revision, Firmware revision, and "Detection algorithm" (the Software Revision String). A missing field (older firmware) shows `–`; a read failure keeps whatever was read before rather than clearing it.
- `app/lib/data/ble/ble_protocol.dart` gained the Device Information Service UUID and its six characteristic UUIDs, plus a generic `parseUtf8String` (also backs `parseName`).

## App: sensor page, version warning, jump display, export choice (decided 2026-09-26)
- **Sensor page** (`lib/ui/settings/sensor_screen.dart`): tapping the paired sensor in Settings (tile or its chevron)
  opens it. It holds Battery, Device info (+ protocol version and boot count from the Info characteristic) and
  "Detection algorithm" (name, confidence kind, reason names, custom fields with description/unit/type). Settings
  keeps pairing, rename and unpair only.
- **Version warning**: shown in Settings (under the sensor) and on the sensor page when app and firmware
  MAJOR.MINOR differ (`lib/domain/version_check.dart`); no warning while the firmware version is unknown.
- **Jump display** settings: "Show time on bed" and "Show total jump time" (bed + flight), both off by default.
  They add a line under the last jump ("Bed: … Bed+Flight: …") and table columns; with extra columns the "s" unit
  moves into the column headers and cell padding shrinks so the table fits a 360 dp phone. Total time is unknown
  when the contact time is (first jump after connecting). The routine total row stays flight-only.
- **Export chooser**: the export button shows whenever there is a finished routine or any jump in the chart
  history; a bottom sheet offers the recorded routine or the last 30 s / 1 min / 5 min (the chart window options,
  max = the 5 min history). File names `opentof_routine_…csv` / `opentof_jumps_…csv`. CSV gained `total_time_s`.
- **More jump details** (setting, off by default; chosen with the product owner): one switch plus a checklist of
  the sensor's values (its confidence and each custom field; stored as *hidden* ids in `hidden_jump_details`, so
  values a new algorithm adds show up by default). When on: one grey line under the last jump ("Confidence 87 % ·
  Landing intensity 143"), one routine-table column per chosen value (more than 5 columns → the table scrolls
  sideways), and tapping the last jump, a table row or a chart bar opens a sheet with everything about that jump
  (all values regardless of the checklist). The checklist only lists values of the currently connected sensor.

## Still open (do not assume — ask when reached)
- Real GATT UUIDs (placeholders in both app and firmware).
- Whether custom-field names/descriptions should be translated (currently English from the sensor; the app could map known `id`s).
- The real takeoff/landing detection algorithm (to be written by the user in `MyJumpDetector`).
- Very long contact times (standing still, then bouncing) are reported as-is; the app/firmware may want a cap.
- Whether the hardware revision string (`0.1` in `FirmwareConfig.h`, documented above as placeholder `1.0` — check which is current) is right for the real board.
