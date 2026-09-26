import 'dart:math' as math;

import 'algorithm_metadata.dart';
import 'jump.dart';
import 'sensor_events.dart';

/// What a sensor event changed about the list of jumps.
sealed class JumpUpdate {
  const JumpUpdate();
}

/// A new jump: its first landing (provisional or final) arrived.
class JumpAdded extends JumpUpdate {
  const JumpAdded(this.jump);
  final Jump jump;
}

/// A known jump got new values (a final estimate replaced a provisional one).
class JumpChanged extends JumpUpdate {
  const JumpChanged(this.jump);
  final Jump jump;
}

/// A known jump's landing was retracted: the jump did not happen (yet).
class JumpRemoved extends JumpUpdate {
  const JumpRemoved(this.serial);
  final int serial;
}

class _Record {
  _Record({required this.hadBaseline, required this.missed});

  /// An earlier jump id was seen before this one (not the first after a
  /// (re)start), so a missing takeoff/landing here means a lost event.
  final bool hadBaseline;
  final bool missed;
  JumpEvent? takeoff;
  JumpEvent? landing;

  /// Set once the jump was handed out ([JumpAdded]).
  int? serial;
  DateTime? landedAt;
}

/// Combines takeoff/landing events (protocol 1) into [Jump]s.
///
/// - A jump appears with its first landing, provided its takeoff is known.
///   Flight time = landing - takeoff of the same jump id; contact time =
///   takeoff - landing of the previous jump id (unknown if that is missing;
///   ids voided by a retracted takeoff are skipped).
/// - Final events replace provisional ones ([JumpChanged]); a retracted
///   landing removes the jump again ([JumpRemoved]), a retracted takeoff drops
///   the jump before it ever appears.
/// - Missed jumps: a gap in the jump ids, or the previous jump id that never
///   became a complete jump, flags the next jump. An id far behind the last
///   one is a sensor restart: new baseline, no warning. Call [reset] when the
///   sensor's boot counter changes.
class JumpAssembler {
  JumpAssembler({this.metadata = AlgorithmMetadata.none});

  /// Decodes confidence reasons and custom fields; may change at any time
  /// (read after connecting), later updates use the new one.
  AlgorithmMetadata metadata;

  static const _keep = 8;
  static const _timeMask = 0xFFFFFFFF;

  final Map<int, _Record> _records = {};

  /// Ids whose takeoff was retracted: that jump never happened, so the jump
  /// before it counts as the previous one.
  final List<int> _voided = [];
  int? _lastId;
  int _nextSerial = 1;

  JumpUpdate? onEvent(JumpEvent e) {
    final r = _records[e.jumpId] ?? _newRecord(e.jumpId);

    if (e.stage == JumpEventStage.retracted) {
      if (e.isLanding) {
        r.landing = null;
        final serial = r.serial;
        r.serial = null;
        r.landedAt = null;
        return serial == null ? null : JumpRemoved(serial);
      }
      r.takeoff = null;
      final serial = r.serial;
      _records.remove(e.jumpId);
      _voided.add(e.jumpId);
      if (_voided.length > _keep) _voided.removeAt(0);
      return serial == null ? null : JumpRemoved(serial);
    }

    final previous = e.isLanding ? r.landing : r.takeoff;
    if (previous != null &&
        previous.stage == JumpEventStage.finalized &&
        e.stage == JumpEventStage.provisional) {
      return null; // stale provisional after the final
    }
    if (e.isLanding) {
      r.landing = e;
    } else {
      r.takeoff = e;
    }

    if (r.serial != null) return JumpChanged(_build(e.jumpId, r));
    if (r.takeoff == null || r.landing == null) return null;
    r.serial = _nextSerial++;
    r.landedAt = r.landing!.receivedAt;
    return JumpAdded(_build(e.jumpId, r));
  }

  _Record _newRecord(int id) {
    final last = _lastId;
    var missed = false;
    if (last != null) {
      final diff = (id - last) & 0xFFFF;
      if (diff >= 0x8000) {
        _records.clear(); // far behind: the sensor restarted
        _voided.clear();
      } else {
        final prev = _previous(id);
        final prevIncomplete =
            prev != null && prev.serial == null && prev.hadBaseline;
        missed = diff > 1 || prevIncomplete;
      }
    }
    final r = _Record(hadBaseline: last != null, missed: missed);
    _records[id] = r;
    _lastId = id;
    while (_records.length > _keep) {
      _records.remove(_records.keys.first);
    }
    return r;
  }

  /// The record of the jump before [id], skipping voided ids.
  _Record? _previous(int id) {
    var prev = (id - 1) & 0xFFFF;
    while (_voided.contains(prev)) {
      prev = (prev - 1) & 0xFFFF;
    }
    return _records[prev];
  }

  Jump _build(int id, _Record r) {
    final takeoff = r.takeoff!;
    final landing = r.landing!;
    final prevLanding = _previous(id)?.landing;
    final confidences = [
      if (takeoff.confidence != null) takeoff.confidence!,
      if (landing.confidence != null) landing.confidence!,
    ];
    return Jump(
      serial: r.serial!,
      flightMs: (landing.deviceTimeMs - takeoff.deviceTimeMs) & _timeMask,
      contactMs: prevLanding == null
          ? null
          : (takeoff.deviceTimeMs - prevLanding.deviceTimeMs) & _timeMask,
      landedAt: r.landedAt!,
      missedEvent: r.missed,
      isFinal:
          takeoff.stage == JumpEventStage.finalized &&
          landing.stage == JumpEventStage.finalized,
      confidence: confidences.isEmpty ? null : confidences.reduce(math.min),
      reasons: metadata.reasonNames(takeoff.reasons | landing.reasons),
      fields: {...metadata.decode(takeoff), ...metadata.decode(landing)},
    );
  }

  /// Forget all jumps (e.g. the sensor restarted or a different sensor).
  void reset() {
    _records.clear();
    _voided.clear();
    _lastId = null;
  }
}
