import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/providers.dart';

/// On Android, wraps the root screen so that pressing Back once shows a hint
/// and pressing it again within [window] exits the app.
class DoubleBackToExit extends ConsumerStatefulWidget {
  const DoubleBackToExit({super.key, required this.child});

  static const window = Duration(seconds: 2);

  final Widget child;

  @override
  ConsumerState<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends ConsumerState<DoubleBackToExit> {
  DateTime? _lastBack;

  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    final now = ref.read(clockProvider)();
    final last = _lastBack;
    if (last != null && now.difference(last) <= DoubleBackToExit.window) {
      ref.read(exitAppProvider)();
      return;
    }
    _lastBack = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pressBackAgainToExit),
          duration: DoubleBackToExit.window,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return widget.child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: widget.child,
    );
  }
}
