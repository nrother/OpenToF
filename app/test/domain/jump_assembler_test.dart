import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/jump_assembler.dart';
import 'package:opentof_app/domain/sensor_events.dart';

final t0 = DateTime(2026, 1, 1);

TakeoffEvent takeoff(int seq, {int contact = 200}) =>
    TakeoffEvent(contactMs: contact, sequence: seq, receivedAt: t0);
LandingEvent landing(int seq, {int flight = 1000}) =>
    LandingEvent(flightMs: flight, sequence: seq, receivedAt: t0);

void main() {
  test('takeoff contact time is attached to the next landing', () {
    final a = JumpAssembler();
    a.onTakeoff(takeoff(1, contact: 250));
    final j = a.onLanding(landing(1, flight: 1100))!;
    expect(j.flightMs, 1100);
    expect(j.contactMs, 250);
    expect(j.missedEvent, isFalse);
  });

  test(
    'landing without a preceding takeoff has unknown contact, no warning',
    () {
      final a = JumpAssembler();
      final j = a.onLanding(landing(1))!;
      expect(j.contactMs, isNull);
      expect(j.missedEvent, isFalse);
    },
  );

  test('contact time is consumed once', () {
    final a = JumpAssembler();
    a.onTakeoff(takeoff(1));
    a.onLanding(landing(1));
    expect(a.onLanding(landing(2))!.contactMs, isNull);
  });

  test('consecutive sequences produce no warning', () {
    final a = JumpAssembler();
    for (var i = 1; i <= 5; i++) {
      a.onTakeoff(takeoff(i));
      expect(a.onLanding(landing(i))!.missedEvent, isFalse);
    }
  });

  test('landing sequence gap flags that jump only', () {
    final a = JumpAssembler();
    a.onTakeoff(takeoff(1));
    a.onLanding(landing(1));
    a.onTakeoff(takeoff(2));
    expect(a.onLanding(landing(3))!.missedEvent, isTrue);
    a.onTakeoff(takeoff(3));
    expect(a.onLanding(landing(4))!.missedEvent, isFalse);
  });

  test('takeoff sequence gap flags the following jump', () {
    final a = JumpAssembler();
    a.onTakeoff(takeoff(1));
    a.onLanding(landing(1));
    a.onTakeoff(takeoff(3)); // takeoff 2 missed
    expect(a.onLanding(landing(2))!.missedEvent, isTrue);
  });

  test('duplicate events are ignored', () {
    final a = JumpAssembler();
    a.onTakeoff(takeoff(1));
    expect(a.onLanding(landing(1)), isNotNull);
    expect(a.onLanding(landing(1)), isNull);
  });

  test('counter reset (lower sequence) is not a gap', () {
    final a = JumpAssembler();
    a.onLanding(landing(50));
    expect(a.onLanding(landing(1))!.missedEvent, isFalse);
    expect(a.onLanding(landing(2))!.missedEvent, isFalse);
  });

  test('reset forgets baselines', () {
    final a = JumpAssembler();
    a.onLanding(landing(1));
    a.reset();
    expect(a.onLanding(landing(100))!.missedEvent, isFalse);
  });
}
