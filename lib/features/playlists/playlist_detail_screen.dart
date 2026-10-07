import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/playlist.dart';
import '../../data/models/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/golden_pill_button.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../prayer_list/prayer_list_controller.dart';
import 'playlist_delete.dart';
import 'playlist_share.dart';
import 'playlists_controller.dart';
import 'widgets/playlist_detail_action_bar.dart';
import 'widgets/playlist_detail_body.dart';
import 'widgets/playlist_detail_frame.dart';

// Other pages import the minutes label from here.
export 'widgets/playlist_detail_stat.dart' show PrayerMinutes;

/// One prayer set, drawn from
/// `design/mobile/icon/wait/01/Buddhist Chanting Prayer Set Details copy.png`.
///
/// The artwork's parts that have no data behind them are left out rather
/// than invented: a set has no tags or like count, and a prayer has no
/// recorded length unless its record says so (none do yet), so the minutes
/// show only where they are known. The cover is the same lotus book for
/// every set — sets carry no picture of their own. Its "ดาวน์โหลด" is
/// dropped (there is no audio), and its bottom bar carries this app's set
/// actions — pin, edit, share — in place of favourite / save / share.
/// "จัดลำดับ" opens the edit page on its chosen-prayers tab, where the
/// reordering lives; the per-row menus are left out, so the rows only play.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  /// The set as last drawn, kept so a delete does not flash "not found"
  /// while this page slides away.
  Playlist? _last;
  bool _deleted = false;

  String get playlistId => widget.playlistId;

  void _open(String prayerId) =>
      context.push('/prayer/$prayerId?pl=$playlistId');

  void _edit() => context.push('/playlists/$playlistId/edit');

  void _reorder() => context.push('/playlists/$playlistId/edit?tab=selected');

  void _delete(Playlist playlist) {
    setState(() => _deleted = true);
    deletePlaylistWithUndo(context, ref, playlist);
    // Opened from a link there is no page underneath to return to.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/playlists');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final watched = ref.watch(playlistProvider(playlistId));
    final playlist = watched ?? (_deleted ? _last : null);
    final prayersAsync = ref.watch(prayerListControllerProvider);

    if (playlist == null) {
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
    _last = playlist;

    final options = [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 16),
        child: PopupMenuButton<String>(
          tooltip: l10n.menuOptions,
          icon: const Icon(Icons.more_vert),
          style: appCircleIconButtonStyle(Theme.of(context)),
          onSelected: (value) {
            if (value == 'edit') _edit();
            if (value == 'delete') _delete(playlist);
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.playlistEditTitle)),
            PopupMenuItem(
              value: 'delete',
              child: Text(l10n.menuDeletePlaylist),
            ),
          ],
        ),
      ),
    ];

    return PlaylistDetailFrame(
      title: l10n.playlistDetailTitle,
      subtitle: l10n.playlistDetailSubtitle,
      actions: options,
      footer: PlaylistDetailActionBar(playlist: playlist, onEdit: _edit),
      slivers: prayersAsync.when(
        loading: () => const [
          SliverFillRemaining(hasScrollBody: false, child: LoadingIndicator()),
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
        data: (sections) {
          final ids = playlist.prayerIds;
          return playlistDetailBody(
            context,
            name: playlist.name,
            description: playlist.description,
            ids: ids,
            byId: _prayersById(sections),
            onOpen: _open,
            onPlayAll: ids.isEmpty ? null : () => _open(ids.first),
            onReorder: _reorder,
            empty: EmptyState(
              icon: Icons.menu_book_outlined,
              message: l10n.playlistEmptyMessage,
              detail: l10n.playlistEmptyDetail,
              action: OutlinedButton.icon(
                style: goldOutlinedButtonStyle(Theme.of(context)),
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.playlistEditShort),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A set received from another device, shown before it is saved: the set
/// page's own layout, so what arrives looks like what it will become, with
/// "ยืนยันรับชุดสวด" at the foot in place of the set's actions.
///
/// Both ways in land here — a pasted code from the paste page, a scanned or
/// picked QR from the scan page — so the decode, the skipped-prayer notice
/// and the import live in one place. Only prayers this device knows are
/// listed and saved. Nothing chants the set as a whole until it is saved
/// (continuous reading follows a saved set), so a row opens one prayer.
class PlaylistPreviewScreen extends ConsumerWidget {
  const PlaylistPreviewScreen({super.key, required this.code});

  final String code;

  void _import(
    BuildContext context,
    WidgetRef ref,
    SharedPlaylist shared,
    List<String> found,
  ) {
    final playlist = ref
        .read(playlistsControllerProvider.notifier)
        .import(shared.name, found, description: shared.description);
    // Leave the receive flow behind: back from the new set returns to the
    // playlists screen, not to a code that has already been used.
    final router = GoRouter.of(context);
    router.go('/playlists');
    router.push('/playlists/${playlist.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shared = decodePlaylistShare(code);
    final prayersAsync = ref.watch(prayerListControllerProvider);

    if (shared == null) {
      return PlaylistDetailFrame(
        title: l10n.playlistDetailTitle,
        subtitle: l10n.playlistPreviewSubtitle,
        slivers: [
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.qr_code_2,
              message: l10n.playlistImportInvalid,
            ),
          ),
        ],
      );
    }

    final byId = _prayersById(prayersAsync.value ?? const []);
    final found = shared.prayerIds.where(byId.containsKey).toList();
    final skipped = shared.prayerIds.length - found.length;
    final ready = prayersAsync.hasValue && found.isNotEmpty;

    return PlaylistDetailFrame(
      title: l10n.playlistDetailTitle,
      subtitle: l10n.playlistPreviewSubtitle,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prayersAsync.hasValue && skipped > 0) ...[
            Text(
              l10n.playlistImportSkipped(skipped),
              key: const ValueKey('preview_skipped'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Held but dimmed while there is nothing to receive, so the page
          // still says what the button would do.
          IgnorePointer(
            ignoring: !ready,
            child: Opacity(
              opacity: ready ? 1 : 0.45,
              child: GoldenPillButton(
                key: const ValueKey('preview_confirm'),
                label: l10n.playlistImportAdd,
                // Supplied lotus tick, tinted to the button's own glyph
                // colour (white on gold, dark on the dark theme's gold).
                icon: Builder(
                  builder: (context) => AppAssetImage(
                    'assets/images/playlists/lotus_checkmark_white.png',
                    height: 22,
                    color: IconTheme.of(context).color,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                height: 56,
                expand: true,
                onPressed: () => _import(context, ref, shared, found),
              ),
            ),
          ),
        ],
      ),
      slivers: prayersAsync.when(
        loading: () => const [
          SliverFillRemaining(hasScrollBody: false, child: LoadingIndicator()),
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
        data: (_) => playlistDetailBody(
          context,
          name: shared.name,
          description: shared.description,
          ids: found,
          byId: byId,
          onOpen: (id) => context.push('/prayer/$id'),
          empty: EmptyState(
            icon: Icons.menu_book_outlined,
            message: l10n.playlistImportEmpty,
          ),
        ),
      ),
    );
  }
}

/// Id -> prayer across every category; a prayer filed in several collapses
/// to one entry.
Map<String, Prayer> _prayersById(List<SectionPrayers> sections) => {
  for (final entry in sections)
    for (final prayer in entry.prayers) prayer.id: prayer,
};
