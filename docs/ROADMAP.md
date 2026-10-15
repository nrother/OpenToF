# OpenToF — Architecture and roadmap

What is built is described in [`../Changelog.md`](../Changelog.md); this file shows how the code is organised and
what is still **open or unverified**. Remove an item once it is done (the changelog records it).

## Architecture

```
firmware/OpenToF_Firmware/      Arduino sketch (XIAO MG24 Sense)
  OpenToF_Firmware.ino          setup()/loop() only; algorithm selection block at the top
  config/                       FirmwareConfig.h (modes, version, timing, pins), BleUuids.h (protocol)
  algorithms/                   one header per detector (+ BatteryCurve.h)
  core/                         IMU, demo source, event rules, BLE service, battery, name, boot counter, sleep

app/lib/                        Flutter app (Riverpod 3)
  main.dart, app.dart           ProviderScope + MaterialApp (home = main screen)
  domain/                       pure Dart, unit-tested, time always passed in:
                                jump, sensor_events, jump_assembler (events -> jumps), routine (state machine),
                                chart_event, csv_exporter, battery_estimator, algorithm_metadata,
                                version_check, changelog (Markdown parser)
  data/
    sensor/sensor.dart          Sensor + SensorBackend interfaces
    sensor/mock_sensor.dart     simulated sensor (debug builds)
    ble/ble_protocol.dart       all UUIDs + byte parsing (mirror of BleUuids.h)
    ble/ble_sensor.dart         flutter_blue_plus implementation, reconnect loop, permissions
    settings_repository, audio_service, export_service, foreground_service
  state/
    providers.dart              settings, backend, audio, export, clock, foreground service
    session.dart                SessionController: sensor -> assembler -> routine, chart, battery
  ui/
    main/                       main_screen, routine_panel, jump_chart (CustomPainter), jump_details,
                                status_indicators
    settings/                   settings_screen, sensor_screen, led_help_screen, changelog_screen
    brand_logo, double_back_to_exit, format
  l10n/                         app_en.arb, app_de.arb (+ generated app_localizations*.dart)
app/test/                       domain/, data/, ui/ (ui/harness.dart = app + MockSensor + fake clock/audio/export)
app/tool/                       generate_sounds.dart, generate_branding.ps1, sync_changelog.dart
```

Data flow: IMU → detector (`algorithms/`) → `JumpEventPublisher` (ids, stage rules) → BLE Event notification →
`BleSensor` → `JumpAssembler` (jumps, gaps, restarts) → `SessionController` (routine, chart, sounds) → UI.

## Open: needs real hardware

- [ ] Verify protocol 1 end-to-end over real BLE (firmware `DEMO_MODE 1` and a real detector): two-stage
      replacement, retraction, metadata reads (including long reads > 22 bytes).
- [ ] Verify the sleep command and "Sensor asleep" with a real sensor and phone.
- [ ] Measure the sleep current; consider checking the IMU before `main()` to shorten the ~0.9 s boot per 3 s wake-up
      check (I2C there currently hangs, see `firmware/deep_sleep_test/`).
- [ ] Read the Device Information fields with a scanner app (e.g. nRF Connect).
- [ ] Tune `BedCycleJumpDetector` on more trampoline data; verify the other detectors or drop them.
- [ ] Real Android 10+ device: scan and permission prompts, foreground-service notification, background connection,
      first scan with Bluetooth off / permissions not yet granted.
- [ ] Real Android device: chart Pause/Resume, connect/disconnect markers, routine length field (keyboard), theme
      selector, notification Exit button, *Settings → Exit app*, double-Back exit (also after swiping the app away).
- [ ] Launcher icon, splash and notification icon on a device.
- [ ] Startup time: a debug build took 14.5 s on a moto g pro; check a release build.
- [ ] iOS: build and test on a Mac (Info.plist keys are untested; German permission text needs Xcode changes).

## Open: product and code

- [ ] Real GATT UUIDs once the protocol is frozen (app and firmware together).
- [ ] The app doesn't check the 20-byte limit when renaming the sensor; the firmware silently undoes too-long names.
- [ ] Reconnecting to a sleeping sensor costs phone battery (10 s direct connect every 10 s); try `autoConnect` or a
      back-off.
- [ ] Battery history is in memory only; persist it if restarts should keep the estimate.
- [ ] The algorithm headers refer to a research repository (`src/opentof_research/…`, `experiments/…`) that is not
      part of this repository; link it or describe where it lives.
- [ ] Open product questions: see [`DECISIONS.md`](DECISIONS.md#open-questions).
