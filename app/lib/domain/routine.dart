import 'jump.dart';

enum RoutinePhase { idle, running, complete, cancelled }

enum CancelReason { user, inactivity }

class RoutineState {
  const RoutineState({
    this.phase = RoutinePhase.idle,
    this.jumps = const [],
    this.paused = false,
    this.cancelReason,
    this.targetJumps = RoutineMachine.defaultJumpsPerRoutine,
  });

  static const idle = RoutineState();

  final RoutinePhase phase;
  final List<Jump> jumps;

  /// True while running but the sensor connection is lost.
  final bool paused;
  final CancelReason? cancelReason;

  /// Jump count this routine ends at (fixed when it was started).
  final int targetJumps;

  int get totalFlightMs => jumps.fold(0, (sum, j) => sum + j.flightMs);
  double get totalFlightSeconds => totalFlightMs / 1000.0;
  bool get hasMissedEvent => jumps.any((j) => j.missedEvent);

  /// Complete or cancelled routine with at least one jump can be exported.
  bool get exportable =>
      (phase == RoutinePhase.complete || phase == RoutinePhase.cancelled) &&
      jumps.isNotEmpty;

  RoutineState copyWith({
    RoutinePhase? phase,
    List<Jump>? jumps,
    bool? paused,
    CancelReason? cancelReason,
  }) => RoutineState(
    phase: phase ?? this.phase,
    jumps: jumps ?? this.jumps,
    paused: paused ?? this.paused,
    cancelReason: cancelReason ?? this.cancelReason,
    targetJumps: targetJumps,
  );
}

/// Pure routine state machine. Time is always passed in, never read from a
/// clock, so it is fully deterministic; the owner drives [tick] from a timer.
///
/// Rules (see docs/DECISIONS.md):
/// - Start needs a last jump that landed within the inactivity timeout; that
///   jump becomes #1 and the inactivity deadline runs from its landing.
/// - Every new jump resets the deadline; passing it cancels the routine.
/// - A disconnect only sets `paused`; the deadline keeps running.
/// - Complete/cancelled state stays until the next successful [start].
/// - The jump count is chosen at [start]; a routine of 1 completes right away.
class RoutineMachine {
  static const defaultJumpsPerRoutine = 10;

  RoutineState _state = RoutineState.idle;
  Duration _timeout = Duration.zero;
  DateTime? _deadline;

  RoutineState get state => _state;

  /// When the running routine will be cancelled for inactivity, or null.
  DateTime? get deadline => _deadline;

  static bool canStart({
    required Jump? lastJump,
    required DateTime now,
    required Duration timeout,
  }) => lastJump != null && now.difference(lastJump.landedAt) <= timeout;

  /// Returns true if the routine was started.
  bool start({
    required Jump? lastJump,
    required DateTime now,
    required Duration timeout,
    int jumpsPerRoutine = defaultJumpsPerRoutine,
  }) {
    if (_state.phase == RoutinePhase.running) return false;
    if (!canStart(lastJump: lastJump, now: now, timeout: timeout)) return false;
    _timeout = timeout;
    _deadline = lastJump!.landedAt.add(timeout);
    final complete = jumpsPerRoutine <= 1;
    if (complete) _deadline = null;
    _state = RoutineState(
      phase: complete ? RoutinePhase.complete : RoutinePhase.running,
      jumps: [lastJump],
      targetJumps: jumpsPerRoutine,
    );
    return true;
  }

  /// Feed every newly detected jump; ignored unless running.
  void onJump(Jump jump) {
    if (_state.phase != RoutinePhase.running) return;
    final jumps = [..._state.jumps, jump];
    if (jumps.length >= _state.targetJumps) {
      _deadline = null;
      _state = RoutineState(
        phase: RoutinePhase.complete,
        jumps: jumps,
        targetJumps: _state.targetJumps,
      );
    } else {
      _deadline = jump.landedAt.add(_timeout);
      _state = _state.copyWith(jumps: jumps);
    }
  }

  /// Checks the inactivity deadline. Cancels the routine if it has passed.
  void tick(DateTime now) {
    final d = _deadline;
    if (_state.phase != RoutinePhase.running || d == null) return;
    if (!now.isBefore(d)) _cancel(CancelReason.inactivity);
  }

  void cancel() {
    if (_state.phase == RoutinePhase.running) _cancel(CancelReason.user);
  }

  void setConnected(bool connected) {
    if (_state.phase != RoutinePhase.running) return;
    _state = _state.copyWith(paused: !connected);
  }

  void _cancel(CancelReason reason) {
    _deadline = null;
    _state = RoutineState(
      phase: RoutinePhase.cancelled,
      jumps: _state.jumps,
      cancelReason: reason,
      targetJumps: _state.targetJumps,
    );
  }
}
