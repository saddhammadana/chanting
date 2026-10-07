import 'dart:async' show Timer, unawaited;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/local/prefs_service.dart';
import '../../data/local/system_bars.dart';
import '../../data/models/playlist.dart';
import '../../data/models/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/golden_pill_button.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../theme/app_theme.dart';
import '../playlists/playlists_controller.dart';
import '../prayer_list/prayer_list_controller.dart';
import '../settings/settings_controller.dart';
import '../stats/practice_log_controller.dart';
import 'auto_scroller.dart';
import 'prayer_detail_controller.dart';
import 'prayer_report_sheet.dart';
import 'read_position_keeper.dart';
import 'reading_session.dart';
import 'widgets/content_end_float.dart';
import 'widgets/continuous_content.dart';
import 'widgets/display_chips.dart';
import 'widgets/edge_glow.dart';
import 'widgets/immersive_hint.dart';
import 'widgets/mala_counter_layer.dart';
import 'widgets/neighbor_bar.dart';
import 'widgets/prayer_content.dart';
import 'widgets/pull_to_advance.dart';
import 'widgets/reading_actions.dart';
import 'widgets/reading_app_bar.dart';
import 'widgets/reading_top_bar.dart';
import 'widgets/report_selection_toolbar.dart';

/// The reading settings both modes pass to the text they print.
typedef _ReadingLook = ({
  double fontScale,
  ReadingColors readingColors,
  Brightness brightness,
  bool showPartTitles,
  double lineHeight,
  bool justifyText,
  bool inlineTranslation,
});

/// The reading screen: one prayer at a time, or a whole category in
/// continuous mode.
class PrayerDetailScreen extends ConsumerStatefulWidget {
  const PrayerDetailScreen({
    super.key,
    required this.prayerId,
    this.playlistId,
    this.sectionId,
    this.resumeReading = false,
  });

  final String prayerId;

  /// When opened from a playlist, previous/next follows the playlist order.
  final String? playlistId;

  /// Incoming section used to resolve the reading sequence.
  final String? sectionId;

  /// Opened from the "continue reading" card; restore the saved scroll offset.
  final bool resumeReading;

  @override
  ConsumerState<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends ConsumerState<PrayerDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Seeded from settings in initState, then owned by the reader's own chips:
  // a chip pressed mid-prayer is for this sitting, not a change of preference.
  bool _showPali = false;
  bool _showMeaning = false;

  /// Show the floating mala counter; see [MalaCounterLayer].
  bool _showMala = false;

  final _scrollController = ScrollController();

  /// Slow auto-scroll while chanting.
  late final AutoScroller _autoScroller;
  Timer? _advanceTimer;

  /// Current prayer index in continuous mode, starting at 0.
  final _continuousIndex = ValueNotifier<int>(0);

  /// The prayer a command should act on.
  static Prayer? _activeIn(List<Prayer> sequence, int index, Prayer? fallback) {
    if (sequence.isEmpty) return fallback;
    return sequence[index.clamp(0, sequence.length - 1)];
  }

  /// Chanting time banked into the practice log; created in `initState`.
  late final ReadingSession _session;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _session.resume();
    } else {
      _session.pause();
    }
  }

  /// Saved reading position to restore to; null means no restore is needed.
  double? _resumeOffset;

  late final _readPosition = ReadPositionKeeper(
    controller: _scrollController,
    persist: (offset) => ref
        .read(prefsServiceProvider)
        .setLastReadPosition(
          offset,
          continuous: ref.read(settingsControllerProvider).continuousReading,
          playlistId: widget.playlistId ?? '',
        ),
  );

  void _toggleAutoScroll() {
    _advanceTimer?.cancel();
    _autoScroller.running ? _autoScroller.stop() : _autoScroller.start();
  }

  void _onAutoScrollChanged() {
    if (mounted) setState(() {});
  }

  /// End reached during auto-scroll.
  void _scheduleAutoAdvance() {
    String? nextId;
    var dir = 'next';
    if (ref.read(settingsControllerProvider).continuousReading) {
      // Continuous playlists end on the same page; there is no next section.
      if (widget.playlistId != null) return;
      nextId = ref.read(nextCategoryProvider(_ctx)).value?.firstPrayerId;
      dir = 'up';
    } else {
      nextId = _nextPrayerIdInSequence();
    }
    if (nextId == null) return;
    final path = _pathToPrayer(nextId, dir);
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      ref.read(autoScrollResumeProvider.notifier).set(true);
      context.pushReplacement(path);
    });
  }

  /// Next prayer id by playlist order when applicable, otherwise by section.
  String? _nextPrayerIdInSequence() {
    if (widget.playlistId != null) {
      final playlist = ref.read(playlistProvider(widget.playlistId!));
      if (playlist == null) return null;
      final ids = playlist.prayerIds;
      final index = ids.indexOf(widget.prayerId);
      return (index != -1 && index < ids.length - 1) ? ids[index + 1] : null;
    }
    return ref.read(prayerNeighborsProvider(_ctx)).value?.next?.id;
  }

  /// Immersive reading mode; tap content to hide/show the top and bottom bars.
  ///
  /// Seeded from `startImmersive` in initState for readers who want the page
  /// and nothing else.
  bool _immersive = false;
  bool _showImmersiveHint = false;

  /// Long-press prayer content to select text for reporting.
  final _selectionKey = GlobalKey<SelectionAreaState>();

  /// Latest selected text. It does not affect rendering, so changes do not need setState.
  String? _selectedText;

  /// Content tap: clear any selection first, otherwise toggle immersive mode.
  void _handleContentTap() {
    if (_selectedText != null) {
      _selectionKey.currentState?.selectableRegion.clearSelection();
      return;
    }
    _toggleImmersive();
  }

  /// Selection toolbar reporting on [prayer]; see [ReportSelectionToolbar].
  Widget _selectionToolbar(SelectableRegionState state, Prayer? prayer) {
    // Capture text before web selection can clear on pointer leave.
    final selected = _selectedText;
    return ReportSelectionToolbar(
      state: state,
      onReport: prayer == null
          ? null
          : () => showPrayerReportSheet(
              context,
              prayer: prayer,
              contentLanguage: ref.read(prayerRepositoryProvider).languageCode,
              selectedText: selected,
            ),
    );
  }

  /// Edge glow for swiping past the end: 0 = hidden, -1 = left, 1 = right.
  int _glowEdge = 0;
  Timer? _glowTimer;

  /// Show edge glow and a message when swiping with no further prayer available.
  void _showEdgeGlow(int edge, String message) {
    setState(() => _glowEdge = edge);
    _glowTimer?.cancel();
    _glowTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _glowEdge = 0);
    });
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        appToast(
          message,
          kind: ToastKind.info,
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  void _toggleImmersive() {
    setState(() {
      _immersive = !_immersive;
      _showImmersiveHint = _immersive;
    });
    if (_immersive) {
      // Hide status/navigation bars on mobile. This is a no-op on web/desktop.
      unawaited(setSystemBarsHidden(true));
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _showImmersiveHint = false);
      });
    } else {
      unawaited(setSystemBarsHidden(false));
    }
  }

  void _setShowPali(bool value) => setState(() => _showPali = value);

  void _setShowMeaning(bool value) => setState(() => _showMeaning = value);

  void _setInlineTranslation(bool value) =>
      ref.read(settingsControllerProvider.notifier).setInlineTranslation(value);

  /// Current prayer plus incoming section, used as provider keys for reading context.
  ReadingContext get _ctx =>
      (prayerId: widget.prayerId, sectionId: widget.sectionId);

  /// Path to another prayer while preserving playlist/section context.
  String _pathToPrayer(String id, String dir, {String? sectionId}) {
    final section = sectionId ?? widget.sectionId;
    return '/prayer/$id?dir=$dir'
        '${widget.playlistId == null ? '' : '&pl=${widget.playlistId}'}'
        '${section == null ? '' : '&section=$section'}';
  }

  @override
  void initState() {
    super.initState();
    _autoScroller = AutoScroller(
      vsync: this,
      controller: _scrollController,
      pxPerSecond: () =>
          ref.read(settingsControllerProvider).autoScrollPxPerSec,
      delaySeconds: () =>
          ref.read(settingsControllerProvider).autoScrollDelaySeconds,
      onReachedEnd: _scheduleAutoAdvance,
    )..addListener(_onAutoScrollChanged);
    WidgetsBinding.instance.addObserver(this);
    _session = ReadingSession(ref.read(practiceLogControllerProvider.notifier))
      ..resume();
    // Restore only when the saved reader context still matches.
    final prefs = ref.read(prefsServiceProvider);
    final settings = ref.read(settingsControllerProvider);
    // Keep the screen awake while chanting; some platforms/tests may lack the
    // plugin. Opt-out lives in settings, so a phone left on a stand does not
    // have to burn its battery on a prayer nobody is reading.
    if (settings.keepScreenOn) WakelockPlus.enable().catchError((_) {});
    _showPali = settings.showRomanDefault;
    _showMeaning = settings.showMeaningDefault;
    if (settings.startImmersive) _immersive = true;
    if (widget.resumeReading &&
        prefs.getLastReadId() == widget.prayerId &&
        prefs.getLastReadContinuous() == settings.continuousReading &&
        prefs.getLastReadPlaylist() == (widget.playlistId ?? '')) {
      final offset = prefs.getLastReadOffset();
      if (offset > 0) _resumeOffset = offset;
    }
    // Save the latest read prayer after the first frame; provider state cannot
    // be changed during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(lastReadControllerProvider.notifier).set(widget.prayerId);
        if (_resumeOffset != null) {
          _readPosition.restore(_resumeOffset!, isMounted: () => mounted);
        } else {
          // New prayer: bind the starting offset to this prayer to avoid stale offsets.
          _readPosition.save(force: true);
        }
        // Start immediately when configured or after auto-advance.
        final settings = ref.read(settingsControllerProvider);
        final resume = ref.read(autoScrollResumeProvider);
        if (resume) ref.read(autoScrollResumeProvider.notifier).set(false);
        if (settings.autoScrollEnabled &&
            (settings.autoScrollAutoStart || resume)) {
          _autoScroller.start();
        }
      }
    });
  }

  @override
  void dispose() {
    // Save the latest offset before leaving so "continue reading" returns here.
    _readPosition.save(force: true);
    _session.pause(deferred: true);
    WidgetsBinding.instance.removeObserver(this);
    _glowTimer?.cancel();
    _advanceTimer?.cancel();
    _autoScroller.dispose();
    _continuousIndex.dispose();
    _scrollController.dispose();
    WakelockPlus.disable().catchError((_) {});
    unawaited(setSystemBarsHidden(false));
    super.dispose();
  }

  /// Neighbours follow the playlist's order when reading one, otherwise the
  /// section's.
  PrayerNeighbors? _watchNeighbors(Playlist? playlist) {
    if (playlist == null) {
      return ref.watch(prayerNeighborsProvider(_ctx)).value;
    }
    final ids = playlist.prayerIds;
    final index = ids.indexOf(widget.prayerId);
    final prevId = index > 0 ? ids[index - 1] : null;
    final nextId = (index != -1 && index < ids.length - 1)
        ? ids[index + 1]
        : null;
    return (
      prev: prevId == null
          ? null
          : ref.watch(prayerDetailProvider(prevId)).value,
      next: nextId == null
          ? null
          : ref.watch(prayerDetailProvider(nextId)).value,
      position: index + 1,
      total: ids.length,
    );
  }

  /// A horizontal fling in swipe mode: the neighbouring prayer, or the edge
  /// glow when there is none.
  void _onSwipe(
    DragEndDetails details,
    PrayerNeighbors? neighbors, {
    required bool continuousReading,
  }) {
    // Continuous mode scrolls through prayers instead of swiping pages.
    if (continuousReading) return;
    final velocity = details.primaryVelocity ?? 0;
    // Sequence is still loading, so we cannot know whether this is the end.
    if (neighbors == null) return;
    final l10n = AppLocalizations.of(context);
    final prev = neighbors.prev;
    final next = neighbors.next;
    if (velocity < -300) {
      if (next != null) {
        context.pushReplacement(_pathToPrayer(next.id, 'next'));
      } else {
        _showEdgeGlow(
          1,
          widget.playlistId != null
              ? l10n.edgeLastInPlaylist
              : l10n.edgeLastInCategory,
        );
      }
    } else if (velocity > 300) {
      if (prev != null) {
        context.pushReplacement(_pathToPrayer(prev.id, 'prev'));
      } else {
        _showEdgeGlow(
          -1,
          widget.playlistId != null
              ? l10n.edgeFirstInPlaylist
              : l10n.edgeFirstInCategory,
        );
      }
    }
  }

  /// Continuous mode: every prayer of the set or section on one page.
  Widget _continuousContent({
    required List<Prayer> sequence,
    required Playlist? playlist,
    required String sectionTitle,
    required AdjacentSection? nextCategory,
    required AdjacentSection? prevCategory,
    required _ReadingLook look,
  }) {
    final l10n = AppLocalizations.of(context);
    return ContinuousContent(
      prayers: sequence,
      indexNotifier: _continuousIndex,
      initialPrayerId: widget.prayerId,
      // When resuming, the saved offset wins over the initial prayer header
      // scroll.
      scrollToInitial: _resumeOffset == null,
      endLabel: playlist != null
          ? l10n.playlistEnd(playlist.name)
          : l10n.categoryEnd(sectionTitle),
      nextCategoryName: nextCategory?.name,
      onNextCategory: nextCategory == null
          ? null
          : () => context.pushReplacement(
              _pathToPrayer(
                nextCategory.firstPrayerId,
                'up',
                sectionId: nextCategory.id,
              ),
            ),
      prevCategoryName: prevCategory?.name,
      onPrevCategory: prevCategory == null
          ? null
          : () => context.pushReplacement(
              _pathToPrayer(
                prevCategory.firstPrayerId,
                'down',
                sectionId: prevCategory.id,
              ),
            ),
      controller: _scrollController,
      fontScale: look.fontScale,
      readingColors: look.readingColors,
      readingBrightness: look.brightness,
      showPartTitles: look.showPartTitles,
      lineHeight: look.lineHeight,
      justifyText: look.justifyText,
      showPali: _showPali,
      onTogglePali: _setShowPali,
      showMeaning: _showMeaning,
      onToggleMeaning: _setShowMeaning,
      inlineTranslation: look.inlineTranslation,
      onInlineTranslationChanged: _setInlineTranslation,
    );
  }

  /// Swipe mode: one prayer under the same pinned bar as continuous mode.
  Widget _singleContent({
    required Prayer prayer,
    required PrayerNeighbors? neighbors,
    required _ReadingLook look,
  }) {
    final l10n = AppLocalizations.of(context);
    final prev = neighbors?.prev;
    final next = neighbors?.next;
    return Column(
      children: [
        ReadingTopBar(
          position: neighbors?.position,
          total: neighbors?.total,
          chips: displayChips(
            context,
            prayer: prayer,
            showPali: _showPali,
            onTogglePali: _setShowPali,
            showMeaning: _showMeaning,
            onToggleMeaning: _setShowMeaning,
            inlineTranslation: look.inlineTranslation,
            onInlineTranslationChanged: _setInlineTranslation,
          ),
        ),
        Expanded(
          // Pull past the edge to navigate.
          child: PullToAdvance(
            nextLabel: next?.title,
            onNext: next == null
                ? null
                : () => context.pushReplacement(_pathToPrayer(next.id, 'next')),
            prevLabel: prev?.title,
            onPrev: prev == null
                ? null
                : () => context.pushReplacement(_pathToPrayer(prev.id, 'prev')),
            moreNext: l10n.pullMoreNextPrayer,
            releaseNext: l10n.pullReleaseNextPrayer,
            morePrev: l10n.pullMorePrevPrayer,
            releasePrev: l10n.pullReleasePrevPrayer,
            child: PrayerContent(
              prayer: prayer,
              controller: _scrollController,
              fontScale: look.fontScale,
              readingColors: look.readingColors,
              readingBrightness: look.brightness,
              showPartTitles: look.showPartTitles,
              lineHeight: look.lineHeight,
              justifyText: look.justifyText,
              showPali: _showPali,
              onTogglePali: _setShowPali,
              showMeaning: _showMeaning,
              onToggleMeaning: _setShowMeaning,
              inlineTranslation: look.inlineTranslation,
              onInlineTranslationChanged: _setInlineTranslation,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayerAsync = ref.watch(prayerDetailProvider(widget.prayerId));

    final playlist = widget.playlistId == null
        ? null
        : ref.watch(playlistProvider(widget.playlistId!));
    final neighbors = _watchNeighbors(playlist);
    final fontScale = ref.watch(
      settingsControllerProvider.select((s) => s.fontScale),
    );
    final readingColors = ref.watch(
      settingsControllerProvider.select((s) => s.readingColors),
    );
    final showPartTitles = ref.watch(
      settingsControllerProvider.select((s) => s.showPartTitles),
    );
    final inlineTranslation = ref.watch(
      settingsControllerProvider.select((s) => s.inlineTranslation),
    );
    final lineHeight = ref.watch(
      settingsControllerProvider.select((s) => s.lineSpacing.height),
    );
    final justifyText = ref.watch(
      settingsControllerProvider.select((s) => s.justifyText),
    );
    final continuousReading = ref.watch(
      settingsControllerProvider.select((s) => s.continuousReading),
    );
    // The reading page has its own paper; a dark app theme forces the night
    // one. Both the scaffold and this screen's own AppBar are painted with it,
    // so the page reads as one sheet rather than a panel inside the app.
    final page = effectiveReadingBackground(
      ref.watch(settingsControllerProvider.select((s) => s.pageBackground)),
      Theme.of(context).brightness,
    );
    final _ReadingLook look = (
      fontScale: fontScale,
      readingColors: readingColors,
      brightness: page.brightness,
      showPartTitles: showPartTitles,
      lineHeight: lineHeight,
      justifyText: justifyText,
      inlineTranslation: inlineTranslation,
    );

    // Continuous mode: all prayers in the same playlist or section on one page.
    List<Prayer> sequence = const [];
    AdjacentSection? nextCategory;
    AdjacentSection? prevCategory;
    // Section name depends on route because prayers can appear in multiple sections.
    final sectionTitle =
        ref.watch(currentSectionProvider(_ctx)).value?.title ?? '';
    if (continuousReading) {
      sequence = playlist != null
          ? playlist.prayerIds
                .map((id) => ref.watch(prayerDetailProvider(id)).value)
                .whereType<Prayer>()
                .toList()
          : ref.watch(categoryPrayersProvider(_ctx)).value ?? const [];
      // Section reading can advance to the next section at the end or pull down
      // at the top to go back. Playlists end inside the playlist.
      if (playlist == null) {
        nextCategory = ref.watch(nextCategoryProvider(_ctx)).value;
        prevCategory = ref.watch(prevCategoryProvider(_ctx)).value;
      }
    }

    final autoScrollEnabled = ref.watch(
      settingsControllerProvider.select((s) => s.autoScrollEnabled),
    );
    // If the feature is disabled while scrolling, stop immediately; the stop
    // button is hidden once disabled.
    ref.listen(settingsControllerProvider.select((s) => s.autoScrollEnabled), (
      _,
      enabled,
    ) {
      if (!enabled && _autoScroller.running) _autoScroller.stop();
    });

    return Scaffold(
      backgroundColor: page.color,
      floatingActionButtonLocation: kContentEndFloat,
      // Auto-scroll start/stop button. Enable/disable and speed live in settings.
      floatingActionButton: !autoScrollEnabled || prayerAsync.value == null
          ? null
          : GoldenIconButton(
              key: const ValueKey('auto_scroll_button'),
              tooltip: _autoScroller.running
                  ? l10n.autoScrollStop
                  : l10n.settingsAutoScroll,
              onPressed: _toggleAutoScroll,
              icon: Icon(
                _autoScroller.running ? Icons.pause : Icons.play_arrow,
              ),
            ),
      bottomNavigationBar:
          _immersive ||
              continuousReading ||
              neighbors == null ||
              (neighbors.prev == null && neighbors.next == null)
          ? null
          : NeighborBar(
              prev: neighbors.prev,
              next: neighbors.next,
              playlistId: widget.playlistId,
              sectionId: widget.sectionId,
            ),
      appBar: _immersive
          ? null
          : ReadingAppBar(
              page: page,
              title: prayerAsync.value == null
                  ? null
                  : continuousReading && playlist != null
                  ? playlist.name
                  : sectionTitle,
              // Rebuilt as the reader scrolls; see [_activeIn].
              actions: ValueListenableBuilder<int>(
                valueListenable: _continuousIndex,
                builder: (context, index, _) {
                  final active = continuousReading
                      ? _activeIn(sequence, index, prayerAsync.value)
                      : prayerAsync.value;
                  return ReadingActions(
                    prayerId: active?.id ?? widget.prayerId,
                    prayer: active,
                    malaOpen: _showMala,
                    onToggleMala: () => setState(() => _showMala = !_showMala),
                    showPali: _showPali,
                    showMeaning: _showMeaning,
                  );
                },
              ),
            ),
      // User drag stops auto-scroll; ticker jumps have no dragDetails.
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            // Cancel both scrolling and any queued advance; the user is in control.
            _advanceTimer?.cancel();
            if (_autoScroller.running) _autoScroller.stop();
          } else if (notification is ScrollEndNotification) {
            // Save the latest reading position. The helper throttles frequent updates.
            _readPosition.save();
          }
          return false;
        },
        child: prayerAsync.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            message: l10n.prayerLoadError,
            detail: '$e',
          ),
          data: (prayer) {
            if (prayer == null) {
              return EmptyState(
                icon: Icons.search_off,
                message: l10n.prayerNotFound,
              );
            }
            // Taps toggle immersive mode; horizontal swipes navigate.
            return SelectionArea(
              key: _selectionKey,
              onSelectionChanged: (content) =>
                  _selectedText = content?.plainText,
              contextMenuBuilder: (_, state) => _selectionToolbar(
                state,
                continuousReading
                    ? _activeIn(sequence, _continuousIndex.value, prayer)
                    : prayer,
              ),
              // Touch swipes navigate; mouse drags remain text selection.
              child: GestureDetector(
                supportedDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
                onHorizontalDragEnd: (details) => _onSwipe(
                  details,
                  neighbors,
                  continuousReading: continuousReading,
                ),
                child: GestureDetector(
                  onTap: _handleContentTap,
                  child: Stack(
                    children: [
                      SafeArea(
                        top: _immersive,
                        bottom: false,
                        child: continuousReading && sequence.isNotEmpty
                            ? _continuousContent(
                                sequence: sequence,
                                playlist: playlist,
                                sectionTitle: sectionTitle,
                                nextCategory: nextCategory,
                                prevCategory: prevCategory,
                                look: look,
                              )
                            : _singleContent(
                                prayer: prayer,
                                neighbors: neighbors,
                                look: look,
                              ),
                      ),
                      // Edge glow when swiping past the end.
                      for (final edge in const [-1, 1])
                        EdgeGlow(edge: edge, visible: _glowEdge == edge),
                      ImmersiveHint(visible: _showImmersiveHint),
                      if (_showMala)
                        MalaCounterLayer(
                          onClose: () => setState(() => _showMala = false),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
