import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/jump.dart';
import 'package:opentof_app/domain/routine.dart';

final t0 = DateTime(2026, 1, 1, 12, 0, 0);
const timeout = Duration(seconds: 4);

Jump jumpAt(int ms, {int flight = 1000, bool missed = false, int serial = 0}) =>
    Jump(
      serial: serial,
      flightMs: flight,
      contactMs: 200,
      landedAt: t0.add(Duration(milliseconds: ms)),
      missedEvent: missed,
    );

RoutineMachine started({Jump? first}) {
  final m = RoutineMachine();
  final j = first ?? jumpAt(0);
  expect(
    m.start(
      lastJump: j,
      now: j.landedAt.add(const Duration(seconds: 1)),
      timeout: timeout,
    ),
    isTrue,
  );
  return m;
}

void main() {
  group('start eligibility', () {
    test('no last jump -> cannot start', () {
      final m = RoutineMachine();
      expect(m.start(lastJump: null, now: t0, timeout: timeout), isFalse);
      expect(m.state.phase, RoutinePhase.idle);
    });

    test('stale last jump (older than timeout) -> cannot start', () {
      final m = RoutineMachine();
      final j = jumpAt(0);
      final now = j.landedAt.add(const Duration(milliseconds: 4001));
      expect(
        RoutineMachine.canStart(lastJump: j, now: now, timeout: timeout),
        isFalse,
      );
      expect(m.start(lastJump: j, now: now, timeout: timeout), isFalse);
    });

    test('jump exactly at timeout age can still start', () {
      final j = jumpAt(0);
      final now = j.landedAt.add(timeout);
      expect(
        RoutineMachine.canStart(lastJump: j, now: now, timeout: timeout),
        isTrue,
      );
    });

    test('last jump becomes jump #1', () {
      final m = started(first: jumpAt(0, flight: 1234));
      expect(m.state.phase, RoutinePhase.running);
      expect(m.state.jumps.length, 1);
      expect(m.state.jumps.first.flightMs, 1234);
    });

    test('start while running is ignored', () {
      final m = started();
      final other = jumpAt(500, flight: 999);
      expect(
        m.start(lastJump: other, now: other.landedAt, timeout: timeout),
        isFalse,
      );
      expect(m.state.jumps.first.flightMs, 1000);
    });
  });

  group('running', () {
    test('completes after jump #10 with total and no deadline', () {
      final m = started();
      for (var i = 1; i < 10; i++) {
        expect(m.state.phase, RoutinePhase.running);
        m.onJump(jumpAt(i * 1000, flight: 1000 + i));
      }
      expect(m.state.phase, RoutinePhase.complete);
      expect(m.state.jumps.length, 10);
      expect(
        m.state.totalFlightMs,
        1000 * 10 + (1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9),
      );
      expect(m.deadline, isNull);
    });

    test(
      'routine can complete instantly when jumps arrive in quick succession',
      () {
        final m = started();
        for (var i = 1; i < 10; i++) {
          m.onJump(jumpAt(i));
        }
        expect(m.state.phase, RoutinePhase.complete);
      },
    );

    test('jumps after completion are ignored', () {
      final m = started();
      for (var i = 1; i <= 12; i++) {
        m.onJump(jumpAt(i * 100));
      }
      expect(m.state.jumps.length, 10);
    });

    test('deadline runs from last landing and resets on each jump', () {
      final m = started(first: jumpAt(0));
      expect(m.deadline, t0.add(timeout));
      m.onJump(jumpAt(3000));
      expect(m.deadline, t0.add(const Duration(seconds: 7)));
    });

    test('inactivity timeout cancels but retains progress', () {
      final m = started();
      m.onJump(jumpAt(1000));
      m.tick(t0.add(const Duration(milliseconds: 4999)));
      expect(m.state.phase, RoutinePhase.running);
      m.tick(t0.add(const Duration(milliseconds: 5000)));
      expect(m.state.phase, RoutinePhase.cancelled);
      expect(m.state.cancelReason, CancelReason.inactivity);
      expect(m.state.jumps.length, 2);
      expect(m.state.exportable, isTrue);
    });

    test('user cancel retains progress', () {
      final m = started();
      m.onJump(jumpAt(1000));
      m.cancel();
      expect(m.state.phase, RoutinePhase.cancelled);
      expect(m.state.cancelReason, CancelReason.user);
      expect(m.state.jumps.length, 2);
    });

    test('cancel outside running is a no-op', () {
      final m = RoutineMachine();
      m.cancel();
      expect(m.state.phase, RoutinePhase.idle);
    });
  });

  group('disconnect', () {
    test('pauses without discarding progress; resumes on reconnect', () {
      final m = started();
      m.onJump(jumpAt(1000));
      m.setConnected(false);
      expect(m.state.paused, isTrue);
      expect(m.state.jumps.length, 2);
      m.setConnected(true);
      expect(m.state.paused, isFalse);
      m.onJump(jumpAt(2000));
      expect(m.state.jumps.length, 3);
    });

    test('inactivity timer keeps running while disconnected', () {
      final m = started();
      m.setConnected(false);
      m.tick(t0.add(const Duration(seconds: 5)));
      expect(m.state.phase, RoutinePhase.cancelled);
      expect(m.state.cancelReason, CancelReason.inactivity);
      expect(m.state.paused, isFalse);
    });

    test('connection changes outside running are ignored', () {
      final m = RoutineMachine();
      m.setConnected(false);
      expect(m.state.paused, isFalse);
    });
  });

  group('after completion / cancel', () {
    test('cancelled state persists until a new start replaces it', () {
      final m = started();
      m.onJump(jumpAt(1000));
      m.cancel();
      m.tick(t0.add(const Duration(minutes: 5)));
      expect(m.state.phase, RoutinePhase.cancelled);
      expect(m.state.jumps.length, 2);

      final fresh = jumpAt(600000, flight: 777);
      expect(
        m.start(lastJump: fresh, now: fresh.landedAt, timeout: timeout),
        isTrue,
      );
      expect(m.state.phase, RoutinePhase.running);
      expect(m.state.jumps.single.flightMs, 777);
      expect(m.state.cancelReason, isNull);
    });

    test('a new routine can start after completion', () {
      final m = started();
      for (var i = 1; i < 10; i++) {
        m.onJump(jumpAt(i * 100));
      }
      final fresh = jumpAt(60000);
      expect(
        m.start(lastJump: fresh, now: fresh.landedAt, timeout: timeout),
        isTrue,
      );
      expect(m.state.jumps.length, 1);
    });

    test(
      'cancelled with zero jumps is not possible; idle is not exportable',
      () {
        expect(RoutineState.idle.exportable, isFalse);
      },
    );
  });

  test('missed event on any jump is surfaced on the routine', () {
    final m = started();
    m.onJump(jumpAt(1000, missed: true));
    expect(m.state.hasMissedEvent, isTrue);
  });

  test('jump height uses h = g*t^2/8', () {
    final j = jumpAt(0, flight: 1000);
    expect(j.heightMeters, closeTo(9.81 / 8, 1e-9));
  });

  test('flight times over 2.5 s are flagged implausible, at/under are not', () {
    expect(jumpAt(0, flight: 2500).isImplausible, isFalse);
    expect(jumpAt(0, flight: 2501).isImplausible, isTrue);
    expect(jumpAt(0, flight: 1000).isImplausible, isFalse);
  });

  group('sensor corrections', () {
    test('replaceJump updates values by serial, also after completion', () {
      final m = started(first: jumpAt(0, serial: 1));
      m.onJump(jumpAt(1500, serial: 2, flight: 1100));
      m.replaceJump(jumpAt(1500, serial: 2, flight: 1050));
      expect(m.state.jumps.map((j) => j.flightMs), [1000, 1050]);

      m.cancel();
      m.replaceJump(jumpAt(0, serial: 1, flight: 990));
      expect(m.state.jumps.first.flightMs, 990);
      m.replaceJump(jumpAt(0, serial: 99)); // unknown: ignored
      expect(m.state.jumps, hasLength(2));
    });

    test('removeJump drops a retracted jump and moves the deadline back', () {
      final m = started(first: jumpAt(0, serial: 1));
      m.onJump(jumpAt(1500, serial: 2));
      m.removeJump(2);
      expect(m.state.jumps.map((j) => j.serial), [1]);
      expect(m.deadline, t0.add(timeout));
    });

    test('removeJump never removes the first jump or touches a finished '
        'routine', () {
      final m = started(first: jumpAt(0, serial: 1));
      m.removeJump(1);
      expect(m.state.jumps, hasLength(1));
      m.onJump(jumpAt(1500, serial: 2));
      m.cancel();
      m.removeJump(2);
      expect(m.state.jumps, hasLength(2));
    });
  });
}
