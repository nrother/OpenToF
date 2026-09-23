import 'jump.dart';
import 'sensor_events.dart';

/// Combines takeoff and landing events into complete [Jump]s and detects
/// missed notifications via the per-characteristic sequence counters.
///
/// Contact time is the one *before* the jump, so the takeoff event of jump N
/// arrives before its landing event: the latest takeoff's contact time is
/// attached to the next landing.
///
/// Sequence handling (per counter): first event sets the baseline; `seq > last+1`
/// is a gap (missed notifications); `seq == last` is a duplicate and is ignored;
/// `seq < last` is treated as a device counter reset (no gap, new baseline).
class JumpAssembler {
  int? _lastLandingSeq;
  int? _lastTakeoffSeq;
  int? _pendingContactMs;
  bool _pendingMissed = false;

  void onTakeoff(TakeoffEvent e) {
    final last = _lastTakeoffSeq;
    if (last != null) {
      if (e.sequence == last) return; // duplicate
      if (e.sequence > last + 1) _pendingMissed = true;
    }
    _lastTakeoffSeq = e.sequence;
    _pendingContactMs = e.contactMs;
  }

  /// Returns the completed jump, or null if the event was a duplicate.
  Jump? onLanding(LandingEvent e) {
    final last = _lastLandingSeq;
    if (last != null) {
      if (e.sequence == last) return null; // duplicate
      if (e.sequence > last + 1) _pendingMissed = true;
    }
    _lastLandingSeq = e.sequence;

    final jump = Jump(
      flightMs: e.flightMs,
      contactMs: _pendingContactMs,
      landedAt: e.receivedAt,
      missedEvent: _pendingMissed,
    );
    _pendingContactMs = null;
    _pendingMissed = false;
    return jump;
  }

  /// Forget all state (e.g. when switching to a different sensor).
  void reset() {
    _lastLandingSeq = null;
    _lastTakeoffSeq = null;
    _pendingContactMs = null;
    _pendingMissed = false;
  }
}
