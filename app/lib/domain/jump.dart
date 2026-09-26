/// Standard gravity used for the (beta) jump-height estimate.
const double gravity = 9.81;

/// Flight times at or above this are almost certainly a sensor glitch, not a
/// real jump (no human is airborne this long on a trampoline). See
/// docs/DECISIONS.md.
const double maxPlausibleFlightSeconds = 2.5;

/// Jumps with a confidence below this are marked as uncertain in the UI
/// (engineering choice, see docs/DECISIONS.md).
const int lowConfidenceThreshold = 50;

class Jump {
  const Jump({
    required this.flightMs,
    required this.landedAt,
    this.serial = 0,
    this.contactMs,
    this.missedEvent = false,
    this.isFinal = true,
    this.confidence,
    this.reasons = const [],
    this.fields = const {},
  });

  /// App-side identity of this jump, unique within a session. Stays the same
  /// when provisional values are replaced by final ones.
  final int serial;

  /// Airborne duration in milliseconds.
  final int flightMs;

  /// Bed contact time *before* this jump's takeoff, or null if unknown
  /// (no previous landing was received).
  final int? contactMs;

  /// Phone-side time the (first) landing event was received.
  final DateTime landedAt;

  /// True if a jump was missed (jump id gap) right before this one.
  final bool missedEvent;

  /// False while the takeoff or landing is still the sensor's provisional
  /// estimate.
  final bool isFinal;

  /// Lower of the takeoff and landing confidence (0-100), or null if the
  /// sensor's algorithm gives none.
  final int? confidence;

  /// Names of the reasons for reduced confidence (takeoff and landing).
  final List<String> reasons;

  /// Custom algorithm fields (id -> value) from the takeoff and landing.
  final Map<String, num> fields;

  double get flightSeconds => flightMs / 1000.0;

  double? get contactSeconds => contactMs == null ? null : contactMs! / 1000.0;

  /// Whole jump cycle: bed contact before the takeoff + flight, or null if
  /// the contact time is unknown.
  int? get totalMs => contactMs == null ? null : contactMs! + flightMs;

  double? get totalSeconds => totalMs == null ? null : totalMs! / 1000.0;

  /// Beta estimate: h = g·t²/8 (t = total flight time), in meters.
  double get heightMeters => gravity * flightSeconds * flightSeconds / 8.0;

  /// True if the flight time is implausibly long (likely a sensor glitch).
  bool get isImplausible => flightSeconds > maxPlausibleFlightSeconds;

  /// True if the sensor flagged this jump as possibly wrong.
  bool get isUncertain =>
      reasons.isNotEmpty ||
      (confidence != null && confidence! < lowConfidenceThreshold);
}
