import 'dart:convert';
import 'dart:io';

import 'package:chanting/data/repositories/prayer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The data files are written by the dhamma admin's export
/// (`/admin/chants/export`), byte for byte in one format: two-space indent,
/// LF, one trailing newline, keys in the order the record was built.
///
/// **This is what catches a hand edit.** A JSON file edited here — a quick fix
/// in the GitHub web editor, an editor that reflows arrays — still parses and passes
/// every data test, and then the next export silently puts the old text back.
/// Re-encoding the parsed file must give back the exact bytes; if it does
/// not, the file did not come from the export. Fix the text in the admin and
/// export again rather than reformatting here.
void main() {
  for (final lang in kContentLanguages) {
    for (final path in [
      PrayerRepository.assetPathFor(lang),
      PrayerRepository.sectionsPathFor(lang),
    ]) {
      test('$path is exactly what the dhamma export writes', () {
        final raw = File(path).readAsStringSync();
        expect(
          raw.contains('\r'),
          isFalse,
          reason: '$path: ต้องขึ้นบรรทัดแบบ LF',
        );
        expect(raw.startsWith('﻿'), isFalse, reason: '$path: ต้องไม่มี BOM');
        final canonical =
            '${const JsonEncoder.withIndent('  ').convert(jsonDecode(raw))}\n';
        if (raw == canonical) return;

        final a = raw.split('\n');
        final b = canonical.split('\n');
        var line = 0;
        while (line < a.length && line < b.length && a[line] == b[line]) {
          line++;
        }
        fail(
          '$path ไม่ใช่รูปแบบที่ export จาก dhamma เขียน '
          '(ต่างกันที่บรรทัด ${line + 1})\n'
          '  ไฟล์:     ${line < a.length ? a[line] : '(จบไฟล์)'}\n'
          '  ที่ควรเป็น: ${line < b.length ? b[line] : '(จบไฟล์)'}\n'
          'ถ้าแก้ไฟล์นี้ด้วยมือ ให้ไปแก้ที่ /admin/chants แล้วดาวน์โหลดใหม่ '
          'ไม่อย่างนั้นการ export ครั้งหน้าจะเขียนทับ',
        );
      });
    }
  }
}
