/// Raw events emitted by a sensor (protocol 1, see docs/DECISIONS.md).
enum JumpEventType { takeoff, landing }

/// `finalized` = the algorithm's refined estimate; `retracted` withdraws an
/// earlier provisional event of the same type and jump.
enum JumpEventStage { provisional, finalized, retracted }

/// One takeoff or landing report. Times are on the device clock (ms since the
/// sensor booted, wraps at 2^32); `receivedAt` is the phone-side receive time.
class JumpEvent {
  const JumpEvent({
    required this.jumpId,
    required this.type,
    required this.stage,
    required this.deviceTimeMs,
    required this.receivedAt,
    this.confidence,
    this.reasons = 0,
    this.extras = const [],
  });

  /// Sensor-assigned jump number (uint16, wraps); takeoff and landing of one
  /// jump share it.
  final int jumpId;
  final JumpEventType type;
  final JumpEventStage stage;

  /// When the event physically happened (0 for a retraction).
  final int deviceTimeMs;
  final DateTime receivedAt;

  /// 0-100, or null if the algorithm gives none.
  final int? confidence;

  /// Reason bitmask for reduced confidence; bit names come from
  /// [AlgorithmMetadata.reasons].
  final int reasons;

  /// Raw custom-field bytes, decoded with [AlgorithmMetadata.decode].
  final List<int> extras;

  bool get isLanding => type == JumpEventType.landing;
}

/// The sensor's Info characteristic.
class SensorInfo {
  const SensorInfo({
    required this.protocol,
    required this.bootCount,
    required this.deviceTimeMs,
  });

  final int protocol;

  /// Increases on every sensor start: a change means the device clock and the
  /// jump ids restarted.
  final int bootCount;
  final int deviceTimeMs;
}
