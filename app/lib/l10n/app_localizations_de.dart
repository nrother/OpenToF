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
  String get startRoutine => 'Routine starten';

  @override
  String get cancelRoutine => 'Abbrechen';

  @override
  String get startDisabledHint =>
      'Der Start ist möglich, solange du springst: Der gerade gemachte Sprung zählt als Sprung 1.';

  @override
  String get routineTitle => 'Routine';

  @override
  String routineRunning(int count, int total) {
    return 'Sprung $count von $total';
  }

  @override
  String get routinePaused => 'Sensor getrennt, Routine pausiert';

  @override
  String get routineComplete => 'Routine abgeschlossen';

  @override
  String get routineCancelledUser => 'Routine abgebrochen';

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
  String get chartRoutineStarted => 'Routine gestartet';

  @override
  String get chartRoutineStopped => 'Routine beendet';

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
  String get exportTooltip => 'Routine als CSV exportieren';

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
  String get routineSection => 'Routine';

  @override
  String get inactivityTimeout => 'Inaktivitäts-Timeout';

  @override
  String get inactivityTimeoutHelp =>
      'Die Routine wird abgebrochen, wenn in dieser Zeit kein Sprung erkannt wird.';

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
  String get jumpsPerRoutine => 'Sprünge pro Routine';

  @override
  String get jumpsPerRoutineHelp =>
      'Eine Routine endet nach dieser Anzahl Sprünge. Gilt für die nächste gestartete Routine.';

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
      'Der Sensor wird getrennt, der Hintergrundbetrieb gestoppt und eine laufende Routine abgebrochen. Der Sensor bleibt gekoppelt.';

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
  String get protocolVersionLabel => 'Protokollversion';

  @override
  String get bootCountLabel => 'Sensor-Starts';

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
  String get exportChooserTitle => 'Als CSV exportieren';

  @override
  String get exportRoutine => 'Aufgezeichnete Routine';

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
      'Zusatzwerte des Sensors unter dem letzten Sprung und in der Routine-Tabelle. Sprung antippen für alle Details.';

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
}
