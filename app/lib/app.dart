import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'state/providers.dart';
import 'ui/double_back_to_exit.dart';
import 'ui/main/main_screen.dart';

class OpenToFApp extends ConsumerWidget {
  const OpenToFApp({super.key});

  /// Blue of the OpenToF logo (sampled from assets/images/OpenToF_logo.png).
  static const _seed = Color(0xFF0052EE);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Instantiate the session so the sensor connects as soon as the app opens.
    ref.read(sessionProvider);
    // Android: keeps the BLE connection alive in the background while paired.
    ref.watch(foregroundServiceProvider);
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: const DoubleBackToExit(child: MainScreen()),
    );
  }
}
