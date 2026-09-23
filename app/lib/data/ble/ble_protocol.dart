import 'dart:convert';
import 'dart:typed_data';

import '../../domain/sensor_events.dart';

/// The single home of all BLE UUIDs and payload byte layouts.
///
/// PLACEHOLDER UUIDs — the real ones are an open item pending firmware
/// agreement (docs/DECISIONS.md). All multi-byte values are little-endian.
///
/// Jump service characteristics:
///  - Landing  (Notify): flight_time_ms uint32, sequence_number uint32
///  - Takeoff  (Notify): contact_time_ms uint32, sequence_number uint32
///  - Name     (Read/Write): UTF-8 string
class BleProtocol {
  BleProtocol._();

  // Placeholder 128-bit UUIDs ("openToF" prefix + index).
  static const jumpService = '6f70656e-546f-4600-0001-000000000000';
  static const landingCharacteristic = '6f70656e-546f-4600-0002-000000000000';
  static const takeoffCharacteristic = '6f70656e-546f-4600-0003-000000000000';
  static const nameCharacteristic = '6f70656e-546f-4600-0004-000000000000';

  // Standard Bluetooth SIG Battery Service / Battery Level.
  static const batteryService = '180f';
  static const batteryLevelCharacteristic = '2a19';

  // Standard Bluetooth SIG Device Information Service. All Read-only UTF-8
  // strings; a sensor may not expose all (or any) of them.
  static const deviceInformationService = '180a';
  static const manufacturerNameCharacteristic = '2a29';
  static const modelNumberCharacteristic = '2a24';
  static const serialNumberCharacteristic = '2a25';
  static const hardwareRevisionCharacteristic = '2a27';
  static const firmwareRevisionCharacteristic = '2a26';

  /// Name of the active jump-detection algorithm running on the sensor.
  static const softwareRevisionCharacteristic = '2a28';

  static const eventPayloadLength = 8;

  /// Returns null for malformed payloads.
  static LandingEvent? parseLanding(List<int> data, DateTime receivedAt) {
    final v = _uint32Pair(data);
    if (v == null) return null;
    return LandingEvent(flightMs: v.$1, sequence: v.$2, receivedAt: receivedAt);
  }

  /// Returns null for malformed payloads.
  static TakeoffEvent? parseTakeoff(List<int> data, DateTime receivedAt) {
    final v = _uint32Pair(data);
    if (v == null) return null;
    return TakeoffEvent(
      contactMs: v.$1,
      sequence: v.$2,
      receivedAt: receivedAt,
    );
  }

  /// Battery level 0-100, or null if malformed / out of range.
  static int? parseBattery(List<int> data) {
    if (data.isEmpty) return null;
    final level = data[0];
    return level <= 100 ? level : null;
  }

  static String? parseName(List<int> data) => parseUtf8String(data);

  /// Shared by every Read-only UTF-8 string characteristic (name, Device
  /// Information Service fields).
  static String? parseUtf8String(List<int> data) {
    if (data.isEmpty) return null;
    return utf8.decode(data, allowMalformed: true);
  }

  static List<int> encodeName(String name) => utf8.encode(name);

  /// Test/mock helper: builds an 8-byte event payload.
  static Uint8List encodeEvent(int durationMs, int sequence) {
    final b = ByteData(eventPayloadLength);
    b.setUint32(0, durationMs, Endian.little);
    b.setUint32(4, sequence, Endian.little);
    return b.buffer.asUint8List();
  }

  static (int, int)? _uint32Pair(List<int> data) {
    if (data.length < eventPayloadLength) return null;
    final b = ByteData.sublistView(Uint8List.fromList(data));
    return (b.getUint32(0, Endian.little), b.getUint32(4, Endian.little));
  }
}
