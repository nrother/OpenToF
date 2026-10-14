import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'sensor_screen.dart';

/// Help page: what the LEDs on the sensor mean. Opened from Settings.
///
/// The orange signals and their timings are those of the sensor firmware; keep
/// them in sync with the "LED status" table in `firmware/README.md`. The red
/// signals are those of the board's charger chip (SGM40567, status pin nCHG):
/// the firmware has no part in them.
class LedHelpScreen extends StatelessWidget {
  const LedHelpScreen({super.key});

  // One blink pattern as (milliseconds, LED on) steps, drawn left to right.
  static const _waiting = [
    (300, true),
    (700, false),
    (300, true),
    (700, false),
  ];
  static const _connected = [(2000, true)];
  static const _goingToSleep = [
    (150, true), (150, false), (150, true), (150, false), (150, true), //
    (150, false), (150, true), (150, false), (150, true), (150, false),
    (150, true), (350, false),
  ];
  static const _asleep = [(2000, false)];
  static const _wokeUp = [
    (80, true),
    (80, false),
    (80, true),
    (80, false),
    (80, true),
    (400, false),
    (300, true),
    (700, false),
    (200, true),
  ];
  static const _error = [
    (100, true), (100, false), (100, true), (100, false), (100, true), //
    (100, false), (100, true), (100, false), (100, true), (100, false),
    (100, true), (100, false), (100, true), (100, false), (100, true),
    (100, false), (100, true), (100, false), (100, true), (100, false),
  ];
  // Charger: one indication period is 1280 ms, lit for an eighth of it.
  static const _charging = [
    (160, true),
    (1120, false),
    (160, true),
    (560, false),
  ];
  static const _charged = [(2000, true)];
  static const _chargeOff = [(2000, false)];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.ledHelpTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Paragraph(l.ledHelpIntro),
            SettingsSection(l.ledOrangeSection),
            _Signal(
              pattern: _waiting,
              title: l.ledWaitingTitle,
              timing: l.ledWaitingTiming,
              meaning: l.ledWaitingMeaning,
            ),
            _Signal(
              pattern: _connected,
              title: l.ledConnectedTitle,
              timing: l.ledConnectedTiming,
              meaning: l.ledConnectedMeaning,
            ),
            _Signal(
              pattern: _goingToSleep,
              title: l.ledGoingToSleepTitle,
              timing: l.ledGoingToSleepTiming,
              meaning: l.ledGoingToSleepMeaning,
            ),
            _Signal(
              pattern: _asleep,
              title: l.ledAsleepTitle,
              timing: l.ledAsleepTiming,
              meaning: l.ledAsleepMeaning,
            ),
            _Signal(
              pattern: _wokeUp,
              title: l.ledWokeUpTitle,
              timing: l.ledWokeUpTiming,
              meaning: l.ledWokeUpMeaning,
            ),
            _Signal(
              pattern: _error,
              title: l.ledErrorTitle,
              timing: l.ledErrorTiming,
              meaning: l.ledErrorMeaning,
            ),
            SettingsSection(l.ledRedSection),
            _Paragraph(l.ledRedBody),
            _Signal(
              pattern: _charging,
              color: Colors.red,
              title: l.ledChargingTitle,
              timing: l.ledChargingTiming,
              meaning: l.ledChargingMeaning,
            ),
            _Signal(
              pattern: _charged,
              color: Colors.red,
              title: l.ledChargedTitle,
              timing: l.ledChargedTiming,
              meaning: l.ledChargedMeaning,
            ),
            _Signal(
              pattern: _chargeOff,
              color: Colors.red,
              title: l.ledChargeOffTitle,
              timing: l.ledChargeOffTiming,
              meaning: l.ledChargeOffMeaning,
            ),
            _Paragraph(l.ledRedSource),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// One LED signal: its name, a picture of the blink pattern over about two
/// seconds, the exact timing and what it means.
class _Signal extends StatelessWidget {
  const _Signal({
    required this.pattern,
    required this.title,
    required this.timing,
    required this.meaning,
    this.color = Colors.orange,
  });

  final List<(int, bool)> pattern;

  /// Colour of the light this signal belongs to.
  final Color color;
  final String title;
  final String timing;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          _PatternStrip(pattern, color),
          const SizedBox(height: 6),
          Text(
            timing,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(meaning, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// The blink pattern as a bar: time runs left to right, coloured = LED on.
class _PatternStrip extends StatelessWidget {
  const _PatternStrip(this.pattern, this.color);

  final List<(int, bool)> pattern;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final off = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 12,
          child: Row(
            children: [
              for (final (ms, on) in pattern)
                Expanded(
                  flex: ms,
                  child: ColoredBox(
                    color: on ? color : off,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
