import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import 'qr_image_saver.dart';

/// Platforms `gal` can write to the photo gallery on; Linux has none, so the
/// share page offers copy-code there instead.
bool get qrImageSaveSupported =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

Future<QrSaveOutcome> saveQrImage(Uint8List png, String name) async {
  try {
    await Gal.putImageBytes(png, name: name);
    return QrSaveOutcome.savedToPhotos;
  } on GalException catch (e) {
    return e.type == GalExceptionType.accessDenied
        ? QrSaveOutcome.denied
        : QrSaveOutcome.failed;
  }
}
