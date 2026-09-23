import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// The large OpenToF wordmark logo (Settings header). The image has an opaque
/// white background, so it reads as a light card on dark surfaces.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.height});

  static const asset = 'assets/images/OpenToF_logo_wordmark.png';

  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height * 0.08),
    child: Image.asset(
      asset,
      height: height,
      semanticLabel: AppLocalizations.of(context).appTitle,
    ),
  );
}

/// The square OpenToF mark (stopwatch with jumper and trampoline): transparent,
/// single blue, readable on light and dark surfaces. For small sizes.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.height});

  static const asset = 'assets/images/OpenToF_mark.png';

  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    height: height,
    semanticLabel: AppLocalizations.of(context).appTitle,
  );
}
