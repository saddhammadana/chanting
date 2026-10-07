import 'package:flutter/widgets.dart';

double responsiveDialogWidth(
  BuildContext context, {
  double maxWidth = 680,
  double horizontalMargin = 80,
}) {
  final available = MediaQuery.sizeOf(context).width - horizontalMargin;
  return available.clamp(160.0, maxWidth);
}
