import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenToF'**
  String get appTitle;

  /// No description provided for @lastJump.
  ///
  /// In en, this message translates to:
  /// **'Last jump'**
  String get lastJump;

  /// No description provided for @noJumpYet.
  ///
  /// In en, this message translates to:
  /// **'No jump yet'**
  String get noJumpYet;

  /// No description provided for @betaTag.
  ///
  /// In en, this message translates to:
  /// **'beta'**
  String get betaTag;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get heightLabel;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{value} s'**
  String seconds(String value);

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String meters(String value);

  /// No description provided for @percent.
  ///
  /// In en, this message translates to:
  /// **'{value} %'**
  String percent(int value);

  /// No description provided for @startRoutine.
  ///
  /// In en, this message translates to:
  /// **'Start routine'**
  String get startRoutine;

  /// No description provided for @cancelRoutine.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelRoutine;

  /// No description provided for @startDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Start is available while you are jumping: it counts the jump you just made as jump 1.'**
  String get startDisabledHint;

  /// No description provided for @routineTitle.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get routineTitle;

  /// No description provided for @routineRunning.
  ///
  /// In en, this message translates to:
  /// **'Jump {count} of {total}'**
  String routineRunning(int count, int total);

  /// No description provided for @routinePaused.
  ///
  /// In en, this message translates to:
  /// **'Sensor disconnected, routine paused'**
  String get routinePaused;

  /// No description provided for @routineComplete.
  ///
  /// In en, this message translates to:
  /// **'Routine complete'**
  String get routineComplete;

  /// No description provided for @routineCancelledUser.
  ///
  /// In en, this message translates to:
  /// **'Routine cancelled'**
  String get routineCancelledUser;

  /// No description provided for @routineCancelledInactivity.
  ///
  /// In en, this message translates to:
  /// **'Cancelled: no jump detected in time'**
  String get routineCancelledInactivity;

  /// No description provided for @tableJump.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get tableJump;

  /// No description provided for @tableFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight time'**
  String get tableFlight;

  /// No description provided for @tableHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get tableHeight;

  /// No description provided for @tableTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get tableTotal;

  /// No description provided for @missedEventWarning.
  ///
  /// In en, this message translates to:
  /// **'A sensor event was missed around this jump'**
  String get missedEventWarning;

  /// No description provided for @chartTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent jumps'**
  String get chartTitle;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @chartEmpty.
  ///
  /// In en, this message translates to:
  /// **'No jumps in this time window'**
  String get chartEmpty;

  /// No description provided for @chartNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get chartNow;

  /// No description provided for @chartPaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get chartPaused;

  /// No description provided for @pauseChart.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseChart;

  /// No description provided for @resumeChart.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeChart;

  /// No description provided for @chartSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'-{seconds} s'**
  String chartSecondsAgo(int seconds);

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export routine as CSV'**
  String get exportTooltip;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {message}'**
  String exportFailed(String message);

  /// No description provided for @connectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionConnected;

  /// No description provided for @connectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionConnecting;

  /// No description provided for @connectionDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectionDisconnected;

  /// No description provided for @connectionNotPaired.
  ///
  /// In en, this message translates to:
  /// **'No sensor paired'**
  String get connectionNotPaired;

  /// No description provided for @batteryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Battery {value} %'**
  String batteryTooltip(int value);

  /// No description provided for @batteryUnknown.
  ///
  /// In en, this message translates to:
  /// **'Battery unknown'**
  String get batteryUnknown;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @pairSensorHint.
  ///
  /// In en, this message translates to:
  /// **'Pair your OpenToF sensor to get started.'**
  String get pairSensorHint;

  /// No description provided for @sensorSection.
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get sensorSection;

  /// No description provided for @sensorPaired.
  ///
  /// In en, this message translates to:
  /// **'Paired sensor'**
  String get sensorPaired;

  /// No description provided for @sensorNone.
  ///
  /// In en, this message translates to:
  /// **'No sensor paired'**
  String get sensorNone;

  /// No description provided for @scanForSensors.
  ///
  /// In en, this message translates to:
  /// **'Scan for sensors'**
  String get scanForSensors;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @noSensorsFound.
  ///
  /// In en, this message translates to:
  /// **'No OpenToF sensors found. Make sure the sensor is powered on and nearby.'**
  String get noSensorsFound;

  /// No description provided for @unnamedSensor.
  ///
  /// In en, this message translates to:
  /// **'Unnamed sensor'**
  String get unnamedSensor;

  /// No description provided for @scanError.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {message}'**
  String scanError(String message);

  /// No description provided for @renameSensor.
  ///
  /// In en, this message translates to:
  /// **'Rename sensor'**
  String get renameSensor;

  /// No description provided for @sensorNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Sensor name'**
  String get sensorNameLabel;

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename sensor: {message}'**
  String renameFailed(String message);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @unpairSensor.
  ///
  /// In en, this message translates to:
  /// **'Unpair sensor'**
  String get unpairSensor;

  /// No description provided for @batterySection.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get batterySection;

  /// No description provided for @batteryLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Battery level'**
  String get batteryLevelLabel;

  /// No description provided for @batteryRemaining.
  ///
  /// In en, this message translates to:
  /// **'Estimated time remaining'**
  String get batteryRemaining;

  /// No description provided for @batteryRemainingUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get batteryRemainingUnknown;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @deviceInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Device info'**
  String get deviceInfoSection;

  /// No description provided for @manufacturerLabel.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get manufacturerLabel;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// No description provided for @serialNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get serialNumberLabel;

  /// No description provided for @hardwareRevisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Hardware revision'**
  String get hardwareRevisionLabel;

  /// No description provided for @firmwareRevisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Firmware revision'**
  String get firmwareRevisionLabel;

  /// No description provided for @algorithmLabel.
  ///
  /// In en, this message translates to:
  /// **'Detection algorithm'**
  String get algorithmLabel;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @routineSection.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get routineSection;

  /// No description provided for @inactivityTimeout.
  ///
  /// In en, this message translates to:
  /// **'Inactivity timeout'**
  String get inactivityTimeout;

  /// No description provided for @inactivityTimeoutHelp.
  ///
  /// In en, this message translates to:
  /// **'The routine is cancelled if no jump is detected within this time.'**
  String get inactivityTimeoutHelp;

  /// No description provided for @feedbackSection.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackSection;

  /// No description provided for @perJumpBeeps.
  ///
  /// In en, this message translates to:
  /// **'Beep on each jump'**
  String get perJumpBeeps;

  /// No description provided for @perJumpBeepsHelp.
  ///
  /// In en, this message translates to:
  /// **'Beeps may feel slightly delayed because of Bluetooth latency.'**
  String get perJumpBeepsHelp;

  /// No description provided for @finalSound.
  ///
  /// In en, this message translates to:
  /// **'Final jump sound'**
  String get finalSound;

  /// No description provided for @chartSection.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get chartSection;

  /// No description provided for @chartWindow.
  ///
  /// In en, this message translates to:
  /// **'Time window'**
  String get chartWindow;

  /// No description provided for @window30s.
  ///
  /// In en, this message translates to:
  /// **'30 s'**
  String get window30s;

  /// No description provided for @window1m.
  ///
  /// In en, this message translates to:
  /// **'1 min'**
  String get window1m;

  /// No description provided for @window5m.
  ///
  /// In en, this message translates to:
  /// **'5 min'**
  String get window5m;

  /// No description provided for @jumpsPerRoutine.
  ///
  /// In en, this message translates to:
  /// **'Jumps per routine'**
  String get jumpsPerRoutine;

  /// No description provided for @jumpsPerRoutineHelp.
  ///
  /// In en, this message translates to:
  /// **'A routine ends after this many jumps. Applies to the next routine you start.'**
  String get jumpsPerRoutineHelp;

  /// No description provided for @jumpsPerRoutineInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from {min} to {max}'**
  String jumpsPerRoutineInvalid(int min, int max);

  /// No description provided for @appearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @foregroundChannelName.
  ///
  /// In en, this message translates to:
  /// **'Sensor connection'**
  String get foregroundChannelName;

  /// No description provided for @foregroundNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Keeping the sensor connection alive'**
  String get foregroundNotificationText;

  /// No description provided for @exitAction.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitAction;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit app'**
  String get exitApp;

  /// No description provided for @exitConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit OpenToF?'**
  String get exitConfirmTitle;

  /// No description provided for @exitConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This disconnects the sensor, stops background operation and cancels a running routine. Your sensor stays paired.'**
  String get exitConfirmBody;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressBackAgainToExit;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get appVersionLabel;

  /// No description provided for @debugSection.
  ///
  /// In en, this message translates to:
  /// **'Developer (debug build)'**
  String get debugSection;

  /// No description provided for @useSimulatedSensor.
  ///
  /// In en, this message translates to:
  /// **'Use simulated sensor'**
  String get useSimulatedSensor;

  /// No description provided for @simStartBouncing.
  ///
  /// In en, this message translates to:
  /// **'Start bouncing'**
  String get simStartBouncing;

  /// No description provided for @simStopBouncing.
  ///
  /// In en, this message translates to:
  /// **'Stop bouncing'**
  String get simStopBouncing;

  /// No description provided for @simSingleJump.
  ///
  /// In en, this message translates to:
  /// **'Single jump'**
  String get simSingleJump;

  /// No description provided for @simDropLanding.
  ///
  /// In en, this message translates to:
  /// **'Drop next landing'**
  String get simDropLanding;

  /// No description provided for @simDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Simulate disconnect'**
  String get simDisconnect;

  /// No description provided for @simReconnect.
  ///
  /// In en, this message translates to:
  /// **'Simulate reconnect'**
  String get simReconnect;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
