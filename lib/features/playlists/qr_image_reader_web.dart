import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web/web.dart' as web;

/// `analyzeImage` is not implemented for the web, so the browser's own
/// `BarcodeDetector` reads the picked image instead — the same native reader
/// the camera is pinned to, and like it, nothing is fetched. Browsers
/// without it (Firefox) hide the picking buttons.
bool get qrImageReadSupported => globalContext.has('BarcodeDetector');

/// Web twin of the device version: picks an image (the browser's file
/// dialog either way; [fromFiles] only narrows it to jpg/png) and returns
/// every QR value found in it. Null means the picker was cancelled.
///
/// Throws when the image cannot be decoded; the caller says so.
Future<List<String>?> pickQrImage(
  MobileScannerController controller, {
  required bool fromFiles,
}) async {
  final file = await FilePicker.pickFile(
    type: fromFiles ? FileType.custom : FileType.image,
    allowedExtensions: fromFiles ? const ['jpg', 'jpeg', 'png'] : null,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  final blob = web.Blob([bytes.toJS].toJS);
  final bitmap = await web.window.createImageBitmap(blob).toDart;
  try {
    final found = await _BarcodeDetector(
      _DetectorOptions(formats: ['qr_code'.toJS].toJS),
    ).detect(bitmap).toDart;
    return [for (final code in found.toDart) code.rawValue];
  } finally {
    bitmap.close();
  }
}

@JS('BarcodeDetector')
extension type _BarcodeDetector._(JSObject _) implements JSObject {
  external factory _BarcodeDetector(_DetectorOptions options);

  external JSPromise<JSArray<_DetectedBarcode>> detect(JSObject image);
}

extension type _DetectorOptions._(JSObject _) implements JSObject {
  external factory _DetectorOptions({JSArray<JSString> formats});
}

extension type _DetectedBarcode._(JSObject _) implements JSObject {
  external String get rawValue;
}
