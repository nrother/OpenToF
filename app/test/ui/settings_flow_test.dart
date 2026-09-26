import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentof_app/ui/brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

/// Route transitions need a first frame to start and then time to finish, so
/// a single large pump is not enough.
Future<void> settleRoute(AppHarness h) async {
  await h.tester.pump();
  await h.advance(const Duration(milliseconds: 600));
}

Future<void> openSettings(AppHarness h) async {
  await h.tester.tap(find.byIcon(Icons.settings));
  await settleRoute(h);
}

/// Settings, then the sensor details page (tap on the paired sensor).
Future<void> openSensor(AppHarness h) async {
  await openSettings(h);
  await h.tester.tap(find.text('OpenToF-Mock'));
  await settleRoute(h);
}

void main() {
  testWidgets('settings show the app version', (tester) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('0.4.3 (4)'), findsOneWidget);
  });

  testWidgets('back twice exits, a single back only shows a hint', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(h.exits, 0);

    await h.advance(const Duration(seconds: 1));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(h.exits, 1);
  });

  testWidgets('a second back after the window only shows the hint again', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await tester.binding.handlePopRoute();
    await h.advance(const Duration(seconds: 3));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(h.exits, 0);
  });

  testWidgets('back in settings returns to the main screen, no exit', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);
    await tester.binding.handlePopRoute();
    await settleRoute(h);
    expect(find.text('Last jump'), findsOneWidget);
    expect(h.exits, 0);
  });

  testWidgets('Exit app in settings asks first and can be cancelled', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);

    await tester.tap(find.text('Exit app'));
    await settleRoute(h);
    expect(find.text('Exit OpenToF?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settleRoute(h);
    expect(h.exits, 0);

    await tester.tap(find.text('Exit app'));
    await settleRoute(h);
    await tester.tap(find.text('Exit'));
    await settleRoute(h);
    expect(h.exits, 1);
  });

  testWidgets('mark shows in the app bar (narrow phone), logo in settings', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    tester.view.physicalSize = const Size(360, 800);
    await h.advance(const Duration(milliseconds: 100));
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.byType(BrandLogo), findsNothing);
    expect(find.text('OpenToF'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await openSettings(h);
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('German UI uses German strings and decimal comma', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final h = await AppHarness.launch(tester);
    expect(find.text('Letzter Sprung'), findsOneWidget);
    expect(find.text('Routine starten'), findsOneWidget);
    await h.jump(flightMs: 1234);
    expect(find.text('1,234 s'), findsOneWidget);
  });

  testWidgets('first launch: main screen, pair via hint, scan and select', (
    tester,
  ) async {
    final h = await AppHarness.launch(
      tester,
      paired: false,
      prefs: {'use_mock_sensor': true},
    );
    expect(find.text('Last jump'), findsOneWidget); // starts on the main screen
    await tester.tap(find.text('Pair your OpenToF sensor to get started.'));
    await settleRoute(h);
    expect(find.text('Scan for sensors'), findsOneWidget);

    await tester.tap(find.text('Scan for sensors'));
    await h.advance(const Duration(seconds: 1));
    expect(find.text('OpenToF-Mock'), findsOneWidget);

    await tester.tap(find.text('OpenToF-Mock'));
    await h.advance(const Duration(seconds: 1));
    await tester.binding.handlePopRoute();
    await settleRoute(h);
    expect(find.text('Last jump'), findsOneWidget);
    expect(find.text('Pair your OpenToF sensor to get started.'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('paired_device_id'),
      'mock-1',
    );
  });

  testWidgets('settings persist: toggles and chart window', (tester) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);

    expect(find.text('4 s'), findsOneWidget); // default inactivity timeout

    await tester.tap(find.text('Beep on each jump'));
    await tester.pump();
    await tester.tap(find.text('5 min'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('per_jump_beep'), isFalse);
    expect(prefs.getInt('window_s'), 300);
    expect(prefs.getBool('final_beep') ?? true, isTrue);
  });

  testWidgets('rename updates the displayed sensor name', (tester) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);
    expect(find.text('OpenToF-Mock'), findsOneWidget);

    // pumpAndSettle never settles here (the app has periodic timers).
    await tester.tap(find.byIcon(Icons.edit));
    await settleRoute(h);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Gym A',
    );
    await tester.tap(find.text('Save'));
    await settleRoute(h);

    expect(find.text('Gym A'), findsOneWidget);
    expect(await h.mock.readName(), 'Gym A');
  });

  testWidgets('unpair returns to the main screen with the pairing hint', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);

    await tester.tap(find.text('Unpair sensor'));
    await settleRoute(h);

    expect(
      find.text('Pair your OpenToF sensor to get started.'),
      findsOneWidget,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('paired_device_id'),
      isNull,
    );
  });

  testWidgets('battery level and missing estimate show on the sensor page', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    h.mock.setBatteryLevel(72);
    await h.advance(const Duration(milliseconds: 100));
    await openSensor(h);

    expect(find.text('72 %'), findsOneWidget);
    expect(find.text('Not enough data yet'), findsOneWidget);
  });

  testWidgets('sensor page shows device info read from the sensor', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);
    expect(find.text('Device info'), findsNothing); // moved to its own page
    await tester.tap(find.text('OpenToF-Mock'));
    await settleRoute(h);

    expect(find.text('Device info'), findsOneWidget);
    expect(find.text('OpenToF'), findsWidgets); // manufacturer (+ app title)
    expect(find.text('OpenToF Sensor (simulated)'), findsOneWidget);
    expect(find.text('MOCK-0001'), findsOneWidget);
    expect(find.text('0.1'), findsOneWidget);
    expect(find.text('0.4.0'), findsOneWidget);
    expect(find.text('MockJumpDetector'), findsOneWidget);
  });

  testWidgets('sensor page describes the algorithm\'s event data', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await openSensor(h);

    expect(find.text('Protocol version'), findsOneWidget);
    expect(find.text('Estimate (higher = more reliable)'), findsOneWidget);
    expect(find.text('• mock: simulated uncertainty'), findsOneWidget);
    expect(find.text('Push-off intensity'), findsOneWidget);
    expect(find.text('at landing · relative values · li · u8'), findsOneWidget);
  });

  testWidgets('no warning while app and firmware share MAJOR.MINOR', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester); // app 0.4.3, firmware 0.4.0
    await openSettings(h);
    expect(find.text("Sensor firmware doesn't match this app"), findsNothing);
  });

  testWidgets('settings and the sensor page warn on a version mismatch', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester, appVersion: '0.5.0 (7)');
    await openSettings(h);
    expect(find.text("Sensor firmware doesn't match this app"), findsOneWidget);
    expect(
      find.textContaining('App 0.5.0, sensor firmware 0.4.0'),
      findsOneWidget,
    );
    await tester.tap(find.text('OpenToF-Mock'));
    await settleRoute(h);
    expect(find.text("Sensor firmware doesn't match this app"), findsOneWidget);
  });

  testWidgets('more jump details: pick which sensor values show', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);
    expect(find.text('Values to show'), findsNothing);
    await tester.tap(find.text('Show more jump details'));
    await tester.pump();

    expect(find.text('Values to show'), findsOneWidget);
    expect(find.text('Confidence (%)'), findsOneWidget);
    expect(find.text('Push-off intensity'), findsOneWidget);
    expect(find.text('Landing intensity'), findsOneWidget);

    await tester.tap(find.text('Landing intensity'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('show_jump_details'), isTrue);
    expect(prefs.getStringList('hidden_jump_details'), ['li']);
  });

  testWidgets('time on bed and total time toggles persist', (tester) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);
    await tester.tap(find.text('Show time on bed'));
    await tester.tap(find.text('Show total jump time'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('show_contact_time'), isTrue);
    expect(prefs.getBool('show_total_time'), isTrue);
  });

  testWidgets('device info section is hidden while no sensor is paired', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester, paired: false);
    await tester.tap(find.text('Pair your OpenToF sensor to get started.'));
    await settleRoute(h);
    expect(find.text('Device info'), findsNothing);
  });

  testWidgets('routine length is an integer field: valid values persist', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    await openSettings(h);
    expect(find.widgetWithText(TextField, '10'), findsOneWidget); // default

    await tester.enterText(find.widgetWithText(TextField, '10'), '25');
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('jumps_per_routine'), 25);
  });

  testWidgets(
    'routine length: 0 is rejected, and reverts when leaving the field',
    (tester) async {
      final h = await AppHarness.launch(
        tester,
        prefs: {'jumps_per_routine': 7},
      );
      await openSettings(h);
      final field = find.byType(TextField);

      await tester.enterText(field, '0');
      await tester.pump();
      expect(find.textContaining('whole number from 1 to 999'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getInt('jumps_per_routine'),
        7,
      ); // invalid value is not saved

      await tester.enterText(field, '');
      await tester.pump();
      expect(find.textContaining('whole number'), findsOneWidget);

      // Tapping elsewhere unfocuses the field: the last valid value returns.
      await tester.tap(find.text('Routine'));
      await tester.pump();
      expect(find.widgetWithText(TextField, '7'), findsOneWidget);
      expect(find.textContaining('whole number'), findsNothing);
    },
  );

  testWidgets('theme selector: system by default, light and dark selectable', (
    tester,
  ) async {
    final h = await AppHarness.launch(tester);
    ThemeMode mode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    expect(mode(), ThemeMode.system);

    await openSettings(h);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(mode(), ThemeMode.dark);
    expect(
      (await SharedPreferences.getInstance()).getString('theme_mode'),
      'dark',
    );

    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(mode(), ThemeMode.light);
  });
}
