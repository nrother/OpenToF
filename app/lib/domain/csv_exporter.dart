import 'routine.dart';

/// Builds the routine CSV. Units: seconds and meters, '.' decimal separator.
/// Contact time is empty when unknown; the last row is the total footer.
class CsvExporter {
  static const header =
      'jump,flight_time_s,contact_time_s,height_m_beta,missed_event';

  static String build(RoutineState routine) {
    final rows = <String>[header];
    for (var i = 0; i < routine.jumps.length; i++) {
      final j = routine.jumps[i];
      rows.add(
        [
          '${i + 1}',
          j.flightSeconds.toStringAsFixed(3),
          j.contactSeconds?.toStringAsFixed(3) ?? '',
          j.heightMeters.toStringAsFixed(3),
          j.missedEvent ? '1' : '0',
        ].join(','),
      );
    }
    rows.add(
      'total,${routine.totalFlightSeconds.toStringAsFixed(3)},,,'
      '${routine.hasMissedEvent ? '1' : '0'}',
    );
    return '${rows.join('\r\n')}\r\n';
  }

  static String fileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'opentof_routine_${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}.csv';
  }
}
