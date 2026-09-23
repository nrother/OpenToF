import 'dart:io' show Platform;
import 'dart:ui' show Color, Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../l10n/app_localizations.dart';

/// Android foreground service that keeps the process (and thus the BLE
/// connection) alive while the app is in the background. No-op elsewhere; iOS
/// relies on CoreBluetooth's background mode (best-effort).
/// Runs in the service's own isolate; only relays the notification's Exit button.
/// The BLE connection lives in the main isolate, which does the real shutdown.
@pragma('vm:entry-point')
void foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_ExitButtonHandler());
}

class _ExitButtonHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id != ForegroundService.exitButtonId) return;
    FlutterForegroundTask.sendDataToMain(ForegroundService.exitMessage);
    // Fallback for when the app's UI is already gone (swiped away): nobody in the
    // main isolate can react, so stop the service (and with it the process
    // pinning) ourselves shortly after.
    Future<void>.delayed(
      const Duration(seconds: 1),
      FlutterForegroundTask.stopService,
    );
  }
}

class ForegroundService {
  ForegroundService._();

  static const _serviceId = 4711;
  static const exitButtonId = 'exit';
  static const exitMessage = 'exit';
  static const notificationIconMetaData =
      'com.opentof.app.service.NOTIFICATION_ICON';

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Must run in `main()` before `runApp` so the service can talk to the UI.
  static void initCommunication() {
    if (_supported) FlutterForegroundTask.initCommunicationPort();
  }

  /// No BuildContext (or Localizations) exists at this level, so resolve the
  /// device locale directly, falling back to English.
  static Future<void> startLocalized() {
    AppLocalizations l;
    try {
      l = lookupAppLocalizations(PlatformDispatcher.instance.locale);
    } catch (_) {
      l = lookupAppLocalizations(const Locale('en'));
    }
    return start(
      channelName: l.foregroundChannelName,
      title: l.appTitle,
      text: l.foregroundNotificationText,
      exitButtonText: l.exitAction,
    );
  }

  static Future<void> start({
    required String channelName,
    required String title,
    required String text,
    required String exitButtonText,
  }) async {
    if (!_supported) return;
    try {
      await FlutterForegroundTask.requestNotificationPermission();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'opentof_sensor_connection',
          channelName: channelName,
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
        ),
      );
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [ForegroundServiceTypes.connectedDevice],
        notificationTitle: title,
        notificationText: text,
        notificationIcon: const NotificationIcon(
          metaDataName: notificationIconMetaData,
          backgroundColor: Color(0xFF1A7EFD), // blue of the logo mark
        ),
        notificationButtons: [
          NotificationButton(id: exitButtonId, text: exitButtonText),
        ],
        callback: foregroundTaskCallback,
      );
    } catch (e) {
      debugPrint('Foreground service start failed: $e');
    }
  }

  /// Calls [onExit] when the notification's Exit button is pressed. Returns a
  /// function that removes the listener.
  static VoidCallback listenForExit(VoidCallback onExit) {
    if (!_supported) return () {};
    void onData(Object data) {
      if (data == exitMessage) onExit();
    }

    FlutterForegroundTask.addTaskDataCallback(onData);
    return () => FlutterForegroundTask.removeTaskDataCallback(onData);
  }

  static Future<void> stop() async {
    if (!_supported) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('Foreground service stop failed: $e');
    }
  }
}
