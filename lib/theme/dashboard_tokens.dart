import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Values measured off the dashboard artwork in `design/`, shared by every
/// screen that uses its gold surfaces.
///
/// They sit apart from [AppColors] because they are not palette entries: they
/// are the specific faces, rims and edges the artwork draws, which the palette's
/// own `gold` at any alpha does not reproduce.
abstract class DashboardTokens {
  /// Raised gold face, top to bottom.
  static const goldFaceTop = Color(0xFFEFAE3C);
  static const goldFaceBottom = Color(0xFFCE8608);

  /// Outline around a raised gold face, and the warm rim just inside it.
  static const goldEdge = Color(0xFFD17B00);
  static const goldRim = Color(0xFFFEE791);

  /// Selected duration chip, measured off its own artwork: a deeper edge and
  /// face than the raised gold above, with a pale line just inside the edge.
  static const chipEdge = Color(0xFFC97905);
  static const chipRim = Color(0xFFFDF1B5);
  static const chipFaceTop = Color(0xFFEDAB2C);
  static const chipFaceBottom = Color(0xFFBD6F03);

  /// Goal page, measured off `Morning Chanting Goal Setup`. The time-of-day
  /// tile being edited is a pale gold with dark content, not the raised gold
  /// face; a chosen day is a deep gold coin with a pale line inside its edge.
  static const slotFaceTop = Color(0xFFFDF5B7);
  static const slotFaceBottom = Color(0xFFFBC25D);
  static const slotEdge = Color(0xFFCF7B09);
  static const slotRim = Color(0xFFFFFFEB);
  static const slotGlyph = Color(0xFFC57A0C);
  static const dayFaceTop = Color(0xFFE8A123);
  static const dayFaceBottom = Color(0xFFC87700);
  static const dayEdge = Color(0xFFDA7507);
  static const dayRim = Color(0xFFFDF4CA);

  /// Session play/pause disc, outside in: gold band, cream ring, lit face.
  static const discBandTop = Color(0xFFFCC91F);
  static const discBandBottom = Color(0xFFC66C01);
  static const discRing = Color(0xFFFDF9DC);
  static const discFaceTop = Color(0xFFFCE267);
  static const discFaceMid = Color(0xFFF2B432);
  static const discFaceBottom = Color(0xFFC37C0A);

  /// Gold the artwork draws its glyphs in — deeper than `AppColors.gold`.
  static const goldGlyph = Color(0xFFD5932A);

  /// Flat tile face and the hairline around cards and tiles.
  static const tileFaceTop = Color(0xFFFEF6E6);
  static const tileFaceBottom = Color(0xFFFDF8EF);
  static const tileEdge = Color(0xFFF8CA87);
  static const cardEdge = Color(0xFFF8D49B);

  /// Outline of a button that shows the card through it.
  static const outlineEdge = Color(0xFFE3A244);

  /// One warm shadow, close to its shape.
  ///
  /// Measured off the artwork, every shadow there is this brown-gold at 6-15%
  /// and fades within 3-8pt of the edge; nothing carries a grey layer.
  static BoxShadow warmShadow(double alpha, {double blur = 4, double dy = 3}) =>
      BoxShadow(
        color: AppColors.goldDark.withValues(alpha: alpha),
        blurRadius: blur,
        offset: Offset(0, dy),
      );

  /// The app's quiet edge: the hairline round a raised surface — cards,
  /// panels, tabs, the round AppBar buttons.
  ///
  /// With [softShadows] it is the one border-and-shadow pair every raised
  /// control shares, so a back button and the card below it cannot drift
  /// into two different depths.
  ///
  /// Light mode is [cardEdge] taken halfway to the cream card face — paler
  /// than the artwork's hairline, but opaque: a translucent gold vanished
  /// against white faces and the shadow round them.
  static Color softEdge(ThemeData theme) =>
      theme.brightness == Brightness.dark ? AppColors.darkBorder : _softEdge;

  static const _softEdge = Color(0xFFFBE8C8);

  /// Outline of a small raised control — the round AppBar buttons and the
  /// search bar paired with them. Stronger than [softEdge]: at 40px a line
  /// that pale is lost, and the control needs its edge to read as pressable.
  static Color controlEdge(ThemeData theme) =>
      theme.brightness == Brightness.dark ? AppColors.darkBorder : cardEdge;

  /// Colour of [softShadows], for painters that cast the same shadow
  /// through a path rather than a box.
  static Color softShadowColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.35)
      : AppColors.goldDark.withValues(alpha: 0.16);

  /// Blur of [softShadows].
  static const softShadowBlur = 8.0;

  /// The soft warm shadow under anything edged in [softEdge].
  static List<BoxShadow> softShadows(ThemeData theme) => [
    BoxShadow(
      color: softShadowColor(theme),
      blurRadius: softShadowBlur,
      offset: const Offset(0, 1),
    ),
  ];

  /// Shadow under a cream card: warm in light, a gold glow over a lifted
  /// edge in dark. [glow] is the card's strength; the home tiles use 0.11-0.2.
  ///
  /// One source for the home dashboard and the settings cards, so the two
  /// screens cannot drift into different depths.
  static List<BoxShadow> cardShadows(ThemeData theme, {double glow = 0.16}) {
    final scheme = theme.colorScheme;
    if (theme.brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: scheme.secondary.withValues(alpha: glow * 0.5),
          blurRadius: 20,
          spreadRadius: 0.5,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: scheme.onSurface.withValues(alpha: 0.18),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [warmShadow(glow * 0.5, blur: 3, dy: 2)];
  }
}
