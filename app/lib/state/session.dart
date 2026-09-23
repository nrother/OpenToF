import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sensor/sensor.dart';
import '../domain/battery_estimator.dart';
import '../domain/chart_event.dart';
import '../domain/jump.dart';
import '../domain/jump_assembler.dart';
import '../domain/routine.dart';
import '../domain/sensor_events.dart';
import 'providers.dart';

class SessionState {
  const SessionState({
    this.connection = SensorConnectionState.disconnected,
    this.batteryLevel,
    this.batteryRemaining,
    this.lastJump,
    this.history = const [],
    this.routine = RoutineState.idle,
    this.deviceName,
    this.deviceInfo,
    this.events = const [],
    this.chartFrozenAt,
  });

  final SensorConnectionState connection;
  final int? batteryLevel;
  final Duration? batteryRemaining;
  final Jump? lastJump;

  /// Recent jumps for the rolling chart (pruned to [SessionController.maxHistory]).
  final List<Jump> history;
  final RoutineState routine;
  final String? deviceName;

  /// Device Information Service fields, re-read on every connection. Null
  /// until the first successful read.
  final DeviceInfo? deviceInfo;

  /// Sensor connect/disconnect markers for the chart (pruned like [history]).
  final List<ChartEvent> events;

  /// Non-null while the chart view is paused: the time its window ends at.
  final DateTime? chartFrozenAt;

  SessionState copyWith({
    SensorConnectionState? connection,
    int? batteryLevel,
    Duration? batteryRemaining,
    Jump? lastJump,
    List<Jump>? history,
    RoutineState? routine,
    String? deviceName,
    DeviceInfo? deviceInfo,
    List<ChartEvent>? events,
    DateTime? chartFrozenAt,
    bool clearChartFrozen = false,
  }) => SessionState(
    connection: connection ?? this.connection,
    batteryLevel: batteryLevel ?? this.batteryLevel,
    batteryRemaining: batteryRemaining ?? this.batteryRemaining,
    lastJump: lastJump ?? this.lastJump,
    history: history ?? this.history,
    routine: routine ?? this.routine,
    deviceName: deviceName ?? this.deviceName,
    deviceInfo: deviceInfo ?? this.deviceInfo,
    events: events ?? this.events,
    chartFrozenAt: clearChartFrozen
        ? null
        : (chartFrozenAt ?? this.chartFrozenAt),
  );
}

/// Owns the sensor connection and everything derived from it. Rebuilt (state
/// reset) whenever the paired device or the sensor backend changes.
class SessionController extends Notifier<SessionState> {
  /// Longest chart window offered in Settings; older jumps are dropped.
  static const maxHistory = Duration(minutes: 5);
  static const _tickInterval = Duration(milliseconds: 200);

  DateTime _now() => ref.read(clockProvider)();

  Sensor? _sensor;
  JumpAssembler _assembler = JumpAssembler();
  RoutineMachine _machine = RoutineMachine();
  BatteryEstimator _battery = BatteryEstimator();
  Timer? _timer;
  bool _wasConnected = false;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  SessionState build() {
    final pairedId = ref.watch(
      settingsProvider.select((s) => s.pairedDeviceId),
    );
    final backend = ref.watch(sensorBackendProvider);
    final pairedName = ref.read(settingsProvider).pairedDeviceName;

    _assembler = JumpAssembler();
    _machine = RoutineMachine();
    _battery = BatteryEstimator();
    _wasConnected = false;
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
    ref.onDispose(_teardown);

    if (pairedId != null) _attach(backend.open(pairedId));
    return SessionState(
      connection:
          _sensor?.currentConnectionState ?? SensorConnectionState.disconnected,
      deviceName: pairedName,
    );
  }

  void _attach(Sensor sensor) {
    _sensor = sensor;
    _subs
      ..add(sensor.connectionState.listen(_onConnection))
      ..add(sensor.takeoffs.listen(_assembler.onTakeoff))
      ..add(sensor.landings.listen(_onLanding))
      ..add(sensor.batteryLevel.listen(_onBattery));
    unawaited(sensor.connect().catchError((Object _) {}));
  }

  /// Stops the sensor connection for good (used when quitting the app).
  Future<void> shutdown() async {
    final sensor = _sensor;
    if (sensor != null) await sensor.disconnect();
  }

  void _teardown() {
    _timer?.cancel();
    _timer = null;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    final sensor = _sensor;
    _sensor = null;
    if (sensor != null) unawaited(sensor.dispose());
  }

  // ---- sensor events ----

  void _onConnection(SensorConnectionState c) {
    _machine.setConnected(c == SensorConnectionState.connected);
    state = state.copyWith(
      connection: c,
      routine: _machine.state,
      events: _withConnectionEvent(c),
    );
    if (c == SensorConnectionState.connected) {
      unawaited(_refreshName());
      unawaited(_refreshDeviceInfo());
    }
  }

  /// Marks only real transitions: reaching `connected`, and losing an
  /// established connection (not each failed reconnect attempt in between).
  List<ChartEvent>? _withConnectionEvent(SensorConnectionState c) {
    final ChartEventType? type;
    if (c == SensorConnectionState.connected && !_wasConnected) {
      type = ChartEventType.connected;
    } else if (c == SensorConnectionState.disconnected && _wasConnected) {
      type = ChartEventType.disconnected;
    } else {
      type = null;
    }
    if (c != SensorConnectionState.connecting) {
      _wasConnected = c == SensorConnectionState.connected;
    }
    if (type == null) return null;
    final at = _now();
    return [
      ...state.events.where((e) => e.at.isAfter(_cutoff(at))),
      ChartEvent(at: at, type: type),
    ];
  }

  /// Oldest time still kept for the chart. While the view is paused, data
  /// around the frozen window must survive, so it is measured from there.
  DateTime _cutoff(DateTime latest) =>
      (state.chartFrozenAt ?? latest).subtract(maxHistory);

  Future<void> _refreshName() async {
    final sensor = _sensor;
    if (sensor == null) return;
    try {
      final name = await sensor.readName();
      if (!ref.mounted || name == null || name.isEmpty) return;
      state = state.copyWith(deviceName: name);
      ref.read(settingsProvider.notifier).setPairedName(name);
    } catch (_) {
      // Name is cosmetic; keep the cached one.
    }
  }

  Future<void> _refreshDeviceInfo() async {
    final sensor = _sensor;
    if (sensor == null) return;
    try {
      final info = await sensor.readDeviceInfo();
      if (!ref.mounted || info.isEmpty) return;
      state = state.copyWith(deviceInfo: info);
    } catch (_) {
      // Informational only; keep whatever was read before (if anything).
    }
  }

  void _onLanding(LandingEvent landing) {
    final jump = _assembler.onLanding(landing);
    if (jump == null) return;

    final before = _machine.state;
    _machine.onJump(jump);
    final after = _machine.state;

    final cutoff = _cutoff(jump.landedAt);
    final history = [
      ...state.history.where((j) => j.landedAt.isAfter(cutoff)),
      jump,
    ];
    state = state.copyWith(
      lastJump: jump,
      history: history,
      events: state.events.where((e) => e.at.isAfter(cutoff)).toList(),
      routine: after,
    );

    if (after.jumps.length > before.jumps.length) {
      _playFor(after.jumps.length, after.targetJumps);
    }
  }

  void _onBattery(int level) {
    _battery.add(_now(), level);
    state = state.copyWith(
      batteryLevel: level,
      batteryRemaining: _battery.remaining(),
    );
  }

  // ---- audio ----

  /// Jumps before the last use the per-jump beep; the last one (the routine's
  /// target) only the final sound.
  void _playFor(int jumpNumber, int target) {
    final settings = ref.read(settingsProvider);
    final audio = ref.read(audioServiceProvider);
    if (jumpNumber >= target) {
      if (settings.finalBeep) unawaited(audio.playFinalBeep());
    } else if (settings.perJumpBeep) {
      unawaited(audio.playJumpBeep());
    }
  }

  // ---- routine ----

  void _tick() {
    _machine.tick(_now());
    if (!identical(_machine.state, state.routine)) {
      state = state.copyWith(routine: _machine.state);
    }
  }

  bool startRoutine() {
    final settings = ref.read(settingsProvider);
    final started = _machine.start(
      lastJump: state.lastJump,
      now: _now(),
      timeout: settings.inactivityTimeout,
      jumpsPerRoutine: settings.jumpsPerRoutine,
    );
    if (started) {
      state = state.copyWith(routine: _machine.state);
      _playFor(1, _machine.state.targetJumps);
    }
    return started;
  }

  void cancelRoutine() {
    _machine.cancel();
    state = state.copyWith(routine: _machine.state);
  }

  void clearHistory() =>
      state = state.copyWith(history: const [], events: const []);

  /// Freezes the chart view at the current time. Jumps and sensor events keep
  /// being recorded; they show up again after [resumeChart].
  void pauseChart() => state = state.copyWith(chartFrozenAt: _now());

  void resumeChart() => state = state.copyWith(clearChartFrozen: true);

  // ---- device ----

  Future<void> renameDevice(String name) async {
    final sensor = _sensor;
    if (sensor == null) return;
    await sensor.writeName(name);
    if (!ref.mounted) return;
    state = state.copyWith(deviceName: name);
    ref.read(settingsProvider.notifier).setPairedName(name);
  }
}
