# OpenToF BLE protocol (version 1)

How the sensor talks to the app, and what a detection algorithm may report. Firmware side:
`firmware/OpenToF_Firmware/config/BleUuids.h` (UUIDs, layout), `core/JumpDetector.h` (algorithm API),
`core/JumpEventPublisher.h` (event rules). App side: `app/lib/data/ble/ble_protocol.dart` (UUIDs, parsing),
`app/lib/domain/jump_assembler.dart` (events → jumps). **Both sides must change together.**

- All multi-byte values are **little-endian**.
- The 128-bit UUIDs are **placeholders** until the protocol is frozen. They spell `open-ToF` and differ only in the
  fourth group (`6f70656e-546f-4600-XXXX-000000000000`).
- The sensor advertises the Jump service; the app scans for that UUID (device names can be changed by the user).
- The protocol version (`proto`) is in every event and in the Info characteristic. App and firmware with the same
  MAJOR.MINOR always speak the same protocol.

## Services

### Jump service `…0001…`

| Characteristic | UUID | Properties | Content |
|---|---|---|---|
| Event | `…0005…` | Notify | One takeoff/landing event, see below |
| Info | `…0006…` | Read | `proto u8`, `boot_count u16`, `device_time_ms u32` (fresh on every read) |
| Fields | `…0007…` | Read | JSON array describing the event's custom fields |
| Reasons | `…0008…` | Read | JSON array of up to 8 strings; entry *i* names reason bit *i* |
| Confidence kind | `…0009…` | Read | `none`, `heuristic` (higher = better) or `calibrated` (N = N % of such events are right) |
| Device name | `…0004…` | Read/Write | UTF-8, 1–20 bytes, no control characters, stored in flash; default `OpenToF` |
| Command | `…000a…` | Write (with response) | 1 byte: `0x01` = go to deep sleep now; other values are ignored |

- `…0002…` and `…0003…` (the Landing/Takeoff characteristics before protocol 1) are retired; don't reuse them.
- Each JSON/metadata string is at most 512 bytes (BLE attribute limit).
- An invalid name write is silently undone by the firmware (ArduinoBLE can't reply with an error), so the writer
  gets no error. The app does not check the 20-byte limit yet.
- The **Command** characteristic exists only in firmware builds that can sleep (not in `DEMO_MODE`). Its presence is
  the feature flag; the app hides "Put sensor to sleep" without it. After the command the sensor answers the write,
  disconnects after ~200 ms and sleeps until it is moved.
- Every custom characteristic has a *Characteristic User Description* descriptor (`0x2901`) so scanner apps such as
  nRF Connect show what it is.

### Standard services (Bluetooth SIG UUIDs)

| Service | Characteristic | UUID | Value |
|---|---|---|---|
| Battery `180F` | Battery Level | `2A19` | uint8 0–100 %, Read/Notify (rough single-cell LiPo curve) |
| Device Information `180A` | Manufacturer Name | `2A29` | `OpenToF` |
| | Model Number | `2A24` | `OpenToF Sensor` |
| | Serial Number | `2A25` | BLE device address |
| | Hardware Revision | `2A27` | `HARDWARE_REVISION` (currently `0.1`) |
| | Firmware Revision | `2A26` | `FIRMWARE_VERSION`, e.g. `0.6.0` |
| | Software Revision | `2A28` | Name of the active detection algorithm (≤ 32 bytes) |
| Generic Access `1800` | Appearance | `2A01` | `0x0540` (Generic Sensor) |

There is no charging state: the board's charger only drives the red LED and the MCU can't read it.

## Event layout

10 fixed bytes, then 0–10 bytes of custom fields:

| Bytes | Field | Type | Meaning |
|---|---|---|---|
| 0 | `proto` | u8 | Protocol version (1) |
| 1–2 | `jump_id` | u16 | +1 per new jump (wraps); takeoff and landing of a jump share it |
| 3 | `kind` | u8 | bit 0: 0 = takeoff, 1 = landing; bits 1–2: 0 = provisional, 1 = final, 2 = retracted |
| 4–7 | `t_ms` | u32 | Time of the event in ms since the sensor started (0 for a retraction) |
| 8 | `confidence` | u8 | 0–100, 255 = not provided |
| 9 | `reasons` | u8 | Bit mask; names come from the Reasons characteristic |
| 10… | extras | | Custom fields in the order of the Fields characteristic |

The sensor has no wall clock. The app derives everything from the event times: flight time = landing − takeoff of the
same jump, time on bed = takeoff − previous landing. Routine timing (inactivity timeout) uses the phone's clock.

## Event rules

**Two stages.** An event can be reported as *provisional* (a fast estimate) and later as *final* (at most ~200 ms
after the event), or as final only. The app beeps, counts and shows the jump on the provisional landing and replaces
the values in place when the final arrives (no second beep). A stale provisional after its final is ignored.

**Retractions.** A provisional event without a final yet can be withdrawn:
- retracted **takeoff** = the whole jump is void (it is never shown);
- retracted **landing** = the jumper is back in the air; a new landing for the same jump may follow. The app removes
  the jump again everywhere, also from a running routine.

The firmware enforces the order (takeoff, landing, takeoff, …) in `JumpEventPublisher` and drops reports that break
it, logging `event ignored: …` over serial: a landing without a takeoff, a second takeoff while airborne, a final
for an event that is already final, a retraction without a matching provisional event.

**Everything beyond the timestamps is optional.** Without confidence, reasons or custom fields the app just shows the
times.

**Restarts.** The boot counter (Info characteristic) goes up on every real start of the sensor (power-on, reset,
waking up from deep sleep). When it has changed on reconnect, the app forgets its jump bookkeeping, because the
device clock and the jump ids started over. The first takeoff after a start has no previous landing, so its time on
bed is unknown.

**Missed events.** There is no buffer on the sensor: events while no app is connected are lost. The app flags a gap
in `jump_id`, or a jump that never got both a takeoff and a landing, as a *missed event* (warning icon, CSV column)
and never makes up a jump. A jump id far behind the last one (≥ 0x8000 back, modulo 2¹⁶) is treated as a restart.

**Uncertain jumps.** A jump with a reason bit set or a confidence below 50 gets a "?" icon in the routine table. A
jump with a flight time over 2.5 s is treated as a glitch: it is left out of routine, display, chart and CSV and only
shown as a warning marker on the chart.

## Custom fields (Fields characteristic)

A JSON array with one object per field, in packing order:

```json
[{"id":"li","name":"Landing intensity","t":"u8","on":"L","rel":true,"na":255}]
```

| Key | Required | Meaning |
|---|---|---|
| `id` | yes | Short stable key; also the CSV column name |
| `name` | yes | English label shown in the app |
| `t` | yes | `u8`, `i8`, `u16`, `i16`, `u32` or `i32` |
| `on` | yes | `T` = carried by takeoff events, `L` = landing events, `TL` = both |
| `desc` | no | Longer English description |
| `unit` | no | Unit shown after the value |
| `scale` | no | Shown value = raw × scale (default 1) |
| `rel` | no | `true` = only meaningful relative to other values of the same session |
| `na` | no | Raw value meaning "not available for this event" |

A takeoff event carries exactly the fields whose `on` contains `T`, a landing event those with `L`, at most 10
bytes per event. If the byte count doesn't match, the app ignores the extras of that event. Field names and reason
texts are shown in English only.

## Writing a detection algorithm

An algorithm is a class derived from `JumpDetector` (`firmware/OpenToF_Firmware/core/JumpDetector.h`); start from
`algorithms/MyJumpDetector.h`. `onSample()` gets every IMU sample (acceleration in g, rotation rate in deg/s,
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
