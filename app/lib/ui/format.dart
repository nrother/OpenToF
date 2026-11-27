import 'package:flutter/material.dart';
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

/// Sample rate, e.g. "416.125 Hz" ("416,125 Hz" in German).
String formatHertz(BuildContext c, double hz) =>
    AppLocalizations.of(c).hertz(NumberFormat('0.000', _locale(c)).format(hz));

/// Sensor uptime: "45 s" below a minute, otherwise like [formatRemaining].
String formatUptime(AppLocalizations l, int seconds) => seconds < 60
    ? l.seconds('$seconds')
    : formatRemaining(l, Duration(seconds: seconds));

String formatRemaining(AppLocalizations l, Duration d) {
  final totalMinutes = d.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0
      ? l.durationHoursMinutes(hours, minutes)
      : l.durationMinutes(minutes);
}

/// Signed flight-time change in ms, e.g. "+12", "−8" (true minus sign), "0".
String formatDeltaMs(int ms) => switch (ms) {
  > 0 => '+$ms',
  < 0 => '−${-ms}',
  _ => '0',
};

/// Colour of a flight-time change: blue = longer, red = shorter, null = no
/// change. Blue/red rather than green/red so colour-blind users can tell
/// them apart.
Color? deltaColor(BuildContext c, int ms) {
  if (ms == 0) return null;
  final dark = Theme.of(c).brightness == Brightness.dark;
  return switch ((ms > 0, dark)) {
    (true, false) => const Color(0xFF1565C0), // blue 800
    (true, true) => const Color(0xFF64B5F6), // blue 300
    (false, false) => const Color(0xFFC62828), // red 800
    (false, true) => const Color(0xFFE57373), // red 300
  };
}
