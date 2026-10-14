import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/changelog.dart';

/// The app shows a bundled copy of the repository's Changelog.md. Tests run
/// with the app folder as working directory.
String _read(String path) => File(path).readAsStringSync().replaceAll('\r', '');

void main() {
  const asset = 'assets/changelog/Changelog.md';

  test('the bundled changelog is the current Changelog.md', () {
    expect(
      _read(asset) == _read('../Changelog.md'),
      isTrue,
      reason:
          '$asset is out of date with ../Changelog.md. '
          'Run: dart run tool/sync_changelog.dart',
    );
  });

  test('the bundled changelog has content for both tabs', () {
    final log = Changelog.parse(_read(asset));
    expect(log.preamble, isNotEmpty);
    for (final part in ChangelogPart.values) {
      final releases = log.releasesFor(part);
      expect(releases.length, greaterThanOrEqualTo(3), reason: '$part');
      for (final r in releases) {
        expect(r.title, isNotEmpty);
        expect(
          r.sectionsFor(part).expand((s) => s.blocks),
          isNotEmpty,
          reason: '$part: "${r.title}" has no text',
        );
      }
    }
    // Sections named after one part are not mistaken for shared ones.
    final titles = [
      for (final r in log.releases)
        for (final s in r.sections)
          if (s.part == null) s.title,
    ];
    expect(titles, ['Sensor ↔ app protocol (breaking)', 'Known limitations']);
  });
}
