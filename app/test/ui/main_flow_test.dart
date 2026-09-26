import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/domain/chart_event.dart';
import 'package:opentof_app/domain/sensor_events.dart';
import 'package:opentof_app/state/providers.dart';
import 'package:opentof_app/ui/main/jump_chart.dart';

import 'harness.dart';

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

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
    await h.advance(const Duration(milliseconds: 600));
    await tester.tap(find.text('Recorded routine'));
    await tester.pump();
    await h.advance(const Duration(milliseconds: 600));
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

    h.mock.dropNextJump();
    await h.jump();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('a provisional landing counts and beeps; the final value '
      'replaces it', (tester) async {
    final h = await AppHarness.launch(tester);
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();
    final beepsAfterStart = h.audio.jumpBeeps;

    h.mock.emitTakeoff(contactMs: 200);
    h.mock.emitLanding(flightMs: 1111, stage: JumpEventStage.provisional);
    await h.advance(const Duration(milliseconds: 50));
    expect(find.text('Jump 2 of 10'), findsOneWidget);
    expect(h.audio.jumpBeeps, beepsAfterStart + 1);
    expect(container(tester).read(sessionProvider).lastJump!.isFinal, isFalse);

    // Final landing 11 ms earlier than the provisional estimate.
    h.mock.emitLanding(flightMs: 1100);
    await h.advance(const Duration(milliseconds: 50));
    final s = container(tester).read(sessionProvider);
    expect(s.lastJump!.flightMs, 1100);
    expect(s.lastJump!.isFinal, isTrue);
    expect(s.routine.jumps.last.flightMs, 1100);
    expect(s.history.last.flightMs, 1100);
    expect(s.routine.jumps, hasLength(2));
    expect(h.audio.jumpBeeps, beepsAfterStart + 1); // no second beep
    expect(find.text('1.100 s'), findsWidgets);
  });

  testWidgets('a retracted landing removes the jump again', (tester) async {
    final h = await AppHarness.launch(tester);
    await h.jump(flightMs: 1234);
    await tester.tap(h.startButton);
    await tester.pump();

    h.mock.emitTakeoff(contactMs: 200);
    h.mock.emitLanding(flightMs: 500, stage: JumpEventStage.provisional);
    await h.advance(const Duration(milliseconds: 50));
    expect(find.text('Jump 2 of 10'), findsOneWidget);

    h.mock.retractLanding();
    await h.advance(const Duration(milliseconds: 50));
    final s = container(tester).read(sessionProvider);
    expect(s.routine.jumps, hasLength(1));
    expect(s.history, hasLength(1));
    expect(s.lastJump!.flightMs, 1234);
    expect(find.text('Jump 1 of 10'), findsOneWidget);
  });

  testWidgets('time on bed and total time show when enabled', (tester) async {
    final h = await AppHarness.launch(
      tester,
      prefs: {'show_contact_time': true, 'show_total_time': true},
    );
    await h.jump(flightMs: 1000); // first jump: no previous landing
    expect(find.text('Bed: –   Bed+Flight: –'), findsOneWidget);
    await h.jump(flightMs: 1100); // harness uses 200 ms on the bed
    expect(find.text('Bed: 0.200 s   Bed+Flight: 1.300 s'), findsOneWidget);

    await tester.tap(h.startButton);
    await tester.pump();
    expect(find.text('Bed (s)'), findsOneWidget);
    expect(find.text('Bed+Flight (s)'), findsOneWidget);
    expect(find.text('1.300'), findsOneWidget); // table cell, unit in header
  });

  testWidgets('all table columns fit a narrow phone (German)', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final h = await AppHarness.launch(
      tester,
      prefs: {'show_contact_time': true, 'show_total_time': true},
    );
    tester.view.physicalSize = const Size(360, 3000);
    await h.jump(flightMs: 2345);
    await h.jump(flightMs: 2345);
    await tester.tap(find.text('Routine starten'));
    await tester.pump();
    for (var i = 0; i < 9; i++) {
      await h.jump(flightMs: 2345);
    }
    // A RenderFlex overflow would have failed the test by now.
    expect(find.text('Tuch+Flug (s)'), findsOneWidget);
  });

  group('more jump details', () {
    const on = {'show_jump_details': true};

    testWidgets('grey line under the last jump shows the chosen values', (
      tester,
    ) async {
      final h = await AppHarness.launch(
        tester,
        prefs: {
          ...on,
          'hidden_jump_details': ['pi'],
        },
      );
      await h.jump();
      final line = find.textContaining('Confidence 90 %');
      expect(line, findsOneWidget);
      final text = tester.widget<Text>(line).data!;
      expect(text, contains('Landing intensity'));
      expect(text, isNot(contains('Push-off intensity')));
    });

    testWidgets('off by default: no line, no tap sheet', (tester) async {
      final h = await AppHarness.launch(tester);
      await h.jump();
      expect(find.textContaining('Confidence'), findsNothing);
      await tester.tap(find.text('1.000 s'));
      await tester.pump();
      await h.advance(const Duration(milliseconds: 600));
      expect(find.text('Jump details'), findsNothing);
    });

    testWidgets('tapping the last jump, a table row or a bar opens details', (
      tester,
    ) async {
      final h = await AppHarness.launch(tester, prefs: on);
      await h.jump(flightMs: 1234);

      Future<void> expectSheet() async {
        await tester.pump();
        await h.advance(const Duration(milliseconds: 600));
        expect(find.text('Jump details'), findsOneWidget);
        expect(find.text('Final'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10)); // outside: close
        await tester.pump();
        await h.advance(const Duration(milliseconds: 600));
        expect(find.text('Jump details'), findsNothing);
      }

      await tester.tap(find.text('1.234 s'));
      await expectSheet();

      final chart = tester.getRect(find.byType(JumpChart));
      await tester.tapAt(Offset(chart.right - 9, chart.center.dy));
      await expectSheet();

      await tester.tap(h.startButton);
      await tester.pump();
      expect(find.text('Confidence (%)'), findsOneWidget); // table column
      await tester.tap(find.text('1.234').first); // row 1 (last = total row)
      await expectSheet();
    });

    testWidgets('many columns scroll sideways instead of overflowing', (
      tester,
    ) async {
      final h = await AppHarness.launch(
        tester,
        prefs: {...on, 'show_contact_time': true, 'show_total_time': true},
      );
      tester.view.physicalSize = const Size(360, 3000);
      await h.jump();
      await h.jump();
      await tester.tap(h.startButton);
      await tester.pump();
      await h.jump();
      expect(
        find.ancestor(
          of: find.text('Landing intensity'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('export: last N seconds or the recorded routine', (tester) async {
    final h = await AppHarness.launch(tester);
    await h.jump();
    await h.advance(const Duration(seconds: 40));
    await h.jump();

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();
    await h.advance(const Duration(milliseconds: 600));
    expect(find.text('Export as CSV'), findsOneWidget);
    expect(find.text('1 jump'), findsOneWidget); // last 30 s
    expect(find.text('2 jumps'), findsNWidgets(2)); // last 1 min, 5 min
    // No routine recorded yet: its entry is disabled.
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Recorded routine'))
          .enabled,
      isFalse,
    );

    await tester.tap(find.text('Last 1 min'));
    await tester.pump();
    await h.advance(const Duration(milliseconds: 600));
    expect(h.export.sharedJumps.single, hasLength(2));
    expect(h.export.shared, isEmpty);
  });

  testWidgets('an uncertain jump is marked in the routine table', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await h.jump();
    await tester.tap(h.startButton);
    await tester.pump();
    h.mock.emitJump(confidence: 30, reasons: 1);
    await h.advance(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
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

    testWidgets('starting and finishing a routine marks start and stop', (
      tester,
    ) async {
      final h = await AppHarness.launch(
        tester,
        prefs: {'jumps_per_routine': 2},
      );
      List<ChartEventType> types() =>
          container(tester)
              .read(sessionProvider)
              .events
              .map((e) => e.type)
              .toList();

      await h.jump();
      await tester.tap(h.startButton);
      // The chart legend keys off a 250 ms periodic "now" ticker; advance
      // enough to guarantee it has caught up (not just tester.pump()).
      await h.advance(const Duration(milliseconds: 300));
      expect(types(), [
        ChartEventType.connected,
        ChartEventType.routineStarted,
      ]);
      expect(find.text('Routine started'), findsOneWidget);

      await h.jump();
      await h.advance(const Duration(milliseconds: 300));
      expect(types(), [
        ChartEventType.connected,
        ChartEventType.routineStarted,
        ChartEventType.routineStopped,
      ]);
      expect(find.text('Routine stopped'), findsOneWidget);
    });

    testWidgets('cancelling (by button or inactivity) also marks stop', (
      tester,
    ) async {
      final h = await AppHarness.launch(tester);
      List<ChartEventType> types() =>
          container(tester)
              .read(sessionProvider)
              .events
              .map((e) => e.type)
              .toList();

      await h.jump();
      await tester.tap(h.startButton);
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(types(), [
        ChartEventType.connected,
        ChartEventType.routineStarted,
        ChartEventType.routineStopped,
      ]);

      await h.jump(); // fresh jump, eligible to start again
      await tester.tap(h.startButton);
      await tester.pump();
      await h.advance(const Duration(seconds: 5)); // default 4 s timeout
      expect(types(), [
        ChartEventType.connected,
        ChartEventType.routineStarted,
        ChartEventType.routineStopped,
        ChartEventType.routineStarted,
        ChartEventType.routineStopped,
      ]);
    });

    testWidgets('a 1-jump routine marks both start and stop at once', (
      tester,
    ) async {
      final h = await AppHarness.launch(
        tester,
        prefs: {'jumps_per_routine': 1},
      );
      await h.jump();
      await tester.tap(h.startButton);
      await tester.pump();
      expect(
        container(tester).read(sessionProvider).events.map((e) => e.type),
        [
          ChartEventType.connected,
          ChartEventType.routineStarted,
          ChartEventType.routineStopped,
        ],
      );
    });

    testWidgets(
      'an implausibly long jump is excluded but marked on the chart',
      (tester) async {
        final h = await AppHarness.launch(tester);
        await h.jump(flightMs: 1234);
        expect(find.text('1.234 s'), findsOneWidget);

        h.mock.emitJump(flightMs: 2600, contactMs: 200);
        // The chart legend keys off a 250 ms periodic "now" ticker; advance
        // enough to guarantee it has caught up.
        await h.advance(const Duration(milliseconds: 300));

        // The last-jump display is unchanged: the implausible one never became "last".
        expect(find.text('1.234 s'), findsOneWidget);
        expect(find.text('2.600 s'), findsNothing);

        final s = container(tester).read(sessionProvider);
        expect(s.lastJump!.flightMs, 1234);
        expect(s.history.length, 1);
        expect(s.events.map((e) => e.type), [
          ChartEventType.connected,
          ChartEventType.implausibleJump,
        ]);
        expect(find.text('Implausible jump (ignored)'), findsOneWidget);
      },
    );

    testWidgets('an implausible jump does not count toward the routine', (
      tester,
    ) async {
      final h = await AppHarness.launch(
        tester,
        prefs: {'jumps_per_routine': 2},
      );
      await h.jump();
      await tester.tap(h.startButton);
      await tester.pump();
      expect(find.text('Jump 1 of 2'), findsOneWidget);

      h.mock.emitJump(flightMs: 2600, contactMs: 200);
      await h.advance(const Duration(milliseconds: 100));
      expect(find.text('Jump 1 of 2'), findsOneWidget); // still waiting for #2

      await h.jump();
      expect(find.text('Routine complete'), findsOneWidget);
    });
  });
}
