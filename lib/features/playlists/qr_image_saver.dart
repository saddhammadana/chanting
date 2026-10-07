/// Saves a rendered QR card: to Photos through `gal` on Android, iOS, macOS
/// and Windows, and as a downloaded PNG on the web. Split by conditional
/// import because `gal` is a native plugin and the download needs `package:web`.
library;

export 'qr_image_saver_io.dart'
    if (dart.library.js_interop) 'qr_image_saver_web.dart';

/// What happened to a save, so the page can say where the image went.
enum QrSaveOutcome { savedToPhotos, downloaded, denied, failed }
