import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/csv_exporter.dart';
import '../domain/routine.dart';

abstract class ExportService {
  /// Opens the OS share sheet with the routine as a CSV file.
  Future<void> shareRoutine(RoutineState routine, {DateTime? now});
}

class ShareExportService implements ExportService {
  @override
  Future<void> shareRoutine(RoutineState routine, {DateTime? now}) async {
    final name = CsvExporter.fileName(now ?? DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(CsvExporter.build(routine), flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
    );
  }
}
