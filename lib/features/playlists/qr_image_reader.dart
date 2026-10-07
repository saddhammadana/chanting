/// Reads prayer-set QR codes out of a picked image, for a code that arrived
/// as a picture (a saved share card sent in a chat) rather than on another
/// screen. Split by conditional import: devices decode with
/// `mobile_scanner`'s `analyzeImage` (Android, iOS, macOS), which the web
/// lacks, so the web uses the browser's `BarcodeDetector`; and the web build
/// cannot import `dart:io`.
library;

export 'qr_image_reader_io.dart'
    if (dart.library.js_interop) 'qr_image_reader_web.dart';
