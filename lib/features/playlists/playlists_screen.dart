import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/prefs_service.dart';
import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gold_play_button.dart';
import '../../theme/app_colors.dart';
import '../../theme/dashboard_tokens.dart';
import '../prayer_list/prayer_list_controller.dart' show foldForSearch;
import 'playlists_controller.dart';
import 'share_page_parts.dart';
import 'widgets/edit_decorations.dart';
import 'widgets/edit_header_app_bar.dart';
import 'widgets/marked_spans.dart';

/// "ชุดสวดของฉัน", drawn from
/// `design/mobile/icon/wait/02/Thai Meditation Mantra Collection App copy.png`:
/// a "create" card over one card per set, in the set and edit pages' frame.
///
/// A bottom-nav destination, so its header has no back button. The
/// artwork's filter tabs are left out (every set here is one the user made
/// or received — there is no "saved" kind). Search matches name and
/// description; the chosen sort is remembered.
/// Each set carries the same lotus-book cover as its own page, since sets
/// have no picture of their own; its length shows only as a prayer count,
/// because this page does not load the prayers to add up their minutes.
/// A card only opens or plays its set: pinning, editing and deleting are on
/// the set's own page.
class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

/// How the list is ordered. Remembered as a view setting; the stored order
/// of the sets is the user's own and a sort never rewrites it.
enum _Sort { created, name, count }

/// Thai writes a leading vowel before the consonant it follows in speech;
/// the dictionary files it under that consonant, so move it back for the
/// key. "เช้า" sorts under ช, not after ฮ.
String _thaiSortKey(String name) {
  final s = name.trim().toLowerCase();
  if (s.length > 1 && 'เแโใไ'.contains(s[0])) {
    return s[1] + s[0] + s.substring(2);
  }
  return s;
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  final _search = TextEditingController();
  // An unknown name (a later release's order) falls back to the default.
  late _Sort _sort =
      _Sort.values.asNameMap()[ref
          .read(prefsServiceProvider)
          .getPlaylistsSort()] ??
      _Sort.created;

  void _setSort(_Sort sort) {
    setState(() => _sort = sort);
    ref.read(prefsServiceProvider).setPlaylistsSort(sort.name);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Playlist> _shown(List<Playlist> all) {
    // Folded as every search in the app is, so "metta" finds "mettā" and
    // the highlight lands where the match was made.
    final query = foldForSearch(_search.text.trim());
    final shown = [
      for (final p in all)
        if (query.isEmpty ||
            foldForSearch(p.name).contains(query) ||
            (p.description != null &&
                foldForSearch(p.description!).contains(query)))
          p,
    ];
    switch (_sort) {
      case _Sort.created:
        break;
      case _Sort.name:
        shown.sort(
          (a, b) => _thaiSortKey(a.name).compareTo(_thaiSortKey(b.name)),
        );
      case _Sort.count:
        // Ties keep the user's order: List.sort is not stable.
        final place = {for (var i = 0; i < shown.length; i++) shown[i]: i};
        shown.sort((a, b) {
          final bySize = b.prayerIds.length.compareTo(a.prayerIds.length);
          return bySize != 0 ? bySize : place[a]!.compareTo(place[b]!);
        });
    }
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(playlistsControllerProvider);
    final playlists = _shown(all);

    return Scaffold(
      backgroundColor: editGround(Theme.of(context)),
      body: LayoutBuilder(
        builder: (context, box) {
          // The same column as Home and Prayers, the tabs either side of
          // this one: it is a list of rows, not a single composition like
          // the set editor, and at the editor's phone-wide column it sat as
          // a narrow strip between two wide tabs.
          final gutter = ((box.maxWidth - ContentWidth.gridWidth) / 2).clamp(
            0.0,
            double.infinity,
          );
          return CustomScrollView(
            slivers: [
              EditHeaderAppBar(
                title: l10n.playlistsTitle,
                subtitle: l10n.playlistsSubtitle,
                showBack: false,
                actions: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16),
                    child: IconButton(
                      icon: const Icon(Icons.move_to_inbox_outlined),
                      tooltip: l10n.playlistImportTitle,
                      style: appCircleIconButtonStyle(Theme.of(context)),
                      onPressed: () => context.push('/playlists/receive'),
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16 + gutter, 12, 16 + gutter, 28),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    // Nothing to search or sort until there is a set.
                    if (all.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('playlists_search'),
                                  controller: _search,
                                  onChanged: (_) => setState(() {}),
                                  decoration: editFieldDecoration(
                                    Theme.of(context),
                                    hint: l10n.playlistsSearchHint,
                                    prefix: const Icon(Icons.search),
                                    suffix: _search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 20,
                                            ),
                                            tooltip: l10n.searchClear,
                                            onPressed: () =>
                                                setState(_search.clear),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _SortButton(value: _sort, onSelected: _setSort),
                            ],
                          ),
                        ),
                      ),
                    if (all.isEmpty)
                      const SliverToBoxAdapter(child: _FirstSet())
                    else ...[
                      const SliverToBoxAdapter(child: _CreateCard()),
                      const SliverToBoxAdapter(child: SizedBox(height: 14)),
                    ],
                    if (all.isNotEmpty && playlists.isEmpty)
                      SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.search_off,
                          message: l10n.playlistsSearchEmpty,
                        ),
                      )
                    else if (all.isNotEmpty)
                      SliverList.separated(
                        itemCount: playlists.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _PlaylistCard(
                          playlist: playlists[index],
                          highlight: _search.text.trim(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The page before the first set: why sets exist, then the one way to make
/// one, then the way to bring one over from another device — the header's
/// receive button is easy to miss on a fresh install.
class _FirstSet extends StatelessWidget {
  const _FirstSet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Center(
          child: ExcludeSemantics(
            child: AppAssetImage(
              'assets/images/playlists/pale_amber_lotus_book.png',
              // The book stands upright, taller than it is wide; the widths
              // on these three pages keep it about as tall as the tilted
              // one it replaced.
              width: 84,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.playlistsEmptyMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.playlistsEmptyDetail,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        const _CreateCard(),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            key: const ValueKey('playlists_receive_link'),
            onPressed: () => context.push('/playlists/receive'),
            child: Text(l10n.playlistsReceiveInstead),
          ),
        ),
      ],
    );
  }
}

/// "จัดเรียง": a field-faced button beside the search that opens the three
/// orders, the current one ticked.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onSelected});

  final _Sort value;
  final ValueChanged<_Sort> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    final labels = {
      _Sort.created: l10n.playlistsSortCreated,
      _Sort.name: l10n.playlistsSortName,
      _Sort.count: l10n.playlistsSortCount,
    };
    return PopupMenuButton<_Sort>(
      key: const ValueKey('playlists_sort'),
      tooltip: l10n.playlistsSort,
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final entry in labels.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: entry.key == value,
            child: Text(entry.value),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkField : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dark ? AppColors.darkBorder : AppColors.panelEdge,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 20, color: shareGold(theme)),
            const SizedBox(width: 6),
            Text(l10n.playlistsSort, style: theme.textTheme.bodyMedium),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
    );
  }
}

/// "สร้างชุดสวดใหม่": a dashed gold ring with +, two lines, a chevron, and
/// the artwork's lotus spray fading in at the right.
class _CreateCard extends StatelessWidget {
  const _CreateCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final gold = shareGold(theme);
    final dark = theme.brightness == Brightness.dark;
    // A warm wash rising towards the lotus, so the card reads apart from
    // the set cards under it.
    final decoration = editPanelDecoration(theme).copyWith(
      border: Border.all(color: DashboardTokens.controlEdge(theme)),
      gradient: LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: dark
            ? [AppColors.darkSurface, AppColors.darkGoldSoft]
            : const [AppColors.creamLight, AppColors.creamWarm],
      ),
    );
    final radius = decoration.borderRadius! as BorderRadius;

    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('playlist_create_button'),
            onTap: () => context.push('/playlists/new'),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: 0,
                  bottom: -6,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Opacity(
                        opacity: dark ? 0.15 : 0.55,
                        child: const AppAssetImage(
                          'assets/images/playlists/golden_lotus_floral_ornament.png',
                          width: 140,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 14),
                  child: Row(
                    children: [
                      CustomPaint(
                        painter: _DashedRingPainter(color: gold),
                        child: SizedBox.square(
                          dimension: 48,
                          child: Icon(Icons.add, color: gold, size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.playlistCreateNew,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.playlistCreateHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
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
}

/// A thin dashed circle, the artwork's frame round the create card's +.
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashes = 24;
    const sweep = 3.14159265 * 2 / dashes;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(0.6), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => old.color != color;
}

/// One set: its cover, name, description and size, with play. Pin, edit
/// and delete live on the set's own page, which the card opens.
class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, this.highlight = ''});

  final Playlist playlist;

  /// The search text, marked in the name and description; empty marks none.
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Flat, held by the stronger control edge: a column of shadowed cards
    // read as a stack of shadows.
    final decoration = editPanelDecoration(theme).copyWith(
      border: Border.all(color: DashboardTokens.controlEdge(theme)),
      boxShadow: const [],
    );
    final description = playlist.description;
    final gold = shareGold(theme);
    final ids = playlist.prayerIds;
    // The all-prayers list's highlight colour.
    final fill = theme.colorScheme.secondaryContainer;

    return DecoratedBox(
      key: ValueKey('playlist_card_${playlist.id}'),
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: decoration.borderRadius! as BorderRadius,
          onTap: () => context.push('/playlists/${playlist.id}'),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 12),
            child: Row(
              children: [
                // Same 48px slot and 14px gap as the "create a set" card's
                // ring above, so the book sits under the ring and the two
                // cards' text starts on one line. Its height is held to the
                // three lines of text beside it rather than standing taller.
                const ExcludeSemantics(
                  child: SizedBox(
                    width: 48,
                    height: 56,
                    child: AppAssetImage(
                      'assets/images/playlists/pale_amber_lotus_book.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: markedSpans(
                            playlist.name,
                            highlight,
                            theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            fill,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description != null)
                        Text.rich(
                          TextSpan(
                            children: markedSpans(
                              description,
                              highlight,
                              theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              fill,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.article_outlined, size: 16, color: gold),
                          const SizedBox(width: 4),
                          Text(
                            l10n.playlistPrayerCount(ids.length),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (ids.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GoldPlayButton(
                    tooltip: l10n.playlistPlayAll,
                    size: 46,
                    onPressed: () =>
                        context.push('/prayer/${ids.first}?pl=${playlist.id}'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
