import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/audio_service.dart';
import '../data/ble/ble_sensor.dart';
import '../data/export_service.dart';
import '../data/foreground_service.dart';
import '../data/sensor/mock_sensor.dart';
import '../data/sensor/sensor.dart';
import '../data/settings_repository.dart';
import 'session.dart';

/// Time source for the whole app; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Must be overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// Human-readable app version (e.g. "1.0.0 (1)"); must be overridden in `main()`.
final appVersionProvider = Provider<String>(
  (ref) => throw UnimplementedError('appVersionProvider not overridden'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  void _set(AppSettings s) {
    state = s;
    ref.read(settingsRepositoryProvider).save(s);
  }

  void setInactivityTimeout(int seconds) => _set(
    state.copyWith(
      inactivityTimeoutSeconds: seconds.clamp(
        AppSettings.minTimeoutSeconds,
        AppSettings.maxTimeoutSeconds,
      ),
    ),
  );

  void setPerJumpBeep(bool v) => _set(state.copyWith(perJumpBeep: v));
  void setFinalBeep(bool v) => _set(state.copyWith(finalBeep: v));
  void setWindowSeconds(int v) => _set(state.copyWith(windowSeconds: v));
  void setJumpsPerRoutine(int v) => _set(
    state.copyWith(
      jumpsPerRoutine: v.clamp(
        AppSettings.minJumpsPerRoutine,
        AppSettings.maxJumpsPerRoutine,
      ),
    ),
  );
  void setUseMockSensor(bool v) => _set(state.copyWith(useMockSensor: v));
  void setThemeMode(AppThemeMode v) => _set(state.copyWith(themeMode: v));
  void setShowContactTime(bool v) => _set(state.copyWith(showContactTime: v));
  void setShowTotalTime(bool v) => _set(state.copyWith(showTotalTime: v));
  void setShowJumpDetails(bool v) => _set(state.copyWith(showJumpDetails: v));
  void setDetailVisible(String key, bool visible) => _set(
    state.copyWith(
      hiddenDetails: [
        ...state.hiddenDetails.where((k) => k != key),
        if (!visible) key,
      ],
    ),
  );

  void pair(String id, String? name) => _set(state.withPaired(id, name));
  void unpair() => _set(state.withPaired(null, null));

  void setPairedName(String name) {
    if (state.pairedDeviceId == null || state.pairedDeviceName == name) return;
    _set(state.withPaired(state.pairedDeviceId, name));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

final audioServiceProvider = Provider<AudioService>((ref) {
  final s = AudioplayersAudioService();
  ref.onDispose(s.dispose);
  return s;
});

final exportServiceProvider = Provider<ExportService>(
  (ref) => ShareExportService(),
);

/// Debug-only simulated sensor (shared singleton so debug controls and the
/// session talk to the same instance).
final mockSensorProvider = Provider<MockSensor>((ref) {
  final m = MockSensor(clock: ref.read(clockProvider));
  ref.onDispose(m.close);
  return m;
});

final sensorBackendProvider = Provider<SensorBackend>((ref) {
  final useMock =
      kDebugMode && ref.watch(settingsProvider.select((s) => s.useMockSensor));
  if (useMock) return MockSensorBackend(sensor: ref.watch(mockSensorProvider));
  return BleSensorBackend();
});

/// Side-effect provider: Android foreground service runs while a sensor is paired.
final foregroundServiceProvider = Provider<void>((ref) {
  // The notification's Exit button.
  ref.onDispose(
    ForegroundService.listenForExit(() => ref.read(exitAppProvider)()),
  );
  final paired = ref.watch(settingsProvider.select((s) => s.isPaired));
  if (paired) {
    ForegroundService.startLocalized();
  } else {
    ForegroundService.stop();
  }
});

/// Really quits the app (Android): disconnects the sensor, stops the foreground
/// service and closes the activity. Pairing is kept. Overridden in tests.
final exitAppProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await ref.read(sessionProvider.notifier).shutdown();
    await ForegroundService.stop();
    await SystemNavigator.pop();
  },
);

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Coarse clock for time-dependent UI (chart window, Start eligibility).
final nowProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.read(clockProvider);
  return Stream.periodic(const Duration(milliseconds: 250), (_) => clock());
});
