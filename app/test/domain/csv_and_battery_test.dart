import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/battery_estimator.dart';
import 'package:opentof_app/domain/csv_exporter.dart';
import 'package:opentof_app/domain/jump.dart';
import 'package:opentof_app/domain/routine.dart';

final t0 = DateTime(2026, 1, 1, 12);

void main() {
  group('CsvExporter', () {
    test('rows, empty unknown contact, missed flag and total footer', () {
      final state = RoutineState(
        phase: RoutinePhase.complete,
        jumps: [
          Jump(flightMs: 1200, contactMs: 200, landedAt: t0),
          Jump(flightMs: 1500, landedAt: t0, missedEvent: true),
        ],
      );
      final csv = CsvExporter.build(state).split('\r\n');
      expect(
        csv[0],
        'jump,flight_time_s,contact_time_s,height_m_beta,missed_event',
      );
      expect(csv[1], '1,1.200,0.200,1.766,0');
      expect(csv[2], '2,1.500,,2.759,1');
      expect(csv[3], 'total,2.700,,,1');
      expect(csv[4], ''); // trailing CRLF
    });

    test('file name is timestamped', () {
      expect(
        CsvExporter.fileName(DateTime(2026, 3, 4, 5, 6, 7)),
        'opentof_routine_20260304_050607.csv',
      );
    });
  });

  group('BatteryEstimator', () {
    test('null with fewer than 2 readings or too short a span', () {
      final b = BatteryEstimator();
      expect(b.remaining(), isNull);
      b.add(t0, 90);
      expect(b.remaining(), isNull);
      b.add(t0.add(const Duration(minutes: 1)), 89);
      expect(b.remaining(), isNull);
    });

    test('extrapolates a steady drain', () {
      // 10 % per hour, currently at 50 % -> 5 h left.
      final b = BatteryEstimator();
      b.add(t0, 60);
      b.add(t0.add(const Duration(hours: 1)), 50);
      expect(b.remaining()!.inMinutes, closeTo(300, 1));
    });

    test('null when level is flat', () {
      final b = BatteryEstimator();
      b.add(t0, 80);
      b.add(t0.add(const Duration(hours: 1)), 80);
      expect(b.remaining(), isNull);
    });

    test('rising level (charging) clears history', () {
      final b = BatteryEstimator();
      b.add(t0, 60);
      b.add(t0.add(const Duration(hours: 1)), 50);
      b.add(t0.add(const Duration(hours: 2)), 70);
      expect(b.readings.length, 1);
      expect(b.remaining(), isNull);
    });

    test('caps stored readings', () {
      final b = BatteryEstimator(maxReadings: 3);
      for (var i = 0; i < 10; i++) {
        b.add(t0.add(Duration(minutes: i)), 90);
      }
      expect(b.readings.length, 3);
    });
  });
}
