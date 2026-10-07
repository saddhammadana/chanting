import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import 'app_colors.dart';
import 'dashboard_tokens.dart';

/// Re-exported so the many `import 'theme/app_theme.dart'` call sites keep
/// reaching `AppTextColor` and the per-lane reading colors from one place.
export 'reading_colors.dart';

/// Prayer content font-size range as a multiplier of normal size.
///
/// The settings slider moves by [kFontScaleStep]; reader A-/A+ buttons move by
/// [kFontScaleButtonStep].
const kFontScaleMin = 0.8;
const kFontScaleMax = 1.6;
const kFontScaleStep = 0.05;
const kFontScaleButtonStep = 0.1;

/// Prayer content line spacing.
///
/// One value controls both line height and spacing between parts. SharedPreferences
/// stores the enum `name`; user-visible labels live in the extension below for
/// the same reason as the reading colors in `reading_colors.dart`.
enum AppLineSpacing {
  compact(1.6),
  normal(1.9),
  loose(2.3);

  const AppLineSpacing(this.height);

  final double height;

  static AppLineSpacing fromName(String name) => AppLineSpacing.values
      .firstWhere((e) => e.name == name, orElse: () => AppLineSpacing.normal);
}

/// The user-visible name of a line spacing.
extension AppLineSpacingLabel on AppLineSpacing {
  String label(AppLocalizations l10n) => switch (this) {
    AppLineSpacing.compact => l10n.lineSpacingCompact,
    AppLineSpacing.normal => l10n.lineSpacingNormal,
    AppLineSpacing.loose => l10n.lineSpacingLoose,
  };
}

/// Builds the app's light and dark themes.
abstract class AppTheme {
  /// Pridi, the Thai serif kept for the reading screen.
  ///
  /// The rest of the app is set in Sarabun; this is what gives the chanted
  /// text — and the chrome around it — the traditional prayer-book feel.
  static TextStyle serif(
    TextStyle? base, {
    FontWeight weight = FontWeight.w500,
  }) => GoogleFonts.pridi(textStyle: base, fontWeight: weight);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brown,
        brightness: Brightness.light,
        primary: AppColors.brown,
        onPrimary: AppColors.creamLight,
        secondary: AppColors.gold,
        secondaryContainer: AppColors.goldSoft,
        onSecondaryContainer: AppColors.brownDark,
        surface: AppColors.creamLight,
        onSurface: AppColors.brownDark,
        outlineVariant: AppColors.creamBorder,
      ),
      scaffoldBackgroundColor: AppColors.cream,
    );
    return _applyCommon(
      base,
      appBarBackground: AppColors.cream,
      appBarForeground: AppColors.brownDark,
      cardColor: AppColors.creamLight,
      fieldFill: AppColors.creamField,
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brown,
        brightness: Brightness.dark,
        primary: AppColors.darkGold,
        onPrimary: AppColors.darkBackground,
        secondary: AppColors.darkGold,
        secondaryContainer: AppColors.darkGoldSoft,
        onSecondaryContainer: AppColors.darkCream,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkCream,
        outlineVariant: AppColors.darkBorder,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
    );
    return _applyCommon(
      base,
      appBarBackground: AppColors.darkBackground,
      appBarForeground: AppColors.darkCream,
      cardColor: AppColors.darkSurface,
      fieldFill: AppColors.darkField,
    );
  }

  static ThemeData _applyCommon(
    ThemeData base, {
    required Color appBarBackground,
    required Color appBarForeground,
    required Color cardColor,
    required Color fieldFill,
  }) {
    final scheme = base.colorScheme;
    // The UI is set in Sarabun throughout; Pridi, the Thai serif that carries
    // the prayer-book feel, is reserved for the reading screen and reached
    // through [AppTheme.serif]. See CLAUDE.md, "Typography".
    final textTheme = GoogleFonts.sarabunTextTheme(base.textTheme);
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.sarabun(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: appBarForeground,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      // M3 lets the seed tonal palette control dialog/menu surfaces, which makes
      // them grey-brown and unlike the app's cream cards. Force dialogs and menus
      // to share the same surface, border, and shape family as cards.
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: GoogleFonts.sarabun(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // M3 defaults to `filled: false`, making fields transparent and easy to
      // lose against dialog/card surfaces. A field fill one step below card
      // surface makes inputs read as editable across the app without per-widget
      // overrides.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        labelStyle: GoogleFonts.sarabun(color: scheme.onSurfaceVariant),
        floatingLabelStyle: GoogleFonts.sarabun(color: scheme.primary),
        hintStyle: GoogleFonts.sarabun(
          color: scheme.onSurface.withValues(alpha: 0.45),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(cardColor),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        hintStyle: WidgetStatePropertyAll(
          GoogleFonts.sarabun(color: scheme.onSurface.withValues(alpha: 0.45)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.brightness == Brightness.light
              ? AppColors.brownDark
              : AppColors.darkBackground,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.sarabun(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      // Every control below is drawn in the app's cream and gold from here,
      // so a page that reaches for a stock Material widget still matches. The
      // gaps this closes were found one screen at a time (the time picker, the
      // SnackBar, the segmented button) before being closed together.
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.onSurface.withValues(alpha: 0.10),
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : scheme.onSurfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outlineVariant,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.onSurfaceVariant,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 5,
        activeTrackColor: scheme.secondary,
        inactiveTrackColor: scheme.secondary.withValues(alpha: 0.2),
        thumbColor: scheme.secondary,
        overlayColor: scheme.secondary.withValues(alpha: 0.14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        valueIndicatorColor: scheme.secondary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.sarabun(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: BorderSide(
            color: scheme.brightness == Brightness.dark
                ? scheme.secondary.withValues(alpha: 0.9)
                : DashboardTokens.outlineEdge,
            width: 1.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.sarabun(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        modalBackgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.secondary.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          scheme.secondary.withValues(alpha: 0.55),
        ),
        radius: const Radius.circular(4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.outlineVariant,
        circularTrackColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: cardColor,
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        labelStyle: GoogleFonts.sarabun(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(iconColor: scheme.secondary),
      dividerTheme: base.dividerTheme.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.08),
      ),
    );
  }
}
