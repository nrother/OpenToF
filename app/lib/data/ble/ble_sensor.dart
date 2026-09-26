import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/algorithm_metadata.dart';
import '../../domain/sensor_events.dart';
import '../sensor/sensor.dart';
import 'ble_protocol.dart';

/// Requests the runtime permissions BLE scanning/connecting needs (Android).
/// iOS prompts by itself via CoreBluetooth (see Info.plist usage strings).
///
/// Location (needed for scanning on Android 10/11 only) is deliberately not
/// requested here: flutter_blue_plus asks for it itself on those versions, and
/// permission_handler would log "No permissions found in manifest" on 12+,
/// where the manifest no longer declares it.
Future<void> ensureBlePermissions() async {
  if (kIsWeb || !Platform.isAndroid) return;
  final results = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ].request();
  final scan = results[Permission.bluetoothScan];
  final connect = results[Permission.bluetoothConnect];
  if (scan?.isPermanentlyDenied == true ||
      connect?.isPermanentlyDenied == true) {
    throw StateError('Bluetooth permission permanently denied');
  }
  if (scan?.isDenied == true || connect?.isDenied == true) {
    throw StateError('Bluetooth permission denied');
  }
}

/// Makes sure the Bluetooth adapter is on before scanning. On Android this
/// shows the system "turn on Bluetooth" prompt instead of failing the scan.
Future<void> ensureBluetoothOn() async {
  if (kIsWeb) return;
  final state = await FlutterBluePlus.adapterState.first;
  if (state == BluetoothAdapterState.on) return;
  if (Platform.isAndroid) {
    await FlutterBluePlus.turnOn();
    return;
  }
  throw StateError('Bluetooth is turned off');
}

class BleSensorBackend implements SensorBackend {
  Timer? _scanTimer;

  @override
  Stream<List<DiscoveredSensor>> scan({
    Duration timeout = const Duration(seconds: 10),
  }) {
    late final StreamController<List<DiscoveredSensor>> controller;
    StreamSubscription<List<ScanResult>>? sub;

    Future<void> finish() async {
      _scanTimer?.cancel();
      await sub?.cancel();
      await FlutterBluePlus.stopScan();
      if (!controller.isClosed) await controller.close();
    }

    controller = StreamController<List<DiscoveredSensor>>(
      onListen: () async {
        try {
          await ensureBlePermissions();
          await ensureBluetoothOn();
          sub = FlutterBluePlus.scanResults.listen(
            (results) => controller.add([
              for (final r in results)
                DiscoveredSensor(
                  id: r.device.remoteId.str,
                  name: r.advertisementData.advName.isNotEmpty
                      ? r.advertisementData.advName
                      : r.device.platformName,
                  rssi: r.rssi,
                ),
            ]),
          );
          await FlutterBluePlus.startScan(
            withServices: [Guid(BleProtocol.jumpService)],
          );
          _scanTimer = Timer(timeout, finish);
        } catch (e, st) {
          controller.addError(e, st);
          await finish();
        }
      },
      onCancel: finish,
    );
    return controller.stream;
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    await FlutterBluePlus.stopScan();
  }

  @override
  Sensor open(String deviceId) => BleSensor(deviceId);
}

/// Real BLE connection to one OpenToF sensor. Keeps reconnecting until
/// [disconnect] is called.
class BleSensor implements Sensor {
  BleSensor(this.id) : _device = BluetoothDevice.fromId(id);

  @override
  final String id;
  final BluetoothDevice _device;

  static const _retryDelay = Duration(seconds: 2);
  static const _connectTimeout = Duration(seconds: 10);

  final _events = StreamController<JumpEvent>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _state = StreamController<SensorConnectionState>.broadcast();

  SensorConnectionState _current = SensorConnectionState.disconnected;
  bool _wantConnected = false;
  bool _running = false;
  Completer<void>? _stop;
  BluetoothCharacteristic? _nameChar;
  List<BluetoothService>? _services;
  final List<StreamSubscription<dynamic>> _charSubs = [];

  @override
  Stream<JumpEvent> get events => _events.stream;
  @override
  Stream<int> get batteryLevel => _battery.stream;
  @override
  Stream<SensorConnectionState> get connectionState => _state.stream;
  @override
  SensorConnectionState get currentConnectionState => _current;

  @override
  Future<void> connect() async {
    _wantConnected = true;
    if (_running) return;
    _running = true;
    _stop = Completer<void>();
    unawaited(_run().whenComplete(() => _running = false));
  }

  Future<void> _run() async {
    while (_wantConnected) {
      try {
        await ensureBlePermissions();
        _set(SensorConnectionState.connecting);
        // Product owner confirmed OpenToF qualifies as non-profit under the
        // package license (docs/DECISIONS.md).
        await _device.connect(
          license: License.nonprofit,
          timeout: _connectTimeout,
        );
        await _subscribe();
        _set(SensorConnectionState.connected);
        await Future.any([
          _device.connectionState.firstWhere(
            (s) => s == BluetoothConnectionState.disconnected,
          ),
          _stop!.future,
        ]);
      } catch (e) {
        debugPrint('BLE connect failed: $e');
      } finally {
        await _clearSubscriptions();
        _set(SensorConnectionState.disconnected);
      }
      if (!_wantConnected) break;
      await Future.any([Future<void>.delayed(_retryDelay), _stop!.future]);
    }
  }

  BluetoothCharacteristic? _findChar(String service, String characteristic) {
    final services = _services;
    if (services == null) return null;
    for (final s in services) {
      if (s.uuid != Guid(service)) continue;
      for (final c in s.characteristics) {
        if (c.uuid == Guid(characteristic)) return c;
      }
    }
    return null;
  }

  Future<void> _subscribe() async {
    final services = await _device.discoverServices();
    _services = services;
    BluetoothCharacteristic? find(String service, String characteristic) =>
        _findChar(service, characteristic);

    final event = find(
      BleProtocol.jumpService,
      BleProtocol.eventCharacteristic,
    );
    final battery = find(
      BleProtocol.batteryService,
      BleProtocol.batteryLevelCharacteristic,
    );
    _nameChar = find(BleProtocol.jumpService, BleProtocol.nameCharacteristic);

    if (event == null) {
      throw StateError('Jump event characteristic not found (old firmware?)');
    }

    // onValueReceived (not lastValueStream): every notification counts, e.g. a
    // provisional and a final event arriving back to back.
    _charSubs.add(
      event.onValueReceived.listen((v) {
        final e = BleProtocol.parseEvent(v, DateTime.now());
        if (e != null) _events.add(e);
      }),
    );
    await event.setNotifyValue(true);

    if (battery != null) {
      _charSubs.add(
        battery.onValueReceived.listen((v) {
          final level = BleProtocol.parseBattery(v);
          if (level != null) _battery.add(level);
        }),
      );
      await battery.setNotifyValue(true);
      final level = BleProtocol.parseBattery(await battery.read());
      if (level != null) _battery.add(level);
    }
  }

  Future<void> _clearSubscriptions() async {
    for (final s in _charSubs) {
      await s.cancel();
    }
    _charSubs.clear();
    _nameChar = null;
    _services = null;
  }

  @override
  Future<void> disconnect() async {
    _wantConnected = false;
    final stop = _stop;
    if (stop != null && !stop.isCompleted) stop.complete();
    try {
      await _device.disconnect();
    } catch (_) {}
    _set(SensorConnectionState.disconnected);
  }

  @override
  Future<String?> readName() async {
    final c = _nameChar;
    if (c == null) return null;
    return BleProtocol.parseName(await c.read());
  }

  @override
  Future<void> writeName(String name) async {
    final c = _nameChar;
    if (c == null) throw StateError('Sensor not connected');
    await c.write(BleProtocol.encodeName(name));
  }

  @override
  Future<DeviceInfo> readDeviceInfo() async {
    Future<String?> readString(String characteristic) async {
      final c = _findChar(BleProtocol.deviceInformationService, characteristic);
      if (c == null) return null;
      try {
        return BleProtocol.parseUtf8String(await c.read());
      } catch (_) {
        return null;
      }
    }

    final manufacturerName = await readString(
      BleProtocol.manufacturerNameCharacteristic,
    );
    final modelNumber = await readString(BleProtocol.modelNumberCharacteristic);
    final serialNumber = await readString(
      BleProtocol.serialNumberCharacteristic,
    );
    final hardwareRevision = await readString(
      BleProtocol.hardwareRevisionCharacteristic,
    );
    final firmwareRevision = await readString(
      BleProtocol.firmwareRevisionCharacteristic,
    );
    final softwareRevision = await readString(
      BleProtocol.softwareRevisionCharacteristic,
    );
    return DeviceInfo(
      manufacturerName: manufacturerName,
      modelNumber: modelNumber,
      serialNumber: serialNumber,
      hardwareRevision: hardwareRevision,
      firmwareRevision: firmwareRevision,
      softwareRevision: softwareRevision,
    );
  }

  Future<List<int>?> _readJumpChar(String characteristic) async {
    final c = _findChar(BleProtocol.jumpService, characteristic);
    if (c == null) return null;
    try {
      return await c.read();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SensorInfo?> readSensorInfo() async {
    final v = await _readJumpChar(BleProtocol.infoCharacteristic);
    return v == null ? null : BleProtocol.parseInfo(v);
  }

  @override
  Future<AlgorithmMetadata> readAlgorithmMetadata() async {
    Future<String?> readString(String characteristic) async {
      final v = await _readJumpChar(characteristic);
      return v == null ? null : BleProtocol.parseUtf8String(v);
    }

    return AlgorithmMetadata.parse(
      fieldsJson: await readString(BleProtocol.fieldsCharacteristic),
      reasonsJson: await readString(BleProtocol.reasonsCharacteristic),
      confidenceKind: await readString(
        BleProtocol.confidenceKindCharacteristic,
      ),
    );
  }

  void _set(SensorConnectionState s) {
    if (_current == s || _state.isClosed) return;
    _current = s;
    _state.add(s);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _battery.close();
    await _state.close();
  }
}
