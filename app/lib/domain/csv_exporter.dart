import 'chart_event.dart';
import 'jump.dart';
import 'routine.dart';

/// Builds the jump CSV (a routine, or any list of jumps). Units: seconds and
/// meters, '.' decimal separator. Contact/total time and confidence are empty
/// when unknown. After the fixed columns come the sensor algorithm's custom
/// fields, one column per field id (in first-seen order). [events] (used for
/// time-range exports) adds `routine_start`/`routine_stop` marker rows,
/// interleaved by time with the jump rows.
class CsvExporter {
  static const header =
      'jump,flight_time_s,contact_time_s,total_time_s,height_m_beta,'
      'missed_event,provisional,confidence,reasons';

  static String build(RoutineState routine) => buildJumps(routine.jumps);

  static String buildJumps(
    List<Jump> jumps, {
    List<ChartEvent> events = const [],
  }) {
    final fieldIds = <String>{for (final j in jumps) ...j.fields.keys}.toList();
    final timedRows = <(DateTime, String)>[
      for (var i = 0; i < jumps.length; i++)
        (jumps[i].landedAt, _jumpRow(jumps[i], i + 1, fieldIds)),
      for (final e in events)
        if (e.type == ChartEventType.routineStarted ||
            e.type == ChartEventType.routineStopped)
          (e.at, _markerRow(e.type, fieldIds.length)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final rows = [
      [header, ...fieldIds.map(_escape)].join(','),
      for (final r in timedRows) r.$2,
    ];
    return '${rows.join('\r\n')}\r\n';
  }

  static String _jumpRow(Jump j, int number, List<String> fieldIds) => [
    '$number',
    j.flightSeconds.toStringAsFixed(3),
    j.contactSeconds?.toStringAsFixed(3) ?? '',
    j.totalSeconds?.toStringAsFixed(3) ?? '',
    j.heightMeters.toStringAsFixed(3),
    j.missedEvent ? '1' : '0',
    j.isFinal ? '0' : '1',
    j.confidence?.toString() ?? '',
    _escape(j.reasons.join('; ')),
    for (final id in fieldIds) _number(j.fields[id]),
  ].join(',');

  static String _markerRow(ChartEventType type, int fieldCount) => [
    type == ChartEventType.routineStarted ? 'routine_start' : 'routine_stop',
    for (var i = 0; i < 8 + fieldCount; i++) '',
  ].join(',');

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
