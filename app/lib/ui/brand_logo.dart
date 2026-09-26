import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// The OpenToF wordmark with the logo as its second O (Settings header),
/// transparent; the dark theme gets the version with light letters and the
/// lighter logo.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.height});

  static const asset = 'assets/images/OpenToF_wordmark.png';
  static const darkAsset = 'assets/images/OpenToF_wordmark_dark.png';

  final double height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: height * 0.15),
    child: Image.asset(
      _isDark(context) ? darkAsset : asset,
      height: height,
      semanticLabel: AppLocalizations.of(context).appTitle,
    ),
  );
}

/// The OpenToF logo (stopwatch with jumper and trampoline), transparent. For
/// small sizes; the dark theme gets the version with the lighter blue.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.height});

  static const asset = 'assets/images/OpenToF_mark.png';
  static const darkAsset = 'assets/images/OpenToF_mark_dark.png';

  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    _isDark(context) ? darkAsset : asset,
    height: height,
    semanticLabel: AppLocalizations.of(context).appTitle,
  );
}
