import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/jump.dart';
import 'package:opentof_app/domain/routine.dart';

final t0 = DateTime(2026, 1, 1, 12);
const timeout = Duration(seconds: 4);

Jump jumpAt(int ms) => Jump(
  flightMs: 1000,
  contactMs: 200,
  landedAt: t0.add(Duration(milliseconds: ms)),
);

RoutineMachine startedWith(int jumps) {
  final m = RoutineMachine();
  final j = jumpAt(0);
  expect(
    m.start(
      lastJump: j,
      now: j.landedAt,
      timeout: timeout,
      jumpsPerRoutine: jumps,
    ),
    isTrue,
  );
  return m;
}

void main() {
  test('default length is 10', () {
    final m = RoutineMachine();
    m.start(lastJump: jumpAt(0), now: t0, timeout: timeout);
    expect(m.state.targetJumps, 10);
  });

  test('a routine ends after the chosen number of jumps', () {
    final m = startedWith(3);
    expect(m.state.targetJumps, 3);
    m.onJump(jumpAt(1000));
    expect(m.state.phase, RoutinePhase.running);
    m.onJump(jumpAt(2000));
    expect(m.state.phase, RoutinePhase.complete);
    expect(m.state.jumps.length, 3);
    expect(m.state.targetJumps, 3);
    expect(m.deadline, isNull);
  });

  test('longer routines than 10 work', () {
    final m = startedWith(25);
    for (var i = 1; i < 24; i++) {
      m.onJump(jumpAt(i * 1000));
    }
    expect(m.state.phase, RoutinePhase.running);
    m.onJump(jumpAt(24000));
    expect(m.state.phase, RoutinePhase.complete);
    expect(m.state.jumps.length, 25);
  });

  test('a routine of 1 completes at Start', () {
    final m = startedWith(1);
    expect(m.state.phase, RoutinePhase.complete);
    expect(m.state.jumps.length, 1);
    expect(m.deadline, isNull);
    expect(m.state.exportable, isTrue);
  });

  test('cancelled routines keep their target', () {
    final m = startedWith(4);
    m.cancel();
    expect(m.state.phase, RoutinePhase.cancelled);
    expect(m.state.targetJumps, 4);
  });
}
