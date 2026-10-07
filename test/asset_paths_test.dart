import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Guards the asset paths written in Dart source, and the weight of the
/// artwork behind them.
///
/// Both halves come from real breakage. An asset renamed in the folder left
/// `settings_scaffold.dart` pointing at a path with no file, and nothing
/// failed: `AppAssetImage` catches the load error and draws the
/// missing-image artwork, so the app kept running with the wrong picture on
/// screen. And the decorative PNGs were shipping at 1536x1024 while being
/// drawn at 34-200 logical pixels, which made `assets/images` 13x heavier
/// than the entire prayer book.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  /// Every `'assets/…'` literal in `lib/`, with the file that wrote it.
  Map<String, Set<String>> assetLiterals() {
    final found = <String, Set<String>>{};
    final pattern = RegExp("'(assets/[^']+)'");
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entry.readAsStringSync())) {
        final path = match.group(1)!;
        // `'assets/data/prayers-$languageCode.json'` names a family, not a
        // file; which editions exist is `prayer_editions_test`'s business.
        if (path.contains(r'$')) continue;
        found.putIfAbsent(path, () => <String>{}).add(entry.path);
      }
    }
    return found;
  }

  test('ทุก path ของ asset ที่โค้ดอ้างถึงโหลดได้จริง', () async {
    final literals = assetLiterals();
    // A literal built from a variable would never be found, so a run that
    // collects nothing means the scan broke, not that the code is clean.
    expect(literals, isNotEmpty, reason: 'ไม่พบ path ของ asset ใน lib/ เลย');

    final missing = <String>[];
    for (final entry in literals.entries) {
      // Both halves are needed. The file on disk is the truth, and
      // `flutter test` can serve a stale copy of a file that was just
      // deleted (its asset bundle is only added to, never pruned) — while
      // the bundle load is what catches a file that exists but never
      // reached the bundle, which is the `mv`-keeps-the-mtime trap.
      var loads = File(entry.key).existsSync();
      if (loads) {
        try {
          await rootBundle.load(entry.key);
        } catch (_) {
          loads = false;
        }
      }
      if (!loads) missing.add('${entry.key}  ← ${entry.value.join(', ')}');
    }
    expect(
      missing,
      isEmpty,
      reason:
          'asset เหล่านี้โหลดไม่ได้ — ไฟล์หาย เปลี่ยนชื่อ หรือยังไม่เข้า bundle\n'
          '(ถ้าไฟล์อยู่จริง ลอง `touch` มัน: mv/git mv รักษา mtime เดิม '
          'ตัว asset bundler จึงไม่เห็นชื่อใหม่)\n'
          '${missing.join('\n')}',
    );
  });

  test('รูปตกแต่งไม่ใหญ่เกินกว่าที่วาดจริง', () {
    // 1024px is ~4x the largest size any of this artwork is painted at, and
    // 400KB is well above every file after the September 2026 downscale
    // (largest: 236KB). Tripping this means a full-resolution export was
    // dropped in; resize it to ~4x its painted size first, e.g.
    // `magick f.png -filter Lanczos -resize 512x512'>' -strip f.png`.
    const maxSide = 1024;
    const maxBytes = 400 * 1024;
    final tooBig = <String>[];
    for (final entry in Directory('assets/images').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.png')) continue;
      final bytes = entry.readAsBytesSync();
      // PNG: 8-byte signature, then the IHDR chunk's width and height.
      final header = bytes.buffer.asByteData();
      final width = header.getUint32(16);
      final height = header.getUint32(20);
      if (width > maxSide || height > maxSide || bytes.length > maxBytes) {
        tooBig.add(
          '${entry.path}  ${width}x$height  ${(bytes.length / 1024).round()}KB',
        );
      }
    }
    expect(
      tooBig,
      isEmpty,
      reason:
          'รูปใหญ่เกินเพดาน (ด้านยาวสุด $maxSide px, ${maxBytes ~/ 1024}KB):\n'
          '${tooBig.join('\n')}',
    );
  });
}
