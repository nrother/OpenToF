# OpenToF App — Implementation Plan

Read `docs/DECISIONS.md` first. Run `flutter analyze` + `flutter test` before ticking anything.

## Architecture (Riverpod 3)
Everything below is rooted at `app/` (the Flutter project root; see repo root `CLAUDE.md` for the monorepo layout).
```
app/
  lib/
    main.dart, app.dart             # ProviderScope + MaterialApp (home = MainScreen)
    l10n/                           # app_en.arb, app_de.arb (+ generated app_localizations*.dart)
    domain/                         # pure Dart, unit-tested, injectable time
      chart_event.dart (chart markers), jump.dart, sensor_events.dart, jump_assembler.dart, routine.dart (RoutineMachine),
      csv_exporter.dart, battery_estimator.dart
    data/
      sensor/sensor.dart            # Sensor + SensorBackend interfaces
      sensor/mock_sensor.dart       # debug-only simulator (+ MockSensorBackend)
      ble/ble_protocol.dart         # ALL UUIDs (placeholders) + byte parsing
      ble/ble_sensor.dart           # flutter_blue_plus implementation + permissions
      settings_repository.dart, audio_service.dart, export_service.dart, foreground_service.dart
    state/
      providers.dart                # settings, backend, audio, export, clock, foreground service
      session.dart                  # SessionController: sensor -> assembler -> routine machine
    ui/
      main/ (main_screen, routine_panel, jump_chart [CustomPainter bar chart], status_indicators)
      settings/settings_screen.dart
      brand_logo.dart               # BrandLogo (wordmark image)
      double_back_to_exit.dart      # Android press-back-twice-to-exit wrapper
      format.dart
  test/
    domain/ data/ ui/               # ui/harness.dart = app + MockSensor + fake clock/audio/export
  tool/generate_sounds.dart         # regenerates assets/sounds/*.wav
  tool/generate_branding.ps1       # derives logo/icon/splash images (Windows PowerShell)
```

## Milestones
- [x] M0  Project created (`com.opentof.app`, minSdk 29 / iOS 15, deps).
- [x] M1  Domain layer + tests.
- [x] M2  Sensor abstraction, MockSensor, `ble_protocol.dart` + tests.
- [x] M3  Main screen: last jump (+beta height), bar chart with rolling window + Clear, status + battery, routine UI, export.
- [x] M4  Settings/pairing: first-launch redirect, scan/select, rename, unpair, battery + estimate, toggles, timeout, window, debug simulator.
- [x] M5  Audio: generated tones in `app/assets/sounds/`, toggles wired (jumps 1–9 beep, #10 final sound).
- [x] M6  BleSensor (auto-reconnect loop), Android permissions + foreground service, iOS Bluetooth keys.
- [x] M7  EN + DE localization, 60+ unit/widget tests, README.

## Firmware
Not version-tracked here (the firmware changes too often for a plan checklist to stay accurate — check
`FirmwareConfig.h` / git history for the current version instead).
- [x] `firmware/OpenToF_Firmware/`: plug-in detector interface (`MyJumpDetector`), real IMU data, optional serial CSV log.
- [x] Simulated-jump testing without hardware: `DEMO_MODE 1` in `config/FirmwareConfig.h` (formerly a separate
  `firmware/OpenToF_Firmware_Dummy/` sketch, removed 2026-09-22 — see DECISIONS.md).
- [x] Split into `config/`, `algorithms/`, `core/` header folders (see the list in the `.ino`), Device Information Service (manufacturer, model, serial, hardware/firmware/software revision; software revision = active algorithm name), description descriptors on the custom characteristics, GAP appearance.
  Compiles with `arduino-cli` for `DEMO_MODE` 0/1, `IMU_SERIAL_LOG` 1 + high-rate profile, and `DEBUG_SERIAL` 0.
- [x] Flashed and run on real hardware by the user (2026-09-22); no jumps detected with the user's own algorithm.
- [x] Diagnostic serial logging added (2026-09-22, `DEBUG_SERIAL`, all compiled out when it's 0): `ImuSource` prints an "IMU: N samples in 2 s (~Hz), M I2C failures" heartbeat every `IMU_HEARTBEAT_MS` (config/FirmwareConfig.h) so "no IMU data" is visible without `IMU_SERIAL_LOG`; `JumpEventPublisher` now logs every transition the algorithm reports, including ones the firmware ignores (duplicate takeoff, landing before any takeoff); `BleService` logs when an event is sent but no app is subscribed (BLE not connected / notifications not enabled).
- [x] First fix attempt (`Wire.setClock` reordering) **did not fix it** — confirmed by reflashing and reading live serial. Real root cause found and fixed the same day by direct experimentation on live hardware (two physical boards, BLE ruled out via a no-BLE test build, a live I2C scan, and a side-by-side test against the LSM6DS3 library's own read functions on the same bus): our single 12-byte burst read across gyro+accel registers failed 100% of the time; six separate 2-byte reads (what the library itself always does) work. Fixed in `core/ImuSource.h`. See DECISIONS.md for the full story.
- [x] **Reflashed and confirmed live on real hardware** (2026-09-22): IMU heartbeat shows ~285 Hz real samples (833 Hz profile; six reads/sample cost more I2C time than the old single burst, still comfortably fast enough), and `StaLtaJumpDetector` reports real takeoff/landing events with plausible flight/contact times.
- [ ] Verify against the user's own trampoline data (only tested stationary/handheld so far) and against `AzPipelineJumpDetector`/`MyJumpDetector`.
- [ ] Reconnect the app and confirm it now receives live jump notifications end-to-end (only verified over serial + a disconnected sensor so far).
- [ ] Read the Device Information fields with a BLE scanner app (e.g. nRF Connect).
- [x] App side: read Device Information (manufacturer/model/serial/hardware/firmware revision + active algorithm) in `ble_protocol.dart` and show it in Settings → Device info (see DECISIONS.md, 2026-09-22). **Confirmed working against a real sensor** (2026-09-22).
- [ ] Flash with `DEMO_MODE 1`, connect with the app (real BLE), verify events/name/battery.
- [ ] Write and tune the real detector in `MyJumpDetector` with real trampoline data.

## Not verified / next steps (need hardware or SDKs this machine lacks)
- [x] Android SDK 36 installed; `flutter build apk --debug` succeeds (manifest merge OK).
- [ ] Run on a real Android 10+ device (or emulator): verify scan/permission prompts, foreground service notification, background connection. Not done: no device/emulator was available.
- [ ] iOS build/test needs a Mac (Xcode). Info.plist keys added but untested. iOS permission text is English only (German `InfoPlist.strings` needs Xcode project changes).
- [ ] Test `BleSensor` against real hardware once firmware agrees on UUIDs/layout (`ble_protocol.dart`).
- [ ] Confirm min OS versions against gym devices (currently Android 10 / iOS 15).
- [ ] Battery estimate is in-memory only; persist readings if restarts should keep history.
- [x] Branding: new mark (launcher icon incl. themed icon, splash, notification icon, app bar), old wordmark in Settings, version in settings (see DECISIONS.md). Icons/splash/notification icon untested on a device.
- [ ] Large polished logo (waiting for image generation): replace the Settings header logo with it (`BrandLogo`) and decide the theme seed colour.
- [ ] Verify on a device: chart Pause/Resume, event markers with a real disconnect, routine length field (keyboard), theme selector.
- [ ] Startup: a debug build took 14.5 s to first display on the moto g pro; check `flutter run --release` (AOT) is fast.
- [ ] Verify on a device: notification Exit button, Settings exit, double-Back exit; also after swiping the app away from recents (then the button only stops the service).
- [ ] Verify on a device: first scan with Bluetooth off / permissions not yet granted works without restarting the app.
