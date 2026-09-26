import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/csv_exporter.dart';
import '../domain/jump.dart';
import '../domain/routine.dart';

abstract class ExportService {
  /// Opens the OS share sheet with the routine as a CSV file.
  Future<void> shareRoutine(RoutineState routine, {DateTime? now});

  /// Opens the OS share sheet with arbitrary jumps (e.g. the last minute) as
  /// a CSV file.
  Future<void> shareJumps(List<Jump> jumps, {DateTime? now});
}

class ShareExportService implements ExportService {
  @override
  Future<void> shareRoutine(RoutineState routine, {DateTime? now}) => _share(
    CsvExporter.fileName(now ?? DateTime.now()),
    CsvExporter.build(routine),
  );

  @override
  Future<void> shareJumps(List<Jump> jumps, {DateTime? now}) => _share(
    CsvExporter.fileName(now ?? DateTime.now(), kind: 'jumps'),
    CsvExporter.buildJumps(jumps),
  );

  Future<void> _share(String name, String csv) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(csv, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
    );
  }
}
