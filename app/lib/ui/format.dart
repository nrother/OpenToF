import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

String _locale(BuildContext c) => Localizations.localeOf(c).toString();

/// Flight time / contact time in seconds, e.g. "1.234" ("1,234" in German).
String formatSecondsValue(BuildContext c, double seconds) =>
    NumberFormat('0.000', _locale(c)).format(seconds);

String formatMetersValue(BuildContext c, double meters) =>
    NumberFormat('0.00', _locale(c)).format(meters);

String formatAxisValue(BuildContext c, double v) =>
    NumberFormat('0.#', _locale(c)).format(v);

String formatRemaining(AppLocalizations l, Duration d) {
  final totalMinutes = d.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0
      ? l.durationHoursMinutes(hours, minutes)
      : l.durationMinutes(minutes);
}
