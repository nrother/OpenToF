# OpenToF companion app

Flutter app (Android 10+ / iOS 15+) that connects to one OpenToF sensor, shows the flight time of every jump, charts
recent jumps, runs routines and exports CSV. Part of the [OpenToF](../README.md) monorepo; the protocol it speaks is
in [`../docs/PROTOCOL.md`](../docs/PROTOCOL.md), the product rules in [`../docs/DECISIONS.md`](../docs/DECISIONS.md)
and the code layout in [`../docs/ROADMAP.md`](../docs/ROADMAP.md).

## Develop

Requires the Flutter SDK. Run everything from this folder.

```sh
flutter pub get
flutter analyze
flutter test
dart format lib test
```

After editing:

| You changed | Run |
|---|---|
| `lib/l10n/app_en.arb` / `app_de.arb` | `flutter gen-l10n` (the generated `app_localizations*.dart` are committed) |
| `../Changelog.md` | `dart run tool/sync_changelog.dart` (updates the bundled copy; `flutter test` fails until you do) |
| the tones in `tool/generate_sounds.dart` | `dart run tool/generate_sounds.dart` |
| the logo in `../img/` | `tool/generate_branding.ps1` (Windows PowerShell), then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` |

## Code rules

- `lib/domain/` is pure Dart: no Flutter or BLE imports, time is passed in (`clockProvider`), and it has unit tests.
- All BLE UUIDs and byte parsing live in `lib/data/ble/ble_protocol.dart`. Keep it in sync with
  `../firmware/OpenToF_Firmware/config/BleUuids.h` and [`../docs/PROTOCOL.md`](../docs/PROTOCOL.md).
- The UI only talks to the `Sensor` interface; `MockSensor` (debug builds) and `BleSensor` implement it.
- Every user-visible string goes through l10n (English and German), never hardcoded.
- The LED help page (`lib/ui/settings/led_help_screen.dart`) repeats the firmware's LED timings: change both together.

## Tests

`test/ui/harness.dart` starts the app with a `MockSensor`, a fake clock, fake audio and a fake export service.

- Don't use `pumpAndSettle`: periodic timers never settle. Use `harness.advance(...)`; for route transitions `pump()`
  and then advance ~600 ms.
- Long lists are built lazily: scroll (`dragUntilVisible`) before looking for items further down.
- A `TextEditingController` belongs to a `State` and is disposed there, not right after `showDialog` returns.

## Run without hardware

Debug builds include a simulated sensor: open **Settings → Developer (debug build) → Use simulated sensor**, pair
"OpenToF-Mock", then use *Start bouncing* / *Single jump* / *Drop next jump* / *Simulate disconnect*.

To try the UI in a browser (no real Bluetooth; export and sound are limited):

```sh
flutter run -d web-server --web-port 8765
```

Then open <http://localhost:8765> in Chrome or Edge (the server only finishes starting once a browser connects).

## Run on a device

Android needs the Android SDK (Android Studio), iOS a Mac with Xcode. `flutter run` uses real Bluetooth; flash the
firmware with `DEMO_MODE 1` (see [`../firmware/README.md`](../firmware/README.md)) to get jumps without a trampoline.
