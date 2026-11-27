// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'OpenToF';

  @override
  String get lastJump => 'Letzter Sprung';

  @override
  String get noJumpYet => 'Noch kein Sprung';

  @override
  String get betaTag => 'Beta';

  @override
  String get heightLabel => 'Höhe';

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
  String get startRoutine => 'Übung starten';

  @override
  String get cancelRoutine => 'Abbrechen';

  @override
  String get startDisabledHint =>
      'Der Start ist möglich, solange du springst: Der Sprung, in dem du gerade bist, zählt als Sprung 1.';

  @override
  String get routineTitle => 'Übung';

  @override
  String routineRunning(int count, int total) {
    return 'Sprung $count von $total';
  }

  @override
  String get routinePaused => 'Sensor getrennt, Übung pausiert';

  @override
  String get routineComplete => 'Übung abgeschlossen';

  @override
  String get routineCancelledUser => 'Übung abgebrochen';

  @override
  String get routineCancelledInactivity =>
      'Abgebrochen: Kein Sprung rechtzeitig erkannt';

  @override
  String get tableJump => 'Sprung';

  @override
  String get tableFlight => 'Flugzeit';

  @override
  String get tableHeight => 'Höhe';

  @override
  String get tableTotal => 'Summe';

  @override
  String get missedEventWarning =>
      'Rund um diesen Sprung wurde ein Sensor-Ereignis verpasst';

  @override
  String get chartTitle => 'Letzte Sprünge';

  @override
  String get clear => 'Leeren';

  @override
  String get chartEmpty => 'Keine Sprünge in diesem Zeitfenster';

  @override
  String get chartNow => 'jetzt';

  @override
  String get chartPaused => 'pausiert';

  @override
  String get chartRoutineStarted => 'Übung gestartet';

  @override
  String get chartRoutineStopped => 'Übung beendet';

  @override
  String get chartImplausibleJump => 'Unplausibler Sprung (ignoriert)';

  @override
  String get pauseChart => 'Pause';

  @override
  String get resumeChart => 'Fortsetzen';

  @override
  String chartSecondsAgo(int seconds) {
    return '-$seconds s';
  }

  @override
  String get export => 'Exportieren';

  @override
  String get exportTooltip => 'Übung als CSV exportieren';

  @override
  String exportFailed(String message) {
    return 'Export fehlgeschlagen: $message';
  }

  @override
  String get connectionConnected => 'Verbunden';

  @override
  String get connectionConnecting => 'Verbinde…';

  @override
  String get connectionDisconnected => 'Getrennt';

  @override
  String get connectionNotPaired => 'Kein Sensor gekoppelt';

  @override
  String batteryTooltip(int value) {
    return 'Akku $value %';
  }

  @override
  String get batteryUnknown => 'Akkustand unbekannt';

  @override
  String get settings => 'Einstellungen';

  @override
  String get pairSensorHint => 'Koppele deinen OpenToF-Sensor, um zu starten.';

  @override
  String get sensorSection => 'Sensor';

  @override
  String get sensorPaired => 'Gekoppelter Sensor';

  @override
  String get sensorNone => 'Kein Sensor gekoppelt';

  @override
  String get scanForSensors => 'Nach Sensoren suchen';

  @override
  String get scanning => 'Suche läuft…';

  @override
  String get noSensorsFound =>
      'Keine OpenToF-Sensoren gefunden. Stelle sicher, dass der Sensor eingeschaltet und in der Nähe ist.';

  @override
  String get unnamedSensor => 'Unbenannter Sensor';

  @override
  String scanError(String message) {
    return 'Suche fehlgeschlagen: $message';
  }

  @override
  String get renameSensor => 'Sensor umbenennen';

  @override
  String get sensorNameLabel => 'Sensorname';

  @override
  String renameFailed(String message) {
    return 'Sensor konnte nicht umbenannt werden: $message';
  }

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get unpairSensor => 'Sensor entkoppeln';

  @override
  String get batterySection => 'Akku';

  @override
  String get batteryLevelLabel => 'Akkustand';

  @override
  String get batteryRemaining => 'Geschätzte Restlaufzeit';

  @override
  String get batteryRemainingUnknown => 'Noch nicht genug Daten';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get deviceInfoSection => 'Geräteinfo';

  @override
  String get manufacturerLabel => 'Hersteller';

  @override
  String get modelLabel => 'Modell';

  @override
  String get serialNumberLabel => 'Seriennummer';

  @override
  String get hardwareRevisionLabel => 'Hardware-Revision';

  @override
  String get firmwareRevisionLabel => 'Firmware-Revision';

  @override
  String get algorithmLabel => 'Erkennungsalgorithmus';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get routineSection => 'Übung';

  @override
  String get inactivityTimeout => 'Inaktivitäts-Timeout';

  @override
  String get inactivityTimeoutHelp =>
      'Die Übung wird abgebrochen, wenn in dieser Zeit kein Sprung erkannt wird.';

  @override
  String get feedbackSection => 'Rückmeldung';

  @override
  String get perJumpBeeps => 'Piepton bei jedem Sprung';

  @override
  String get perJumpBeepsHelp =>
      'Die Pieptöne können wegen der Bluetooth-Latenz leicht verzögert wirken.';

  @override
  String get finalSound => 'Ton beim letzten Sprung';

  @override
  String get chartSection => 'Diagramm';

  @override
  String get chartWindow => 'Zeitfenster';

  @override
  String get window30s => '30 s';

  @override
  String get window1m => '1 min';

  @override
  String get window5m => '5 min';

  @override
  String get jumpsPerRoutine => 'Sprünge pro Übung';

  @override
  String get jumpsPerRoutineHelp =>
      'Eine Übung endet nach dieser Anzahl Sprünge. Gilt für die nächste gestartete Übung.';

  @override
  String jumpsPerRoutineInvalid(int min, int max) {
    return 'Ganze Zahl von $min bis $max eingeben';
  }

  @override
  String get appearanceSection => 'Darstellung';

  @override
  String get themeMode => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get foregroundChannelName => 'Sensorverbindung';

  @override
  String get foregroundNotificationText => 'Die Sensorverbindung bleibt aktiv';

  @override
  String get exitAction => 'Beenden';

  @override
  String get exitApp => 'App beenden';

  @override
  String get exitConfirmTitle => 'OpenToF beenden?';

  @override
  String get exitConfirmBody =>
      'Der Sensor wird getrennt, der Hintergrundbetrieb gestoppt und eine laufende Übung abgebrochen. Der Sensor bleibt gekoppelt.';

  @override
  String get pressBackAgainToExit => 'Zum Beenden erneut Zurück drücken';

  @override
  String get aboutSection => 'Über die App';

  @override
  String get appVersionLabel => 'Version';

  @override
  String get debugSection => 'Entwickler (Debug-Build)';

  @override
  String get useSimulatedSensor => 'Simulierten Sensor verwenden';

  @override
  String get simStartBouncing => 'Springen starten';

  @override
  String get simStopBouncing => 'Springen stoppen';

  @override
  String get simSingleJump => 'Einzelner Sprung';

  @override
  String get simDropJump => 'Nächsten Sprung verlieren';

  @override
  String get simDisconnect => 'Trennung simulieren';

  @override
  String get simReconnect => 'Wiederverbindung simulieren';

  @override
  String get uncertainJumpWarning =>
      'Der Sensor ist sich bei diesem Sprung unsicher';

  @override
  String confidenceValue(int value) {
    return 'Konfidenz: $value %';
  }

  @override
  String get protocolMismatchTitle => 'Sensor nutzt ein anderes Protokoll';

  @override
  String get protocolMismatchBody =>
      'Seine Sprünge werden ignoriert. Bitte die Sensor-Firmware oder diese App aktualisieren.';

  @override
  String get versionMismatchTitle => 'Sensor-Firmware passt nicht zur App';

  @override
  String versionMismatchBody(String app, String firmware) {
    return 'App $app, Sensor-Firmware $firmware. Bitte die ältere Version aktualisieren, sonst kommen Sprünge evtl. nicht an.';
  }

  @override
  String get sensorDetails => 'Sensor-Details';

  @override
  String get algorithmSection => 'Erkennungsalgorithmus';

  @override
  String get confidenceKindLabel => 'Konfidenz';

  @override
  String get confidenceKindNone => 'Nicht angegeben';

  @override
  String get confidenceKindHeuristic => 'Schätzung (höher = zuverlässiger)';

  @override
  String get confidenceKindCalibrated => 'Kalibrierte Wahrscheinlichkeit';

  @override
  String get reasonsLabel => 'Gründe für Unsicherheit';

  @override
  String get customFieldsLabel => 'Zusatzwerte pro Sprung';

  @override
  String get noneProvided => 'Keine';

  @override
  String get fieldOnTakeoff => 'beim Absprung';

  @override
  String get fieldOnLanding => 'bei der Landung';

  @override
  String get fieldOnBoth => 'bei Absprung und Landung';

  @override
  String get fieldRelative => 'relative Werte';

  @override
  String get displaySection => 'Sprunganzeige';

  @override
  String get showContactTime => 'Zeit auf dem Tuch anzeigen';

  @override
  String get showContactTimeHelp => 'Kontaktzeit vor jedem Sprung';

  @override
  String get showTotalTime => 'Gesamte Sprungzeit anzeigen';

  @override
  String get showTotalTimeHelp => 'Zeit auf dem Tuch + Flugzeit';

  @override
  String get contactLabel => 'Tuch';

  @override
  String get totalTimeLabel => 'Tuch+Flug';

  @override
  String columnSeconds(String label) {
    return '$label (s)';
  }

  @override
  String get showFlightDelta => 'Änderung zum vorherigen Sprung anzeigen';

  @override
  String get showFlightDeltaHelp =>
      'Unterschied der Flugzeit in ms (blau = länger, rot = kürzer)';

  @override
  String get deltaLabel => 'Δ';

  @override
  String columnMilliseconds(String label) {
    return '$label (ms)';
  }

  @override
  String milliseconds(String value) {
    return '$value ms';
  }

  @override
  String get exportChooserTitle => 'Als CSV exportieren';

  @override
  String get exportRoutine => 'Aufgezeichnete Übung';

  @override
  String exportLastWindow(String window) {
    return 'Letzte $window';
  }

  @override
  String jumpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sprünge',
      one: '1 Sprung',
    );
    return '$_temp0';
  }

  @override
  String get showJumpDetails => 'Mehr Sprungdetails anzeigen';

  @override
  String get showJumpDetailsHelp =>
      'Zusatzwerte des Sensors unter dem letzten Sprung und in der Übungstabelle. Sprung antippen für alle Details.';

  @override
  String get detailsToShow => 'Angezeigte Werte';

  @override
  String get detailsNoSensorValues =>
      'Sensor verbinden, um zu sehen, welche Werte er liefert.';

  @override
  String get jumpDetailsTitle => 'Sprungdetails';

  @override
  String get landedAtLabel => 'Gelandet um';

  @override
  String get flightTimeLabel => 'Flugzeit';

  @override
  String get contactTimeLabel => 'Zeit auf dem Tuch';

  @override
  String get totalJumpTimeLabel => 'Gesamtzeit (Tuch + Flug)';

  @override
  String get stageLabel => 'Status';

  @override
  String get stageFinal => 'Endgültig';

  @override
  String get stageProvisional => 'Vorläufig (erste Schätzung des Sensors)';

  @override
  String get ledHelpTile => 'LED-Signale';

  @override
  String get ledHelpTileHelp => 'Was die Lichter am Sensor bedeuten';

  @override
  String get ledHelpTitle => 'LED-Signale';

  @override
  String get ledHelpIntro =>
      'Orange zeigt den Zustand des Sensors, Rot das Laden. Beide sitzen dicht beieinander und sind leicht zu verwechseln. Jeder Balken zeigt etwa 2 s; farbig = an.';

  @override
  String get ledOrangeSection => 'Oranges Licht';

  @override
  String get ledWaitingTitle => 'Langsames Blinken';

  @override
  String get ledWaitingTiming => '0,3 s an, 0,7 s aus, fortlaufend';

  @override
  String get ledWaitingMeaning => 'Wach, wartet auf die App.';

  @override
  String get ledConnectedTitle => 'Dauerhaft an';

  @override
  String get ledConnectedTiming => 'Dauerlicht';

  @override
  String get ledConnectedMeaning => 'Mit der App verbunden.';

  @override
  String get ledGoingToSleepTitle => '6-mal schnelles Blinken, dann aus';

  @override
  String get ledGoingToSleepTiming => '0,15 s an, 0,15 s aus, 6-mal';

  @override
  String get ledGoingToSleepMeaning =>
      'Schläft ein nach 1 min ohne App und ohne Sprung.';

  @override
  String get ledAsleepTitle => 'Aus';

  @override
  String get ledAsleepTiming => 'Kein Licht';

  @override
  String get ledAsleepMeaning =>
      'Schläft oder Akku leer. Zum Aufwecken schütteln (dauert bis zu 4 s).';

  @override
  String get ledWokeUpTitle => '3-mal kurzes Blinken, dann langsames Blinken';

  @override
  String get ledWokeUpTiming => '0,08 s an, 0,08 s aus, 3-mal';

  @override
  String get ledWokeUpMeaning => 'Durch Bewegung aufgewacht.';

  @override
  String get ledErrorTitle => 'Schnelles Blinken ohne Ende';

  @override
  String get ledErrorTiming => '0,1 s an, 0,1 s aus, ohne Ende';

  @override
  String get ledErrorMeaning =>
      'Start fehlgeschlagen. Reset drücken oder Strom kurz trennen.';

  @override
  String get ledRedSection => 'Rotes Licht (Laden)';

  @override
  String get ledRedBody => 'Leuchtet nur, solange USB angeschlossen ist.';

  @override
  String get ledChargingTitle => 'Kurzes Aufblitzen etwa einmal pro Sekunde';

  @override
  String get ledChargingTiming => '0,16 s an, 1,12 s aus, fortlaufend';

  @override
  String get ledChargingMeaning =>
      'Lädt. Die letzten 10 % können noch 30 min oder länger dauern.';

  @override
  String get ledChargedTitle => 'Knapp eine Minute an, dann aus';

  @override
  String get ledChargedTiming => 'Dauerlicht für etwa 50 s';

  @override
  String get ledChargedMeaning => 'Voll geladen.';

  @override
  String get ledChargeOffTitle => 'Aus trotz USB-Anschluss';

  @override
  String get ledChargeOffTiming => 'Kein Licht';

  @override
  String get ledChargeOffMeaning =>
      'Meist voll. Ging es nie an, Kabel und Stromquelle prüfen.';

  @override
  String get ledRedSource =>
      'Laut Datenblatt des Ladechips; an echten Sensoren ist bisher nur das Blitzen beim Laden bestätigt.';

  @override
  String get simRestart => 'Sensor-Neustart simulieren';

  @override
  String get changelogTileHelp => 'Änderungen anzeigen';

  @override
  String get changelogTitle => 'Änderungen';

  @override
  String get changelogAppTab => 'App';

  @override
  String get changelogFirmwareTab => 'Sensor-Firmware';

  @override
  String get changelogLanguageNote =>
      'Die Änderungshinweise gibt es nur auf Englisch.';

  @override
  String get changelogAbout => 'Zu den Versionsnummern';

  @override
  String get changelogLoadFailed =>
      'Die Änderungen konnten nicht geladen werden.';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get healthSection => 'Sensorzustand';

  @override
  String get sampleRateLabel => 'Abtastrate';

  @override
  String hertz(String value) {
    return '$value Hz';
  }

  @override
  String get pllLabel => 'Abtasttakt (PLL)';

  @override
  String get pllLocked => 'Eingerastet';

  @override
  String get pllAcquiring => 'Stellt sich ein…';

  @override
  String get pllNotAvailable => 'Nicht verfügbar';

  @override
  String get uptimeLabel => 'Zeit seit dem Start';
}
