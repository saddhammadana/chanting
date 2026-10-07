import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/app_toast.dart';
import '../../theme/app_colors.dart';
import 'playlist_share.dart';
import 'share_page_parts.dart';

/// Paste-a-code page for receiving a prayer set, drawn from
/// `design/mobile/icon/wait/02/Thai prayer code paste screen.png`.
///
/// It only takes the code: once it decodes, "ดูชุดสวด" opens the received
/// set's preview (`/playlists/preview`), the set page's own layout with
/// "ยืนยันรับชุดสวด" at its foot — the same page a scan lands on — so the
/// list, the skipped-prayer notice and the import live there, not here.
class PlaylistPasteScreen extends StatefulWidget {
  const PlaylistPasteScreen({super.key});

  @override
  State<PlaylistPasteScreen> createState() => _PlaylistPasteScreenState();
}

class _PlaylistPasteScreenState extends State<PlaylistPasteScreen> {
  final _codeController = TextEditingController();

  static const _artwork = 'assets/images/playlists/ivory_lotus_clipboard.png';
  static const _cornerLeft =
      'assets/images/playlists/gold_cloud_lotus_corner_left.png';
  static const _cornerRight =
      'assets/images/playlists/gold_cloud_lotus_corner_right.png';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      messenger.showSnackBar(
        appToast(l10n.playlistPasteClipboardEmpty, kind: ToastKind.warning),
      );
      return;
    }
    setState(() => _codeController.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;

    final text = _codeController.text.trim();
    final decoded = text.isEmpty ? null : decodePlaylistShare(text);

    return SharePageScaffold(
      title: l10n.playlistPasteTitle,
      subtitle: l10n.playlistPasteSubtitle,
      backdrop: [
        for (final (asset, left) in [
          (_cornerLeft, true),
          (_cornerRight, false),
        ])
          Positioned(
            left: left ? 0 : null,
            right: left ? null : 0,
            bottom: 0,
            width: 150,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: dark ? 0.12 : 0.7,
                  child: AppAssetImage(asset, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
      ],
      children: [
        ExcludeSemantics(
          child: Opacity(
            opacity: dark ? 0.85 : 1,
            child: const AppAssetImage(
              _artwork,
              height: 190,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.playlistPasteLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('paste_code_field'),
          controller: _codeController,
          minLines: 4,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.playlistImportHint,
            errorText: text.isNotEmpty && decoded == null
                ? l10n.playlistImportInvalid
                : null,
            errorMaxLines: 2,
            // White, as the edit page's fields: the theme's cream fill all
            // but vanished against this page's cream ground.
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? AppColors.darkField
                : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: shareGold(theme)),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('paste_from_clipboard'),
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
          ),
          onPressed: _pasteFromClipboard,
          icon: const Icon(Icons.content_paste),
          label: Text(l10n.playlistPasteFromClipboard),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: shareGold(theme)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.playlistPasteNote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('paste_submit'),
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
          ),
          // Disabled until the code decodes, as the artwork draws it.
          onPressed: decoded == null
              ? null
              : () => context.push('/playlists/preview', extra: text),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.playlistViewSet),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        // Room for the corner lotuses under the button.
        const SizedBox(height: 90),
      ],
    );
  }
}
