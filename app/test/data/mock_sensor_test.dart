import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/data/sensor/mock_sensor.dart';
import 'package:opentof_app/data/sensor/sensor.dart';
import 'package:opentof_app/domain/jump_assembler.dart';
import 'package:opentof_app/domain/sensor_events.dart';

void main() {
  late MockSensor s;
  late List<JumpEvent> events;

  setUp(() async {
    s = MockSensor();
    events = [];
    s.events.listen(events.add);
    await s.connect();
  });

  tearDown(() => s.close());

  Future<JumpUpdate?> feedAll(JumpAssembler a) async {
    await Future<void>.delayed(Duration.zero);
    JumpUpdate? last;
    for (final e in events) {
      last = a.onEvent(e) ?? last;
    }
    events.clear();
    return last;
  }

  test('connect reports connected', () {
    expect(s.currentConnectionState, SensorConnectionState.connected);
  });

  test(
    'emitJump sends a final takeoff and landing sharing a jump id',
    () async {
      s.emitJump(flightMs: 1234);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.type), [
        JumpEventType.takeoff,
        JumpEventType.landing,
      ]);
      expect(events.map((e) => e.stage).toSet(), {JumpEventStage.finalized});
      expect(events.map((e) => e.jumpId).toSet(), {1});
      expect(events[1].deviceTimeMs - events[0].deviceTimeMs, 1234);
    },
  );

  test('contact time is measured from the previous landing', () async {
    final a = JumpAssembler();
    s.emitJump();
    s.emitJump(flightMs: 1100, contactMs: 230);
    final u = await feedAll(a);
    final j = (u! as JumpAdded).jump;
    expect(j.flightMs, 1100);
    expect(j.contactMs, 230);
  });

  test('events while disconnected are lost and show up as a gap', () async {
    final a = JumpAssembler();
    s.emitJump();
    expect(((await feedAll(a))! as JumpAdded).jump.missedEvent, isFalse);

    s.simulateDisconnect();
    s.emitJump(); // lost
    s.simulateReconnect();
    s.emitJump();
    expect(((await feedAll(a))! as JumpAdded).jump.missedEvent, isTrue);
  });

  test('dropNextJump skips a jump id', () async {
    s.emitJump();
    s.dropNextJump();
    s.emitJump();
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.jumpId), [1, 1, 3, 3]);
  });

  test('metadata describes the two intensity fields', () async {
    final m = await s.readAlgorithmMetadata();
    expect(m.fields.map((f) => f.id), ['pi', 'li']);
    expect(m.confidenceKind, 'heuristic');
    expect(m.reasons, hasLength(1));
    s.emitJump();
    final j = ((await feedAll(JumpAssembler(metadata: m)))! as JumpAdded).jump;
    expect(j.fields.keys.toSet(), {'pi', 'li'});
    expect(j.confidence, 90);
  });

  test('battery level is emitted on connect and on change', () async {
    final levels = <int>[];
    s.batteryLevel.listen(levels.add);
    s.setBatteryLevel(55);
    await Future<void>.delayed(Duration.zero);
    expect(levels, [55]);
  });

  test('name can be read and written', () async {
    await s.writeName('Gym A');
    expect(await s.readName(), 'Gym A');
  });

  test('device info returns fixed placeholder values', () async {
    final info = await s.readDeviceInfo();
    expect(info.isEmpty, isFalse);
    expect(info.manufacturerName, 'OpenToF');
    expect(info.modelNumber, isNotNull);
    expect(info.serialNumber, isNotNull);
    expect(info.hardwareRevision, isNotNull);
    expect(info.firmwareRevision, isNotNull);
    expect(info.softwareRevision, isNotNull);
    expect((await s.readSensorInfo())!.protocol, 1);
  });
}
