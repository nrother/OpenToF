# OpenToF Companion App

Flutter (iOS + Android) app: connects to one OpenToF BLE sensor on a trampoline, shows live jump
flight time, and runs a 10-jump routine with CSV export.

This folder is part of the OpenToF monorepo (see the repo root `CLAUDE.md` for the overall layout and
repo-wide working rules). The firmware lives in `../firmware/`.

**Git: never `git push`; ask the user before every commit or branch change; ask major/minor/hotfix and bump
`version:` in `pubspec.yaml` on a commit that changes app code; major/minor also bumps the firmware to the same
MAJOR.MINOR. Full policy in the repo root `CLAUDE.md`.**

## Read first (in this order, keep them current)
1. `../docs/DECISIONS.md` — resolved product decisions; **overrides** the spec on conflict.
2. `../docs/PLAN.md` — architecture + milestone checklist; tick items as done, resume from first unticked.
3. `OpenToF-App-Specification-v0.1.md` — original spec (background only).

## Working rules
- Domain logic lives in `lib/domain` (pure Dart, injectable clock, no BLE/Flutter imports) and must have unit tests.
- All BLE UUIDs and byte parsing live only in `lib/data/ble/ble_protocol.dart` (UUIDs are placeholders,
  little-endian); keep in sync with `../firmware/OpenToF_Firmware/config/BleUuids.h`.
- UI talks to a `Sensor` interface only; `MockSensor` is debug-only, `BleSensor` is real.
- All user-visible strings go through l10n (`lib/l10n/app_en.arb`, `app_de.arb`); never hardcode text.
- No raw-data streaming in v1. Jump height is included but always labeled "beta".
- Metric units only. No accounts, cloud, or history browser.

## Commands
Flutter is at `C:\Tools\flutter` and NOT on PATH — prefix every PowerShell call with
`$env:Path = "C:\Tools\flutter\bin;" + $env:Path`. Run these from inside `app/`.
- `flutter pub get` · `flutter analyze` · `flutter test` · `dart format lib test`
- `flutter gen-l10n` (after editing ARB files) · `flutter run` (device/emulator; use MockSensor in debug)
- Android SDK is not installed here: `flutter build apk`/`run` on Android are unverified; analyze/test work.

## Testing notes
- Widget tests use `test/ui/harness.dart` (MockSensor + fake clock/audio/export). Don't use `pumpAndSettle`
  (periodic timers never settle); pump `advance(...)`, and for route transitions `pump()` then a ~600 ms advance.
- Own `TextEditingController`s in a State (dispose there), never dispose right after `showDialog` returns.

## Token-saving tips for agents
- Don't re-read the spec; use `../docs/DECISIONS.md`. Use Grep/Glob before opening files; read only needed ranges.
- Run `flutter analyze` and targeted tests (`flutter test test/domain/...`) rather than the whole suite while iterating.
- Environment: Windows 11; Windows PowerShell 5.1 (no `&&`). iOS builds are not possible on this machine.
