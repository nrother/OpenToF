import 'dart:async';
import 'dart:math' as math;

import '../../domain/sensor_events.dart';
import 'sensor.dart';

/// Debug-only simulated sensor. Never selected in release builds.
///
/// Emits events in the same order as the real device: the takeoff event
/// (carrying the contact time that just ended) precedes the landing event
/// (carrying the flight time that just ended).
class MockSensor implements Sensor {
  MockSensor({
    this.id = 'mock-1',
    this._name = 'OpenToF-Mock',
    DateTime Function()? clock,
    int seed = 1,
  }) : _clock = clock ?? DateTime.now,
       _random = math.Random(seed);

  @override
  final String id;
  String _name;
  final DateTime Function() _clock;
  final math.Random _random;

  final _landings = StreamController<LandingEvent>.broadcast();
  final _takeoffs = StreamController<TakeoffEvent>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _state = StreamController<SensorConnectionState>.broadcast();

  SensorConnectionState _current = SensorConnectionState.disconnected;
  bool _wantConnected = false;
  int _landingSeq = 0;
  int _takeoffSeq = 0;
  int _batteryLevel = 100;

  Timer? _bounceTimer;
  Timer? _batteryTimer;
  bool _inAir = false;

  @override
  Stream<LandingEvent> get landings => _landings.stream;
  @override
  Stream<TakeoffEvent> get takeoffs => _takeoffs.stream;
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
    firmwareRevision: '0.3.0',
    softwareRevision: 'MockJumpDetector',
  );

  // ---- Simulation controls (debug UI / tests) ----

  /// Emits one complete jump immediately (takeoff, then landing).
  void emitJump({int? flightMs, int? contactMs}) {
    emitTakeoff(contactMs: contactMs);
    emitLanding(flightMs: flightMs);
  }

  void emitTakeoff({int? contactMs}) {
    final seq = ++_takeoffSeq;
    if (_current != SensorConnectionState.connected) return; // lost in the air
    _takeoffs.add(
      TakeoffEvent(
        contactMs: contactMs ?? 150 + _random.nextInt(100),
        sequence: seq,
        receivedAt: _clock(),
      ),
    );
  }

  void emitLanding({int? flightMs}) {
    final seq = ++_landingSeq;
    if (_current != SensorConnectionState.connected) return;
    _landings.add(
      LandingEvent(
        flightMs: flightMs ?? 1000 + _random.nextInt(600),
        sequence: seq,
        receivedAt: _clock(),
      ),
    );
  }

  /// Consumes a landing sequence number without delivering it (missed BLE
  /// notification): the next landing shows a gap.
  void dropNextLanding() => _landingSeq++;

  /// Continuously bounces like a gymnast: contact, takeoff, flight, landing...
  void startBouncing() {
    if (_bounceTimer != null) return;
    _bounceTimer = Timer(Duration.zero, _bounceStep);
  }

  void stopBouncing() {
    _bounceTimer?.cancel();
    _bounceTimer = null;
    _inAir = false;
  }

  void _bounceStep() {
    if (_bounceTimer == null) return;
    final int wait;
    if (_inAir) {
      final flight = 1000 + _random.nextInt(600);
      emitLanding(flightMs: flight);
      _inAir = false;
      wait = 150 + _random.nextInt(100); // bed contact
    } else {
      emitTakeoff();
      _inAir = true;
      wait = 1000 + _random.nextInt(600); // flight
    }
    _bounceTimer = Timer(Duration(milliseconds: wait), _bounceStep);
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
    await _landings.close();
    await _takeoffs.close();
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
