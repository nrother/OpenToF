import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/app.dart';
import 'package:opentof_app/data/audio_service.dart';
import 'package:opentof_app/data/export_service.dart';
import 'package:opentof_app/data/sensor/mock_sensor.dart';
import 'package:opentof_app/domain/jump.dart';
import 'package:opentof_app/domain/routine.dart';
import 'package:opentof_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAudio implements AudioService {
  int jumpBeeps = 0;
  int finalBeeps = 0;

  @override
  Future<void> playJumpBeep() async => jumpBeeps++;
  @override
  Future<void> playFinalBeep() async => finalBeeps++;
  @override
  Future<void> dispose() async {}
}

class FakeExport implements ExportService {
  final List<RoutineState> shared = [];
  final List<List<Jump>> sharedJumps = [];

  @override
  Future<void> shareRoutine(RoutineState routine, {DateTime? now}) async =>
      shared.add(routine);

  @override
  Future<void> shareJumps(List<Jump> jumps, {DateTime? now}) async =>
      sharedJumps.add(jumps);
}

/// Running app wired to a MockSensor, a manually advanced clock and fakes.
class AppHarness {
  AppHarness._(this.tester, this.audio, this.export, this._clock, this._exits);

  /// How often the app asked to quit (exitAppProvider is faked in tests).
  int get exits => _exits.count;
  final _Counter _exits;

  final WidgetTester tester;
  final FakeAudio audio;
  final FakeExport export;
  final _Clock _clock;

  MockSensor get mock =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
          .read(mockSensorProvider);

  /// Advances the fake clock and the test's timers together.
  Future<void> advance(Duration d) async {
    _clock.now = _clock.now.add(d);
    await tester.pump(d);
  }

  /// One complete jump: the sensor emits it, the UI settles.
  Future<void> jump({int flightMs = 1000}) async {
    mock.emitJump(flightMs: flightMs, contactMs: 200);
    await advance(const Duration(milliseconds: 100));
  }

  Finder get startButton => find.ancestor(
    of: find.text('Start routine'),
    matching: find.bySubtype<FilledButton>(),
  );

  bool get startEnabled =>
      tester.widget<FilledButton>(startButton).onPressed != null;

  static Future<AppHarness> launch(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool paired = true,
    String appVersion = '0.4.3 (4)', // same MAJOR.MINOR as the mock firmware
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      if (paired) 'paired_device_id': 'mock-1',
      if (paired) 'use_mock_sensor': true,
      ...prefs,
    });
    final sp = await SharedPreferences.getInstance();
    final clock = _Clock(DateTime(2026, 1, 1, 12));
    final audio = FakeAudio();
    final export = FakeExport();
    final exits = _Counter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          appVersionProvider.overrideWithValue(appVersion),
          exitAppProvider.overrideWithValue(() async => exits.count++),
          clockProvider.overrideWithValue(() => clock.now),
          audioServiceProvider.overrideWithValue(audio),
          exportServiceProvider.overrideWithValue(export),
        ],
        child: const OpenToFApp(),
      ),
    );
    final h = AppHarness._(tester, audio, export, clock, exits);
    await h.advance(const Duration(milliseconds: 500)); // mock connects
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
    });
    return h;
  }
}

class _Counter {
  int count = 0;
}

class _Clock {
  _Clock(this.now);
  DateTime now;
}
