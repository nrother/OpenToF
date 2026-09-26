import 'jump.dart';
import 'routine.dart';

/// Builds the jump CSV (a routine, or any list of jumps). Units: seconds and
/// meters, '.' decimal separator. Contact/total time and confidence are empty
/// when unknown; the last row is the total footer. After the fixed columns
/// come the sensor algorithm's custom fields, one column per field id (in
/// first-seen order).
class CsvExporter {
  static const header =
      'jump,flight_time_s,contact_time_s,total_time_s,height_m_beta,'
      'missed_event,provisional,confidence,reasons';

  static String build(RoutineState routine) => buildJumps(routine.jumps);

  static String buildJumps(List<Jump> jumps) {
    final fieldIds = <String>{for (final j in jumps) ...j.fields.keys}.toList();
    final rows = <String>[
      [header, ...fieldIds.map(_escape)].join(','),
    ];
    for (var i = 0; i < jumps.length; i++) {
      final j = jumps[i];
      rows.add(
        [
          '${i + 1}',
          j.flightSeconds.toStringAsFixed(3),
          j.contactSeconds?.toStringAsFixed(3) ?? '',
          j.totalSeconds?.toStringAsFixed(3) ?? '',
          j.heightMeters.toStringAsFixed(3),
          j.missedEvent ? '1' : '0',
          j.isFinal ? '0' : '1',
          j.confidence?.toString() ?? '',
          _escape(j.reasons.join('; ')),
          for (final id in fieldIds) _number(j.fields[id]),
        ].join(','),
      );
    }
    final totalFlightMs = jumps.fold(0, (sum, j) => sum + j.flightMs);
    rows.add(
      [
        'total',
        (totalFlightMs / 1000.0).toStringAsFixed(3),
        '',
        '',
        '',
        jumps.any((j) => j.missedEvent) ? '1' : '0',
        '',
        '',
        '',
        for (final _ in fieldIds) '',
      ].join(','),
    );
    return '${rows.join('\r\n')}\r\n';
  }

  static String _number(num? v) {
    if (v == null) return '';
    if (v is int || v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(3);
  }

  static String _escape(String s) =>
      s.contains(RegExp('[,"\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;

  /// `opentof_routine_…csv` for a routine, `opentof_jumps_…csv` otherwise.
  static String fileName(DateTime now, {String kind = 'routine'}) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'opentof_${kind}_${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}.csv';
  }
}
