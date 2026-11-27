import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/algorithm_metadata.dart';
import '../../domain/sensor_health.dart';
import '../../domain/version_check.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../format.dart';

/// Everything the paired sensor reports about itself: battery, device
/// information, and what its detection algorithm puts into the jump events.
/// Opened by tapping the sensor in Settings.
class SensorScreen extends ConsumerWidget {
  const SensorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final info = session.deviceInfo;
    final algorithm = session.algorithm;
    final health = session.health;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.deviceName ??
              ref.watch(settingsProvider).pairedDeviceName ??
              l.sensorDetails,
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const VersionMismatchWarning(),
            const ProtocolMismatchWarning(),
            SettingsSection(l.batterySection),
            InfoRow(
              l.batteryLevelLabel,
              session.batteryLevel == null
                  ? null
                  : l.percent(session.batteryLevel!),
            ),
            InfoRow(
              l.batteryRemaining,
              session.batteryRemaining == null
                  ? l.batteryRemainingUnknown
                  : formatRemaining(l, session.batteryRemaining!),
            ),

            SettingsSection(l.healthSection),
            InfoRow(
              l.sampleRateLabel,
              health?.pllFrequencyHz == null
                  ? null
                  : formatHertz(context, health!.pllFrequencyHz!),
            ),
            InfoRow(l.pllLabel, _pllState(l, health)),
            InfoRow(
              l.uptimeLabel,
              health?.uptimeSeconds == null
                  ? null
                  : formatUptime(l, health!.uptimeSeconds!),
            ),

            SettingsSection(l.deviceInfoSection),
            InfoRow(l.manufacturerLabel, info?.manufacturerName),
            InfoRow(l.modelLabel, info?.modelNumber),
            InfoRow(l.serialNumberLabel, info?.serialNumber),
            InfoRow(l.hardwareRevisionLabel, info?.hardwareRevision),
            InfoRow(l.firmwareRevisionLabel, info?.firmwareRevision),

            SettingsSection(l.algorithmSection),
            InfoRow(l.algorithmLabel, info?.softwareRevision),
            InfoRow(
              l.confidenceKindLabel,
              _confidenceKind(l, algorithm.confidenceKind),
            ),
            _Subheading(l.reasonsLabel),
            if (algorithm.reasons.isEmpty)
              _Plain(l.noneProvided)
            else
              for (final r in algorithm.reasons) _Plain('• $r'),
            _Subheading(l.customFieldsLabel),
            if (algorithm.fields.isEmpty)
              _Plain(l.noneProvided)
            else
              for (final f in algorithm.fields)
                ListTile(
                  dense: true,
                  title: Text(f.name),
                  subtitle: Text(
                    [
                      if (f.description != null) f.description!,
                      _fieldDetails(l, f),
                    ].join('\n'),
                  ),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Null ('–') while no health has arrived; a sensor without a PLL (demo
  /// mode) reports it as not available.
  static String? _pllState(AppLocalizations l, SensorHealth? health) {
    if (health == null) return null;
    return switch (health.pllLocked) {
      true => l.pllLocked,
      false => l.pllAcquiring,
      null => l.pllNotAvailable,
    };
  }

  static String _confidenceKind(AppLocalizations l, String kind) =>
      switch (kind) {
        'none' => l.confidenceKindNone,
        'heuristic' => l.confidenceKindHeuristic,
        'calibrated' => l.confidenceKindCalibrated,
        _ => kind,
      };

  static String _fieldDetails(AppLocalizations l, CustomField f) => [
    f.onTakeoff && f.onLanding
        ? l.fieldOnBoth
        : (f.onTakeoff ? l.fieldOnTakeoff : l.fieldOnLanding),
    if (f.unit != null) f.unit!,
    if (f.relative) l.fieldRelative,
    '${f.id} · ${f.type}',
  ].join(' · ');
}

/// Warning card shown when the sensor firmware's MAJOR.MINOR differs from the
/// app's (hotfix versions may differ). Nothing while either is unknown.
class VersionMismatchWarning extends ConsumerWidget {
  const VersionMismatchWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appVersionProvider);
    final firmware = ref.watch(
      sessionProvider.select((s) => s.deviceInfo?.firmwareRevision),
    );
    if (versionsCompatible(app, firmware)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: scheme.error),
        title: Text(
          l.versionMismatchTitle,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        subtitle: Text(
          l.versionMismatchBody(app.split(' ').first, firmware!),
          style: TextStyle(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}

/// Shown while the connected sensor sends events in a protocol version this
/// app does not understand.
class ProtocolMismatchWarning extends ConsumerWidget {
  const ProtocolMismatchWarning({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mismatch = ref.watch(
      sessionProvider.select((s) => s.protocolMismatch),
    );
    if (!mismatch) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: margin,
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: scheme.error),
        title: Text(
          l.protocolMismatchTitle,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        subtitle: Text(
          l.protocolMismatchBody,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}

/// Section heading used on the settings pages.
class SettingsSection extends StatelessWidget {
  const SettingsSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// Read-only label/value row; '–' while the value hasn't been read yet (or
/// the sensor doesn't expose it). The value is width-limited so a long one
/// (e.g. a serial number) can't push the row into overflow.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Text(
        value ?? '–',
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _Subheading extends StatelessWidget {
  const _Subheading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
  );
}

class _Plain extends StatelessWidget {
  const _Plain(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 2, 16, 2),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
