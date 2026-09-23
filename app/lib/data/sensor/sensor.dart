import '../../domain/sensor_events.dart';

enum SensorConnectionState { disconnected, connecting, connected }

class DiscoveredSensor {
  const DiscoveredSensor({
    required this.id,
    required this.name,
    required this.rssi,
  });

  /// Platform device identifier (MAC on Android, UUID on iOS).
  final String id;

  /// User-assignable name advertised by the sensor.
  final String name;
  final int rssi;
}

/// Static identification data from the sensor's BLE Device Information
/// Service. Each field is null if the sensor doesn't expose that
/// characteristic (e.g. older firmware).
class DeviceInfo {
  const DeviceInfo({
    this.manufacturerName,
    this.modelNumber,
    this.serialNumber,
    this.hardwareRevision,
    this.firmwareRevision,
    this.softwareRevision,
  });

  static const empty = DeviceInfo();

  final String? manufacturerName;
  final String? modelNumber;
  final String? serialNumber;
  final String? hardwareRevision;
  final String? firmwareRevision;

  /// Name of the active jump-detection algorithm running on the sensor.
  final String? softwareRevision;

  bool get isEmpty =>
      manufacturerName == null &&
      modelNumber == null &&
      serialNumber == null &&
      hardwareRevision == null &&
      firmwareRevision == null &&
      softwareRevision == null;
}

/// One connection to one OpenToF sensor. The app currently holds a single
/// instance, but nothing here assumes there can only ever be one.
abstract class Sensor {
  String get id;

  Stream<LandingEvent> get landings;
  Stream<TakeoffEvent> get takeoffs;

  /// Battery level in percent (0-100).
  Stream<int> get batteryLevel;

  Stream<SensorConnectionState> get connectionState;
  SensorConnectionState get currentConnectionState;

  /// Connects and keeps the connection alive, reconnecting automatically after
  /// drops, until [disconnect] is called.
  Future<void> connect();

  Future<void> disconnect();

  /// The sensor's user-assigned name (null if unavailable).
  Future<String?> readName();

  Future<void> writeName(String name);

  /// Static Device Information Service fields (manufacturer, model, serial
  /// number, hardware/firmware revision, active algorithm). Never throws;
  /// unavailable fields come back null.
  Future<DeviceInfo> readDeviceInfo();

  /// Releases all resources. The sensor must not be used afterwards.
  Future<void> dispose();
}

/// Finds sensors and creates [Sensor] connections for them.
abstract class SensorBackend {
  /// Emits the growing list of nearby OpenToF sensors until [stopScan] or the
  /// timeout.
  Stream<List<DiscoveredSensor>> scan({
    Duration timeout = const Duration(seconds: 10),
  });

  Future<void> stopScan();

  Sensor open(String deviceId);
}
