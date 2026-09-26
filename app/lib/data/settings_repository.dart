import 'package:shared_preferences/shared_preferences.dart';

import '../domain/routine.dart';

/// User choice for light/dark appearance (system = follow the device).
enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    this.inactivityTimeoutSeconds = defaultTimeoutSeconds,
    this.perJumpBeep = true,
    this.finalBeep = true,
    this.windowSeconds = 60,
    this.jumpsPerRoutine = RoutineMachine.defaultJumpsPerRoutine,
    this.pairedDeviceId,
    this.pairedDeviceName,
    this.useMockSensor = false,
    this.themeMode = AppThemeMode.system,
    this.showContactTime = false,
    this.showTotalTime = false,
    this.showJumpDetails = false,
    this.hiddenDetails = const [],
  });

  /// Key of the sensor's confidence in [hiddenDetails]; custom fields use
  /// their own id.
  static const confidenceDetail = '_confidence';

  static const defaultTimeoutSeconds = 4;
  static const minTimeoutSeconds = 1;
  static const maxTimeoutSeconds = 30;
  static const windowOptionsSeconds = [30, 60, 300];
  static const minJumpsPerRoutine = 1;

  /// Technical limit only (keeps the routine table and the input sane).
  static const maxJumpsPerRoutine = 999;

  final int inactivityTimeoutSeconds;
  final bool perJumpBeep;
  final bool finalBeep;

  /// Rolling history chart window.
  final int windowSeconds;

  /// Jumps after which a routine completes.
  final int jumpsPerRoutine;

  final String? pairedDeviceId;

  /// Last known name of the paired sensor (shown while disconnected).
  final String? pairedDeviceName;

  /// Debug builds only: use the simulated sensor instead of BLE.
  final bool useMockSensor;

  final AppThemeMode themeMode;

  /// Show the time on the bed before each jump next to its flight time.
  final bool showContactTime;

  /// Show each jump's total time (time on the bed + flight time).
  final bool showTotalTime;

  /// Show the sensor's extra per-jump information (confidence, custom values)
  /// under the last jump and in the routine table, and a details sheet on tap.
  final bool showJumpDetails;

  /// Details the user switched off (stored as "hidden" so values a new
  /// algorithm adds appear by default).
  final List<String> hiddenDetails;

  bool detailVisible(String key) =>
      showJumpDetails && !hiddenDetails.contains(key);

  Duration get inactivityTimeout => Duration(seconds: inactivityTimeoutSeconds);
  Duration get window => Duration(seconds: windowSeconds);
  bool get isPaired => pairedDeviceId != null;

  AppSettings copyWith({
    int? inactivityTimeoutSeconds,
    bool? perJumpBeep,
    bool? finalBeep,
    int? windowSeconds,
    int? jumpsPerRoutine,
    bool? useMockSensor,
    AppThemeMode? themeMode,
    bool? showContactTime,
    bool? showTotalTime,
    bool? showJumpDetails,
    List<String>? hiddenDetails,
  }) => AppSettings(
    inactivityTimeoutSeconds:
        inactivityTimeoutSeconds ?? this.inactivityTimeoutSeconds,
    perJumpBeep: perJumpBeep ?? this.perJumpBeep,
    finalBeep: finalBeep ?? this.finalBeep,
    windowSeconds: windowSeconds ?? this.windowSeconds,
    jumpsPerRoutine: jumpsPerRoutine ?? this.jumpsPerRoutine,
    pairedDeviceId: pairedDeviceId,
    pairedDeviceName: pairedDeviceName,
    useMockSensor: useMockSensor ?? this.useMockSensor,
    themeMode: themeMode ?? this.themeMode,
    showContactTime: showContactTime ?? this.showContactTime,
    showTotalTime: showTotalTime ?? this.showTotalTime,
    showJumpDetails: showJumpDetails ?? this.showJumpDetails,
    hiddenDetails: hiddenDetails ?? this.hiddenDetails,
  );

  AppSettings withPaired(String? id, String? name) => AppSettings(
    inactivityTimeoutSeconds: inactivityTimeoutSeconds,
    perJumpBeep: perJumpBeep,
    finalBeep: finalBeep,
    windowSeconds: windowSeconds,
    jumpsPerRoutine: jumpsPerRoutine,
    pairedDeviceId: id,
    pairedDeviceName: name,
    useMockSensor: useMockSensor,
    themeMode: themeMode,
    showContactTime: showContactTime,
    showTotalTime: showTotalTime,
    showJumpDetails: showJumpDetails,
    hiddenDetails: hiddenDetails,
  );
}

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kTimeout = 'inactivity_timeout_s';
  static const _kPerJump = 'per_jump_beep';
  static const _kFinal = 'final_beep';
  static const _kWindow = 'window_s';
  static const _kJumps = 'jumps_per_routine';
  static const _kPairedId = 'paired_device_id';
  static const _kPairedName = 'paired_device_name';
  static const _kMock = 'use_mock_sensor';
  static const _kTheme = 'theme_mode';
  static const _kShowContact = 'show_contact_time';
  static const _kShowTotal = 'show_total_time';
  static const _kShowDetails = 'show_jump_details';
  static const _kHiddenDetails = 'hidden_jump_details';

  AppSettings load() {
    const d = AppSettings();
    return AppSettings(
      inactivityTimeoutSeconds:
          (_prefs.getInt(_kTimeout) ?? d.inactivityTimeoutSeconds).clamp(
            AppSettings.minTimeoutSeconds,
            AppSettings.maxTimeoutSeconds,
          ),
      perJumpBeep: _prefs.getBool(_kPerJump) ?? d.perJumpBeep,
      finalBeep: _prefs.getBool(_kFinal) ?? d.finalBeep,
      windowSeconds: _prefs.getInt(_kWindow) ?? d.windowSeconds,
      jumpsPerRoutine: (_prefs.getInt(_kJumps) ?? d.jumpsPerRoutine).clamp(
        AppSettings.minJumpsPerRoutine,
        AppSettings.maxJumpsPerRoutine,
      ),
      pairedDeviceId: _prefs.getString(_kPairedId),
      pairedDeviceName: _prefs.getString(_kPairedName),
      useMockSensor: _prefs.getBool(_kMock) ?? d.useMockSensor,
      themeMode:
          AppThemeMode.values.asNameMap()[_prefs.getString(_kTheme)] ??
          d.themeMode,
      showContactTime: _prefs.getBool(_kShowContact) ?? d.showContactTime,
      showTotalTime: _prefs.getBool(_kShowTotal) ?? d.showTotalTime,
      showJumpDetails: _prefs.getBool(_kShowDetails) ?? d.showJumpDetails,
      hiddenDetails: _prefs.getStringList(_kHiddenDetails) ?? d.hiddenDetails,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_kTimeout, s.inactivityTimeoutSeconds);
    await _prefs.setBool(_kPerJump, s.perJumpBeep);
    await _prefs.setBool(_kFinal, s.finalBeep);
    await _prefs.setInt(_kWindow, s.windowSeconds);
    await _prefs.setInt(_kJumps, s.jumpsPerRoutine);
    await _prefs.setBool(_kMock, s.useMockSensor);
    await _prefs.setString(_kTheme, s.themeMode.name);
    await _prefs.setBool(_kShowContact, s.showContactTime);
    await _prefs.setBool(_kShowTotal, s.showTotalTime);
    await _prefs.setBool(_kShowDetails, s.showJumpDetails);
    await _prefs.setStringList(_kHiddenDetails, s.hiddenDetails);
    if (s.pairedDeviceId == null) {
      await _prefs.remove(_kPairedId);
      await _prefs.remove(_kPairedName);
    } else {
      await _prefs.setString(_kPairedId, s.pairedDeviceId!);
      if (s.pairedDeviceName == null) {
        await _prefs.remove(_kPairedName);
      } else {
        await _prefs.setString(_kPairedName, s.pairedDeviceName!);
      }
    }
  }
}
