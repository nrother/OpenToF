import 'package:flutter/material.dart';

import '../../domain/jump.dart';
import '../../domain/routine.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import 'jump_details.dart';

/// Status banner + jump table (one row per target jump) + running total for a routine
/// (running, complete or cancelled). Optional columns: time on bed, total
/// jump time and the sensor's extra values ([details]); with any of those the
/// seconds unit moves into the headers so the table still fits a phone, and
/// with more than [_maxFittingColumns] columns the table scrolls sideways.
class RoutinePanel extends StatelessWidget {
  const RoutinePanel({
    super.key,
    required this.routine,
    this.showContact = false,
    this.showTotal = false,
    this.details = const [],
    this.onJumpTap,
  });

  final RoutineState routine;
  final bool showContact;
  final bool showTotal;
  final List<JumpDetail> details;

  /// Tapping a filled row calls this (e.g. to show the jump's details).
  final void Function(Jump)? onJumpTap;

  static const _maxFittingColumns = 5;

  bool get _compact => showContact || showTotal || details.isNotEmpty;

  int get _columns =>
      3 + (showContact ? 1 : 0) + (showTotal ? 1 : 0) + details.length;

  /// Seconds cell text: with unit normally, bare number in compact mode.
  String _secs(BuildContext context, AppLocalizations l, double? v) {
    if (v == null) return '–';
    final n = formatSecondsValue(context, v);
    return _compact ? n : l.seconds(n);
  }

  String _secsHeader(AppLocalizations l, String label) =>
      _compact ? l.columnSeconds(label) : label;

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

    TableRow row(
      List<Widget> cells, {
      Color? background,
      VoidCallback? onTap,
    }) => TableRow(
      decoration: background == null ? null : BoxDecoration(color: background),
      children: [
        for (final c in cells)
          _tappable(
            onTap,
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: 5,
                horizontal: _compact ? 4 : 8,
              ),
              child: c,
            ),
          ),
      ],
    );

    final rows = <TableRow>[
      row([
        Text(l.tableJump, style: headerStyle),
        Text(
          _secsHeader(l, l.tableFlight),
          style: headerStyle,
          textAlign: TextAlign.end,
        ),
        if (showContact)
          Text(
            _secsHeader(l, l.contactLabel),
            style: headerStyle,
            textAlign: TextAlign.end,
          ),
        if (showTotal)
          Text(
            _secsHeader(l, l.totalTimeLabel),
            style: headerStyle,
            textAlign: TextAlign.end,
          ),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(l.tableHeight, style: headerStyle),
            const BetaTag(),
          ],
        ),
        for (final d in details)
          Text(d.header, style: headerStyle, textAlign: TextAlign.end),
      ]),
      for (var i = 0; i < routine.targetJumps; i++)
        _jumpRow(context, i, row, mono, l),
      row([
        Text(l.tableTotal, style: mono?.copyWith(fontWeight: FontWeight.bold)),
        Text(
          _secs(context, l, routine.totalFlightSeconds),
          style: mono?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.end,
        ),
        if (showContact) const SizedBox.shrink(),
        if (showTotal) const SizedBox.shrink(),
        const SizedBox.shrink(),
        for (final _ in details) const SizedBox.shrink(),
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
            if (_columns <= _maxFittingColumns)
              Table(
                columnWidths: {
                  0: const FlexColumnWidth(1.2),
                  for (var c = 1; c < _columns; c++)
                    c: const FlexColumnWidth(2),
                },
                children: rows,
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: rows,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _tappable(VoidCallback? onTap, Widget child) =>
      onTap == null ? child : TableRowInkWell(onTap: onTap, child: child);

  TableRow _jumpRow(
    BuildContext context,
    int index,
    TableRow Function(List<Widget>, {Color? background, VoidCallback? onTap})
    row,
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
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
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
            if (jump != null && jump.isUncertain)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Tooltip(
                  message: [
                    l.uncertainJumpWarning,
                    if (jump.confidence != null)
                      l.confidenceValue(jump.confidence!),
                    ...jump.reasons,
                  ].join('\n'),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: scheme.tertiary,
                  ),
                ),
              ),
          ],
        ),
        Text(
          _secs(context, l, jump?.flightSeconds),
          style: jump == null ? dim : mono,
          textAlign: TextAlign.end,
        ),
        if (showContact) _optional(context, l, jump?.contactSeconds),
        if (showTotal) _optional(context, l, jump?.totalSeconds),
        Text(
          jump == null
              ? '–'
              : l.meters(formatMetersValue(context, jump.heightMeters)),
          style: jump == null ? dim : mono,
          textAlign: TextAlign.end,
        ),
        for (final d in details)
          Text(
            (jump == null ? null : d.value(jump)) ?? '–',
            style: jump == null || d.value(jump) == null ? dim : mono,
            textAlign: TextAlign.end,
          ),
      ],
      background: isNext
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      onTap: jump == null || onJumpTap == null ? null : () => onJumpTap!(jump),
    );
  }

  Widget _optional(BuildContext context, AppLocalizations l, double? seconds) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: seconds == null ? theme.colorScheme.outline : null,
    );
    return Text(
      _secs(context, l, seconds),
      style: style,
      textAlign: TextAlign.end,
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
