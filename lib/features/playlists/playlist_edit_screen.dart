import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/playlist.dart';
import '../../data/models/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../prayer_list/prayer_list_controller.dart';
import 'playlists_controller.dart';
import 'share_page_parts.dart';
import 'widgets/edit_decorations.dart';
import 'widgets/edit_foot_frame.dart';
import 'widgets/edit_form_card.dart';
import 'widgets/edit_header_app_bar.dart';
import 'widgets/edit_tabs.dart';
import 'widgets/prayer_rows.dart';
import 'widgets/saved_dialog.dart';
import 'widgets/section_chips.dart';

/// Creates a set, or edits one, drawn from
/// `design/mobile/icon/wait/01/Thai Lotus Chant Set Builder.png` (the look)
/// and screens 2 and 4 of `Thai chant app with clean lists.png` (the chosen
/// tab and the success dialog). The widgets are in `widgets/`.
///
/// Everything is a draft until "บันทึกชุดสวด": leaving with changes asks
/// first. The artwork's cover picture and "เปลี่ยนรูปภาพ" are left out: sets
/// carry no picture.
class PlaylistEditScreen extends ConsumerStatefulWidget {
  const PlaylistEditScreen({
    super.key,
    this.playlistId,
    this.startOnSelected = false,
  });

  /// Null creates a new set.
  final String? playlistId;

  /// Open on "บทสวดที่เลือก" instead of "เลือกบทสวด".
  final bool startOnSelected;

  @override
  ConsumerState<PlaylistEditScreen> createState() => _PlaylistEditScreenState();
}

class _PlaylistEditScreenState extends ConsumerState<PlaylistEditScreen> {
  late final Playlist? _original = widget.playlistId == null
      ? null
      : ref.read(playlistProvider(widget.playlistId!));
  late final _name = TextEditingController(text: _original?.name);
  late final _description = TextEditingController(text: _original?.description);
  final _search = TextEditingController();
  late List<String> _ids = [...?_original?.prayerIds];
  late bool _onSelected = widget.startOnSelected;

  /// The page scrolls as one, so each tab keeps its own offset: coming back
  /// to "เลือกบทสวด" lands where the list was left. Null until visited.
  final _scroll = ScrollController();
  final _tabOffsets = <bool, double>{};

  /// On the pinned tab band, to find the offset at which it pins.
  final _tabsKey = GlobalKey();

  /// The page's own messenger: "added" is about this form, and in the root
  /// one it outlived the page and showed over the list it popped back to.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Category chip; null is "ทั้งหมด".
  String? _sectionId;
  String _query = '';
  bool _nameMissing = false;

  /// Set once saved, so leaving afterwards does not ask to discard.
  bool _saved = false;

  bool get _creating => widget.playlistId == null;

  bool get _dirty {
    if (_saved) return false;
    final o = _original;
    return _name.text.trim() != (o?.name ?? '') ||
        _description.text.trim() != (o?.description ?? '') ||
        !_sameIds(_ids, o?.prayerIds ?? const []);
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke: PopScope.canPop reads [_dirty], and a stale
    // value would let the page close without asking.
    _name.addListener(_textChanged);
    _description.addListener(_textChanged);
  }

  void _textChanged() => setState(() {
    if (_name.text.trim().isNotEmpty) _nameMissing = false;
  });

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(String prayerId) {
    final l10n = AppLocalizations.of(context);
    final adding = !_ids.contains(prayerId);
    setState(() {
      _ids = adding
          ? [..._ids, prayerId]
          : _ids.where((id) => id != prayerId).toList();
    });
    // Both ways: a row that leaves the selected tab with no word said reads
    // as a tap that did the wrong thing.
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        appToast(
          adding ? l10n.playlistPrayerAdded : l10n.playlistPrayerRemoved,
          kind: ToastKind.info,
          duration: const Duration(milliseconds: 1200),
        ),
      );
  }

  void _move(int oldIndex, int newIndex) {
    setState(() {
      final ids = [..._ids];
      ids.insert(newIndex, ids.removeAt(oldIndex));
      _ids = ids;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    final playlist = ref
        .read(playlistsControllerProvider.notifier)
        .save(
          id: widget.playlistId,
          name: name,
          description: _description.text,
          prayerIds: _ids,
        );
    setState(() => _saved = true);
    if (!_creating) {
      context.pop();
      return;
    }
    final view = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SavedDialog(name: playlist.name),
    );
    if (!mounted) return;
    if (view == true) {
      // Back from the set lands on the list, not on this finished form.
      context.pushReplacement('/playlists/${playlist.id}');
    } else {
      context.go('/');
    }
  }

  void _switchTab(bool selected) {
    if (selected == _onSelected) return;
    double? target = _tabOffsets[selected];
    if (_scroll.hasClients) {
      final here = _scroll.offset;
      _tabOffsets[_onSelected] = here;
      // A tab not visited yet opens at its top, with the tabs in view.
      if (target == null) {
        final sliver = _tabsKey.currentContext
            ?.findAncestorRenderObjectOfType<RenderSliver>();
        // The band pins once it reaches the bottom of the header.
        final pinsAt = sliver == null
            ? here
            : sliver.constraints.precedingScrollExtent -
                  MediaQuery.paddingOf(context).top -
                  EditHeaderAppBar.expandedHeight;
        target = here < pinsAt ? here : pinsAt;
      }
    }
    setState(() => _onSelected = selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || target == null) return;
      final p = _scroll.position;
      _scroll.jumpTo(target.clamp(p.minScrollExtent, p.maxScrollExtent));
    });
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlistDiscardTitle),
        content: Text(l10n.playlistDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.playlistKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.playlistDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_creating && _original == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          leadingWidth: appBackButtonLeadingWidth,
        ),
        body: EmptyState(
          icon: Icons.search_off,
          message: l10n.playlistNotFound,
        ),
      );
    }
    final prayersAsync = ref.watch(prayerListControllerProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _saved = true);
          Navigator.of(context).pop();
        }
      },
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          backgroundColor: editGround(theme),
          bottomNavigationBar: EditSaveBar(onSave: _save),
          // The header spans the window like the save bar's corners do; only
          // the form below it is held to the composed width.
          body: LayoutBuilder(
            builder: (context, box) => CustomScrollView(
              controller: _scroll,
              slivers: [
                EditHeaderAppBar(
                  title: _creating
                      ? l10n.playlistCreate
                      : l10n.playlistEditTitle,
                  subtitle: l10n.playlistEditSubtitle,
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16 + _gutter(box.maxWidth),
                    8,
                    16 + _gutter(box.maxWidth),
                    20,
                  ),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: EditFormCard(
                          name: _name,
                          description: _description,
                          nameMissing: _nameMissing,
                        ),
                      ),
                      // Pinned, so a long list never scrolls the way to the
                      // other tab off the screen.
                      PinnedHeaderSliver(
                        child: ColoredBox(
                          key: _tabsKey,
                          color: editGround(theme),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: EditTabs(
                              onSelected: _onSelected,
                              selectedCount: _ids.length,
                              onChanged: _switchTab,
                            ),
                          ),
                        ),
                      ),
                      // The selected tab opens into this panel.
                      DecoratedSliver(
                        // Its top edge is covered under the selected tab,
                        // whose own line and shadow carry on round it.
                        decoration: editPanelDecoration(
                          theme,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(18),
                          ),
                        ),
                        sliver: SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                          sliver: SliverMainAxisGroup(
                            slivers: prayersAsync.when(
                              loading: () => const [
                                SliverToBoxAdapter(child: LoadingIndicator()),
                              ],
                              error: (e, _) => [
                                SliverToBoxAdapter(
                                  child: EmptyState(
                                    icon: Icons.error_outline,
                                    message: l10n.prayerLoadError,
                                    detail: '$e',
                                  ),
                                ),
                              ],
                              data: (sections) => _onSelected
                                  ? _selectedSlivers(context, sections)
                                  : _chooseSlivers(context, sections),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Side space that centres the form in [ContentWidth.gridWidth].
  static double _gutter(double width) =>
      ((width - ContentWidth.gridWidth) / 2).clamp(0.0, double.infinity);

  /// Prayer id -> the first category it is filed under, for the row's tag.
  static Map<String, String> _sectionTitles(List<SectionPrayers> sections) => {
    for (final entry in sections.reversed)
      for (final prayer in entry.prayers) prayer.id: entry.section.title,
  };

  List<Widget> _chooseSlivers(
    BuildContext context,
    List<SectionPrayers> sections,
  ) {
    final l10n = AppLocalizations.of(context);
    final titles = _sectionTitles(sections);
    // Folded the way the all-prayers search folds, so "metta" finds "mettā".
    final query = foldForSearch(_query.trim());
    // One prayer can sit in several categories; this list picks prayers, so
    // each appears once, under the first category that holds it.
    final seen = <String>{};
    final prayers = [
      for (final entry in sections)
        if (_sectionId == null || entry.section.id == _sectionId)
          for (final prayer in entry.prayers)
            if (seen.add(prayer.id) &&
                (query.isEmpty || foldForSearch(prayer.title).contains(query)))
              prayer,
    ];

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionChips(
              sections: sections,
              selectedId: _sectionId,
              onSelected: (id) => setState(() => _sectionId = id),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('playlist_edit_search'),
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: editFieldDecoration(
                Theme.of(context),
                hint: l10n.playlistSearchHint,
                prefix: const Icon(Icons.search),
                suffix: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('playlist_edit_search_clear'),
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: l10n.searchClear,
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      if (prayers.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.search_off,
            message: l10n.searchNoResults,
          ),
        )
      else
        SliverList.separated(
          itemCount: prayers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final prayer = prayers[index];
            return ChoiceRow(
              key: ValueKey('choose_${prayer.id}'),
              prayer: prayer,
              tag: titles[prayer.id],
              selected: _ids.contains(prayer.id),
              onToggle: () => _toggle(prayer.id),
              highlight: _query.trim(),
            );
          },
        ),
    ];
  }

  List<Widget> _selectedSlivers(
    BuildContext context,
    List<SectionPrayers> sections,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (_ids.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.menu_book_outlined,
            message: l10n.playlistSelectedEmpty,
            detail: l10n.playlistSelectedEmptyDetail,
          ),
        ),
      ];
    }
    final titles = _sectionTitles(sections);
    final byId = <String, Prayer>{
      for (final entry in sections)
        for (final prayer in entry.prayers) prayer.id: prayer,
    };
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.drag_indicator, size: 18, color: shareGold(theme)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.playlistReorderHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverReorderableList(
        itemCount: _ids.length,
        onReorderItem: _move,
        proxyDecorator: (child, index, animation) =>
            Material(type: MaterialType.transparency, child: child),
        itemBuilder: (context, index) {
          final id = _ids[index];
          final prayer = byId[id];
          return Padding(
            key: ValueKey(id),
            padding: const EdgeInsets.only(bottom: 10),
            child: ReorderableDelayedDragStartListener(
              index: index,
              child: SelectedRow(
                index: index,
                title: prayer?.title ?? id,
                minutes: prayer?.durationMinutes,
                tag: titles[id],
                onRemove: () => _toggle(id),
              ),
            ),
          );
        },
      ),
    ];
  }
}
