import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/dashboard_tokens.dart';
import '../share_page_parts.dart';

/// Colours and decorations shared by the pieces of the create/edit page,
/// drawn from `design/mobile/icon/wait/01/Thai Lotus Chant Set Builder.png`.

/// The page's flat ground. Flat rather than the share pages' radial glow,
/// because the pinned header and tab band sit on it and must match it.
Color editGround(ThemeData theme) => theme.brightness == Brightness.dark
    ? theme.scaffoldBackgroundColor
    : AppColors.cream;

/// Quiet beige behind tags, unselected chips and the far tab — measured off
/// the artwork, which keeps gold for what is selected.
Color editBeige(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColors.darkGoldSoft
    : AppColors.beige;

/// The folder panel the selected tab opens into, and its rows' face.
Color editPanelColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColors.darkSurface
    : AppColors.creamLight;

/// The line round the selected tab and its panel: the app's soft edge.
Color editPanelLine(ThemeData theme) => DashboardTokens.softEdge(theme);

/// The face shared by the form card and the tab panel: panel colour, the
/// quiet [editPanelLine] and the same soft warm shadow the selected tab
/// casts, so every box on the page is one family.
BoxDecoration editPanelDecoration(
  ThemeData theme, {
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(18)),
}) => BoxDecoration(
  color: editPanelColor(theme),
  borderRadius: borderRadius,
  border: Border.all(color: editPanelLine(theme)),
  boxShadow: DashboardTokens.softShadows(theme),
);

/// White field with a quiet hairline, as the artwork draws its inputs.
InputDecoration editFieldDecoration(
  ThemeData theme, {
  String? hint,
  String? error,
  Widget? prefix,
  Widget? suffix,
}) {
  final dark = theme.brightness == Brightness.dark;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    errorText: error,
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: dark ? AppColors.darkField : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: border(dark ? AppColors.darkBorder : AppColors.panelEdge),
    focusedBorder: border(shareGold(theme), 1.4),
    errorBorder: border(theme.colorScheme.error),
    focusedErrorBorder: border(theme.colorScheme.error, 1.4),
  );
}
