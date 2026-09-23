import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/jump.dart';
import 'package:opentof_app/ui/main/jump_chart.dart';

final now = DateTime(2026, 1, 1, 12);

Jump jumpAgo(int seconds, {int flightMs = 1000}) => Jump(
  flightMs: flightMs,
  landedAt: now.subtract(Duration(seconds: seconds)),
);

void main() {
  const window = Duration(seconds: 30);

  test(
    'window is time based: includes now, excludes older and future jumps',
    () {
      expect(jumpInWindow(jumpAgo(0), now, window), isTrue);
      expect(jumpInWindow(jumpAgo(30), now, window), isTrue);
      expect(jumpInWindow(jumpAgo(31), now, window), isFalse);
      expect(jumpInWindow(jumpAgo(-1), now, window), isFalse);
    },
  );

  test('y axis is at least 1 s and grows in 0.5 s steps', () {
    expect(chartYMax(const []), 1.0);
    expect(chartYMax([jumpAgo(1, flightMs: 800)]), 1.0);
    expect(chartYMax([jumpAgo(1, flightMs: 1001)]), 1.5);
    expect(chartYMax([jumpAgo(1, flightMs: 1500)]), 1.5);
    expect(chartYMax([jumpAgo(1, flightMs: 2300)]), 2.5);
  });
}
