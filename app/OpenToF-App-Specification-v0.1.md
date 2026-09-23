# OpenToF Companion App — Specification (Draft v0.1)

Status: **Draft for discussion.** Sections marked *(proposed)* are suggestions to react to, not decisions. Open items are tracked at the end.

## 1. Purpose

A mobile app (iOS + Android) that connects to a single OpenToF sensor unit and displays trampoline "time of flight" (jump flight time) data in real time, and lets a coach/gymnast run a structured 10-jump routine.

**Scope:** training aid and casual/informal competition use. **Not** intended (in this version) to meet FIG official competition scoring requirements.

## 2. Hardware Reference

- Board: Seeed XIAO MG24 Sense (Silicon Labs EFR32MG24, Cortex-M33, BLE 5.3).
- Sensor: onboard 6-axis IMU (LSM6DS3TR-C), accelerometer + gyroscope, sampled at 400–800 Hz.
- Mounting: fixed to the trampoline frame near the springs (not worn by the gymnast).
- The firmware (not the phone) is responsible for detecting takeoff/landing events from the IMU signal. It is assumed reliable for this app's purposes — algorithm correctness is out of scope for this document.
- Single sensor per app in this version; app should not assume it will never need more (see §8).

## 3. Core Domain Concepts

- **Jump**: one takeoff→landing cycle. Has a **flight time** (airborne duration) and a **bed contact time** (time on the bed before the next takeoff, i.e. time between landing and the *next* takeoff).
- **Last Jump**: the flight time of the most recently completed jump. Updated continuously, live, any time the sensor detects a jump — including outside of a formal routine (casual bouncing).
- **Routine**: a fixed sequence of 10 consecutive jumps, started explicitly by the user. Jump #1 of a routine is *the jump that just happened* at the moment Start is pressed (i.e. the current "Last Jump" becomes jump #1 immediately — a routine can complete instantly if 9 more jumps follow in quick succession). Jumps #2–#10 are the next 9 detected jumps in sequence.

## 4. BLE Interface *(proposed)*

### 4.1 Device identity & advertising
- Each sensor advertises with a **user-assignable name** (stored on-device, settable from the app's pairing screen), so the app can show a friendly name rather than a MAC address.
- No authentication/pairing security required for v1 (single trusted sensor, gym environment).

### 4.2 Connection model
- The app connects **on app open** and holds the connection **persistently** while the app is running.
- No absolute time sync between device and phone — the device never needs to expose wall-clock time; all values are relative durations per event.
- On disconnect: app shows a connection-lost state, **pauses** any in-progress routine without discarding its progress, and attempts to reconnect. If reconnection succeeds, the routine can resume from where it left off.
- Android: use a foreground service to keep the BLE connection alive while backgrounded.
- iOS: rely on the standard "already-connected peripheral can still deliver notifications in background" behavior; full background operation is not guaranteed and is treated as best-effort (see open items, §9).

### 4.3 GATT services/characteristics *(proposed layout — needs firmware-side confirmation)*

**Jump Service** (custom UUID, TBD)
| Characteristic | Properties | Payload (proposed) |
|---|---|---|
| Jump Event | Notify | `flight_time_ms: uint32`, `contact_time_ms: uint32`, `sequence_number: uint32` (monotonically increasing counter, lets the app detect missed/dropped BLE notifications) |
| Raw Data Mode | Read/Write | `enabled: uint8` (0/1) — toggles the device between normal (jump-event-only) mode and raw streaming mode |
| Raw Sample | Notify (only active when Raw Data Mode = 1) | `timestamp_ms: uint32` (device-relative), `accel_x/y/z: int16`, `gyro_x/y/z: int16` |
| Device Name | Read/Write | UTF-8 string, user-settable |

**Standard Battery Service** (0x180F)
| Characteristic | Properties | Payload |
|---|---|---|
| Battery Level | Read/Notify | `level: uint8` (0–100%) |

- Confidence score was considered but is **not included** — algorithm can't reliably produce one yet; add later if/when available.
- Raw streaming mode is understood to increase sensor power draw; it is a developer/debug feature, off by default, toggled via a switch in app settings — not intended for coach/athlete daily use.

## 5. App Functional Requirements

### 5.1 Main Screen
- Large "Last Jump" flight time display, continuously updated live (works outside of routines too, for casual bouncing).
- A diagram/chart of recent jump history, using a **time-based rolling window** (default: last 1 minute, adjustable in Settings — e.g. last 30s/1min/5min).
- A **Clear** button to reset/empty the rolling history chart on demand.
- "Start Routine" button.
- Sensor connection status indicator + **battery icon**.
- Small/unobtrusive **export** control (only meaningful once a routine has completed).

### 5.2 Routine Flow (state machine)
1. **Idle** — last-jump display active, Start button available.
2. **Armed/Running** — user pressed Start:
   - The jump that just occurred becomes jump #1 immediately.
   - App displays a live table of 10 rows (jump number, flight time), with a running **sum of flight times** updated after each jump.
   - If no new jump is detected within a configurable **inactivity timeout** (default **4 seconds**, adjustable in Settings), the routine **automatically moves to Cancelled** (progress retained, per state 4 below).
   - A **Cancel** button is available at all times during a routine.
   - On BLE disconnect: routine pauses (progress is **retained**, not discarded), reconnection is attempted; on reconnect, routine resumes from current progress.
3. **Complete** — after jump #10: play a completion beep, show final table + total, surface the export control.
4. **Cancelled** — user pressed Cancel, or the inactivity timeout was hit. Progress is **retained** (not discarded) — the partial jump table/total remains visible and exportable, same as a completed routine. Starting a new routine replaces it. Returning to Idle does not itself wipe the last routine's data; it's still exportable until a new routine starts.

- No manual jump correction/discarding in v1 — every detected jump counts.
- **Jump height (beta):** included in v1, computed from flight time via h = g·t²/8, but clearly labeled as a **beta/experimental** feature in the UI (e.g. a "beta" tag next to the value) since accuracy has not been validated.

### 5.3 Pairing / Settings Screen
- Scan for nearby named OpenToF devices, select one to connect.
- Rename the currently paired device.
- **Unpair** sensor.
- Show estimated **battery time remaining** (hidden here, away from the main screen). Estimated **phone-side**, by tracking recent Battery Level readings over time and extrapolating a drain rate — no firmware-side estimate needed.
- Raw-data developer mode toggle.
- Inactivity timeout value (default 4s, editable).
- On first launch with no sensor ever paired, the app opens directly into this screen.

### 5.4 Feedback
- Visual: live-updating jump table + running sum during a routine is the primary feedback mechanism.
- Audio: a beep on **each** of the 10 jumps as they're counted, plus a **distinct** sound for the 10th/final jump. Included in v1 as an experiment — BLE-notification latency may make per-jump beeps feel out of sync with the actual jump, so a **Settings toggle** lets users turn per-jump beeps off. The final-jump sound has its **own separate mute toggle**, independent of the per-jump-beeps toggle.
- No connection-error sound in v1.

### 5.5 Export
- Triggered from a small button on the main screen after a routine completes.
- Format: **CSV** (jump number, flight time, contact time; routine total as a summary row/footer).
- Delivered via the OS share sheet (Files/Mail/AirDrop/etc.) — the app does not manage a persistent export library in v1.
- No on-device routine history/browsing in v1; export-at-completion is the only persistence mechanism.

## 6. Non-Functional Requirements

- **Platform:** Flutter (single Dart codebase for iOS + Android), using a maintained BLE plugin (e.g. flutter_blue_plus or equivalent).
- **Units:** metric only (seconds, meters).
- **Accounts/cloud sync:** none. Explicitly out of scope, not just deferred.
- **Multi-athlete profiles:** not needed in v1, but data model should not preclude adding named profiles later.
- **Multi-sensor support:** not needed in v1 (single sensor assumed), but BLE/device-selection code should not hard-code a single-device assumption so deeply that adding a second sensor later requires a rewrite.

## 7. Out of Scope (v1)

- FIG-compliant competition scoring / certified accuracy.
- Confidence scoring and low-confidence jump flagging.
- Jump height display.
- Multiple simultaneous sensors or gymnasts.
- Cloud sync, accounts, or online mode.
- Persistent in-app routine history browser.

## 8. Future Considerations (not designed for, but kept in mind)

- Named gymnast profiles (local, no accounts).
- Multiple sensors / multiple simultaneous athletes.
- Confidence score once the algorithm supports it.
- Jump height estimation.
- Possible path toward stricter/competition-grade timing rules.

## 9. Open Items / TODO

- [ ] Exact BLE GATT UUIDs and payload byte layout — needs firmware-side agreement (this doc's §4.3 is a starting proposal).
- [ ] Minimum supported OS versions (iOS/Android) — to be checked against existing gym hardware.
- [ ] iOS background BLE behavior: confirm what's achievable in practice once BLE plugin is chosen; treat as best-effort per §4.2 until tested.
