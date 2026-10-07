import 'package:flutter/material.dart';

import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/ornament_divider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// One prayer's text as the reader prints it: the chant, with the Romanized
/// Pali and the translation shown or hidden per lane.
class PrayerContent extends StatelessWidget {
  const PrayerContent({
    super.key,
    required this.prayer,
    this.controller,
    required this.fontScale,
    required this.readingColors,
    required this.showPartTitles,
    required this.lineHeight,
    required this.justifyText,
    required this.showPali,
    required this.onTogglePali,
    required this.showMeaning,
    required this.onToggleMeaning,
    required this.inlineTranslation,
    required this.onInlineTranslationChanged,
    required this.readingBrightness,
    this.embedded = false,
  });

  /// Embedded inside continuous reading.
  final bool embedded;

  final Prayer prayer;

  /// Reader scroll controller for normal mode auto-scroll.
  final ScrollController? controller;
  final double fontScale;

  /// Per-lane text colors: chant, Romanized Pali, translation.
  final ReadingColors readingColors;

  /// Whether block headings render above each part; see [_partHeading].
  final bool showPartTitles;
  final double lineHeight;
  final bool justifyText;
  final bool showPali;
  final ValueChanged<bool> onTogglePali;
  final bool showMeaning;
  final ValueChanged<bool> onToggleMeaning;
  final bool inlineTranslation;
  final ValueChanged<bool> onInlineTranslationChanged;

  /// Brightness the lane colors resolve against.
  ///
  /// The reading page has its own paper (`ReadingBackground`), so this is not
  /// always `Theme.of(context).brightness` — reading on the night page under a
  /// light app must still pick each lane's dark color, or the text is drawn in
  /// the light-theme brown on near-black.
  final Brightness readingBrightness;

  /// Text alignment from settings.
  TextAlign get _align => justifyText ? TextAlign.justify : TextAlign.start;

  /// Content blocks split by blank lines, trimming each block separately.
  /// See docs/architecture/reader-rendering.md for why whole-string trim is wrong.
  static List<String> blocks(String value) => [
    for (final b in value.split('\n\n')) b.trim(),
  ];

  /// Inline support is available only when companion block counts match text.
  static bool canInlinePali(Prayer p) =>
      p.hasDistinctPali && blocks(p.paliText!).length == blocks(p.text).length;

  static bool canInlineMeaning(Prayer p) =>
      p.meaning != null && blocks(p.meaning!).length == blocks(p.text).length;

  /// Legacy leader prompt prefix: spoken by one leader, not chanted together.
  static const _leaderPrefix = '(นำ)';

  /// Intentionally narrow; many parenthesized lines are real chant text.
  static bool _isLeaderLine(String line) =>
      line.trimLeft().startsWith(_leaderPrefix);

  /// Part that is **not chanted together**; render with the leader-line style.
  static bool _isAsidePart(PrayerPart? part) =>
      part != null &&
      (part.type == PrayerPartType.lead || part.type == PrayerPartType.rubric);

  /// New-format part at index [i], or null for legacy-format prayers.
  ///
  /// The index matches [blocks] because `Prayer` emits one paragraph per part.
  PrayerPart? _partAt(int i) {
    final parts = prayer.parts;
    return (parts != null && i < parts.length) ? parts[i] : null;
  }

  /// Whether any heading will actually be drawn for this prayer.
  bool get _hasVisibleHeadings {
    if (!showPartTitles) return false;
    final parts = prayer.parts;
    if (parts == null) return false;
    return parts.any(
      (p) =>
          p.type != PrayerPartType.rubric &&
          p.titleFor(prayer.languageCode) != null,
    );
  }

  Widget? _partHeading(ThemeData theme, PrayerPart? part) {
    if (!showPartTitles) return null;
    if (part?.type == PrayerPartType.rubric) return null;
    final title = part?.titleFor(prayer.languageCode);
    if (title == null) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        textAlign: TextAlign.start,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Chant text with leader lines styled separately.
  Widget _chantText(String value, TextStyle? style, TextStyle? leaderStyle) {
    final lines = value.split('\n');
    if (!lines.any(_isLeaderLine)) {
      return Text(value, style: style, textAlign: _align);
    }
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, line) in lines.indexed)
            TextSpan(
              // Reattach newlines except after the last line so text wrapping
              // and line breaks stay exactly the same; only style changes.
              text: i == lines.length - 1 ? line : '$line\n',
              style: _isLeaderLine(line) ? leaderStyle : style,
            ),
        ],
      ),
      textAlign: _align,
    );
  }

  /// Container for companion content: pale gold background, no border.
  ///
  /// Keyed on the page's brightness rather than the theme's — this is a filled
  /// surface, so on the night page a light-theme fill would be a bright block
  /// in the middle of the text. In the ordinary case the two agree and the
  /// values are exactly `secondaryContainer` for each theme.
  static Widget _supportBox(
    Brightness readingBrightness,
    Widget child, {
    EdgeInsets? margin,
  }) => Container(
    margin: margin ?? const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color:
          (readingBrightness == Brightness.dark
                  ? AppColors.darkGoldSoft
                  : AppColors.goldSoft)
              .withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Each lane carries its own color; null means the theme default.
    Color? laneColor(ReadingLane lane) =>
        readingColors.of(lane).resolve(readingBrightness);

    // An `auto` lane follows the page, not the app theme, for the same reason.
    Color autoColor() => defaultReadingText(readingBrightness);

    // Auto companion lanes stay secondary to chant text.
    Color companionColor(ReadingLane lane) =>
        laneColor(lane) ?? autoColor().withValues(alpha: 0.8);

    // Never null: an `auto` chant lane is the page's own text color, which is
    // what `bodyLarge` would have supplied anyway on a matching theme.
    final chantColor = laneColor(ReadingLane.chant) ?? autoColor();
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 18 * fontScale,
      height: lineHeight,
      color: chantColor,
    );
    final paliBaseStyle = bodyStyle?.copyWith(
      fontSize: 16 * fontScale,
      color: companionColor(ReadingLane.roman),
    );
    final meaningBaseStyle = bodyStyle?.copyWith(
      fontSize: 16 * fontScale,
      color: companionColor(ReadingLane.meaning),
    );
    // Faded even when chant has an explicit color: the fade means "do not recite".
    final leaderStyle = bodyStyle?.copyWith(
      fontSize: 15 * fontScale,
      color: chantColor.withValues(alpha: 0.6),
    );

    // Inline companion text only when block counts match the chant.
    final text = prayer.text.trim();
    final textBlocks = blocks(text);
    // hasDistinctPali: editions where Pali is the main text have no extra Pali box.
    final paliText = prayer.hasDistinctPali ? prayer.paliText!.trim() : null;
    final meaningText = prayer.meaning?.trim();
    // Count raw blocks so inline checks and indexed rendering agree.
    final paliBlocks = paliText == null ? null : blocks(prayer.paliText!);
    final meaningBlocks = meaningText == null ? null : blocks(prayer.meaning!);
    final paliInline = inlineTranslation && showPali && canInlinePali(prayer);
    final meaningInline =
        inlineTranslation && showMeaning && canInlineMeaning(prayer);

    final children = <Widget>[
      // Section lives in the AppBar; the content heading is the prayer title.
      if (!embedded) ...[
        Center(
          child: Text(
            prayer.title,
            textAlign: TextAlign.center,
            // The reading screen keeps the Thai serif; the rest of the app is
            // set in Sarabun. See [AppTheme.serif].
            style: AppTheme.serif(theme.textTheme.titleLarge),
          ),
        ),
        const SizedBox(height: 14),
        const OrnamentDivider(),
        const SizedBox(height: 12),
      ],
      if (paliInline || meaningInline)
        ..._interleavedContent(
          theme,
          bodyStyle,
          paliBaseStyle,
          meaningBaseStyle,
          leaderStyle,
          textBlocks,
          paliInline ? paliBlocks : null,
          meaningInline ? meaningBlocks : null,
        )
      else
        ..._plainContent(theme, bodyStyle, leaderStyle, textBlocks, text),
      // End-of-prayer mode: Pali/meaning boxes with labels.
      if (showPali && !paliInline && paliText != null)
        _supportBox(
          readingBrightness,
          margin: const EdgeInsets.only(top: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.paliSectionTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                paliText,
                style: paliBaseStyle?.copyWith(fontStyle: FontStyle.italic),
                textAlign: _align,
              ),
            ],
          ),
        ),
      if (showMeaning && !meaningInline && meaningText != null)
        _supportBox(
          readingBrightness,
          margin: const EdgeInsets.only(top: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.labelMeaning,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(meaningText, style: meaningBaseStyle, textAlign: _align),
            ],
          ),
        ),
    ];

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      key: const ValueKey('prayer_scroll'),
      controller: controller,
      // Always accept drags. Clamping physics rejects drags when content is not
      // scrollable (maxScrollExtent = 0), leaving short prayers with no overscroll
      // for `PullToAdvance` to observe.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      // Constrain only inner content width; the ListView stays full-screen so
      // page-swipe gestures work from anywhere.
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  /// Plain chant content without inline Pali/meaning.
  List<Widget> _plainContent(
    ThemeData theme,
    TextStyle? bodyStyle,
    TextStyle? leaderStyle,
    List<String> textBlocks,
    String text,
  ) {
    if (!_hasVisibleHeadings) {
      return [_chantText(text, bodyStyle, leaderStyle)];
    }
    // Match a blank line in plain text and interleaved mode.
    final blockGap = 18 * fontScale * lineHeight;
    final widgets = <Widget>[];
    for (var i = 0; i < textBlocks.length; i++) {
      final part = _partAt(i);
      final heading = _partHeading(theme, part);
      if (heading != null) widgets.add(heading);
      widgets.add(
        _chantText(
          textBlocks[i],
          _isAsidePart(part) ? leaderStyle : bodyStyle,
          leaderStyle,
        ),
      );
      if (i < textBlocks.length - 1) widgets.add(SizedBox(height: blockGap));
    }
    return widgets;
  }

  /// Interleaved chant and companion content.
  List<Widget> _interleavedContent(
    ThemeData theme,
    TextStyle? bodyStyle,
    TextStyle? paliBaseStyle,
    TextStyle? meaningBaseStyle,
    TextStyle? leaderStyle,
    List<String> textBlocks,
    List<String>? paliBlocks,
    List<String>? meaningBlocks,
  ) {
    final chantStyle = bodyStyle?.copyWith(fontWeight: FontWeight.w600);
    // Companion line height scales down from the chant line height.
    final insetHeight = (lineHeight - 0.4).clamp(1.3, 2.0);
    final paliStyle = paliBaseStyle?.copyWith(
      fontStyle: FontStyle.italic,
      height: insetHeight,
    );
    final meaningStyle = meaningBaseStyle?.copyWith(height: insetHeight);

    // Block gap equals one blank chant line, matching plain mode.
    final blockGap = 18 * fontScale * lineHeight;
    final pairGap = blockGap * 0.45;

    // Inline companion box; same shape as end-of-prayer mode.
    Widget insetBox(Widget child) => _supportBox(readingBrightness, child);

    final widgets = <Widget>[];
    for (var i = 0; i < textBlocks.length; i++) {
      final part = _partAt(i);
      final heading = _partHeading(theme, part);
      if (heading != null) widgets.add(heading);
      // Non-communal parts use the muted style for the whole block.
      final blockChantStyle = _isAsidePart(part) ? leaderStyle : chantStyle;
      final chantLines = textBlocks[i].split('\n');
      // Empty companion block means there is nothing to insert. Rubric parts
      // naturally have no Pali/meaning but still count as paragraphs so block
      // alignment is preserved. Without this guard, enabling companion text would
      // render empty boxes under those lines.
      final paliBlock = paliBlocks?[i];
      final meaningBlock = meaningBlocks?[i];
      final paliLines = (paliBlock == null || paliBlock.isEmpty)
          ? null
          : paliBlock.split('\n');
      final meaningLines = (meaningBlock == null || meaningBlock.isEmpty)
          ? null
          : meaningBlock.split('\n');
      final paliPerLine =
          paliLines != null && paliLines.length == chantLines.length;
      final meaningPerLine =
          meaningLines != null && meaningLines.length == chantLines.length;

      if (chantLines.length > 1 && (paliPerLine || meaningPerLine)) {
        // Pair line by line: chant line, then a box containing Pali/meaning for it.
        for (var j = 0; j < chantLines.length; j++) {
          widgets.add(
            Text(
              chantLines[j],
              style: _isLeaderLine(chantLines[j])
                  ? leaderStyle
                  : blockChantStyle,
              textAlign: _align,
            ),
          );
          final inserts = <Widget>[
            if (paliPerLine)
              Text(paliLines[j], style: paliStyle, textAlign: _align),
            // When both Pali and meaning are visible, separate them with a thin rule.
            if (paliPerLine && meaningPerLine)
              Divider(
                height: 14,
                color: theme.colorScheme.secondary.withValues(alpha: 0.35),
              ),
            if (meaningPerLine)
              Text(meaningLines[j], style: meaningStyle, textAlign: _align),
          ];
          if (inserts.isNotEmpty) {
            widgets.add(
              insetBox(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: inserts,
                ),
              ),
            );
          }
          if (j < chantLines.length - 1) {
            widgets.add(SizedBox(height: pairGap));
          }
        }
        // Companion text that cannot pair line-by-line goes at the end of the block.
        if (paliLines != null && !paliPerLine) {
          widgets.add(
            insetBox(Text(paliBlock!, style: paliStyle, textAlign: _align)),
          );
        }
        if (meaningLines != null && !meaningPerLine) {
          widgets.add(
            insetBox(
              Text(meaningBlock!, style: meaningStyle, textAlign: _align),
            ),
          );
        }
      } else {
        // Insert the whole block.
        widgets.add(_chantText(textBlocks[i], blockChantStyle, leaderStyle));
        if (paliLines != null) {
          widgets.add(
            insetBox(Text(paliBlock!, style: paliStyle, textAlign: _align)),
          );
        }
        if (meaningLines != null) {
          widgets.add(
            insetBox(
              Text(meaningBlock!, style: meaningStyle, textAlign: _align),
            ),
          );
        }
      }
      if (i < textBlocks.length - 1) {
        widgets.add(SizedBox(height: blockGap));
      }
    }
    return widgets;
  }
}
