/// Standard gravity used for the (beta) jump-height estimate.
const double gravity = 9.81;

class Jump {
  const Jump({
    required this.flightMs,
    required this.landedAt,
    this.contactMs,
    this.missedEvent = false,
  });

  /// Airborne duration in milliseconds.
  final int flightMs;

  /// Bed contact time *before* this jump's takeoff, or null if unknown
  /// (no takeoff event was received for it).
  final int? contactMs;

  /// Phone-side time the landing event was received.
  final DateTime landedAt;

  /// True if a BLE notification was missed (sequence gap) around this jump.
  final bool missedEvent;

  double get flightSeconds => flightMs / 1000.0;

  double? get contactSeconds => contactMs == null ? null : contactMs! / 1000.0;

  /// Beta estimate: h = g·t²/8 (t = total flight time), in meters.
  double get heightMeters => gravity * flightSeconds * flightSeconds / 8.0;
}
