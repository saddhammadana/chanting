import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';

/// Copies a playlist share [code] and confirms with a SnackBar.
///
/// Public so any page offering the chat-code route shares one behaviour and
/// one message; the receiving side is "รับชุดสวด" on the playlists screen.
Future<void> copyPlaylistShareCode(BuildContext context, String code) async {
  final l10n = AppLocalizations.of(context);
  await Clipboard.setData(ClipboardData(text: code));
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(appToast(l10n.playlistShareCopied));
  }
}

/// "คัดลอกโค้ด" button for a playlist share [code]; [style] lets a page keep
/// its own button shape.
class PlaylistCopyCodeButton extends StatelessWidget {
  const PlaylistCopyCodeButton({super.key, required this.code, this.style});

  final String code;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: style,
      onPressed: () => copyPlaylistShareCode(context, code),
      icon: const Icon(Icons.copy_outlined),
      label: Text(AppLocalizations.of(context).playlistShareCopy),
    );
  }
}
