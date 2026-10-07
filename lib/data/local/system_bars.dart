import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('th.chanting.app/system_bars');

/// Hides or shows the status and navigation bars. A no-op on web and desktop.
///
/// Android asks the window directly (see `MainActivity`) instead of going
/// through [SystemChrome.setEnabledSystemUIMode]. Switching modes there also
/// switches how the window fits the system bars, and on some phones coming
/// back from immersive left the status bar as an empty black band on every
/// screen afterwards.
Future<void> setSystemBarsHidden(bool hidden) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await _channel.invokeMethod<void>('setHidden', {'hidden': hidden});
      return;
    } catch (_) {
      // No handler (tests, an embedder without MainActivity): fall through.
    }
  }
  try {
    await SystemChrome.setEnabledSystemUIMode(
      hidden ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  } catch (_) {
    // Nothing to hide on this platform.
  }
}
