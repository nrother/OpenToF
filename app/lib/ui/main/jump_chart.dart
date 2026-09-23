import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/chart_event.dart';
import '../../domain/jump.dart';

/// Bar chart of flight times over a rolling, time-proportional window
/// ending at [now]. One bar per jump, positioned at its landing time.
class JumpChart extends StatelessWidget {
  const JumpChart({
    super.key,
    required this.jumps,
    required this.now,
    required this.window,
    required this.formatAxis,
    required this.startLabel,
    required this.midLabel,
    required this.nowLabel,
    this.events = const [],
    this.height = 180,
  });

  final List<Jump> jumps;
  final List<ChartEvent> events;
  final DateTime now;
  final Duration window;
  final String Function(double) formatAxis;
  final String startLabel;
  final String midLabel;
  final String nowLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: JumpChartPainter(
          jumps: jumps,
          now: now,
          window: window,
          barColor: scheme.primary,
          warnColor: scheme.error,
          gridColor: scheme.outlineVariant,
          textStyle:
              Theme.of(context).textTheme.labelSmall ?? const TextStyle(),
          textColor: scheme.onSurfaceVariant,
          formatAxis: formatAxis,
          startLabel: startLabel,
          midLabel: midLabel,
          nowLabel: nowLabel,
          events: events,
          connectedColor: connectedEventColor,
          disconnectedColor: scheme.error,
        ),
      ),
    );
  }
}

/// Marker color for a sensor-connected event (same green as the status indicator).
final Color connectedEventColor = Colors.green.shade600;

/// Icon drawn for an event marker.
IconData chartEventIcon(ChartEventType t) => t == ChartEventType.connected
    ? Icons.bluetooth_connected
    : Icons.bluetooth_disabled;

/// True if an event falls inside the window ending at [now].
bool eventInWindow(ChartEvent e, DateTime now, Duration window) =>
    !e.at.isBefore(now.subtract(window)) && !e.at.isAfter(now);

/// True if [jump] falls inside the window ending at [now].
bool jumpInWindow(Jump jump, DateTime now, Duration window) {
  final start = now.subtract(window);
  return !jump.landedAt.isBefore(start) && !jump.landedAt.isAfter(now);
}

/// Upper y-axis bound in seconds: at least 1 s, rounded up to 0.5 s steps.
double chartYMax(Iterable<Jump> visible) {
  final maxFlight = visible.fold<double>(
    0,
    (m, j) => math.max(m, j.flightSeconds),
  );
  return math.max(1.0, (maxFlight * 2).ceil() / 2);
}

class JumpChartPainter extends CustomPainter {
  JumpChartPainter({
    required this.jumps,
    required this.now,
    required this.window,
    required this.barColor,
    required this.warnColor,
    required this.gridColor,
    required this.textStyle,
    required this.textColor,
    required this.formatAxis,
    required this.startLabel,
    required this.midLabel,
    required this.nowLabel,
    this.events = const [],
    this.connectedColor = Colors.green,
    this.disconnectedColor = Colors.red,
  });

  final List<Jump> jumps;
  final List<ChartEvent> events;
  final Color connectedColor;
  final Color disconnectedColor;
  final DateTime now;
  final Duration window;
  final Color barColor;
  final Color warnColor;
  final Color gridColor;
  final TextStyle textStyle;
  final Color textColor;
  final String Function(double) formatAxis;
  final String startLabel;
  final String midLabel;
  final String nowLabel;

  static const _left = 32.0;
  static const _right = 8.0;
  static const _top = 18.0; // room for the event icons above the plot
  static const _bottom = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    final style = textStyle.copyWith(color: textColor);
    final visible = jumps.where((j) => jumpInWindow(j, now, window)).toList();
    final yMax = chartYMax(visible);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final v in [0.0, yMax / 2, yMax]) {
      final y = plot.bottom - (v / yMax) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        formatAxis(v),
        style,
        Offset(_left - 4, y),
        alignRight: true,
        centerY: true,
      );
    }

    final windowMs = window.inMilliseconds;
    final start = now.subtract(window);
    final barWidth = (plot.width * 1.2 / window.inSeconds).clamp(1.5, 10.0);
    for (final j in visible) {
      final frac = j.landedAt.difference(start).inMilliseconds / windowMs;
      final x = plot.left + frac * plot.width;
      final h = (j.flightSeconds / yMax).clamp(0.0, 1.0) * plot.height;
      final paint = Paint()..color = j.missedEvent ? warnColor : barColor;
      canvas.drawRect(
        Rect.fromLTWH(x - barWidth / 2, plot.bottom - h, barWidth, h),
        paint,
      );
    }

    _paintEvents(canvas, plot, start);

    final labelY = plot.bottom + 4;
    _text(canvas, startLabel, style, Offset(plot.left, labelY));
    _text(
      canvas,
      midLabel,
      style,
      Offset(plot.center.dx, labelY),
      center: true,
    );
    _text(
      canvas,
      nowLabel,
      style,
      Offset(plot.right, labelY),
      alignRight: true,
    );
  }

  /// Sensor connect/disconnect: a vertical line through the plot with an icon
  /// above it, drawn over the bars.
  void _paintEvents(Canvas canvas, Rect plot, DateTime start) {
    final windowMs = window.inMilliseconds;
    for (final e in events) {
      if (!eventInWindow(e, now, window)) continue;
      final frac = e.at.difference(start).inMilliseconds / windowMs;
      final x = plot.left + frac * plot.width;
      final color = e.type == ChartEventType.connected
          ? connectedColor
          : disconnectedColor;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = color
          ..strokeWidth = 1.5,
      );
      final icon = chartEventIcon(e.type);
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, plot.top - tp.height - 1));
    }
  }

  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    bool alignRight = false,
    bool center = false,
    bool centerY = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (alignRight) dx -= tp.width;
    if (center) dx -= tp.width / 2;
    final dy = centerY ? at.dy - tp.height / 2 : at.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(JumpChartPainter old) =>
      old.now != now ||
      old.window != window ||
      old.jumps != jumps ||
      old.events != events ||
      old.barColor != barColor ||
      old.startLabel != startLabel ||
      old.nowLabel != nowLabel;
}
