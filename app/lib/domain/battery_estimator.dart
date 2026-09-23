class BatteryReading {
  const BatteryReading(this.at, this.level);
  final DateTime at;
  final int level;
}

/// Phone-side battery time-remaining estimate: least-squares slope over recent
/// readings, extrapolated to 0 %. Returns null when there is not enough data
/// or the level is not dropping (e.g. charging or flat).
class BatteryEstimator {
  BatteryEstimator({
    this.maxReadings = 200,
    this.minSpan = const Duration(minutes: 5),
    this.minDrop = 1,
  });

  /// Oldest readings are discarded beyond this many.
  final int maxReadings;

  /// Minimum time between first and last reading before estimating.
  final Duration minSpan;

  /// Minimum total level drop (percentage points) before estimating.
  final int minDrop;

  final List<BatteryReading> _readings = [];

  List<BatteryReading> get readings => List.unmodifiable(_readings);

  /// Records a reading. A rising level (charge / battery swap) clears older
  /// history so it does not skew the drain rate.
  void add(DateTime at, int level) {
    if (_readings.isNotEmpty && level > _readings.last.level) {
      _readings.clear();
    }
    _readings.add(BatteryReading(at, level));
    if (_readings.length > maxReadings) _readings.removeAt(0);
  }

  void clear() => _readings.clear();

  Duration? remaining() {
    if (_readings.length < 2) return null;
    final first = _readings.first;
    final last = _readings.last;
    if (last.at.difference(first.at) < minSpan) return null;
    if (first.level - last.level < minDrop) return null;

    // Least squares of level (%) against time (hours since first reading).
    final n = _readings.length;
    double sx = 0, sy = 0, sxx = 0, sxy = 0;
    for (final r in _readings) {
      final x = r.at.difference(first.at).inMilliseconds / 3600000.0;
      final y = r.level.toDouble();
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
    }
    final denom = n * sxx - sx * sx;
    if (denom == 0) return null;
    final slope = (n * sxy - sx * sy) / denom; // % per hour, negative = drain
    if (slope >= 0) return null;
    final hours = last.level / -slope;
    return Duration(milliseconds: (hours * 3600000).round());
  }
}
