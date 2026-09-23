import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sensor/sensor.dart';
import '../../data/settings_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../brand_logo.dart';
import '../format.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  StreamSubscription<List<DiscoveredSensor>>? _scanSub;
  List<DiscoveredSensor> _found = const [];
  bool _scanning = false;
  bool _scanned = false;
  String? _scanError;

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  void _startScan() {
    _scanSub?.cancel();
    setState(() {
      _scanning = true;
      _scanned = true;
      _scanError = null;
      _found = const [];
    });
    _scanSub = ref
        .read(sensorBackendProvider)
        .scan()
        .listen(
          (list) {
            if (mounted) setState(() => _found = list);
          },
          onError: (Object e) {
            if (mounted) {
              setState(() {
                _scanError = '$e';
                _scanning = false;
              });
            }
          },
          onDone: () {
            if (mounted) setState(() => _scanning = false);
          },
        );
  }

  Future<void> _rename() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(
        initialName: ref.read(sessionProvider).deviceName ?? '',
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(sessionProvider.notifier).renameDevice(name);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.renameFailed('$e'))));
    }
  }

  Future<void> _confirmExit() async {
    final l = AppLocalizations.of(context);
    final exit = ref.read(exitAppProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.exitConfirmTitle),
        content: Text(l.exitConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.exitAction),
          ),
        ],
      ),
    );
    if (ok == true) await exit();
  }

  void _unpair() {
    ref.read(settingsProvider.notifier).unpair();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: BrandLogo(height: 120)),
            ),
            _Section(l.sensorSection),
            if (settings.isPaired) ...[
              ListTile(
                leading: const Icon(Icons.sensors),
                title: Text(
                  session.deviceName ??
                      settings.pairedDeviceName ??
                      l.unnamedSensor,
                ),
                subtitle: Text(_connectionText(l, session.connection)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: l.renameSensor,
                  onPressed:
                      session.connection == SensorConnectionState.connected
                      ? _rename
                      : null,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.link_off),
                title: Text(l.unpairSensor),
                onTap: _unpair,
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.sensors_off),
                title: Text(l.sensorNone),
              ),
            ListTile(
              leading: _scanning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              title: Text(_scanning ? l.scanning : l.scanForSensors),
              onTap: _scanning ? null : _startScan,
            ),
            if (_scanError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l.scanError(_scanError!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_scanned && !_scanning && _found.isEmpty && _scanError == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l.noSensorsFound),
              ),
            for (final d in _found)
              ListTile(
                leading: const Icon(Icons.sensors),
                title: Text(d.name.isEmpty ? l.unnamedSensor : d.name),
                subtitle: Text('${d.rssi} dBm'),
                trailing: d.id == settings.pairedDeviceId
                    ? const Icon(Icons.check)
                    : null,
                onTap: d.id == settings.pairedDeviceId
                    ? null
                    : () => notifier.pair(d.id, d.name.isEmpty ? null : d.name),
              ),

            if (settings.isPaired) ...[
              _Section(l.batterySection),
              ListTile(
                title: Text(l.batteryLevelLabel),
                trailing: Text(
                  session.batteryLevel == null
                      ? '–'
                      : l.percent(session.batteryLevel!),
                ),
              ),
              ListTile(
                title: Text(l.batteryRemaining),
                trailing: Text(
                  session.batteryRemaining == null
                      ? l.batteryRemainingUnknown
                      : formatRemaining(l, session.batteryRemaining!),
                ),
              ),

              _Section(l.deviceInfoSection),
              _infoRow(
                l.manufacturerLabel,
                session.deviceInfo?.manufacturerName,
              ),
              _infoRow(l.modelLabel, session.deviceInfo?.modelNumber),
              _infoRow(l.serialNumberLabel, session.deviceInfo?.serialNumber),
              _infoRow(
                l.hardwareRevisionLabel,
                session.deviceInfo?.hardwareRevision,
              ),
              _infoRow(
                l.firmwareRevisionLabel,
                session.deviceInfo?.firmwareRevision,
              ),
              _infoRow(l.algorithmLabel, session.deviceInfo?.softwareRevision),
            ],

            _Section(l.routineSection),
            ListTile(
              title: Text(l.inactivityTimeout),
              subtitle: Text(l.inactivityTimeoutHelp),
              trailing: Text(l.seconds('${settings.inactivityTimeoutSeconds}')),
            ),
            Slider(
              min: AppSettings.minTimeoutSeconds.toDouble(),
              max: AppSettings.maxTimeoutSeconds.toDouble(),
              divisions:
                  AppSettings.maxTimeoutSeconds - AppSettings.minTimeoutSeconds,
              value: settings.inactivityTimeoutSeconds.toDouble(),
              label: l.seconds('${settings.inactivityTimeoutSeconds}'),
              onChanged: (v) => notifier.setInactivityTimeout(v.round()),
            ),
            const _JumpCountField(),

            _Section(l.feedbackSection),
            SwitchListTile(
              title: Text(l.perJumpBeeps),
              subtitle: Text(l.perJumpBeepsHelp),
              value: settings.perJumpBeep,
              onChanged: notifier.setPerJumpBeep,
            ),
            SwitchListTile(
              title: Text(l.finalSound),
              value: settings.finalBeep,
              onChanged: notifier.setFinalBeep,
            ),

            _Section(l.appearanceSection),
            ListTile(
              title: Text(l.themeMode),
              trailing: SegmentedButton<AppThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AppThemeMode.system,
                    label: Text(l.themeSystem),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    label: Text(l.themeLight),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    label: Text(l.themeDark),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => notifier.setThemeMode(s.first),
              ),
            ),

            _Section(l.chartSection),
            ListTile(
              title: Text(l.chartWindow),
              trailing: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 30, label: Text(l.window30s)),
                  ButtonSegment(value: 60, label: Text(l.window1m)),
                  ButtonSegment(value: 300, label: Text(l.window5m)),
                ],
                selected: {settings.windowSeconds},
                onSelectionChanged: (s) => notifier.setWindowSeconds(s.first),
              ),
            ),

            _Section(l.aboutSection),
            ListTile(
              title: Text(l.appVersionLabel),
              trailing: Text(ref.watch(appVersionProvider)),
            ),
            if (defaultTargetPlatform == TargetPlatform.android)
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: Text(l.exitApp),
                onTap: _confirmExit,
              ),

            if (kDebugMode) ...[
              _Section(l.debugSection),
              SwitchListTile(
                title: Text(l.useSimulatedSensor),
                value: settings.useMockSensor,
                onChanged: notifier.setUseMockSensor,
              ),
              if (settings.useMockSensor) const _SimulatorControls(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Read-only Device Information row; '–' while the value hasn't been read
  /// yet (or the sensor doesn't expose it). The value is width-limited so a
  /// long one (e.g. a serial number) can't push the row into overflow.
  Widget _infoRow(String label, String? value) => ListTile(
    title: Text(label),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Text(
        value ?? '–',
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );

  String _connectionText(AppLocalizations l, SensorConnectionState c) =>
      switch (c) {
        SensorConnectionState.connected => l.connectionConnected,
        SensorConnectionState.connecting => l.connectionConnecting,
        SensorConnectionState.disconnected => l.connectionDisconnected,
      };
}

/// Owns its [TextEditingController] so it outlives the dialog's exit animation.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.renameSensor),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l.sensorNameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Integer input for the routine length. Owns its controller (disposed here);
/// only valid values are saved, an invalid entry is reverted on focus loss.
class _JumpCountField extends ConsumerStatefulWidget {
  const _JumpCountField();

  @override
  ConsumerState<_JumpCountField> createState() => _JumpCountFieldState();
}

class _JumpCountFieldState extends ConsumerState<_JumpCountField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${ref.read(settingsProvider).jumpsPerRoutine}',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final v = int.tryParse(text);
    final valid =
        v != null &&
        v >= AppSettings.minJumpsPerRoutine &&
        v <= AppSettings.maxJumpsPerRoutine;
    if (valid) ref.read(settingsProvider.notifier).setJumpsPerRoutine(v);
    setState(() => _invalid = !valid);
  }

  void _onFocusChange(bool hasFocus) {
    if (hasFocus || !_invalid) return;
    _controller.text = '${ref.read(settingsProvider).jumpsPerRoutine}';
    setState(() => _invalid = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Focus(
        onFocusChange: _onFocusChange,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(
              '${AppSettings.maxJumpsPerRoutine}'.length,
            ),
          ],
          decoration: InputDecoration(
            labelText: l.jumpsPerRoutine,
            helperText: l.jumpsPerRoutineHelp,
            helperMaxLines: 3,
            errorText: _invalid
                ? l.jumpsPerRoutineInvalid(
                    AppSettings.minJumpsPerRoutine,
                    AppSettings.maxJumpsPerRoutine,
                  )
                : null,
          ),
          onChanged: _onChanged,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _SimulatorControls extends ConsumerWidget {
  const _SimulatorControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mock = ref.watch(mockSensorProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonal(
            onPressed: mock.startBouncing,
            child: Text(l.simStartBouncing),
          ),
          FilledButton.tonal(
            onPressed: mock.stopBouncing,
            child: Text(l.simStopBouncing),
          ),
          FilledButton.tonal(
            onPressed: mock.emitJump,
            child: Text(l.simSingleJump),
          ),
          FilledButton.tonal(
            onPressed: mock.dropNextLanding,
            child: Text(l.simDropLanding),
          ),
          FilledButton.tonal(
            onPressed: mock.simulateDisconnect,
            child: Text(l.simDisconnect),
          ),
          FilledButton.tonal(
            onPressed: mock.simulateReconnect,
            child: Text(l.simReconnect),
          ),
        ],
      ),
    );
  }
}
