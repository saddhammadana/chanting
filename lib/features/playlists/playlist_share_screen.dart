import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../theme/dashboard_tokens.dart';
import 'playlist_copy_code.dart';
import 'playlist_share.dart';
import 'playlists_controller.dart';
import 'qr_image_saver.dart';
import 'share_page_parts.dart';

/// Full page with a scannable QR card for one playlist, drawn from
/// `design/mobile/icon/wait/01/Thai Prayer Collection QR Share.png`.
///
/// The artwork's "แชร์ผ่าน" row (LINE, Facebook, …) is left out on purpose.
/// "บันทึก QR Code" saves the whole card as an image — to Photos on a device,
/// as a downloaded PNG on the web — and is hidden where that cannot work (no
/// QR for a very long set, or Linux, which has no gallery). "คัดลอกโค้ด" sits
/// under it on every platform.
class PlaylistShareScreen extends ConsumerStatefulWidget {
  const PlaylistShareScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<PlaylistShareScreen> createState() =>
      _PlaylistShareScreenState();
}

class _PlaylistShareScreenState extends ConsumerState<PlaylistShareScreen> {
  /// Boundary around the card, which is what "บันทึก QR Code" saves.
  final _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _saveCard() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _saving = true);
    // Anything thrown on the way (rendering, encoding, a platform error the
    // saver does not map) counts as a failed save. Uncaught, it skipped the
    // reset below and left the button disabled until the page was reopened.
    var outcome = QrSaveOutcome.failed;
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data != null) {
        outcome = await saveQrImage(
          data.buffer.asUint8List(),
          'chanting_qr_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (_) {
      outcome = QrSaveOutcome.failed;
    }
    final message = switch (outcome) {
      QrSaveOutcome.savedToPhotos => l10n.playlistShareQrSaved,
      QrSaveOutcome.downloaded => l10n.playlistShareQrDownloaded,
      QrSaveOutcome.denied => l10n.playlistShareQrSaveDenied,
      QrSaveOutcome.failed => l10n.playlistShareQrSaveFailed,
    };
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      appToast(
        message,
        kind: switch (outcome) {
          QrSaveOutcome.savedToPhotos ||
          QrSaveOutcome.downloaded => ToastKind.success,
          QrSaveOutcome.denied => ToastKind.warning,
          QrSaveOutcome.failed => ToastKind.error,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playlist = ref.watch(playlistProvider(widget.playlistId));

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

    final code = encodePlaylistShare(playlist);
    final canSave = code.length <= kShareQrMaxChars && qrImageSaveSupported;
    // Only the height is ours; colours and shape come from the theme.
    const buttonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
    );

    return SharePageScaffold(
      title: l10n.playlistShareTitle,
      subtitle: l10n.playlistShareQrSubtitle,
      children: [
        RepaintBoundary(
          key: _cardKey,
          child: _QrCard(playlist: playlist, code: code),
        ),
        const SizedBox(height: 20),
        _HowToCard(
          title: l10n.playlistShareHowTo,
          body: l10n.playlistShareScanHint,
        ),
        const SizedBox(height: 20),
        // The theme's pair, as on the playlist page's
        // "เพิ่มบท" / "เริ่มสวด" row: filled primary, outlined
        // secondary. Stacked rather than side by side, because
        // "บันทึก QR Code" wraps in half of a 360px phone.
        // Copy-code is always offered — it works on every
        // platform and for sets too long to draw as a QR.
        if (canSave) ...[
          FilledButton.icon(
            style: buttonStyle,
            onPressed: _saving ? null : _saveCard,
            icon: const Icon(Icons.file_download_outlined),
            label: Text(l10n.playlistShareQrSave),
          ),
          const SizedBox(height: 12),
        ],
        PlaylistCopyCodeButton(code: code, style: buttonStyle),
      ],
    );
  }
}

/// The shareable card: lotus crest, set name and size, QR, caption and motto
/// over the cloud-and-temple artwork.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.playlist, required this.code});

  final Playlist playlist;
  final String code;

  /// The supplied cloud-and-temple frame, cut in two across its thinnest
  /// point. The card is taller than the
  /// drawing, so the halves pin to the top and the bottom at their own aspect
  /// instead of one image being stretched; the cut edges are feathered, so
  /// they meet or leave a gap without a seam.
  static const _artworkTop =
      'assets/images/playlists/lotus_temple_cloud_frame_top.png';
  static const _artworkBottom =
      'assets/images/playlists/lotus_temple_cloud_frame_bottom.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    final gold = shareGold(theme);
    final soft = theme.colorScheme.onSurfaceVariant;

    final decoration = shareCardDecoration(theme);
    // The artwork runs to the card's edge, so the hairline is painted in the
    // foreground; drawn behind, the clouds and lotuses covered it.
    return Container(
      decoration: BoxDecoration(
        color: decoration.color,
        borderRadius: decoration.borderRadius,
        boxShadow: decoration.boxShadow,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: decoration.borderRadius,
        border: decoration.border,
      ),
      child: ClipRRect(
        borderRadius: decoration.borderRadius!,
        child: Stack(
          children: [
            // The artwork frames the sides and bottom; its middle is
            // transparent, so the text and QR sit on the card's own ground.
            for (final (asset, top) in [
              (_artworkTop, true),
              (_artworkBottom, false),
            ])
              Positioned(
                top: top ? 0 : null,
                bottom: top ? null : 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: dark ? 0.18 : 1,
                      child: AppAssetImage(asset, fit: BoxFit.fitWidth),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                children: [
                  _Crest(color: gold),
                  const SizedBox(height: 14),
                  Text(
                    playlist.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.playlistPrayerCount(playlist.prayerIds.length),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: soft),
                  ),
                  const SizedBox(height: 18),
                  if (code.length <= kShareQrMaxChars)
                    _QrBox(
                      code: code,
                      label: l10n.playlistShareQrSemantics(playlist.name),
                    )
                  else
                    // Very long playlists make a QR too dense to scan from a
                    // screen; the copy-code button below still works.
                    _TooLongNote(text: l10n.playlistShareTooLong),
                  const SizedBox(height: 14),
                  Text(
                    l10n.playlistShareQrCaption,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: soft),
                  ),
                  const SizedBox(height: 12),
                  const LotusRule(width: 200, lotus: 18),
                  const SizedBox(height: 10),
                  Text(
                    l10n.playlistShareQrMotto,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: soft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's lotus with an arrow-tipped rule reaching in from either side.
class _Crest extends StatelessWidget {
  const _Crest({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget arrow({required bool pointsRight}) => SizedBox(
      width: 44,
      child: Row(
        children: [
          if (!pointsRight) Icon(Icons.arrow_left, size: 12, color: color),
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.7)),
          ),
          if (pointsRight) Icon(Icons.arrow_right, size: 12, color: color),
        ],
      ),
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: arrow(pointsRight: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: OutlineLotus(size: 64, color: color),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: arrow(pointsRight: false),
          ),
        ],
      ),
    );
  }
}

class _QrBox extends StatelessWidget {
  const _QrBox({required this.code, required this.label});

  final String code;

  /// Read by screen readers in place of the modules, which say nothing.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // QR must stay black on white even in dark theme; inverted QR fails
        // on some scanners.
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [DashboardTokens.warmShadow(0.12, blur: 8, dy: 2)],
      ),
      child: QrImageView(
        data: code,
        size: 172,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
    return Semantics(
      // Its own node, so the label is not folded into the card's text.
      container: true,
      label: label,
      image: true,
      child: ExcludeSemantics(child: box),
    );
  }
}

class _TooLongNote extends StatelessWidget {
  const _TooLongNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

/// "วิธีการใช้งาน" row: a gold info disc beside a title and one line of help.
class _HowToCard extends StatelessWidget {
  const _HowToCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: shareCardDecoration(theme),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            // Same badge as a settings row's icon.
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondaryContainer.withValues(alpha: 0.45),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(Icons.info_outline, color: scheme.secondary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
