import 'package:flutter/material.dart';

import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/ornament_divider.dart';
import '../../../theme/app_theme.dart';
import 'prayer_content.dart';
import 'pull_to_advance.dart';
import 'reading_top_bar.dart';

/// Continuous reading mode: all prayers on one scrollable page.
class ContinuousContent extends StatefulWidget {
  const ContinuousContent({
    super.key,
    required this.prayers,
    required this.indexNotifier,
    required this.initialPrayerId,
    this.scrollToInitial = true,
    required this.endLabel,
    required this.nextCategoryName,
    required this.onNextCategory,
    required this.prevCategoryName,
    required this.onPrevCategory,
    required this.controller,
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
  });

  final List<Prayer> prayers;

  /// Current prayer index.
  final ValueNotifier<int> indexNotifier;

  /// Prayer the user opened.
  final String initialPrayerId;

  /// Disable when the reader restores a saved offset instead.
  final bool scrollToInitial;

  /// End label, e.g. section end or playlist end.
  final String endLabel;

  /// Next section, or null for the last section or playlists.
  final String? nextCategoryName;
  final VoidCallback? onNextCategory;

  /// Previous section (null for the first section or playlists).
  final String? prevCategoryName;
  final VoidCallback? onPrevCategory;
  final ScrollController controller;
  final double fontScale;

  /// Per-lane text colors.
  final ReadingColors readingColors;

  /// Block-heading visibility.
  final bool showPartTitles;
  final double lineHeight;
  final bool justifyText;
  final bool showPali;
  final ValueChanged<bool> onTogglePali;
  final bool showMeaning;
  final ValueChanged<bool> onToggleMeaning;
  final bool inlineTranslation;
  final ValueChanged<bool> onInlineTranslationChanged;

  /// Brightness the lane colors resolve against; see [PrayerContent].
  final Brightness readingBrightness;

  /// Inline translation is available when segment counts match prayer text.
  static bool _canInline(Prayer p) =>
      PrayerContent.canInlinePali(p) || PrayerContent.canInlineMeaning(p);

  @override
  State<ContinuousContent> createState() => _ContinuousContentState();
}

class _ContinuousContentState extends State<ContinuousContent> {
  /// Header keys for each prayer.
  final _sectionKeys = <String, GlobalKey>{};
  bool _scrolledToInitial = false;

  /// Throttle position checks during auto-scroll.
  DateTime _lastIndexCheck = DateTime.fromMillisecondsSinceEpoch(0);

  /// Find the latest prayer whose header has crossed the reading area top.
  void _updateCurrentIndex() {
    final now = DateTime.now();
    if (now.difference(_lastIndexCheck) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastIndexCheck = now;
    final self = context.findRenderObject() as RenderBox?;
    if (self == null || !self.attached) return;
    final top = self.localToGlobal(Offset.zero).dy;
    var index = 0;
    for (var i = 0; i < widget.prayers.length; i++) {
      final target = _sectionKeys[widget.prayers[i].id]?.currentContext;
      final box = target?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      // 120px gives the header room to pass the top before counting as active.
      if (box.localToGlobal(Offset.zero).dy - top <= 120) index = i;
    }
    // Avoid rebuilding the whole section every 250 ms.
    widget.indexNotifier.value = index;
  }

  /// Updates the current prayer index; pull navigation lives in [PullToAdvance].
  bool _handleScrollNotification(ScrollNotification notification) {
    _updateCurrentIndex();
    return false;
  }

  /// Scroll once to the opened prayer.
  void _scrollToInitial() {
    if (_scrolledToInitial || !widget.scrollToInitial) return;
    final index = widget.prayers.indexWhere(
      (p) => p.id == widget.initialPrayerId,
    );
    if (index == 0) {
      _scrolledToInitial = true; // The first prayer is already at the top.
      return;
    }
    final sectionContext = _sectionKeys[widget.initialPrayerId]?.currentContext;
    if (sectionContext == null) return;
    _scrolledToInitial = true;
    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final prayers = widget.prayers;
    final anyPali = prayers.any((p) => p.hasDistinctPali);
    final anyMeaning = prayers.any((p) => p.meaning != null);
    final anyCanInline = prayers.any(ContinuousContent._canInline);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToInitial();
    });

    return Column(
      children: [
        // Pinned controls and progress for the whole continuous section.
        ReadingTopBar(
          total: prayers.length,
          positionListenable: widget.indexNotifier,
          chips: [
            if (anyPali)
              FilterChip(
                label: Text(l10n.labelPali),
                selected: widget.showPali,
                onSelected: widget.onTogglePali,
              ),
            if (anyMeaning)
              FilterChip(
                label: Text(l10n.labelMeaning),
                selected: widget.showMeaning,
                onSelected: widget.onToggleMeaning,
              ),
            // Non-inlineable prayers fall back to end-of-prayer sections.
            if ((widget.showPali || widget.showMeaning) && anyCanInline)
              ActionChip(
                avatar: Icon(
                  Icons.swap_vert,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
                label: Text(
                  widget.inlineTranslation
                      ? l10n.chipInline
                      : l10n.chipEndOfPrayer,
                ),
                onPressed: () => widget.onInlineTranslationChanged(
                  !widget.inlineTranslation,
                ),
              ),
          ],
        ),
        Expanded(
          // Pull gestures change sections here, prayers in paged mode.
          child: PullToAdvance(
            nextLabel: widget.nextCategoryName,
            onNext: widget.onNextCategory,
            prevLabel: widget.prevCategoryName,
            onPrev: widget.onPrevCategory,
            moreNext: l10n.pullMoreNext,
            releaseNext: l10n.pullReleaseNext,
            morePrev: l10n.pullMorePrev,
            releasePrev: l10n.pullReleasePrev,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              // Build every prayer up front so keys can be scrolled to.
              child: SingleChildScrollView(
                key: const ValueKey('continuous_scroll'),
                controller: widget.controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                // Keep the scrollable full-screen for pull gestures.
                child: ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fallback for pull-down navigation.
                      if (widget.prevCategoryName != null) ...[
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              Icons.expand_less,
                              color: theme.colorScheme.secondary,
                            ),
                            title: Text(l10n.prevCategory),
                            subtitle: Text(widget.prevCategoryName!),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: widget.onPrevCategory,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            l10n.prevCategoryHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      for (var i = 0; i < prayers.length; i++) ...[
                        if (i > 0) const SizedBox(height: 28),
                        OrnamentDivider(
                          key: _sectionKeys.putIfAbsent(
                            prayers[i].id,
                            GlobalKey.new,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            prayers[i].title,
                            textAlign: TextAlign.center,
                            style: AppTheme.serif(theme.textTheme.titleLarge),
                          ),
                        ),
                        const SizedBox(height: 12),
                        PrayerContent(
                          prayer: prayers[i],
                          embedded: true,
                          fontScale: widget.fontScale,
                          readingColors: widget.readingColors,
                          readingBrightness: widget.readingBrightness,
                          showPartTitles: widget.showPartTitles,
                          lineHeight: widget.lineHeight,
                          justifyText: widget.justifyText,
                          showPali: widget.showPali,
                          onTogglePali: widget.onTogglePali,
                          showMeaning: widget.showMeaning,
                          onToggleMeaning: widget.onToggleMeaning,
                          inlineTranslation: widget.inlineTranslation,
                          onInlineTranslationChanged:
                              widget.onInlineTranslationChanged,
                        ),
                      ],
                      // Content end marker.
                      const SizedBox(height: 32),
                      const OrnamentDivider(),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          widget.endLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ),
                      // Fallback for pull-up navigation.
                      if (widget.nextCategoryName != null) ...[
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              Icons.auto_stories_outlined,
                              color: theme.colorScheme.secondary,
                            ),
                            title: Text(l10n.nextCategory),
                            subtitle: Text(widget.nextCategoryName!),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: widget.onNextCategory,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            l10n.nextCategoryHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
