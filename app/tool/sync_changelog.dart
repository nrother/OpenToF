// Copies the project's Changelog.md (repository root) into the app's assets,
// where Settings → Version shows it. Run after every change to Changelog.md:
//   dart run tool/sync_changelog.dart
// test/changelog_asset_test.dart fails while the copy is out of date.

import 'dart:io';

void main() {
  // tool/ -> app/
  final app = File.fromUri(Platform.script).parent.parent;
  final source = File('${app.parent.path}/Changelog.md');
  final target = File('${app.path}/assets/changelog/Changelog.md');

  // Unix line endings, whatever the checkout uses.
  final text = source.readAsStringSync().replaceAll('\r\n', '\n');
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(text);
  stdout.writeln('Copied ${source.path} to ${target.path}');
}
