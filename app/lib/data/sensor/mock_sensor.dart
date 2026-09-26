import 'dart:async';
import 'dart:math' as math;

import '../../domain/algorithm_metadata.dart';
import '../../domain/sensor_events.dart';
import 'sensor.dart';

/// Debug-only simulated sensor. Never selected in release builds.
///
/// Speaks protocol 1 like the real firmware's demo mode: takeoff and landing
/// events on its own device clock, sharing a jump id per jump. [emitJump]
/// sends final events right away; [startBouncing] sends each event as a
/// provisional estimate followed by the final one, with confidence, an
/// occasional reason bit, two intensity fields, and now and then a false
/// landing that is retracted.
class MockSensor implements Sensor {
  MockSensor({
    this.id = 'mock-1',
    this._name = 'OpenToF-Mock',
    DateTime Function()? clock,
    int seed = 1,
  }) : _clock = clock ?? DateTime.now,
       _random = math.Random(seed) {
    _epoch = _clock();
  }

  static const fieldsJson =
      '[{"id":"pi","name":"Push-off intensity","t":"u8","on":"T","rel":true,'
      '"na":255},{"id":"li","name":"Landing intensity","t":"u8","on":"L",'
      '"rel":true,"na":255}]';
  static const reasonsJson = '["mock: simulated uncertainty"]';

  @override
  final String id;
  String _name;
  final DateTime Function() _clock;
  final math.Random _random;
  late final DateTime _epoch;

  final _events = StreamController<JumpEvent>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _state = StreamController<SensorConnectionState>.broadcast();

  SensorConnectionState _current = SensorConnectionState.disconnected;
  bool _wantConnected = false;
  int _batteryLevel = 100;

  // Device-side jump bookkeeping (like the firmware's JumpEventPublisher).
  int _jumpId = 0;
  int? _takeoffMs;
  int? _lastLandingMs;
  int _lastEventMs = 0;

  Timer? _bounceTimer;
  final List<Timer> _pending = [];
  bool _inAir = false;

  @override
  Stream<JumpEvent> get events => _events.stream;
  @override
  Stream<int> get batteryLevel => _battery.stream;
  @override
  Stream<SensorConnectionState> get connectionState => _state.stream;
  @override
  SensorConnectionState get currentConnectionState => _current;

  bool get isBouncing => _bounceTimer != null;

  @override
  Future<void> connect() async {
    _wantConnected = true;
    _setState(SensorConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!_wantConnected) return;
    _setState(SensorConnectionState.connected);
    _battery.add(_batteryLevel);
    _batteryTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (_batteryLevel > 0) _batteryLevel--;
      if (_current == SensorConnectionState.connected) {
        _battery.add(_batteryLevel);
      }
    });
  }

  Timer? _batteryTimer;

  @override
  Future<void> disconnect() async {
    _wantConnected = false;
    stopBouncing();
    _batteryTimer?.cancel();
    _batteryTimer = null;
    _setState(SensorConnectionState.disconnected);
  }

  @override
  Future<String?> readName() async => _name;

  @override
  Future<void> writeName(String name) async => _name = name;

  @override
  Future<DeviceInfo> readDeviceInfo() async => const DeviceInfo(
    manufacturerName: 'OpenToF',
    modelNumber: 'OpenToF Sensor (simulated)',
    serialNumber: 'MOCK-0001',
    hardwareRevision: '0.1',
    firmwareRevision: '0.4.0',
    softwareRevision: 'MockJumpDetector',
  );

  @override
  Future<SensorInfo?> readSensorInfo() async =>
      SensorInfo(protocol: 1, bootCount: 1, deviceTimeMs: _nowMs());

  @override
  Future<AlgorithmMetadata> readAlgorithmMetadata() async =>
      AlgorithmMetadata.parse(
        fieldsJson: fieldsJson,
        reasonsJson: reasonsJson,
        confidenceKind: 'heuristic',
      );

  // ---- Simulation controls (debug UI / tests) ----

  /// Emits one complete jump immediately: final takeoff, then final landing.
  /// Contact time is measured from the previous landing (unknown for the
  /// first jump).
  void emitJump({
    int? flightMs,
    int? contactMs,
    int confidence = 90,
    int reasons = 0,
  }) {
    emitTakeoff(contactMs: contactMs, confidence: confidence);
    emitLanding(flightMs: flightMs, confidence: confidence, reasons: reasons);
  }

  /// Starts a new jump (or finalizes the current provisional takeoff when
  /// [stage] is final and [newJump] is false).
  void emitTakeoff({
    int? contactMs,
    JumpEventStage stage = JumpEventStage.finalized,
    bool newJump = true,
    int? confidence = 90,
    int reasons = 0,
  }) {
    if (newJump) {
      _jumpId = (_jumpId + 1) & 0xFFFF;
      final last = _lastLandingMs;
      _takeoffMs = last == null
          ? math.max(_nowMs(), _lastEventMs)
          : last + (contactMs ?? 150 + _random.nextInt(100));
    }
    _send(JumpEventType.takeoff, stage, _takeoffMs!, confidence, reasons, [
      stage == JumpEventStage.finalized ? 60 + _random.nextInt(170) : 255,
    ]);
  }

  /// Lands the current jump ([flightMs] after its takeoff).
  void emitLanding({
    int? flightMs,
    JumpEventStage stage = JumpEventStage.finalized,
    int? confidence = 90,
    int reasons = 0,
  }) {
    final takeoff = _takeoffMs;
    if (takeoff == null) return;
    final landing = takeoff + (flightMs ?? 1000 + _random.nextInt(600));
    _lastLandingMs = landing;
    _send(JumpEventType.landing, stage, landing, confidence, reasons, [
      stage == JumpEventStage.finalized ? 60 + _random.nextInt(170) : 255,
    ]);
  }

  /// Withdraws the current provisional landing.
  void retractLanding() => _send(
    JumpEventType.landing,
    JumpEventStage.retracted,
    0,
    null,
    0,
    const [],
  );

  /// Consumes a jump id without sending anything (a jump the app never
  /// hears of): the next jump shows a gap.
  void dropNextJump() => _jumpId = (_jumpId + 1) & 0xFFFF;

  /// Continuously bounces like a gymnast, two-stage: contact, takeoff,
  /// flight, landing...
  void startBouncing() {
    if (_bounceTimer != null) return;
    _bounceTimer = Timer(Duration.zero, _bounceStep);
  }

  void stopBouncing() {
    _bounceTimer?.cancel();
    _bounceTimer = null;
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
    _inAir = false;
  }

  void _later(int ms, void Function() f) =>
      _pending.add(Timer(Duration(milliseconds: ms), f));

  void _bounceStep() {
    if (_bounceTimer == null) return;
    _pending.removeWhere((t) => !t.isActive);
    final int wait;
    if (_inAir) {
      final flight = 1000 + _random.nextInt(600);
      final lowConfidence = _random.nextInt(10) == 0;
      emitLanding(
        flightMs: flight,
        stage: JumpEventStage.provisional,
        confidence: 50 + _random.nextInt(30),
      );
      final landingMs = _lastLandingMs!;
      _later(30 + _random.nextInt(90), () {
        _lastLandingMs = landingMs;
        _send(
          JumpEventType.landing,
          JumpEventStage.finalized,
          landingMs,
          lowConfidence ? 30 + _random.nextInt(20) : 80 + _random.nextInt(21),
          lowConfidence ? 1 : 0,
          [60 + _random.nextInt(170)],
        );
      });
      _inAir = false;
      wait = 150 + _random.nextInt(100); // bed contact
    } else {
      emitTakeoff(
        stage: JumpEventStage.provisional,
        confidence: 50 + _random.nextInt(30),
      );
      _later(
        80 + _random.nextInt(30),
        () => emitTakeoff(
          stage: JumpEventStage.finalized,
          newJump: false,
          confidence: 80 + _random.nextInt(21),
        ),
      );
      _inAir = true;
      wait = 1000 + _random.nextInt(600); // flight
      if (_random.nextInt(15) == 0) {
        _later(wait ~/ 2, () {
          _send(
            JumpEventType.landing,
            JumpEventStage.provisional,
            _takeoffMs! + wait ~/ 2,
            20 + _random.nextInt(30),
            0,
            const [255],
          );
        });
        _later(wait ~/ 2 + 60, retractLanding);
      }
    }
    _bounceTimer = Timer(Duration(milliseconds: wait), _bounceStep);
  }

  int _nowMs() => _clock().difference(_epoch).inMilliseconds;

  void _send(
    JumpEventType type,
    JumpEventStage stage,
    int deviceTimeMs,
    int? confidence,
    int reasons,
    List<int> extras,
  ) {
    if (deviceTimeMs > _lastEventMs) _lastEventMs = deviceTimeMs;
    if (_current != SensorConnectionState.connected) return; // lost
    _events.add(
      JumpEvent(
        jumpId: _jumpId,
        type: type,
        stage: stage,
        deviceTimeMs: deviceTimeMs,
        receivedAt: _clock(),
        confidence: confidence,
        reasons: reasons,
        extras: extras,
      ),
    );
  }

  /// Simulates a BLE drop; events that occur meanwhile are lost.
  void simulateDisconnect() => _setState(SensorConnectionState.disconnected);

  void simulateReconnect() {
    if (!_wantConnected) return;
    _setState(SensorConnectionState.connected);
    _battery.add(_batteryLevel);
  }

  void setBatteryLevel(int level) {
    _batteryLevel = level.clamp(0, 100);
    if (_current == SensorConnectionState.connected) {
      _battery.add(_batteryLevel);
    }
  }

  void _setState(SensorConnectionState s) {
    if (_current == s) return;
    _current = s;
    _state.add(s);
  }

  /// Only disconnects: the mock is a shared singleton that must survive
  /// session rebuilds. Use [close] to release the streams for good.
  @override
  Future<void> dispose() => disconnect();

  Future<void> close() async {
    await disconnect();
    await _events.close();
    await _battery.close();
    await _state.close();
  }
}

class MockSensorBackend implements SensorBackend {
  MockSensorBackend({MockSensor? sensor}) : sensor = sensor ?? MockSensor();

  final MockSensor sensor;

  @override
  Stream<List<DiscoveredSensor>> scan({
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    yield [DiscoveredSensor(id: sensor.id, name: 'OpenToF-Mock', rssi: -50)];
  }

  @override
  Future<void> stopScan() async {}

  @override
  Sensor open(String deviceId) => sensor;
}
