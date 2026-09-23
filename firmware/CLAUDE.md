# OpenToF Firmware

Arduino sketch for the OpenToF sensor. Part of the OpenToF monorepo (see the repo root `CLAUDE.md` for the
overall layout and repo-wide working rules). The companion app lives in `../app/`.

**Git: never `git push`; ask the user before every commit or branch change; ask major/minor/hotfix and bump
`FIRMWARE_VERSION` in `OpenToF_Firmware/config/FirmwareConfig.h` on a commit that changes `OpenToF_Firmware/`
(not the helper sketches below). Full policy in the repo root `CLAUDE.md`.**

`OpenToF_Firmware/` (Arduino, XIAO MG24 Sense; user writes `MyJumpDetector.h`). Simulated jumps for testing
the app without real detection are `DEMO_MODE 1` in `config/FirmwareConfig.h`, not a separate sketch (a former
`OpenToF_Firmware_Dummy/` sketch was folded into this one and removed, 2026-09-22). Keep BLE UUIDs/payloads in
sync with `../app/lib/data/ble/ble_protocol.dart`. The user installs the Arduino tooling themselves.

The main sketch is multi-file: `.ino` has only `setup()/loop()`, everything else is a header in `config/`
(settings in `FirmwareConfig.h`, all UUIDs in `BleUuids.h`), `algorithms/` (one header per jump-detection
algorithm, e.g. `MyJumpDetector.h`, `BatteryCurve.h`; which algorithm builds is picked by commenting
`#include`+`typedef` pairs in/out at the top of the `.ino`, see its header comment) or `core/` (plumbing);
list in the `.ino` comment. Headers include each other relative to their own folder (`../core/X.h`); the
sketch root is not on the include path.

Arduino IDE pitfall: it auto-generates prototypes for free functions in `.ino` files above the sketch's own
types, so keep code in headers (not affected) and keep free functions in the `.ino` free of sketch-defined
types in their signatures.

Compile check (works from PowerShell, ~1 min, run from inside `firmware/`): the Arduino IDE's bundled CLI at
`$env:LOCALAPPDATA\Programs\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe compile --fqbn SiliconLabs:silabs:xiao_mg24:protocol_stack=ble_arduino --build-path <tmp> OpenToF_Firmware`.

## Other files in this folder
`datalogger/`, `ble_test/` and `deep_sleep_test/` are standalone preliminary/reference sketches, not part of
`OpenToF_Firmware/`. Hardware datasheets (battery, IMU, board schematic) live in `../docs/hardware/`, not here.
