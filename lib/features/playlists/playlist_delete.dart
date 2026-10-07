import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import 'playlists_controller.dart';

/// Deletes [playlist] at once and offers "เลิกทำ" in a SnackBar.
///
/// Undo instead of a confirm dialog: deleting is rare and deliberate, so a
/// question every time is friction, while a mistaken tap still costs nothing.
/// The messenger and notifier are read up front, because the set page calls
/// this as it closes.
void deletePlaylistWithUndo(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(playlistsControllerProvider.notifier);
  final index = notifier.remove(playlist.id);
  if (index < 0) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      appToast(
        l10n.playlistDeleted(playlist.name),
        kind: ToastKind.info,
        duration: const Duration(seconds: 6),
        actionLabel: l10n.playlistUndo,
        onAction: () => notifier.restore(playlist, index),
      ),
    );
}
