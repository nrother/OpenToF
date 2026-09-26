import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/algorithm_metadata.dart';
import 'package:opentof_app/domain/jump.dart';
import 'package:opentof_app/domain/jump_assembler.dart';
import 'package:opentof_app/domain/sensor_events.dart';

final t0 = DateTime(2026, 1, 1);

JumpEvent ev(
  int id,
  JumpEventType type,
  int t, {
  JumpEventStage stage = JumpEventStage.finalized,
  int? confidence,
  int reasons = 0,
  List<int> extras = const [],
}) => JumpEvent(
  jumpId: id,
  type: type,
  stage: stage,
  deviceTimeMs: t,
  receivedAt: t0.add(Duration(milliseconds: t)),
  confidence: confidence,
  reasons: reasons,
  extras: extras,
);

JumpEvent takeoff(int id, int t, {JumpEventStage? stage, int? confidence}) =>
    ev(
      id,
      JumpEventType.takeoff,
      t,
      stage: stage ?? JumpEventStage.finalized,
      confidence: confidence,
    );
JumpEvent landing(int id, int t, {JumpEventStage? stage, int? confidence}) =>
    ev(
      id,
      JumpEventType.landing,
      t,
      stage: stage ?? JumpEventStage.finalized,
      confidence: confidence,
    );
JumpEvent retracted(int id, JumpEventType type) =>
    ev(id, type, 0, stage: JumpEventStage.retracted);

Jump added(JumpUpdate? u) => (u! as JumpAdded).jump;
Jump changed(JumpUpdate? u) => (u! as JumpChanged).jump;

void main() {
  test('a jump appears with its landing: flight = landing - takeoff', () {
    final a = JumpAssembler();
    expect(a.onEvent(takeoff(1, 1000)), isNull);
    final j = added(a.onEvent(landing(1, 2150)));
    expect(j.flightMs, 1150);
    expect(j.contactMs, isNull); // no previous landing
    expect(j.isFinal, isTrue);
    expect(j.missedEvent, isFalse);
    expect(j.landedAt, t0.add(const Duration(milliseconds: 2150)));
  });

  test('contact time = takeoff - previous landing', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1000));
    a.onEvent(landing(1, 2000));
    a.onEvent(takeoff(2, 2230));
    final j = added(a.onEvent(landing(2, 3300)));
    expect(j.contactMs, 230);
    expect(j.flightMs, 1070);
  });

  test('provisional values are replaced by the final ones', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1005, stage: JumpEventStage.provisional));
    final first = added(
      a.onEvent(landing(1, 2010, stage: JumpEventStage.provisional)),
    );
    expect(first.isFinal, isFalse);
    expect(first.flightMs, 1005);

    final t = changed(a.onEvent(takeoff(1, 1000)));
    expect(t.serial, first.serial);
    expect(t.flightMs, 1010);
    expect(t.isFinal, isFalse); // landing still provisional

    final l = changed(a.onEvent(landing(1, 2000)));
    expect(l.flightMs, 1000);
    expect(l.isFinal, isTrue);
    expect(l.landedAt, first.landedAt); // keeps the first receive time
  });

  test('a stale provisional after the final is ignored', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1000));
    a.onEvent(landing(1, 2000));
    expect(
      a.onEvent(landing(1, 2500, stage: JumpEventStage.provisional)),
      isNull,
    );
  });

  test('a retracted landing removes the jump; a new landing re-adds it', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1000));
    final fake = added(
      a.onEvent(landing(1, 1500, stage: JumpEventStage.provisional)),
    );
    final removed = a.onEvent(retracted(1, JumpEventType.landing));
    expect((removed! as JumpRemoved).serial, fake.serial);

    final real = added(a.onEvent(landing(1, 2100)));
    expect(real.flightMs, 1100);
    expect(real.serial, isNot(fake.serial));
  });

  test('a retracted takeoff drops the jump silently, no gap warning', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1000));
    a.onEvent(landing(1, 2000));
    a.onEvent(takeoff(2, 2200, stage: JumpEventStage.provisional));
    expect(a.onEvent(retracted(2, JumpEventType.takeoff)), isNull);
    a.onEvent(takeoff(3, 2250));
    final j = added(a.onEvent(landing(3, 3250)));
    expect(j.missedEvent, isFalse);
    expect(j.contactMs, 250); // from jump 1's landing: jump 2 never happened
  });

  test('a jump id gap flags the next jump', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1000));
    a.onEvent(landing(1, 2000));
    a.onEvent(takeoff(3, 5000));
    expect(added(a.onEvent(landing(3, 6000))).missedEvent, isTrue);
  });

  test('a lost landing flags the next jump', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1000));
    a.onEvent(landing(1, 2000));
    a.onEvent(takeoff(2, 2200)); // its landing never arrives
    a.onEvent(takeoff(3, 3500));
    final j = added(a.onEvent(landing(3, 4500)));
    expect(j.missedEvent, isTrue);
    expect(j.contactMs, isNull);
  });

  test('connecting mid-flight: a lone first landing is no warning', () {
    final a = JumpAssembler();
    expect(a.onEvent(landing(7, 2000)), isNull);
    a.onEvent(takeoff(8, 2200));
    final j = added(a.onEvent(landing(8, 3200)));
    expect(j.missedEvent, isFalse);
    expect(j.contactMs, 200);
  });

  test('a jump id far behind is a sensor restart: new baseline', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(50, 1000));
    a.onEvent(landing(50, 2000));
    a.onEvent(takeoff(1, 300));
    final j = added(a.onEvent(landing(1, 1300)));
    expect(j.missedEvent, isFalse);
    expect(j.flightMs, 1000);
  });

  test('jump ids and device times wrap around', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(0xFFFF, 0xFFFFFF00));
    a.onEvent(landing(0xFFFF, 0xFFFFFFF0));
    a.onEvent(takeoff(0, 0x100));
    final j = added(a.onEvent(landing(0, 0x500)));
    expect(j.missedEvent, isFalse);
    expect(j.contactMs, 0x110);
    expect(j.flightMs, 0x400);
  });

  test('reset forgets the baseline', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1000));
    a.onEvent(landing(1, 2000));
    a.reset();
    a.onEvent(takeoff(5, 100));
    expect(added(a.onEvent(landing(5, 1100))).missedEvent, isFalse);
  });

  test('confidence, reasons and custom fields', () {
    final a = JumpAssembler(
      metadata: AlgorithmMetadata.parse(
        fieldsJson:
            '[{"id":"pi","name":"Push","t":"u8","on":"T","na":255},'
            '{"id":"li","name":"Land","t":"u16","on":"L","scale":0.5}]',
        reasonsJson: '["weak push","clipped"]',
        confidenceKind: 'heuristic',
      ),
    );
    a.onEvent(
      ev(1, JumpEventType.takeoff, 1000, confidence: 80, extras: [255]),
    );
    final j = added(
      a.onEvent(
        ev(
          1,
          JumpEventType.landing,
          2000,
          confidence: 40,
          reasons: 0x2,
          extras: [0x10, 0x01],
        ),
      ),
    );
    expect(j.confidence, 40);
    expect(j.reasons, ['clipped']);
    expect(j.fields, {'li': 136}); // 0x0110 * 0.5; pi not available
    expect(j.isUncertain, isTrue);
  });

  test('no confidence given: not uncertain', () {
    final a = JumpAssembler();
    a.onEvent(takeoff(1, 1000));
    final j = added(a.onEvent(landing(1, 2000)));
    expect(j.confidence, isNull);
    expect(j.reasons, isEmpty);
    expect(j.fields, isEmpty);
    expect(j.isUncertain, isFalse);
  });
}
