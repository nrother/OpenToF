enum ChartEventType { connected, disconnected }

/// A sensor event shown as a marker on the jump chart's time axis.
class ChartEvent {
  const ChartEvent({required this.at, required this.type});

  final DateTime at;
  final ChartEventType type;
}
