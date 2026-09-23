/// Raw events emitted by a sensor. `receivedAt` is the phone-side receive time
/// (the device exposes no wall-clock time).
class LandingEvent {
  const LandingEvent({
    required this.flightMs,
    required this.sequence,
    required this.receivedAt,
  });

  /// Airborne duration that just ended.
  final int flightMs;
  final int sequence;
  final DateTime receivedAt;
}

class TakeoffEvent {
  const TakeoffEvent({
    required this.contactMs,
    required this.sequence,
    required this.receivedAt,
  });

  /// Bed contact time that just ended (previous landing -> this takeoff).
  final int contactMs;
  final int sequence;
  final DateTime receivedAt;
}
