// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenToF';

  @override
  String get lastJump => 'Last jump';

  @override
  String get noJumpYet => 'No jump yet';

  @override
  String get betaTag => 'beta';

  @override
  String get heightLabel => 'Height';

  @override
  String seconds(String value) {
    return '$value s';
  }

  @override
  String meters(String value) {
    return '$value m';
  }

  @override
  String percent(int value) {
    return '$value %';
  }

  @override
  String get startRoutine => 'Start routine';

  @override
  String get cancelRoutine => 'Cancel';

  @override
  String get startDisabledHint =>
      'Start is available while you are jumping: it counts the jump you just made as jump 1.';

  @override
  String get routineTitle => 'Routine';

  @override
  String routineRunning(int count, int total) {
    return 'Jump $count of $total';
  }

  @override
  String get routinePaused => 'Sensor disconnected, routine paused';

  @override
  String get routineComplete => 'Routine complete';

  @override
  String get routineCancelledUser => 'Routine cancelled';

  @override
  String get routineCancelledInactivity =>
      'Cancelled: no jump detected in time';

  @override
  String get tableJump => 'Jump';

  @override
  String get tableFlight => 'Flight time';

  @override
  String get tableHeight => 'Height';

  @override
  String get tableTotal => 'Total';

  @override
  String get missedEventWarning => 'A sensor event was missed around this jump';

  @override
  String get chartTitle => 'Recent jumps';

  @override
  String get clear => 'Clear';

  @override
  String get chartEmpty => 'No jumps in this time window';

  @override
  String get chartNow => 'now';

  @override
  String get chartPaused => 'paused';

  @override
  String get chartRoutineStarted => 'Routine started';

  @override
  String get chartRoutineStopped => 'Routine stopped';

  @override
  String get chartImplausibleJump => 'Implausible jump (ignored)';

  @override
  String get pauseChart => 'Pause';

  @override
  String get resumeChart => 'Resume';

  @override
  String chartSecondsAgo(int seconds) {
    return '-$seconds s';
  }

  @override
  String get export => 'Export';

  @override
  String get exportTooltip => 'Export routine as CSV';

  @override
  String exportFailed(String message) {
    return 'Export failed: $message';
  }

  @override
  String get connectionConnected => 'Connected';

  @override
  String get connectionConnecting => 'Connecting…';

  @override
  String get connectionDisconnected => 'Disconnected';

  @override
  String get connectionNotPaired => 'No sensor paired';

  @override
  String batteryTooltip(int value) {
    return 'Battery $value %';
  }

  @override
  String get batteryUnknown => 'Battery unknown';

  @override
  String get settings => 'Settings';

  @override
  String get pairSensorHint => 'Pair your OpenToF sensor to get started.';

  @override
  String get sensorSection => 'Sensor';

  @override
  String get sensorPaired => 'Paired sensor';

  @override
  String get sensorNone => 'No sensor paired';

  @override
  String get scanForSensors => 'Scan for sensors';

  @override
  String get scanning => 'Scanning…';

  @override
  String get noSensorsFound =>
      'No OpenToF sensors found. Make sure the sensor is powered on and nearby.';

  @override
  String get unnamedSensor => 'Unnamed sensor';

  @override
  String scanError(String message) {
    return 'Scan failed: $message';
  }

  @override
  String get renameSensor => 'Rename sensor';

  @override
  String get sensorNameLabel => 'Sensor name';

  @override
  String renameFailed(String message) {
    return 'Could not rename sensor: $message';
  }

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get unpairSensor => 'Unpair sensor';

  @override
  String get batterySection => 'Battery';

  @override
  String get batteryLevelLabel => 'Battery level';

  @override
  String get batteryRemaining => 'Estimated time remaining';

  @override
  String get batteryRemainingUnknown => 'Not enough data yet';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get deviceInfoSection => 'Device info';

  @override
  String get manufacturerLabel => 'Manufacturer';

  @override
  String get modelLabel => 'Model';

  @override
  String get serialNumberLabel => 'Serial number';

  @override
  String get hardwareRevisionLabel => 'Hardware revision';

  @override
  String get firmwareRevisionLabel => 'Firmware revision';

  @override
  String get algorithmLabel => 'Detection algorithm';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get routineSection => 'Routine';

  @override
  String get inactivityTimeout => 'Inactivity timeout';

  @override
  String get inactivityTimeoutHelp =>
      'The routine is cancelled if no jump is detected within this time.';

  @override
  String get feedbackSection => 'Feedback';

  @override
  String get perJumpBeeps => 'Beep on each jump';

  @override
  String get perJumpBeepsHelp =>
      'Beeps may feel slightly delayed because of Bluetooth latency.';

  @override
  String get finalSound => 'Final jump sound';

  @override
  String get chartSection => 'Chart';

  @override
  String get chartWindow => 'Time window';

  @override
  String get window30s => '30 s';

  @override
  String get window1m => '1 min';

  @override
  String get window5m => '5 min';

  @override
  String get jumpsPerRoutine => 'Jumps per routine';

  @override
  String get jumpsPerRoutineHelp =>
      'A routine ends after this many jumps. Applies to the next routine you start.';

  @override
  String jumpsPerRoutineInvalid(int min, int max) {
    return 'Enter a whole number from $min to $max';
  }

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get foregroundChannelName => 'Sensor connection';

  @override
  String get foregroundNotificationText =>
      'Keeping the sensor connection alive';

  @override
  String get exitAction => 'Exit';

  @override
  String get exitApp => 'Exit app';

  @override
  String get exitConfirmTitle => 'Exit OpenToF?';

  @override
  String get exitConfirmBody =>
      'This disconnects the sensor, stops background operation and cancels a running routine. Your sensor stays paired.';

  @override
  String get pressBackAgainToExit => 'Press back again to exit';

  @override
  String get aboutSection => 'About';

  @override
  String get appVersionLabel => 'Version';

  @override
  String get debugSection => 'Developer (debug build)';

  @override
  String get useSimulatedSensor => 'Use simulated sensor';

  @override
  String get simStartBouncing => 'Start bouncing';

  @override
  String get simStopBouncing => 'Stop bouncing';

  @override
  String get simSingleJump => 'Single jump';

  @override
  String get simDropJump => 'Drop next jump';

  @override
  String get simDisconnect => 'Simulate disconnect';

  @override
  String get simReconnect => 'Simulate reconnect';

  @override
  String get uncertainJumpWarning => 'The sensor is unsure about this jump';

  @override
  String confidenceValue(int value) {
    return 'Confidence: $value %';
  }

  @override
  String get versionMismatchTitle => 'Sensor firmware doesn\'t match this app';

  @override
  String versionMismatchBody(String app, String firmware) {
    return 'App $app, sensor firmware $firmware. Update the older one, otherwise jumps may not be received.';
  }

  @override
  String get sensorDetails => 'Sensor details';

  @override
  String get algorithmSection => 'Detection algorithm';

  @override
  String get protocolVersionLabel => 'Protocol version';

  @override
  String get bootCountLabel => 'Sensor starts';

  @override
  String get confidenceKindLabel => 'Confidence';

  @override
  String get confidenceKindNone => 'Not provided';

  @override
  String get confidenceKindHeuristic => 'Estimate (higher = more reliable)';

  @override
  String get confidenceKindCalibrated => 'Calibrated probability';

  @override
  String get reasonsLabel => 'Reasons for uncertainty';

  @override
  String get customFieldsLabel => 'Extra values per jump';

  @override
  String get noneProvided => 'None';

  @override
  String get fieldOnTakeoff => 'at takeoff';

  @override
  String get fieldOnLanding => 'at landing';

  @override
  String get fieldOnBoth => 'at takeoff and landing';

  @override
  String get fieldRelative => 'relative values';

  @override
  String get displaySection => 'Jump display';

  @override
  String get showContactTime => 'Show time on bed';

  @override
  String get showContactTimeHelp => 'Contact time before each jump';

  @override
  String get showTotalTime => 'Show total jump time';

  @override
  String get showTotalTimeHelp => 'Time on bed + flight time';

  @override
  String get contactLabel => 'Bed';

  @override
  String get totalTimeLabel => 'Bed+Flight';

  @override
  String columnSeconds(String label) {
    return '$label (s)';
  }

  @override
  String get exportChooserTitle => 'Export as CSV';

  @override
  String get exportRoutine => 'Recorded routine';

  @override
  String exportLastWindow(String window) {
    return 'Last $window';
  }

  @override
  String jumpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jumps',
      one: '1 jump',
    );
    return '$_temp0';
  }

  @override
  String get showJumpDetails => 'Show more jump details';

  @override
  String get showJumpDetailsHelp =>
      'Extra values from the sensor under the last jump and in the routine table. Tap a jump for all its details.';

  @override
  String get detailsToShow => 'Values to show';

  @override
  String get detailsNoSensorValues =>
      'Connect a sensor to see which values it provides.';

  @override
  String get jumpDetailsTitle => 'Jump details';

  @override
  String get landedAtLabel => 'Landed at';

  @override
  String get flightTimeLabel => 'Flight time';

  @override
  String get contactTimeLabel => 'Time on bed';

  @override
  String get totalJumpTimeLabel => 'Total time (bed + flight)';

  @override
  String get stageLabel => 'Status';

  @override
  String get stageFinal => 'Final';

  @override
  String get stageProvisional => 'Provisional (sensor\'s first estimate)';
}
