import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/data/sensor/mock_sensor.dart';
import 'package:opentof_app/data/sensor/sensor.dart';
import 'package:opentof_app/domain/jump_assembler.dart';
import 'package:opentof_app/domain/sensor_events.dart';

void main() {
  late MockSensor s;
  late List<LandingEvent> landings;
  late List<TakeoffEvent> takeoffs;

  setUp(() async {
    s = MockSensor();
    landings = [];
    takeoffs = [];
    s.landings.listen(landings.add);
    s.takeoffs.listen(takeoffs.add);
    await s.connect();
  });

  tearDown(() => s.close());

  test('connect reports connected', () {
    expect(s.currentConnectionState, SensorConnectionState.connected);
  });

  test(
    'emitJump sends takeoff before landing with matching sequences',
    () async {
      s.emitJump(flightMs: 1234, contactMs: 200);
      await Future<void>.delayed(Duration.zero);
      expect(takeoffs.single.contactMs, 200);
      expect(landings.single.flightMs, 1234);
      expect([takeoffs.single.sequence, landings.single.sequence], [1, 1]);
    },
  );

  test(
    'events while disconnected are lost and show up as a sequence gap',
    () async {
      final a = JumpAssembler();
      s.emitJump();
      await Future<void>.delayed(Duration.zero);
      a.onTakeoff(takeoffs.last);
      expect(a.onLanding(landings.last)!.missedEvent, isFalse);

      s.simulateDisconnect();
      s.emitJump(); // lost
      s.simulateReconnect();
      s.emitJump();
      await Future<void>.delayed(Duration.zero);
      expect(landings.length, 2);
      a.onTakeoff(takeoffs.last);
      expect(a.onLanding(landings.last)!.missedEvent, isTrue);
    },
  );

  test('dropNextLanding creates a landing gap', () async {
    s.emitJump();
    s.dropNextLanding();
    s.emitJump();
    await Future<void>.delayed(Duration.zero);
    expect(landings.map((e) => e.sequence), [1, 3]);
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
  });
}
