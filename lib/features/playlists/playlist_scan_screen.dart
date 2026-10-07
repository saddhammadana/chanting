import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../theme/app_colors.dart';
import 'playlist_share.dart';
import 'qr_image_reader.dart';
import 'share_page_parts.dart';

/// Whether in-app QR scanning is available on this platform: phones, and the
/// web through the browser's camera. Desktop apps show the receive page's
/// scan card disabled and keep paste, which works everywhere.
///
/// Use `defaultTargetPlatform`, not `dart:io Platform`, because this file must
/// compile for web builds. A browser can report any target platform, so
/// [kIsWeb] is checked first.
bool get playlistScanSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Stands in for [pickQrImage] in widget tests, which have neither a picker
/// nor a decoder; null uses the real one.
@visibleForTesting
Future<List<String>?> Function({required bool fromFiles})? debugPickQrImage;

/// QR scanner page for importing a playlist, drawn from
/// `design/mobile/icon/wait/01/Elegant Thai QR Scanner Interface.png`.
///
/// When a valid code is found — by the camera, or in a picked image — the
/// page pops with the raw code so the receive page can use the existing
/// preview flow. Scanning is just another way to enter the code; it has no
/// import logic of its own.
class PlaylistScanScreen extends StatefulWidget {
  const PlaylistScanScreen({super.key});

  @override
  State<PlaylistScanScreen> createState() => _PlaylistScanScreenState();
}

class _PlaylistScanScreenState extends State<PlaylistScanScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);

  /// Prevents repeated onDetect calls while the page is popping.
  bool _handled = false;

  /// Whether a non-app QR was seen; keep one warning instead of repeating per frame.
  bool _sawForeignCode = false;

  /// An image is being picked or decoded; the two pick buttons wait for it.
  bool _readingImage = false;

  static const _cornerLeft =
      'assets/images/playlists/gold_cloud_lotus_corner_left.png';
  static const _cornerRight =
      'assets/images/playlists/gold_cloud_lotus_corner_right.png';

  @override
  void initState() {
    super.initState();
    // The browser's own BarcodeDetector only (Chrome, Edge, Safari 17+).
    // The default falls back to a ~2 MB decoder fetched from a CDN, and this
    // app does not reach the network; without the API the camera panel shows
    // its error state and paste still works.
    if (kIsWeb) {
      MobileScannerPlatform.instance.setWebBarcodeReader(
        WebBarcodeReader.barcodeDetector,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pops with the first value that is a prayer-set code; true if one was.
  bool _accept(Iterable<String?> values) {
    if (_handled) return true;
    for (final raw in values) {
      if (raw != null && decodePlaylistShare(raw) != null) {
        _handled = true;
        context.pop(raw);
        return true;
      }
    }
    return false;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_accept(capture.barcodes.map((b) => b.rawValue))) return;
    if (!_sawForeignCode && capture.barcodes.isNotEmpty) {
      setState(() => _sawForeignCode = true);
    }
  }

  Future<void> _readImage({required bool fromFiles}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _readingImage = true);
    String? problem;
    try {
      final values =
          await (debugPickQrImage?.call(fromFiles: fromFiles) ??
              pickQrImage(_controller, fromFiles: fromFiles));
      if (values != null && !_accept(values)) {
        problem = l10n.playlistScanImageNotFound;
      }
    } catch (_) {
      problem = l10n.playlistScanImageFailed;
    }
    if (!mounted) return;
    setState(() => _readingImage = false);
    if (problem != null) {
      messenger.showSnackBar(appToast(problem, kind: ToastKind.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canReadImage = qrImageReadSupported;
    final pickEnabled = canReadImage && !_readingImage;

    return SharePageScaffold(
      title: l10n.playlistReceiveScanTitle,
      subtitle: l10n.playlistScanSubtitle,
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
                  opacity: Theme.of(context).brightness == Brightness.dark
                      ? 0.12
                      : 0.7,
                  child: AppAssetImage(asset, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
      ],
      children: [
        _CameraPanel(
          controller: _controller,
          onDetect: _onDetect,
          sawForeignCode: _sawForeignCode,
          onPickImage: pickEnabled ? () => _readImage(fromFiles: false) : null,
          // On the web both pickers are the same browser file dialog, so
          // the camera's photo button would repeat the card below. On a
          // phone they differ: photo library vs files app (where Safari puts
          // a downloaded share card).
          showPickImage: canReadImage && !kIsWeb,
        ),
        const SizedBox(height: 16),
        const _HowToCard(),
        if (canReadImage) ...[
          const SizedBox(height: 14),
          _OrDivider(text: l10n.playlistScanOr),
          const SizedBox(height: 14),
          _PickFileCard(
            onTap: pickEnabled ? () => _readImage(fromFiles: true) : null,
          ),
        ],
        const SizedBox(height: 18),
        _WhereNote(text: l10n.playlistScanWhereNote),
        // Room for the corner lotuses under the last line.
        const SizedBox(height: 70),
      ],
    );
  }
}

/// The live camera in a rounded panel: gold frame, flash and gallery
/// buttons, and the hint under the frame.
class _CameraPanel extends StatelessWidget {
  const _CameraPanel({
    required this.controller,
    required this.onDetect,
    required this.sawForeignCode,
    required this.onPickImage,
    required this.showPickImage,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool sawForeignCode;
  final VoidCallback? onPickImage;
  final bool showPickImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(22);
    // Text over the live picture: white with a soft shadow reads on any scene.
    const onCamera = TextStyle(
      color: Colors.white,
      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
    );

    // Square, taller than the artwork's panel, so the frame can sit in the
    // middle with room under it for the hint. The two round buttons share the top
    // corners; at the artwork's bottom left the gallery label ran into the
    // frame and the hint.
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: MobileScanner(
                controller: controller,
                onDetect: onDetect,
                // Camera startup failure is usually denied permission; show a
                // clear message instead of a black preview.
                errorBuilder: (context, error) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: EmptyState(
                    icon: Icons.no_photography_outlined,
                    message: l10n.playlistScanCameraError,
                  ),
                ),
              ),
            ),
            // Only the brackets are drawn; the camera is not dimmed around
            // them, as in the artwork. The hint sits under the frame. Both
            // go when the camera fails, or they cover its error message.
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, _) => state.error != null
                  ? const SizedBox.shrink()
                  : LayoutBuilder(
                      builder: (context, box) {
                        // Leaves the top corners' buttons and labels clear of it.
                        final frame = box.maxWidth * 0.5;
                        final top = (box.maxHeight - frame) / 2;
                        return Stack(
                          children: [
                            Positioned(
                              top: top,
                              left: (box.maxWidth - frame) / 2,
                              width: frame,
                              height: frame,
                              child: const CustomPaint(
                                painter: _FramePainter(),
                              ),
                            ),
                            Positioned(
                              top: top + frame + 12,
                              left: 24,
                              right: 24,
                              child: Text(
                                sawForeignCode
                                    ? l10n.playlistImportInvalid
                                    : l10n.playlistScanFrameHint,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.merge(
                                  onCamera,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _TorchButton(controller: controller, style: onCamera),
            ),
            if (showPickImage)
              Positioned(
                left: 12,
                top: 12,
                child: _RoundCameraButton(
                  icon: Icons.image_outlined,
                  label: l10n.playlistScanGallery,
                  style: onCamera,
                  onPressed: onPickImage,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Four thick gold corner brackets joined by a hairline square.
class _FramePainter extends CustomPainter {
  const _FramePainter();

  static const _gold = AppColors.scanFrameGold;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hairline = Paint()
      ..color = _gold.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(10)),
      hairline,
    );

    final bracket = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final arm = size.shortestSide * 0.16;
    const r = 12.0;
    for (final (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
      final x = dx * size.width;
      final y = dy * size.height;
      final sx = dx == 0 ? 1.0 : -1.0;
      final sy = dy == 0 ? 1.0 : -1.0;
      final path = Path()
        ..moveTo(x, y + sy * arm)
        ..lineTo(x, y + sy * r)
        ..arcToPoint(
          Offset(x + sx * r, y),
          radius: const Radius.circular(r),
          clockwise: sx * sy > 0,
        )
        ..lineTo(x + sx * arm, y);
      canvas.drawPath(path, bracket);
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => false;
}

/// Flash toggle, shown only while the camera reports a torch.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller, required this.style});

  final MobileScannerController controller;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final torch = state.torchState;
        if (torch == TorchState.unavailable) return const SizedBox.shrink();
        return _RoundCameraButton(
          icon: torch == TorchState.on
              ? Icons.flash_on
              : Icons.flash_off_outlined,
          label: l10n.playlistScanFlash,
          style: style,
          onPressed: controller.toggleTorch,
        );
      },
    );
  }
}

/// Dark glass circle over the camera with a label under it.
class _RoundCameraButton extends StatelessWidget {
  const _RoundCameraButton({
    required this.icon,
    required this.label,
    required this.style,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final TextStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          tooltip: label,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.45),
            foregroundColor: Colors.white,
            fixedSize: const Size.square(48),
          ),
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: Text(label, style: theme.textTheme.labelMedium?.merge(style)),
        ),
      ],
    );
  }
}

/// "วิธีการสแกน": a badge, a title and three numbered steps, with the lotus
/// artwork in the corner.
class _HowToCard extends StatelessWidget {
  const _HowToCard();

  static const _lotus =
      'assets/images/playlists/golden_lotus_glowing_stars.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    final decoration = shareCardDecoration(theme);
    final steps = [
      l10n.playlistScanStep1,
      l10n.playlistScanStep2,
      l10n.playlistScanStep3,
    ];

    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: decoration.borderRadius!,
        child: Stack(
          children: [
            Positioned(
              right: -8,
              bottom: -6,
              width: 130,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: dark ? 0.12 : 0.55,
                  child: const AppAssetImage(_lotus, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    // Same badge as a settings row's icon, squared off as drawn.
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: scheme.secondaryContainer.withValues(alpha: 0.45),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(
                      Icons.qr_code_2,
                      size: 30,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.playlistScanHowTo,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (final (i, step) in steps.indexed)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: scheme.secondaryContainer,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSecondaryContainer,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
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

/// "หรือ" between two hairlines.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = Expanded(
      child: Divider(color: theme.colorScheme.outlineVariant, height: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// "เลือกจากไฟล์" row: pick a jpg/png from the files app and read its QR.
class _PickFileCard extends StatelessWidget {
  const _PickFileCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final decoration = shareCardDecoration(theme);
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('scan_pick_file'),
          borderRadius: decoration.borderRadius as BorderRadius?,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 34,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.playlistScanFileTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.playlistScanFileDetail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The closing line: where a code is usually found.
class _WhereNote extends StatelessWidget {
  const _WhereNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 20, color: shareGold(theme)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
