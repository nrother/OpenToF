import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/data/ble/ble_protocol.dart';

final t = DateTime(2026, 1, 1);

void main() {
  test('landing parses little-endian flight time and sequence', () {
    // 1234 ms = 0x04D2, seq 7
    final e = BleProtocol.parseLanding([0xD2, 0x04, 0, 0, 7, 0, 0, 0], t)!;
    expect(e.flightMs, 1234);
    expect(e.sequence, 7);
    expect(e.receivedAt, t);
  });

  test('takeoff parses contact time and sequence, incl. large uint32', () {
    final e = BleProtocol.parseTakeoff([
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      1,
      1,
      0,
      0,
    ], t)!;
    expect(e.contactMs, 0xFFFFFFFF);
    expect(e.sequence, 257);
  });

  test('encodeEvent round-trips through the parsers', () {
    final bytes = BleProtocol.encodeEvent(987, 42);
    expect(BleProtocol.parseLanding(bytes, t)!.flightMs, 987);
    expect(BleProtocol.parseTakeoff(bytes, t)!.sequence, 42);
  });

  test('short payloads are rejected, longer ones tolerated', () {
    expect(BleProtocol.parseLanding([1, 2, 3], t), isNull);
    expect(BleProtocol.parseTakeoff(const [], t), isNull);
    expect(
      BleProtocol.parseLanding([1, 0, 0, 0, 1, 0, 0, 0, 99], t),
      isNotNull,
    );
  });

  test('battery level 0-100 only', () {
    expect(BleProtocol.parseBattery([0]), 0);
    expect(BleProtocol.parseBattery([100]), 100);
    expect(BleProtocol.parseBattery([101]), isNull);
    expect(BleProtocol.parseBattery([]), isNull);
  });

  test('name round-trips UTF-8', () {
    const name = 'Trampolin Süd';
    expect(BleProtocol.parseName(BleProtocol.encodeName(name)), name);
    expect(BleProtocol.parseName([]), isNull);
  });

  test('parseUtf8String backs every Device Information field the same way', () {
    expect(
      BleProtocol.parseUtf8String(BleProtocol.encodeName('OpenToF')),
      'OpenToF',
    );
    expect(BleProtocol.parseUtf8String([]), isNull);
  });

  test('device information UUIDs are the Bluetooth SIG assigned numbers', () {
    expect(BleProtocol.deviceInformationService, '180a');
    expect(BleProtocol.manufacturerNameCharacteristic, '2a29');
    expect(BleProtocol.modelNumberCharacteristic, '2a24');
    expect(BleProtocol.serialNumberCharacteristic, '2a25');
    expect(BleProtocol.hardwareRevisionCharacteristic, '2a27');
    expect(BleProtocol.firmwareRevisionCharacteristic, '2a26');
    expect(BleProtocol.softwareRevisionCharacteristic, '2a28');
  });
}
