import 'package:flutter/material.dart';

/// Asset image with the product-owned missing-image artwork.
///
/// Keeping this behavior in one widget prevents decorative and content images
/// from disappearing into an empty box when an asset is renamed or omitted.
class AppAssetImage extends StatelessWidget {
  const AppAssetImage(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.cacheWidth,
  });

  static const fallbackAsset = 'assets/images/shared/image_not_found.png';

  final String asset;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    color: color,
    colorBlendMode: colorBlendMode,
    cacheWidth: cacheWidth,
    errorBuilder: (context, error, stackTrace) => Image.asset(
      fallbackAsset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: alignment,
    ),
  );
}
