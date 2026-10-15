# OpenToF firmware

Firmware for the OpenToF sensor: a [Seeed XIAO MG24 Sense](https://www.seeedstudio.com/Seeed-XIAO-MG24-Sense-p-6248.html)
(EFR32MG24 with an onboard LSM6DS3TR-C IMU) that detects takeoffs and landings and sends them to the app over BLE.
The protocol is in [`../docs/PROTOCOL.md`](../docs/PROTOCOL.md).

## Setup

Arduino IDE 2 (see also Seeed's [getting started guide](https://wiki.seeedstudio.com/xiao_mg24_getting_started/)):

1. *File → Preferences → Additional boards manager URLs*: add
   `https://siliconlabs.github.io/arduino/package_arduinosilabs_index.json`.
2. *Boards Manager*: install **Silicon Labs** and select the board **XIAO MG24 Sense**.
3. *Tools → Protocol stack*: **BLE (Arduino)** (not "BLE (Silabs)").
4. *Library Manager*: install **ArduinoBLE** and **Seeed Arduino LSM6DS3** (2.0.4 or newer).
5. Open `OpenToF_Firmware/OpenToF_Firmware.ino`, *Verify*, then *Upload*.

From the command line (the Arduino IDE ships `arduino-cli`, e.g. on Windows under
`%LOCALAPPDATA%\Programs\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe`):

```sh
arduino-cli compile --fqbn SiliconLabs:silabs:xiao_mg24:protocol_stack=ble_arduino OpenToF_Firmware
```

## Code layout

| Path | Contents |
|---|---|
| `OpenToF_Firmware.ino` | Only `setup()` and `loop()`, plus the algorithm selection block at the top |
| `config/FirmwareConfig.h` | Every setting: modes, version and identity strings, timing, pins |
| `config/BleUuids.h` | All BLE UUIDs and the protocol description |
| `algorithms/` | One header per detection algorithm, plus `BatteryCurve.h` (voltage → %) |
| `core/` | Plumbing you normally don't edit: IMU, demo source, event rules, BLE service, battery, device name, boot counter, deep sleep |

Headers include each other relative to their own folder (`../core/Logging.h`); the sketch folder is not on the
include path. The Arduino IDE only shows files in the sketch folder itself as tabs, so open the headers in another
editor (compiling is not affected).

Keep code in headers. The IDE generates prototypes for functions in `.ino` files above the sketch's own types, so a
free function in the `.ino` must not use a sketch-defined type in its signature.

## Configuration (`config/FirmwareConfig.h`)

| Setting | Default | Meaning |
|---|---|---|
| `DEMO_MODE` | 0 | 1 = send simulated jumps instead of reading the IMU (two-stage events, confidence, intensities, occasional retracted landings); for testing the app without a trampoline. Disables deep sleep. |
| `IMU_USE_HIGH_RATE_PROFILE` | 0 | IMU profile if the detector doesn't choose one: 0 = 416 Hz / ±8 g, 1 = 833 Hz / ±16 g |
| `IMU_SERIAL_LOG` | 0 | 1 = print IMU samples as CSV over serial (every `IMU_SERIAL_LOG_EVERY_N`th) |
| `DEBUG_SERIAL` | 1 | Diagnostic messages over serial (115200 baud); 0 compiles them out |
| `DEEP_SLEEP_ENABLED` | 1 | Sleep when idle, wake up on motion |
| `SLEEP_AFTER_IDLE_MS` | 60 s | Idle time (no app connected, no jump) before sleeping |
| `SLEEP_POLL_INTERVAL_MS` | 3 s | How often the sleeping sensor checks for motion |
| `IMU_WAKE_UP_THS` / `_DUR` | 0x02 / 0x00 | How hard it must be moved to wake up |
| `FIRMWARE_VERSION` | | Bump on every release (see "Releasing" in the root README) |

## Detection algorithms

Which algorithm is built is chosen at the top of `OpenToF_Firmware.ino`: each algorithm has an `#include` + `typedef …
ActiveJumpDetector;` pair, and exactly one pair is not commented out.

| Algorithm | Notes |
|---|---|
| `BedCycleJumpDetector` | **Default.** Accel + gyro "bed cycle" detector with provisional and final events, confidence, reasons and two intensity fields |
| `StaLtaJumpDetector` | STA/LTA envelope detector |
| `AzPipelineJumpDetector` | Causal port of the vertical-acceleration pipeline |
| `AzPipelineBufferedJumpDetector` | Buffered variant; reports ~1 s late, which breaks the 200 ms deadline for final events |
| `MyJumpDetector` | Template with an illustration, not a working detector |

To write your own: copy `algorithms/MyJumpDetector.h`, rename the class, implement `onSample()`, and add a pair for
it in the selection block. The API and the rules for events are in
[`../docs/PROTOCOL.md`](../docs/PROTOCOL.md#writing-a-detection-algorithm). To see what the data looks like, set
`IMU_SERIAL_LOG 1` and watch the Serial Monitor or Plotter while someone bounces.

## Debugging over serial

With `DEBUG_SERIAL 1` the firmware logs to serial (115200 baud). When the app shows no jumps, read it top to bottom:

- No `IMU:` lines at all: check `DEBUG_SERIAL` and the baud rate.
- `IMU: 0 samples … NO DATA`: the I2C reads fail.
- A healthy sample rate (~285/s with the 833 Hz profile, which is expected) but no `takeoff`/`landing` lines: the
  algorithm doesn't fire.
- `event ignored: …` lines: the algorithm reports events in an invalid order (see the event rules in the protocol).
- Events are logged but the app sees nothing: look for "no app subscribed" (not connected, or notifications off).

## Deep sleep

`core/DeepSleep.h` explains the details in its header comment; read it before touching the IMU or pin setup.

- The sensor sleeps (EM4) after `SLEEP_AFTER_IDLE_MS` without a connected app and without a jump, or right away when
  the app sends the sleep command. Both go through `sleepNow()` in the `.ino`.
- The IMU's interrupt pins are not wired, so a timer wakes the MCU every `SLEEP_POLL_INTERVAL_MS` to read the IMU's
  wake-up flag. Each wake-up is a reset.
- Anything added to `setup()` must come after the wake check at its top, and nothing before that check may call
  `pinMode()` on `IMU_POWER_PIN` (PD5): it would glitch the IMU's power and reset it.
- **Flashing a sleeping sensor** fails with "cannot read IDR". Retry the upload a few times, shake the sensor first,
  or hold D1 low during a reset to keep it awake. For testing, lower `SLEEP_AFTER_IDLE_MS`.

## LED signals

The board has two LEDs. The firmware only controls the orange **user LED**; the red **charge LED** is driven by the
charger chip.

The app explains the same signals under *Settings → LED signals* (`app/lib/ui/settings/led_help_screen.dart`, texts
in `app/lib/l10n/`). When a signal or timing changes here, change it there too.

### User LED (orange)

| What you see | Timing | Meaning | What to do |
| --- | --- | --- | --- |
| Slow blinking | 0.3 s on, 0.7 s off, repeating | Awake and waiting for the app to connect. | Connect with the app. |
| On, steady | on all the time | The app is connected. The sensor does not go to sleep by itself in this state. | — |
| 6 quick blinks, then off | 0.15 s on, 0.15 s off, 6 times (1.8 s) | Going to deep sleep now: either no app was connected and no jump was detected for 1 minute (`SLEEP_AFTER_IDLE_MS`), or the app sent the sleep command. | Shake or hit the sensor to wake it up. |
| Off | off all the time | Deep sleep. The sensor checks for motion every 3 s (`SLEEP_POLL_INTERVAL_MS`). | Shake or hit the sensor: it answers within about 4 s. |
| 3 short blinks, then slow blinking | 0.08 s on, 0.08 s off, 3 times (0.5 s) | Woke up from deep sleep because it was moved. | Connect with the app. |
| Fast blinking without stopping | 0.1 s on, 0.1 s off, forever | Start-up failed: either Bluetooth or the motion sensor (IMU) did not start. The sensor does not work and does not sleep. | Press reset or power-cycle. The serial log says which one (`BLE init failed` / `IMU init failed`). |
| On, steady, but the app cannot find the sensor | on all the time | Held awake for flashing: pin D1 was low during a reset. The firmware is not running. | Release D1 and press reset. |

A start by the reset button or by plugging in power has no signal of its own: the LED goes straight to slow
blinking (after about 0.3 s). The slow blinking can be changed with `LED_WAITING_ON_MS` / `LED_WAITING_OFF_MS`.

### Charge LED (red)

Driven by the charger chip (SGM40567-4.2, about 200 mA charge current) while USB power is connected. It is the
second LED inside the same part as the orange user LED (dual LED D2 on the schematic), so the two sit right next to
each other. The firmware cannot read or change it, and the charging state is not sent to the app.

| What you see | Timing | Meaning |
| --- | --- | --- |
| Short flash about once a second | 0.16 s on, 1.12 s off, repeating | Charging. The last part is slow: it can keep flashing for half an hour or more above 90 %. |
| On, steady, then off | on for about 51 s | Charging finished. |
| Off | off all the time | On USB: usually full (it can start flashing again when the charger tops up). Without USB: always off. |

Source: board schematic (`docs/hardware/XIAO_MGM240S_KICAD_Prj.pdf`) and the SGM40567 data sheet. Only the flashing
has been seen on a real sensor so far; the other two rows are from the data sheet.

### Where this is in the code

- Slow blinking / steady on: `updateStatusLed()` in `OpenToF_Firmware.ino`
- Sleep and wake-up blinks: `sleepNow()` and `setup()` in `OpenToF_Firmware.ino` (`blinkLed()`)
- Start-up failure: `fatalBlink()` in `OpenToF_Firmware.ino`
- Held awake for flashing: `escape_hatch()` in the Arduino core's `ArduinoLowPower` library

## Helper sketches

Standalone sketches, not part of the main firmware and without a version number:

| Sketch | Purpose |
|---|---|
| `datalogger_selfmade/` | Streams raw IMU samples (binary, 921600 baud) for recording data; read them with `../software/dump_data.py` and plot with `../software/visualizer/plot.py`. Send `r` to clear the FIFO. |
| `deep_sleep_test/` | Experiments for deep sleep / wake on motion, including the attempt to read the IMU before `main()` |
| `ble_test/` | Early BLE test with the "BLE (Silabs)" stack (random flight times); superseded by `DEMO_MODE` |

Datasheets for the board, IMU and battery are in [`../docs/hardware/`](../docs/hardware/).
