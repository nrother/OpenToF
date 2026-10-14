import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/changelog.dart';

const _sample = '''
# Changelog

Both parts are **released together**.

See `docs/DECISIONS.md`.

## 0.6.1 — app hotfix

### App
- Fixed a crash.

## 0.6.0 — 2026-11-01

**App 0.6.0** and *firmware* 0.6.0.

### Sensor firmware
- **Deep sleep:** sleeps after 1 minute
  and wakes on motion.
- Second item with `SLEEP_AFTER_IDLE_MS`.

### App
- An app change.

A closing paragraph.

### Sensor ↔ app protocol (breaking)
- Concerns both.

### Known limitations
- Also both.

## Before 0.6.0

### App 1.1.0
- Old app.

### Firmware 0.3.2 (and the 0.1–0.3 line)
- Old firmware.
''';

String _plain(List<ChangelogSpan> spans) => spans.map((s) => s.text).join();

void main() {
  final log = Changelog.parse(_sample);

  test('releases and their sections come in the order of the file', () {
    expect(log.releases.map((r) => r.title), [
      '0.6.1 — app hotfix',
      '0.6.0 — 2026-11-01',
      'Before 0.6.0',
    ]);
    expect(log.releases[1].sections.map((s) => s.title), [
      'Sensor firmware',
      'App',
      'Sensor ↔ app protocol (breaking)',
      'Known limitations',
    ]);
  });

  test('the text before the first release is the preamble, without the '
      'document title', () {
    expect(log.preamble, hasLength(2));
    expect(
      _plain((log.preamble[0] as ChangelogParagraph).spans),
      'Both parts are released together.',
    );
  });

  test('a release keeps the text between its heading and first section', () {
    final intro = log.releases[1].intro.single as ChangelogParagraph;
    expect(intro.spans, const [
      ChangelogSpan('App 0.6.0', bold: true),
      ChangelogSpan(' and '),
      ChangelogSpan('firmware', italic: true),
      ChangelogSpan(' 0.6.0.'),
    ]);
  });

  test('bullets: continuation lines are joined, inline styles are kept', () {
    final bullets =
        log.releases[1].sections[0].blocks.single as ChangelogBullets;
    expect(bullets.items, hasLength(2));
    expect(bullets.items[0], const [
      ChangelogSpan('Deep sleep:', bold: true),
      ChangelogSpan(' sleeps after 1 minute and wakes on motion.'),
    ]);
    expect(bullets.items[1], const [
      ChangelogSpan('Second item with '),
      ChangelogSpan('SLEEP_AFTER_IDLE_MS', code: true),
      ChangelogSpan('.'),
    ]);
  });

  test('a paragraph after a bullet list is its own block', () {
    final blocks = log.releases[1].sections[1].blocks;
    expect(blocks, hasLength(2));
    expect(blocks[0], isA<ChangelogBullets>());
    expect(
      _plain((blocks[1] as ChangelogParagraph).spans),
      'A closing paragraph.',
    );
  });

  test('section headings decide the part; both or neither means shared', () {
    ChangelogPart? part(String title) =>
        ChangelogSection(title: title, blocks: const []).part;
    expect(part('App'), ChangelogPart.app);
    expect(part('App 1.1.0'), ChangelogPart.app);
    expect(part('Sensor firmware'), ChangelogPart.firmware);
    expect(part('Firmware'), ChangelogPart.firmware);
    expect(
      part('Firmware 0.3.2 (and the 0.1–0.3 line)'),
      ChangelogPart.firmware,
    );
    expect(part('Sensor ↔ app protocol (breaking)'), isNull);
    expect(part('Known limitations'), isNull);
  });

  test('each part sees its own sections plus the shared ones', () {
    final release = log.releases[1];
    expect(release.sectionsFor(ChangelogPart.app).map((s) => s.title), [
      'App',
      'Sensor ↔ app protocol (breaking)',
      'Known limitations',
    ]);
    expect(release.sectionsFor(ChangelogPart.firmware).map((s) => s.title), [
      'Sensor firmware',
      'Sensor ↔ app protocol (breaking)',
      'Known limitations',
    ]);
  });

  test('a release that only changed the other part is left out', () {
    expect(log.releasesFor(ChangelogPart.app), hasLength(3));
    expect(log.releasesFor(ChangelogPart.firmware).map((r) => r.title), [
      '0.6.0 — 2026-11-01',
      'Before 0.6.0',
    ]);
  });

  test('a release without part sections shows for both parts', () {
    final c = Changelog.parse('## 1.0.0\n\nJust text.\n\n### Notes\n- x\n');
    expect(c.releasesFor(ChangelogPart.app), hasLength(1));
    expect(c.releasesFor(ChangelogPart.firmware), hasLength(1));
  });

  test('inline: unmatched markers stay text, code is taken literally', () {
    expect(Changelog.parseInline('2 * 3 and a ** b'), const [
      ChangelogSpan('2 * 3 and a ** b'),
    ]);
    expect(Changelog.parseInline('`a * b` is *not* `**bold**`'), const [
      ChangelogSpan('a * b', code: true),
      ChangelogSpan(' is '),
      ChangelogSpan('not', italic: true),
      ChangelogSpan(' '),
      ChangelogSpan('**bold**', code: true),
    ]);
    expect(Changelog.parseInline('**bold with `code`** end'), const [
      ChangelogSpan('bold with ', bold: true),
      ChangelogSpan('code', bold: true, code: true),
      ChangelogSpan(' end'),
    ]);
  });

  test('Windows line endings parse the same', () {
    final crlf = Changelog.parse(_sample.replaceAll('\n', '\r\n'));
    expect(crlf.releases.map((r) => r.title), log.releases.map((r) => r.title));
    expect(crlf.releases[1].sections, hasLength(4));
  });
}
