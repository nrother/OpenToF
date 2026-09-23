import 'package:flutter/material.dart';

import '../../domain/routine.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';

/// Status banner + jump table (one row per target jump) + running total for a routine
/// (running, complete or cancelled).
class RoutinePanel extends StatelessWidget {
  const RoutinePanel({super.key, required this.routine});

  final RoutineState routine;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (String status, Color color) = switch (routine.phase) {
      RoutinePhase.running when routine.paused => (
        l.routinePaused,
        scheme.error,
      ),
      RoutinePhase.running => (
        l.routineRunning(routine.jumps.length, routine.targetJumps),
        scheme.primary,
      ),
      RoutinePhase.complete => (l.routineComplete, Colors.green.shade700),
      RoutinePhase.cancelled => (
        routine.cancelReason == CancelReason.inactivity
            ? l.routineCancelledInactivity
            : l.routineCancelledUser,
        scheme.error,
      ),
      RoutinePhase.idle => ('', scheme.onSurface),
    };

    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final mono = theme.textTheme.bodyLarge?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    TableRow row(List<Widget> cells, {Color? background}) => TableRow(
      decoration: background == null ? null : BoxDecoration(color: background),
      children: [
        for (final c in cells)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            child: c,
          ),
      ],
    );

    final rows = <TableRow>[
      row([
        Text(l.tableJump, style: headerStyle),
        Text(l.tableFlight, style: headerStyle, textAlign: TextAlign.end),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(l.tableHeight, style: headerStyle),
            const SizedBox(width: 4),
            const BetaTag(),
          ],
        ),
      ]),
      for (var i = 0; i < routine.targetJumps; i++)
        _jumpRow(context, i, row, mono, l),
      row([
        Text(l.tableTotal, style: mono?.copyWith(fontWeight: FontWeight.bold)),
        Text(
          l.seconds(formatSecondsValue(context, routine.totalFlightSeconds)),
          style: mono?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.end,
        ),
        const SizedBox.shrink(),
      ], background: scheme.surfaceContainerHighest),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l.routineTitle, style: theme.textTheme.titleMedium),
                const Spacer(),
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: rows,
            ),
          ],
        ),
      ),
    );
  }

  TableRow _jumpRow(
    BuildContext context,
    int index,
    TableRow Function(List<Widget>, {Color? background}) row,
    TextStyle? mono,
    AppLocalizations l,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final jump = index < routine.jumps.length ? routine.jumps[index] : null;
    final isNext =
        routine.phase == RoutinePhase.running && index == routine.jumps.length;
    final dim = mono?.copyWith(color: scheme.outline);

    return row(
      [
        Row(
          children: [
            Text('${index + 1}', style: mono),
            if (jump?.missedEvent ?? false)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Tooltip(
                  message: l.missedEventWarning,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: scheme.error,
                  ),
                ),
              ),
          ],
        ),
        Text(
          jump == null
              ? '–'
              : l.seconds(formatSecondsValue(context, jump.flightSeconds)),
          style: jump == null ? dim : mono,
          textAlign: TextAlign.end,
        ),
        Text(
          jump == null
              ? '–'
              : l.meters(formatMetersValue(context, jump.heightMeters)),
          style: jump == null ? dim : mono,
          textAlign: TextAlign.end,
        ),
      ],
      background: isNext
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : null,
    );
  }
}

/// Small "beta" badge for jump-height values.
class BetaTag extends StatelessWidget {
  const BetaTag({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l.betaTag,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}
