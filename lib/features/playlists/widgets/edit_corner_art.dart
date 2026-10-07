import 'package:flutter/material.dart';

import '../../../shared/widgets/app_asset_image.dart';

/// Decorative art: never hit-tested, never read out. Held well back in light
/// mode so the header text and the rows read first, and fainter still on
/// the dark ground.
class EditCornerArt extends StatelessWidget {
  const EditCornerArt(this.asset, {super.key, required this.width});

  final String asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: dark ? 0.18 : 0.6,
          child: AppAssetImage(asset, width: width),
        ),
      ),
    );
  }
}
