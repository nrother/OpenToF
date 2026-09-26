import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import '../../domain/chart_event.dart';
import '../../domain/jump.dart';
import '../../domain/routine.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../brand_logo.dart';
import '../format.dart';
import '../settings/settings_screen.dart';
import 'jump_chart.dart';
import 'jump_details.dart';
import 'routine_panel.dart';
import 'status_indicators.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final connection = ref.watch(sessionProvider.select((s) => s.connection));
    final battery = ref.watch(sessionProvider.select((s) => s.batteryLevel));
    final routine = ref.watch(sessionProvider.select((s) => s.routine));
    final hasHistory = ref.watch(
      sessionProvider.select((s) => s.history.isNotEmpty),
    );
    final paired = ref.watch(settingsProvider.select((s) => s.isPaired));
    final showContact = ref.watch(
      settingsProvider.select((s) => s.showContactTime),
    );
    final showTotal = ref.watch(
      settingsProvider.select((s) => s.showTotalTime),
    );
    final settings = ref.watch(settingsProvider);
    final detailsOn = settings.showJumpDetails;
    final algorithm = ref.watch(sessionProvider.select((s) => s.algorithm));
    final details = visibleDetails(context, l, algorithm, settings);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(height: 34),
            const SizedBox(width: 12),
            Flexible(child: Text(l.appTitle, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (routine.exportable || hasHistory)
            IconButton(
              icon: const Icon(Icons.ios_share, size: 20),
              tooltip: l.exportTooltip,
              onPressed: () => _chooseExport(context, ref),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ConnectionIndicator(connection: connection, paired: paired),
          ),
          BatteryIndicator(level: battery),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l.settings,
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!paired) ...[
              _PairSensorCard(onTap: () => _openSettings(context)),
              const SizedBox(height: 12),
            ],
            const _LastJumpCard(),
            const SizedBox(height: 12),
            const _RoutineActions(),
            if (routine.phase != RoutinePhase.idle) ...[
              const SizedBox(height: 12),
              RoutinePanel(
                routine: routine,
                showContact: showContact,
                showTotal: showTotal,
                details: details,
                onJumpTap: detailsOn
                    ? (j) => showJumpDetailsSheet(context, j, algorithm)
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            const _ChartCard(),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  /// Lets the user export either the recorded routine or all jumps of the
  /// last 30 s / 1 min / 5 min (the chart's window options).
  Future<void> _chooseExport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final session = ref.read(sessionProvider);
    final now = ref.read(clockProvider)();
    final routine = session.routine;
    List<Jump> lastSeconds(int seconds) {
      final from = now.subtract(Duration(seconds: seconds));
      return [
        for (final j in session.history)
          if (j.landedAt.isAfter(from)) j,
      ];
    }

    final windowLabels = {30: l.window30s, 60: l.window1m, 300: l.window5m};
    final export = ref.read(exportServiceProvider);
    final action = await showModalBottomSheet<Future<void> Function()>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l.exportChooserTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.format_list_numbered),
              title: Text(l.exportRoutine),
              subtitle: Text(l.jumpCount(routine.jumps.length)),
              enabled: routine.exportable,
              onTap: () =>
                  Navigator.pop(context, () => export.shareRoutine(routine)),
            ),
            for (final seconds in AppSettings.windowOptionsSeconds)
              Builder(
                builder: (context) {
                  final jumps = lastSeconds(seconds);
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(l.exportLastWindow(windowLabels[seconds]!)),
                    subtitle: Text(l.jumpCount(jumps.length)),
                    enabled: jumps.isNotEmpty,
                    onTap: () =>
                        Navigator.pop(context, () => export.shareJumps(jumps)),
                  );
                },
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  }
}

/// Shown while no sensor is paired: points to the pairing in Settings.
class _PairSensorCard extends StatelessWidget {
  const _PairSensorCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.bluetooth_searching),
      title: Text(AppLocalizations.of(context).pairSensorHint),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _LastJumpCard extends ConsumerWidget {
  const _LastJumpCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final Jump? jump = ref.watch(sessionProvider.select((s) => s.lastJump));
    final showContact = ref.watch(
      settingsProvider.select((s) => s.showContactTime),
    );
    final showTotal = ref.watch(
      settingsProvider.select((s) => s.showTotalTime),
    );
    String secondsOrDash(double? v) =>
        v == null ? '–' : l.seconds(formatSecondsValue(context, v));
    final times = [
      if (showContact && jump != null)
        '${l.contactLabel}: ${secondsOrDash(jump.contactSeconds)}',
      if (showTotal && jump != null)
        '${l.totalTimeLabel}: ${secondsOrDash(jump.totalSeconds)}',
    ];
    final settings = ref.watch(settingsProvider);
    final algorithm = ref.watch(sessionProvider.select((s) => s.algorithm));
    final detailLine = jump == null
        ? ''
        : [
            for (final d in visibleDetails(context, l, algorithm, settings))
              d.describe(jump),
          ].nonNulls.join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: settings.showJumpDetails && jump != null
            ? () => showJumpDetailsSheet(context, jump, algorithm)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Text(l.lastJump, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  jump == null
                      ? l.noJumpYet
                      : l.seconds(
                          formatSecondsValue(context, jump.flightSeconds),
                        ),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (times.isNotEmpty)
                Text(
                  times.join('   '),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (jump != null) ...[
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '${l.heightLabel}: ${l.meters(formatMetersValue(context, jump.heightMeters))}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const BetaTag(),
                  ],
                ),
              ],
              if (detailLine.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    detailLine,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineActions extends ConsumerWidget {
  const _RoutineActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final running = ref.watch(
      sessionProvider.select((s) => s.routine.phase == RoutinePhase.running),
    );
    final lastJump = ref.watch(sessionProvider.select((s) => s.lastJump));
    final timeout = ref.watch(
      settingsProvider.select((s) => s.inactivityTimeout),
    );
    final now = ref.watch(nowProvider).value ?? ref.read(clockProvider)();
    final controller = ref.read(sessionProvider.notifier);

    if (running) {
      return SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: controller.cancelRoutine,
          icon: const Icon(Icons.stop),
          label: Text(l.cancelRoutine),
        ),
      );
    }

    final canStart = RoutineMachine.canStart(
      lastJump: lastJump,
      now: now,
      timeout: timeout,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: canStart ? controller.startRoutine : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(l.startRoutine),
          ),
        ),
        if (!canStart)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.startDisabledHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChartCard extends ConsumerWidget {
  const _ChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final history = ref.watch(sessionProvider.select((s) => s.history));
    final events = ref.watch(sessionProvider.select((s) => s.events));
    final frozenAt = ref.watch(sessionProvider.select((s) => s.chartFrozenAt));
    final session = ref.read(sessionProvider.notifier);
    final window = ref.watch(settingsProvider.select((s) => s.window));
    final liveNow = ref.watch(nowProvider).value ?? ref.read(clockProvider)();
    final now = frozenAt ?? liveNow;
    final empty = !history.any((j) => jumpInWindow(j, now, window));
    final visibleTypes = {
      for (final e in events)
        if (eventInWindow(e, now, window)) e.type,
    };
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.chartTitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: frozenAt == null
                      ? session.pauseChart
                      : session.resumeChart,
                  icon: Icon(
                    frozenAt == null ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(frozenAt == null ? l.pauseChart : l.resumeChart),
                ),
                TextButton(
                  onPressed: session.clearHistory,
                  child: Text(l.clear),
                ),
              ],
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                JumpChart(
                  jumps: history,
                  events: events,
                  now: now,
                  window: window,
                  formatAxis: (v) => formatAxisValue(context, v),
                  startLabel: l.chartSecondsAgo(window.inSeconds),
                  midLabel: l.chartSecondsAgo(window.inSeconds ~/ 2),
                  nowLabel: frozenAt == null ? l.chartNow : l.chartPaused,
                  onJumpTap:
                      ref.watch(
                        settingsProvider.select((s) => s.showJumpDetails),
                      )
                      ? (j) => showJumpDetailsSheet(
                          context,
                          j,
                          ref.read(sessionProvider).algorithm,
                        )
                      : null,
                ),
                if (empty)
                  Text(
                    l.chartEmpty,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (visibleTypes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 16,
                  children: [
                    for (final t in ChartEventType.values)
                      if (visibleTypes.contains(t))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              chartEventIcon(t),
                              size: 14,
                              color: chartEventColor(t, scheme),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _eventLabel(l, t),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _eventLabel(AppLocalizations l, ChartEventType t) => switch (t) {
  ChartEventType.connected => l.connectionConnected,
  ChartEventType.disconnected => l.connectionDisconnected,
  ChartEventType.routineStarted => l.chartRoutineStarted,
  ChartEventType.routineStopped => l.chartRoutineStopped,
  ChartEventType.implausibleJump => l.chartImplausibleJump,
};
