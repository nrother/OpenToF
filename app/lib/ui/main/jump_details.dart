import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/settings_repository.dart';
import '../../domain/algorithm_metadata.dart';
import '../../domain/jump.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';

/// One extra per-jump value from the sensor (its confidence or a custom
/// algorithm field), shown when "Show more jump details" is on.
class JumpDetail {
  const JumpDetail({
    required this.key,
    required this.label,
    required this.value,
    this.unit,
    this.description,
  });

  /// [AppSettings.confidenceDetail] or the custom field's id.
  final String key;
  final String label;
  final String? unit;
  final String? description;

  /// Formatted value without unit, or null if the jump has none.
  final String? Function(Jump) value;

  /// "Label (unit)" for table headers.
  String get header => unit == null ? label : '$label ($unit)';

  /// "Label value unit", or null if the jump has no value.
  String? describe(Jump j) {
    final v = value(j);
    if (v == null) return null;
    return unit == null ? '$label $v' : '$label $v $unit';
  }
}

/// Everything the connected sensor can report per jump beyond the times.
List<JumpDetail> availableDetails(
  BuildContext context,
  AppLocalizations l,
  AlgorithmMetadata m,
) {
  final number = NumberFormat(
    '0.##',
    Localizations.localeOf(context).toString(),
  );
  return [
    if (m.confidenceKind != 'none')
      JumpDetail(
        key: AppSettings.confidenceDetail,
        label: l.confidenceKindLabel,
        unit: '%',
        value: (j) => j.confidence?.toString(),
      ),
    for (final f in m.fields)
      JumpDetail(
        key: f.id,
        label: f.name,
        unit: f.unit,
        description: f.description,
        value: (j) {
          final v = j.fields[f.id];
          return v == null ? null : number.format(v);
        },
      ),
  ];
}

/// The details the user wants to see (empty while the setting is off).
List<JumpDetail> visibleDetails(
  BuildContext context,
  AppLocalizations l,
  AlgorithmMetadata m,
  AppSettings settings,
) => [
  for (final d in availableDetails(context, l, m))
    if (settings.detailVisible(d.key)) d,
];

/// Bottom sheet with everything known about one jump.
Future<void> showJumpDetailsSheet(
  BuildContext context,
  Jump jump,
  AlgorithmMetadata algorithm,
) {
  final l = AppLocalizations.of(context);
  String secs(double? v) =>
      v == null ? '–' : l.seconds(formatSecondsValue(context, v));
  final extras = availableDetails(context, l, algorithm);
  final time = DateFormat.Hms(Localizations.localeOf(context).toString())
      .format(jump.landedAt);

  Widget row(String label, String value, {String? subtitle}) => ListTile(
    dense: true,
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Text(value, textAlign: TextAlign.end),
    ),
  );

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l.jumpDetailsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            row(l.landedAtLabel, time),
            row(l.flightTimeLabel, secs(jump.flightSeconds)),
            row(l.contactTimeLabel, secs(jump.contactSeconds)),
            row(l.totalJumpTimeLabel, secs(jump.totalSeconds)),
            row(
              '${l.heightLabel} (${l.betaTag})',
              l.meters(formatMetersValue(context, jump.heightMeters)),
            ),
            row(l.stageLabel, jump.isFinal ? l.stageFinal : l.stageProvisional),
            if (jump.missedEvent) row(l.missedEventWarning, ''),
            row(
              l.confidenceKindLabel,
              jump.confidence == null ? '–' : l.percent(jump.confidence!),
            ),
            row(
              l.reasonsLabel,
              jump.reasons.isEmpty ? l.noneProvided : jump.reasons.join('\n'),
            ),
            for (final d in extras)
              if (d.key != AppSettings.confidenceDetail)
                row(
                  d.label,
                  d.value(jump) == null
                      ? '–'
                      : [d.value(jump)!, if (d.unit != null) d.unit!].join(' '),
                  subtitle: d.description,
                ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
