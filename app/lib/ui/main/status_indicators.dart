import 'package:flutter/material.dart';

import '../../data/sensor/sensor.dart';
import '../../l10n/app_localizations.dart';

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({
    super.key,
    required this.connection,
    required this.paired,
  });

  final SensorConnectionState connection;
  final bool paired;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (String text, IconData icon, Color color) = !paired
        ? (l.connectionNotPaired, Icons.bluetooth_disabled, scheme.outline)
        : switch (connection) {
            SensorConnectionState.connected => (
              l.connectionConnected,
              Icons.bluetooth_connected,
              Colors.green.shade600,
            ),
            SensorConnectionState.connecting => (
              l.connectionConnecting,
              Icons.bluetooth_searching,
              scheme.tertiary,
            ),
            SensorConnectionState.disconnected => (
              l.connectionDisconnected,
              Icons.bluetooth_disabled,
              scheme.error,
            ),
          };
    return Tooltip(
      message: text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({super.key, required this.level});

  final int? level;

  static IconData iconFor(int? level) {
    if (level == null) return Icons.battery_unknown;
    if (level >= 90) return Icons.battery_full;
    if (level >= 75) return Icons.battery_6_bar;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 45) return Icons.battery_4_bar;
    if (level >= 30) return Icons.battery_3_bar;
    if (level >= 15) return Icons.battery_2_bar;
    if (level >= 5) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final low = level != null && level! <= 15;
    return Tooltip(
      message: level == null ? l.batteryUnknown : l.batteryTooltip(level!),
      child: Icon(iconFor(level), color: low ? scheme.error : scheme.onSurface),
    );
  }
}
