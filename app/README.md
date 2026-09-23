# OpenToF Companion App

Flutter app (Android 10+ / iOS 15+) that connects to one OpenToF BLE sensor on a trampoline, shows the
live flight time of the last jump, charts recent jumps and runs a 10-jump routine with CSV export.

This app is part of the [OpenToF](../README.md) monorepo; the sensor firmware lives in [`../firmware/`](../firmware/).

Docs: [`../docs/DECISIONS.md`](../docs/DECISIONS.md) (resolved product decisions, overrides the spec),
[`../docs/PLAN.md`](../docs/PLAN.md) (architecture, status, open items),
[`OpenToF-App-Specification-v0.1.md`](OpenToF-App-Specification-v0.1.md) (original spec).

## Develop

Requires the Flutter SDK on your `PATH`.

```sh
flutter pub get
flutter gen-l10n                     # after editing lib/l10n/*.arb
flutter analyze
flutter test
dart run tool/generate_sounds.dart   # regenerate assets/sounds/*.wav
```

## Try the UI in the browser

Start the web server:

```sh
flutter run -d web-server --web-port 8765
```

Then open <http://localhost:8765> in Chrome or Edge (the server only finishes starting once a browser
connects). Press `r` in the terminal to hot reload, `q` to quit. Pick any free port if 8765 is taken.

Real Bluetooth is not available in the browser, so use the simulated sensor (next section). CSV export and
sound playback are limited in the browser.

## Run without hardware

Debug builds include a simulated sensor: open **Settings → Developer (debug build) → Use simulated
sensor**, pair "OpenToF-Mock", then use *Start bouncing* / *Single jump* / *Drop next landing* /
*Simulate disconnect* to exercise the app.

## Firmware

See [`../firmware/CLAUDE.md`](../firmware/CLAUDE.md) for the firmware's own structure. Quick summary:

`../firmware/OpenToF_Firmware/OpenToF_Firmware.ino` is the sensor firmware for the Seeed XIAO MG24 Sense.

Arduino IDE setup:
1. *File → Preferences → Additional boards manager URLs*: add
   `https://siliconlabs.github.io/arduino/package_arduinosilabs_index.json`.
2. *Boards Manager*: install **Silicon Labs**. Select board **XIAO MG24 Sense**.
3. *Tools → Protocol stack*: **BLE (Arduino)** (not "BLE (Silabs)").
4. *Library Manager*: install **ArduinoBLE** and **Seeed Arduino LSM6DS3** (version 2.0.4 or newer).
5. Open the `.ino`, *Verify*, then *Upload*.

One sketch, `../firmware/OpenToF_Firmware/`:
- It reads the real IMU and has a plug-in interface for your own detection algorithm: write your logic in
  `MyJumpDetector::onSample()` (search for "YOUR ALGORITHM"). It gets accel (g) and gyro (deg/s) for every
  sample and reports `takeoff()` / `landing()`. Set `IMU_SERIAL_LOG 1` to stream the raw data to the Serial
  Monitor while tuning.
- Set `DEMO_MODE 1` (`config/FirmwareConfig.h`) to send simulated jumps instead of reading the IMU: use this to
  test the app and the BLE link without hardware or a tuned algorithm.

## Run on a device

Needs the Android SDK (Android Studio) for Android, or a Mac with Xcode for iOS:
`flutter run` (real BLE) — the BLE UUIDs in `lib/data/ble/ble_protocol.dart` are **placeholders** until
they are agreed with the firmware.
