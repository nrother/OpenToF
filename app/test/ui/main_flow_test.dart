import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/chart_event.dart';
import 'package:opentof_app/state/providers.dart';
import 'package:opentof_app/ui/main/jump_chart.dart';

import 'harness.dart';

void main() {
  testWidgets(
    'without a paired sensor the app still starts on the main screen',
    (tester) async {
      await AppHarness.launch(tester, paired: false);
      expect(find.text('Last jump'), findsOneWidget);
      expect(
        find.text('Pair your OpenToF sensor to get started.'),
        findsOneWidget,
      );
      expect(find.text('Scan for sensors'), findsNothing);
    },
  );

  testWidgets('Start is disabled until a fresh jump, then enabled', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    expect(find.text('No jump yet'), findsOneWidget);
    expect(h.startEnabled, isFalse);

    await h.jump(flightMs: 1234);
    expect(find.text('1.234 s'), findsOneWidget);
    expect(h.startEnabled, isTrue);

    // Stale after the 4 s inactivity timeout.
    await h.advance(const Duration(seconds: 5));
    expect(h.startEnabled, isFalse);
  });

  testWidgets('full routine: 10 jumps complete with total, sounds and export', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await h.jump(flightMs: 1234);
    await tester.tap(h.startButton);
    await tester.pump();

    expect(find.text('Jump 1 of 10'), findsOneWidget);
    expect(h.audio.jumpBeeps, 1); // jump #1 beeps at Start

    for (var i = 2; i <= 9; i++) {
      await h.jump();
    }
    expect(find.text('Jump 9 of 10'), findsOneWidget);
    expect(h.audio.jumpBeeps, 9);
    expect(h.audio.finalBeeps, 0);

    await h.jump();
    expect(find.text('Routine complete'), findsOneWidget);
    expect(h.audio.jumpBeeps, 9); // #10 plays only the final sound
    expect(h.audio.finalBeeps, 1);
    expect(find.text('10.234 s'), findsWidgets); // total: 1.234 + 9 * 1.000

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();
    expect(h.export.shared.single.jumps.length, 10);
  });

  testWidgets('inactivity cancels the routine but keeps it exportable', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();
    await h.jump();

    await h.advance(const Duration(seconds: 5));
    expect(find.text('Cancelled: no jump detected in time'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);

    // Table still shows the two counted jumps.
    expect(find.text('2.000 s'), findsWidgets);
  });

  testWidgets('cancel button cancels a running routine', (tester) async {
    final h = await AppHarness.launch(tester);
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Routine cancelled'), findsOneWidget);
  });

  testWidgets('a new routine replaces a finished one', (tester) async {
    final h = await AppHarness.launch(tester);
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await h.jump(flightMs: 1500);
    await tester.tap(h.startButton);
    await tester.pump();
    expect(find.text('Jump 1 of 10'), findsOneWidget);
    expect(find.text('Routine cancelled'), findsNothing);
  });

  testWidgets('disconnect pauses the routine and shows the state', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();

    h.mock.simulateDisconnect();
    await h.advance(const Duration(milliseconds: 500));
    expect(find.text('Sensor disconnected, routine paused'), findsOneWidget);

    h.mock.simulateReconnect();
    await h.advance(const Duration(milliseconds: 500));
    expect(find.text('Jump 1 of 10'), findsOneWidget);
  });

  testWidgets('a missed sensor event is flagged on the affected jump', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();

    h.mock.dropNextLanding();
    await h.jump();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('beep toggles: per-jump off keeps the final sound', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester, prefs: {'per_jump_beep': false});
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();
    for (var i = 2; i <= 10; i++) {
      await h.jump();
    }
    expect(h.audio.jumpBeeps, 0);
    expect(h.audio.finalBeeps, 1);
  });

  testWidgets('final sound can be muted independently', (tester) async {
    final h = await AppHarness.launch(tester, prefs: {'final_beep': false});
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();
    for (var i = 2; i <= 10; i++) {
      await h.jump();
    }
    expect(h.audio.jumpBeeps, 9);
    expect(h.audio.finalBeeps, 0);
  });

  testWidgets('Clear empties the history chart', (tester) async {
    final h = await AppHarness.launch(tester);
    expect(find.text('No jumps in this time window'), findsOneWidget);
    await h.jump();
    expect(find.text('No jumps in this time window'), findsNothing);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('No jumps in this time window'), findsOneWidget);
    // Last jump display is unaffected by Clear.
    expect(find.text('1.000 s'), findsOneWidget);
  });

  testWidgets(
    'routine length follows the setting (3 jumps, final sound on #3)',
    (tester) async {
      final h = await AppHarness.launch(
        tester,
        prefs: {'jumps_per_routine': 3},
      );
      await h.jump();
      await tester.tap(h.startButton);
      await tester.pump();
      expect(find.text('Jump 1 of 3'), findsOneWidget);
      expect(h.audio.jumpBeeps, 1);

      await h.jump();
      expect(find.text('Jump 2 of 3'), findsOneWidget);
      await h.jump();
      expect(find.text('Routine complete'), findsOneWidget);
      expect(h.audio.jumpBeeps, 2);
      expect(h.audio.finalBeeps, 1);
    },
  );

  testWidgets('a 1-jump routine completes at Start with only the final sound', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester, prefs: {'jumps_per_routine': 1});
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();
    expect(find.text('Routine complete'), findsOneWidget);
    expect(h.audio.jumpBeeps, 0);
    expect(h.audio.finalBeeps, 1);
  });

  testWidgets('changing the setting mid-routine only affects the next one', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester, prefs: {'jumps_per_routine': 3});
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();

    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(settingsProvider.notifier)
        .setJumpsPerRoutine(5);
    await h.jump();
    await h.jump();
    expect(find.text('Routine complete'), findsOneWidget);
    expect(h.export.shared, isEmpty);
  });

  group('chart pause and event markers', () {
    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    // The axis labels are painted, not Text widgets: read them off the chart.
    String chartLabel(WidgetTester tester) =>
        tester.widget<JumpChart>(find.byType(JumpChart)).nowLabel;

    testWidgets(
      'pause freezes the view; jumps recorded meanwhile show on resume',
      (tester) async {
        final h = await AppHarness.launch(tester);
        await h.jump();
        expect(chartLabel(tester), 'now');

        await tester.tap(find.text('Pause'));
        await tester.pump();
        final frozen = container(tester).read(sessionProvider).chartFrozenAt;
        expect(frozen, isNotNull);
        expect(chartLabel(tester), 'paused');
        expect(find.text('Resume'), findsOneWidget);

        await h.advance(const Duration(seconds: 3));
        await h.jump();
        final s = container(tester).read(sessionProvider);
        expect(s.chartFrozenAt, frozen); // view did not move
        expect(s.history.length, 2); // ...but the jump was recorded

        await tester.tap(find.text('Resume'));
        await tester.pump();
        expect(container(tester).read(sessionProvider).chartFrozenAt, isNull);
        expect(chartLabel(tester), 'now');
        expect(find.text('Pause'), findsOneWidget);
      },
    );

    testWidgets(
      'sensor connect and disconnect are marked, reconnect attempts are not',
      (tester) async {
        final h = await AppHarness.launch(tester);
        List<ChartEventType> types() =>
            container(tester)
                .read(sessionProvider)
                .events
                .map((e) => e.type)
                .toList();
        expect(types(), [ChartEventType.connected]);

        h.mock.simulateDisconnect();
        await h.advance(const Duration(milliseconds: 100));
        expect(types(), [
          ChartEventType.connected,
          ChartEventType.disconnected,
        ]);
        expect(find.text('Disconnected'), findsWidgets);

        h.mock.simulateDisconnect(); // still down: no second marker
        await h.advance(const Duration(milliseconds: 100));
        expect(types().length, 2);

        h.mock.simulateReconnect();
        await h.advance(const Duration(seconds: 1));
        expect(types(), [
          ChartEventType.connected,
          ChartEventType.disconnected,
          ChartEventType.connected,
        ]);
      },
    );

    testWidgets('events keep being recorded while paused; Clear removes them', (
      tester,
    ) async {
      final h = await AppHarness.launch(tester);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      h.mock.simulateDisconnect();
      await h.advance(const Duration(milliseconds: 100));
      expect(container(tester).read(sessionProvider).events.length, 2);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      final s = container(tester).read(sessionProvider);
      expect(s.events, isEmpty);
      expect(s.chartFrozenAt, isNotNull); // Clear does not resume
    });
  });
}
