/// Device health the sensor publishes about once per second (Health
/// characteristic, docs/PROTOCOL.md "Health layout").
class SensorHealth {
  const SensorHealth({
    required this.pllLocked,
    required this.pllFrequencyHz,
    this.uptimeSeconds,
  });

  /// Both fields are null when this source has no PLL (demo mode).
  final bool? pllLocked;
  final double? pllFrequencyHz;

  /// Whole seconds since boot; null for older six-byte health payloads.
  final int? uptimeSeconds;
}
