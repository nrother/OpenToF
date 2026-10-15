# OpenToF app — agent notes

Read `README.md` in this folder first (commands, code rules, test notes). Product rules: `../docs/DECISIONS.md`;
protocol: `../docs/PROTOCOL.md`; code layout: `../docs/ROADMAP.md`.

## Environment (this machine)
- Flutter is at `C:\Tools\flutter` and NOT on PATH. PowerShell: `$env:Path = "C:\Tools\flutter\bin;" + $env:Path`;
  Bash: `export PATH="/c/Tools/flutter/bin:$PATH"`. Run Flutter commands from inside `app/`.
- Windows PowerShell 5.1 (no `&&`). No Mac, so no iOS builds. The Android SDK is installed (`flutter build apk`
  works), but there is no device or emulator.

## Working
- After a change: `flutter analyze` and targeted tests (`flutter test test/domain/...`) while iterating, the full
  `flutter test` before handing back. `dart format lib test` before committing.
- Changing a user-visible string means editing both `app_en.arb` and `app_de.arb`, then `flutter gen-l10n`.
- A protocol change touches `lib/data/ble/ble_protocol.dart`, `../firmware/OpenToF_Firmware/config/BleUuids.h` and
  `../docs/PROTOCOL.md` together.
