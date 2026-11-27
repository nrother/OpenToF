import 'dart:convert';
import 'dart:typed_data';

import '../../domain/sensor_events.dart';
import '../../domain/sensor_health.dart';

/// The single home of all BLE UUIDs and payload byte layouts. Must match
/// `firmware/OpenToF_Firmware/config/BleUuids.h`.
///
/// PLACEHOLDER UUIDs — the real ones are an open item pending firmware
/// agreement (docs/DECISIONS.md). All multi-byte values are little-endian.
///
/// Jump service characteristics (protocol 2):
///  - Event            (Notify): proto u8, jump_id u16, kind u8, t_ms u32,
///                     confidence u8, reasons u8, then up to 10 bytes of
///                     custom fields. kind bit 0 = landing, bits 1-2 = stage
///                     (0 provisional, 1 final, 2 retracted).
///  - Fields           (Read): JSON array of custom field descriptions
///  - Reasons          (Read): JSON array naming the reason bits
///  - Confidence kind  (Read): "none" | "heuristic" | "calibrated"
///  - Name             (Read/Write): UTF-8 string
///  - Health           (Read/Notify): version u8, flags u8, PLL frequency u32 mHz
///                     followed by uptime u32 seconds

class BleProtocol {
  BleProtocol._();

  /// Event layout version this app understands.
  static const protocolVersion = 2;

  // Placeholder 128-bit UUIDs ("openToF" prefix + index). 0002/0003 were the
  // protocol-0 Landing/Takeoff characteristics and are not reused.
  static const jumpService = '6f70656e-546f-4600-0001-000000000000';
  static const nameCharacteristic = '6f70656e-546f-4600-0004-000000000000';
  static const eventCharacteristic = '6f70656e-546f-4600-0005-000000000000';
  static const fieldsCharacteristic = '6f70656e-546f-4600-0007-000000000000';
  static const reasonsCharacteristic = '6f70656e-546f-4600-0008-000000000000';
  static const confidenceKindCharacteristic =
      '6f70656e-546f-4600-0009-000000000000';
  static const healthCharacteristic = '6f70656e-546f-4600-000b-000000000000';

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

  static const eventFixedLength = 10;
  static const eventExtrasMax = 10;
  static const _noConfidence = 255;

  /// The protocol byte of an event payload that [parseEvent] rejects only
  /// because it is not [protocolVersion]; null otherwise.
  static int? foreignProtocol(List<int> data) =>
      data.isNotEmpty && data[0] != protocolVersion ? data[0] : null;

  /// Returns null for malformed payloads, unknown protocol versions and
  /// unknown stages.
  static JumpEvent? parseEvent(List<int> data, DateTime receivedAt) {
    if (data.length < eventFixedLength) return null;
    if (data.length > eventFixedLength + eventExtrasMax) return null;
    final b = ByteData.sublistView(Uint8List.fromList(data));
    if (b.getUint8(0) != protocolVersion) return null;
    final kind = b.getUint8(3);
    final stageBits = (kind >> 1) & 0x3;
    if (stageBits > 2) return null;
    final confidence = b.getUint8(8);
    return JumpEvent(
      jumpId: b.getUint16(1, Endian.little),
      type: kind & 1 == 1 ? JumpEventType.landing : JumpEventType.takeoff,
      stage: JumpEventStage.values[stageBits],
      deviceTimeMs: b.getUint32(4, Endian.little),
      receivedAt: receivedAt,
      confidence: confidence == _noConfidence ? null : confidence,
      reasons: b.getUint8(9),
      extras: List.unmodifiable(data.sublist(eventFixedLength)),
    );
  }

  /// Test/mock helper: the inverse of [parseEvent].
  static Uint8List encodeEvent({
    required int jumpId,
    required JumpEventType type,
    required JumpEventStage stage,
    required int deviceTimeMs,
    int? confidence,
    int reasons = 0,
    List<int> extras = const [],
  }) {
    final b = ByteData(eventFixedLength + extras.length);
    b.setUint8(0, protocolVersion);
    b.setUint16(1, jumpId & 0xFFFF, Endian.little);
    b.setUint8(3, (type == JumpEventType.landing ? 1 : 0) | (stage.index << 1));
    b.setUint32(4, deviceTimeMs & 0xFFFFFFFF, Endian.little);
    b.setUint8(8, confidence ?? _noConfidence);
    b.setUint8(9, reasons);
    for (var i = 0; i < extras.length; i++) {
      b.setUint8(eventFixedLength + i, extras[i]);
    }
    return b.buffer.asUint8List();
  }

  /// Battery level 0-100, or null if malformed / out of range.
  static int? parseBattery(List<int> data) {
    if (data.isEmpty) return null;
    final level = data[0];
    return level <= 100 ? level : null;
  }

  /// Accept appended fields and unknown flag bits for future health additions.
  /// A changed prefix layout requires a new health version.
  static SensorHealth? parseHealth(List<int> data) {
    if (data.length < 6 || data[0] != 1) return null;
    if (data.length > 6 && data.length < 10) return null;
    final b = ByteData.sublistView(Uint8List.fromList(data));
    final flags = b.getUint8(1);
    final available = (flags & 1) != 0;
    return SensorHealth(
      pllLocked: available ? (flags & 2) != 0 : null,
      pllFrequencyHz: available ? b.getUint32(2, Endian.little) / 1000.0 : null,
      uptimeSeconds: data.length >= 10 ? b.getUint32(6, Endian.little) : null,
    );
  }

  static String? parseName(List<int> data) => parseUtf8String(data);

  /// Shared by every Read-only UTF-8 string characteristic (name, Device
  /// Information Service fields, algorithm description).
  static String? parseUtf8String(List<int> data) {
    if (data.isEmpty) return null;
    return utf8.decode(data, allowMalformed: true);
  }

  static List<int> encodeName(String name) => utf8.encode(name);
}
