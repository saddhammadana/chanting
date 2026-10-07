import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'qr_image_saver.dart';

/// Every browser can download a file, so the web always offers saving.
bool get qrImageSaveSupported => true;

Future<QrSaveOutcome> saveQrImage(Uint8List png, String name) async {
  try {
    final blob = web.Blob(
      [png.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = '$name.png';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    // Revoking in the same tick can cancel the download in some browsers.
    Future<void>.delayed(
      const Duration(seconds: 1),
      () => web.URL.revokeObjectURL(url),
    );
    return QrSaveOutcome.downloaded;
  } catch (_) {
    return QrSaveOutcome.failed;
  }
}
