# OpenToF BLE protocol (version 1)
- All multi-byte values are **little-endian**.
- The 128-bit UUIDs spell `open-ToF` and differ only in the fourth group (`6f70656e-546f-4600-XXXX-000000000000`).
- The sensor advertises the Jump service; the app scans for that UUID.
- The protocol version (`proto`) is in every event.

## Services

### Jump service `6f70656e-546f-4600-0001-000000000000`

| Characteristic | UUID | Properties | Content |
|---|---|---|---|
| Event | `6f70656e-546f-4600-0005-000000000000` | Notify | One takeoff/landing event, see below |
| Fields | `6f70656e-546f-4600-0007-000000000000` | Read | JSON array describing the event's custom fields |
| Reasons | `6f70656e-546f-4600-0008-000000000000` | Read | JSON array of up to 8 strings; entry *i* names reason bit *i* |
| Confidence kind | `6f70656e-546f-4600-0009-000000000000` | Read | `none`, `heuristic` (higher = better) or `calibrated` (N = N % of such events are right) |
| Device name | `6f70656e-546f-4600-0004-000000000000` | Read/Write | UTF-8, 1–20 bytes, stored in flash; default `OpenToF` |

- Each JSON string is at most 512 bytes (BLE attribute limit).
- An invalid name write is silently ignored by the firmware.
- Every custom characteristic has a *Characteristic User Description* descriptor (`0x2901`) with a description.

### Standard services (Bluetooth SIG UUIDs)

| Service | Characteristic | UUID | Value |
|---|---|---|---|
| Battery `180F` | Battery Level | `2A19` | uint8 0–100 %, Read/Notify |
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

## Event rules

**Two stages.** An event can be reported as *provisional* (a fast estimate) and later as *final* (~200 ms
after the event), or as final only. The app beeps, counts and shows the jump on the provisional landing and replaces
the values in place when the final arrives.

**Retractions.** A provisional event without a final yet can be withdrawn:
- retracted **takeoff** = the whole jump is void (it is never shown);
- retracted **landing** = the jumper is back in the air; a new landing for the same jump may follow. The app removes
  the jump again everywhere, also from a running routine.

**Everything beyond the timestamps is optional.** Without confidence, reasons or custom fields the app just shows the
times.

## Custom fields (Fields characteristic)

A JSON array with one object per field, in packing order:

```json
[{"id":"li","name":"Landing intensity","t":"u8","on":"L","rel":true,"na":255}]
```

| Key | Required | Meaning |
|---|---|---|
| `id` | yes | Short stable key; also the CSV column name |
| `name` | yes | English label shown in the app |
| `t` | yes | Data type: `u8`, `i8`, `u16`, `i16`, `u32` or `i32` |
| `on` | yes | `T` = carried by takeoff events, `L` = landing events, `TL` = both |
| `desc` | no | Longer English description |
| `unit` | no | Unit shown after the value |
| `scale` | no | Shown value = raw × scale (default 1) |
| `rel` | no | `true` = only meaningful relative to other values of the same session |
| `na` | no | Raw value meaning "not available for this event" |

A takeoff event carries exactly the fields whose `on` contains `T`, a landing event those with `L`, at most 10
bytes per event.
