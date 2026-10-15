# OpenToF firmware — agent notes

Read `README.md` in this folder first (setup, layout, configuration, algorithms, deep sleep, LED signals). Protocol
and algorithm API: `../docs/PROTOCOL.md`; decisions: `../docs/DECISIONS.md`.

## Environment (this machine)
- The user installs and runs the Arduino tooling and flashes the board. `arduino-cli` is not on PATH; use the IDE's
  bundled one. Compile check (~1 min, from inside `firmware/`, works from PowerShell and Bash):
  `"$LOCALAPPDATA/Programs/Arduino IDE/resources/app/lib/backend/resources/arduino-cli.exe" compile --fqbn SiliconLabs:silabs:xiao_mg24:protocol_stack=ble_arduino --build-path <tmp> OpenToF_Firmware`
- Compile-check `DEMO_MODE` 0 and 1 when touching code that both use.

## Working
- Only `OpenToF_Firmware/` is versioned and released; the helper sketches are standalone.
- A protocol change touches `config/BleUuids.h`, `../app/lib/data/ble/ble_protocol.dart` and `../docs/PROTOCOL.md`
  together.
- LED timings and the sleep time also appear in the app's LED help texts (`../app/lib/l10n/`); change both.
- Before touching `setup()`, pins or the IMU, read the header comment of `core/DeepSleep.h`.
