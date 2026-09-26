import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/data/ble/ble_protocol.dart';
import 'package:opentof_app/domain/sensor_events.dart';

final t = DateTime(2026, 1, 1);

void main() {
  test('event parses the fixed little-endian layout and the extras', () {
    final e = BleProtocol.parseEvent([
      1, // proto
      0x34, 0x12, // jump_id 0x1234
      0x03, // landing, final
      0xD2, 0x04, 0x00, 0x00, // 1234 ms
      87, // confidence
      0x05, // reasons
      0xAA, 0xBB, // extras
    ], t)!;
    expect(e.jumpId, 0x1234);
    expect(e.type, JumpEventType.landing);
    expect(e.stage, JumpEventStage.finalized);
    expect(e.deviceTimeMs, 1234);
    expect(e.confidence, 87);
    expect(e.reasons, 5);
    expect(e.extras, [0xAA, 0xBB]);
    expect(e.receivedAt, t);
  });

  test('kind byte: takeoff provisional and retracted; 255 = no confidence', () {
    final p = BleProtocol.parseEvent([1, 1, 0, 0x00, 0, 0, 0, 0, 255, 0], t)!;
    expect(p.type, JumpEventType.takeoff);
    expect(p.stage, JumpEventStage.provisional);
    expect(p.confidence, isNull);
    final r = BleProtocol.parseEvent([1, 1, 0, 0x05, 0, 0, 0, 0, 255, 0], t)!;
    expect(r.type, JumpEventType.landing);
    expect(r.stage, JumpEventStage.retracted);
  });

  test('encodeEvent round-trips through parseEvent', () {
    final bytes = BleProtocol.encodeEvent(
      jumpId: 0xFFFF,
      type: JumpEventType.takeoff,
      stage: JumpEventStage.finalized,
      deviceTimeMs: 0xFFFFFFFF,
      confidence: 42,
      reasons: 0x80,
      extras: [1, 2, 3],
    );
    final e = BleProtocol.parseEvent(bytes, t)!;
    expect(e.jumpId, 0xFFFF);
    expect(e.type, JumpEventType.takeoff);
    expect(e.stage, JumpEventStage.finalized);
    expect(e.deviceTimeMs, 0xFFFFFFFF);
    expect(e.confidence, 42);
    expect(e.reasons, 0x80);
    expect(e.extras, [1, 2, 3]);
  });

  test('malformed events are rejected', () {
    List<int> ok() => [1, 1, 0, 0, 0, 0, 0, 0, 255, 0];
    expect(BleProtocol.parseEvent(ok().sublist(0, 9), t), isNull);
    expect(BleProtocol.parseEvent([...ok(), ...List.filled(11, 0)], t), isNull);
    expect(BleProtocol.parseEvent([2, ...ok().sublist(1)], t), isNull); // proto
    final badStage = ok()..[3] = 0x06; // stage 3
    expect(BleProtocol.parseEvent(badStage, t), isNull);
  });

  test('info: proto, boot counter, device time', () {
    final i = BleProtocol.parseInfo([1, 0x02, 0x01, 0x10, 0x27, 0, 0])!;
    expect(i.protocol, 1);
    expect(i.bootCount, 0x0102);
    expect(i.deviceTimeMs, 10000);
    expect(BleProtocol.parseInfo([1, 2, 3]), isNull);
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
