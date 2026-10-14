import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/changelog.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import 'sensor_screen.dart';

/// What changed in each version, one tab for the app and one for the sensor
/// firmware, newest version first. Opened from the Version row in Settings.
///
/// The text is the project's `Changelog.md`, bundled as an asset (see
/// `tool/sync_changelog.dart`); it exists in English only.
class ChangelogScreen extends ConsumerWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final changelog = ref.watch(changelogProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.changelogTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l.changelogAppTab),
              Tab(text: l.changelogFirmwareTab),
            ],
          ),
        ),
        body: SafeArea(
          child: changelog.when(
            data: (c) => TabBarView(
              children: [
                _PartView(c, ChangelogPart.app),
                _PartView(c, ChangelogPart.firmware),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.changelogLoadFailed),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// All releases that concern one part.
class _PartView extends StatelessWidget {
  const _PartView(this.changelog, this.part);

  final Changelog changelog;
  final ChangelogPart part;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (l.changelogLanguageNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              l.changelogLanguageNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final release in changelog.releasesFor(part)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Text(release.title, style: theme.textTheme.titleLarge),
          ),
          for (final block in release.intro) _Block(block),
          for (final section in release.sectionsFor(part)) ...[
            SettingsSection(section.title),
            for (final block in section.blocks) _Block(block),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Divider(height: 1),
          ),
        ],
        if (changelog.preamble.isNotEmpty) ...[
          SettingsSection(l.changelogAbout),
          for (final block in changelog.preamble) _Block(block),
        ],
      ],
    );
  }
}

/// One paragraph or bullet list.
class _Block extends StatelessWidget {
  const _Block(this.block);

  final ChangelogBlock block;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: switch (block) {
        ChangelogParagraph(:final spans) => Text.rich(
          _text(context, spans),
          style: style,
        ),
        ChangelogBullets(:final items) => Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(child: Text('•  ', style: style)),
                    Expanded(
                      child: Text.rich(_text(context, item), style: style),
                    ),
                  ],
                ),
              ),
          ],
        ),
      },
    );
  }

  static TextSpan _text(BuildContext context, List<ChangelogSpan> spans) {
    final codeBackground = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest;
    return TextSpan(
      children: [
        for (final s in spans)
          TextSpan(
            text: s.text,
            style: TextStyle(
              fontWeight: s.bold ? FontWeight.bold : null,
              fontStyle: s.italic ? FontStyle.italic : null,
              fontFamily: s.code ? 'monospace' : null,
              backgroundColor: s.code ? codeBackground : null,
            ),
          ),
      ],
    );
  }
}
