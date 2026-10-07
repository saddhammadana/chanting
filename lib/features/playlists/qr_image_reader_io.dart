import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Platforms where `mobile_scanner` can decode a still image.
bool get qrImageReadSupported =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Lets the user pick an image — from the photo library, or with
/// [fromFiles] from the files app limited to jpg/png — and returns every QR
/// value found in it. Null means the picker was cancelled.
///
/// Throws when the image cannot be read or decoded; the caller says so.
Future<List<String>?> pickQrImage(
  MobileScannerController controller, {
  required bool fromFiles,
}) async {
  final file = await FilePicker.pickFile(
    type: fromFiles ? FileType.custom : FileType.image,
    allowedExtensions: fromFiles ? const ['jpg', 'jpeg', 'png'] : null,
  );
  if (file == null) return null;

  // Android hands back a content:// uri with no path; analyzeImage needs a
  // file, so copy it out to a temporary one.
  var path = file.path;
  Directory? temp;
  if (path == null) {
    temp = await Directory.systemTemp.createTemp('chanting_qr');
    final copy = File('${temp.path}/${file.name}');
    await copy.writeAsBytes(await file.readAsBytes());
    path = copy.path;
  }
  try {
    final capture = await controller.analyzeImage(
      path,
      formats: const [BarcodeFormat.qrCode],
    );
    return [
      for (final barcode in capture?.barcodes ?? const <Barcode>[])
        if (barcode.rawValue != null) barcode.rawValue!,
    ];
  } finally {
    await temp?.delete(recursive: true);
  }
}
