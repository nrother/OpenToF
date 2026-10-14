/// Reads the project's `Changelog.md` (the copy bundled with the app) into
/// releases and sections, sorted into what concerns the app and what concerns
/// the sensor firmware.
///
/// Understood Markdown: `##` starts a release, `###` a section inside it;
/// paragraphs and `-`/`*` bullet lists (continuation lines are joined, nested
/// bullets become plain bullets); inline `**bold**`, `*italic*` and `` `code` ``.
library;

import 'dart:convert';

/// The two parts of OpenToF that the changelog is shown for.
enum ChangelogPart { app, firmware }

/// A run of text with one inline style.
class ChangelogSpan {
  const ChangelogSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  @override
  bool operator ==(Object other) =>
      other is ChangelogSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.code == code;

  @override
  int get hashCode => Object.hash(text, bold, italic, code);

  @override
  String toString() =>
      'ChangelogSpan("$text"'
      '${bold ? ', bold' : ''}${italic ? ', italic' : ''}'
      '${code ? ', code' : ''})';
}

sealed class ChangelogBlock {
  const ChangelogBlock();
}

class ChangelogParagraph extends ChangelogBlock {
  const ChangelogParagraph(this.spans);

  final List<ChangelogSpan> spans;
}

class ChangelogBullets extends ChangelogBlock {
  const ChangelogBullets(this.items);

  final List<List<ChangelogSpan>> items;
}

/// A `###` section of a release.
class ChangelogSection {
  const ChangelogSection({required this.title, required this.blocks});

  final String title;
  final List<ChangelogBlock> blocks;

  static final _app = RegExp(r'\bapp\b');
  static final _firmware = RegExp(r'\b(firmware|sensor)\b');

  /// The part this section is about, judged by its heading ("App",
  /// "Sensor firmware", "Firmware 0.3.2 ..."). Null if it concerns both: a
  /// heading that names both or neither ("Sensor ↔ app protocol", "Known
  /// limitations").
  ChangelogPart? get part {
    final heading = title.toLowerCase();
    final app = _app.hasMatch(heading);
    final firmware = _firmware.hasMatch(heading);
    if (app == firmware) return null;
    return app ? ChangelogPart.app : ChangelogPart.firmware;
  }
}

/// A `##` release: its heading, the text right below it and its sections.
class ChangelogRelease {
  const ChangelogRelease({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final List<ChangelogBlock> intro;
  final List<ChangelogSection> sections;

  /// The sections to show for [part]: its own and those concerning both, in
  /// the order of the file.
  List<ChangelogSection> sectionsFor(ChangelogPart part) => [
    for (final s in sections)
      if (s.part == null || s.part == part) s,
  ];

  /// False for a release that only changed the other part (e.g. an app-only
  /// hotfix seen from the firmware).
  bool concerns(ChangelogPart part) =>
      sections.any((s) => s.part == part) ||
      !sections.any((s) => s.part != null);
}

class Changelog {
  const Changelog({required this.preamble, required this.releases});

  /// The text before the first release (how the versions work).
  final List<ChangelogBlock> preamble;

  /// Releases in the order of the file: newest first.
  final List<ChangelogRelease> releases;

  List<ChangelogRelease> releasesFor(ChangelogPart part) => [
    for (final r in releases)
      if (r.concerns(part)) r,
  ];

  static final _bullet = RegExp(r'^\s*[-*]\s+(.*)$');

  static Changelog parse(String markdown) {
    final preamble = <ChangelogBlock>[];
    final releases = <ChangelogRelease>[];
    var blocks = preamble;

    // The block being collected: the lines of a paragraph, or of the last
    // item of a bullet list.
    List<String>? paragraph;
    List<List<String>>? bullets;

    void flush() {
      if (paragraph != null) {
        blocks.add(ChangelogParagraph(parseInline(paragraph!.join(' '))));
      }
      if (bullets != null) {
        blocks.add(
          ChangelogBullets([
            for (final item in bullets!) parseInline(item.join(' ')),
          ]),
        );
      }
      paragraph = null;
      bullets = null;
    }

    for (final raw in const LineSplitter().convert(markdown)) {
      final line = raw.trim();
      final bullet = _bullet.firstMatch(raw);
      if (line.isEmpty) {
        // A blank line ends a paragraph; a bullet list goes on if more
        // bullets follow.
        if (paragraph != null) flush();
      } else if (line.startsWith('### ')) {
        flush();
        blocks = <ChangelogBlock>[];
        final section = ChangelogSection(
          title: line.substring(4).trim(),
          blocks: blocks,
        );
        if (releases.isEmpty) {
          releases.add(
            ChangelogRelease(title: '', intro: const [], sections: [section]),
          );
        } else {
          releases.last.sections.add(section);
        }
      } else if (line.startsWith('## ')) {
        flush();
        blocks = <ChangelogBlock>[];
        releases.add(
          ChangelogRelease(
            title: line.substring(3).trim(),
            intro: blocks,
            sections: [],
          ),
        );
      } else if (line.startsWith('# ')) {
        flush(); // the document title: the page has its own
      } else if (bullet != null) {
        if (paragraph != null) flush();
        (bullets ??= []).add([bullet.group(1)!.trim()]);
      } else if (bullets != null && raw.startsWith(RegExp(r'\s'))) {
        bullets!.last.add(line);
      } else {
        if (bullets != null) flush();
        (paragraph ??= []).add(line);
      }
    }
    flush();
    return Changelog(preamble: preamble, releases: releases);
  }

  /// Splits one paragraph or bullet into styled runs. A marker without a
  /// partner stays as plain text.
  static List<ChangelogSpan> parseInline(String text) {
    final spans = <ChangelogSpan>[];
    final plain = StringBuffer();
    var bold = false;
    var italic = false;

    void emit() {
      if (plain.isEmpty) return;
      spans.add(ChangelogSpan(plain.toString(), bold: bold, italic: italic));
      plain.clear();
    }

    var i = 0;
    while (i < text.length) {
      if (text[i] == '`') {
        final end = text.indexOf('`', i + 1);
        if (end > i) {
          emit();
          spans.add(
            ChangelogSpan(
              text.substring(i + 1, end),
              bold: bold,
              italic: italic,
              code: true,
            ),
          );
          i = end + 1;
          continue;
        }
      } else if (text.startsWith('**', i)) {
        if (bold || text.indexOf('**', i + 2) > i) {
          emit();
          bold = !bold;
          i += 2;
          continue;
        }
      } else if (text[i] == '*') {
        if (italic || _closesItalic(text, i + 1)) {
          emit();
          italic = !italic;
          i += 1;
          continue;
        }
      }
      plain.write(text[i]);
      i++;
    }
    emit();
    return spans;
  }

  /// Whether a single `*` (not part of `**`) follows at or after [from].
  static bool _closesItalic(String text, int from) {
    var i = from;
    while (i < text.length) {
      if (text[i] == '`') {
        final end = text.indexOf('`', i + 1);
        if (end > i) {
          i = end + 1;
          continue;
        }
      } else if (text.startsWith('**', i)) {
        i += 2;
        continue;
      } else if (text[i] == '*') {
        return true;
      }
      i++;
    }
    return false;
  }
}
