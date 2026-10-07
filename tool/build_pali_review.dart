// Builds a review page for checking paliText against a prayer book.
//
// Usage: dart run tool/build_pali_review.dart
// Output: build/pali-review.html (gitignored). Open it in a browser.
//
// Always reads the real assets/data/prayers-th.json. It does not copy content
// elsewhere, so it cannot drift; rerun it to see current verification progress.
//
// This is a script, not a test, so CI does not generate the review page on every
// run.
//
// Fonts are embedded so Pali renders with the same bundled Sarabun font users
// see in the app. Missing glyphs should surface during review, not in production.
library;

import 'dart:convert';
import 'dart:io';

/// Every Pali diacritic used in the file. These are common transcription errors,
/// so the review page highlights them.
final _diacritics = RegExp('([āīūñṅṇṭḍḷṃĀÑ])');

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _mark(String s) =>
    _esc(s).replaceAllMapped(_diacritics, (m) => '<b class="d">${m[1]}</b>');

List<String> _lines(String? s) => (s ?? '')
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();

String _fontData(String file) =>
    base64Encode(File('assets/google_fonts/$file').readAsBytesSync());

/// Whether this record's Pali is verified.
bool _paliVerified(Map<String, dynamic> e) =>
    (e['verificationStatus'] as Map?)?['pali'] == 'verified' ||
    e['paliVerified'] == true;

void main() {
  final prayers =
      (jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

  // Order and categories come from sections, not from prayer record fields.
  final sections =
      (jsonDecode(File('assets/data/sections-th.json').readAsStringSync())
              as List<dynamic>)
          .cast<Map<String, dynamic>>();
  final byId = {for (final p in prayers) p['id'] as String: p};

  final total = prayers.length;
  final done = prayers.where(_paliVerified).length;

  final cards = StringBuffer();
  var n = 0;
  final seen = <String>{};

  for (final section in sections) {
    cards.write('<h2>${_esc(section['title'] as String)}</h2>');
    for (final id in (section['prayerIds'] as List<dynamic>).cast<String>()) {
      final p = byId[id];
      // One prayer can appear in multiple sections; review it once.
      if (p == null || !seen.add(id)) continue;
      n++;
      final verified = _paliVerified(p);
      final thai = _lines(p['text'] as String?);
      final pali = _lines(p['paliText'] as String?);

      cards.write(
        '<section${verified ? ' class="done"' : ''}>'
        '<header><span class="num">$n</span>'
        '<h3>${_esc(p['title'] as String)}</h3>'
        '<code>${_esc(p['id'] as String)}</code>'
        '<span class="flag">${verified ? 'ทานแล้ว' : 'ยังไม่ทาน'}</span></header>',
      );

      // Pair line by line only when counts match. If counts differ, pretending
      // to align them compares the wrong lines.
      if (pali.isNotEmpty && thai.length == pali.length) {
        cards.write('<div class="rows">');
        for (var i = 0; i < pali.length; i++) {
          cards.write(
            '<div class="row"><p class="ref">${_esc(thai[i])}</p>'
            '<p class="pali">${_mark(pali[i])}</p></div>',
          );
        }
        cards.write('</div>');
      } else {
        cards.write(
          '<p class="note">Thai lines (${thai.length}) and Pali lines '
          '(${pali.length}) differ. Showing block comparison instead.</p>'
          '<div class="rows"><div class="row">'
          '<p class="ref">${_esc(thai.join('\n'))}</p>'
          '<p class="pali">${_mark(pali.join('\n'))}</p>'
          '</div></div>',
        );
      }
      cards.write('</section>');
    }
  }

  final html = StringBuffer()
    ..write('<!doctype html><html lang="th"><head><meta charset="utf-8">')
    ..write(
      '<meta name="viewport" content="width=device-width,initial-scale=1">',
    )
    ..write('<title>ทานบาลี $total บท — สวดมนต์</title><style>')
    ..write(
      '@font-face{font-family:Sarabun;src:url(data:font/ttf;base64,'
      '${_fontData('Sarabun-Regular.ttf')}) format("truetype");'
      'font-weight:400;font-display:block}'
      '@font-face{font-family:Pridi;src:url(data:font/ttf;base64,'
      '${_fontData('Pridi-SemiBold.ttf')}) format("truetype");'
      'font-weight:600;font-display:block}',
    )
    // Same palette as lib/theme/app_colors.dart, so the review page feels like
    // part of the app it supports.
    ..write(r'''
:root{--ground:#FAF3E3;--surface:#FFFBF0;--ink:#6D4C2F;--ink-soft:#9C7B5A;
--gold:#C9A227;--gold-soft:#F1E4BE;--border:#E7DABC;--flag:#A8422A}
@media (prefers-color-scheme:dark){:root{--ground:#241C14;--surface:#322718;
--ink:#E8DCC3;--ink-soft:#B8A88C;--gold:#D9B84A;--gold-soft:#473A22;
--border:#443725;--flag:#E0937C}}
*{box-sizing:border-box}
body{background:var(--ground);color:var(--ink);
font:400 16px/1.75 Sarabun,system-ui,sans-serif;
max-width:1180px;margin:0 auto;padding:32px 20px 80px}
h1{font:600 1.9rem/1.3 Pridi,serif;margin:0 0 .4em;text-wrap:balance}
h2{font:600 1.15rem/1.4 Pridi,serif;color:var(--gold);margin:3rem 0 .75rem;
padding-bottom:.35rem;border-bottom:1px solid var(--border);letter-spacing:.02em}
h3{font:600 1rem/1.4 Pridi,serif;margin:0}
.lead{background:var(--surface);border:1px solid var(--border);
border-left:3px solid var(--flag);border-radius:10px;padding:16px 18px;margin:0 0 1.5rem}
.lead p{margin:0 0 .5em}.lead p:last-child{margin:0}.lead strong{color:var(--flag)}
.bar{display:flex;align-items:center;gap:14px;flex-wrap:wrap;background:var(--surface);
border:1px solid var(--border);border-radius:10px;padding:10px 16px;margin-bottom:2rem;
position:sticky;top:8px;z-index:2}
.count{font-variant-numeric:tabular-nums;font-weight:600}
.track{flex:1;min-width:120px;height:6px;border-radius:3px;background:var(--gold-soft);overflow:hidden}
.fill{height:100%;background:var(--gold)}
.bar label{display:flex;align-items:center;gap:.45em;font-size:.85rem;color:var(--ink-soft);cursor:pointer}
.bar input{accent-color:var(--gold);width:1rem;height:1rem}
.bar input:focus-visible{outline:2px solid var(--gold);outline-offset:2px}
section{background:var(--surface);border:1px solid var(--border);border-radius:12px;
padding:16px 18px;margin-bottom:14px}
section.done{border-color:var(--gold)}
section header{display:flex;align-items:center;gap:.7em;flex-wrap:wrap;margin-bottom:.9rem}
.num{flex:none;width:1.75rem;height:1.75rem;border-radius:50%;display:grid;place-items:center;
background:var(--gold-soft);color:var(--ink);font-size:.8rem;font-weight:600;
font-variant-numeric:tabular-nums}
code{font:.72rem ui-monospace,monospace;color:var(--ink-soft)}
.flag{margin-left:auto;font-size:.7rem;font-weight:600;letter-spacing:.04em;
padding:.2em .7em;border-radius:999px;border:1px solid currentColor;color:var(--flag)}
section.done .flag{color:var(--gold)}
.rows{display:flex;flex-direction:column;gap:2px}
.row{display:grid;grid-template-columns:1fr 1fr;gap:18px;padding:6px 0;
border-top:1px solid var(--border)}
.row:first-child{border-top:0}
p{margin:0;white-space:pre-wrap}
.ref{color:var(--ink-soft);font-size:.95rem}
.pali{background:var(--gold-soft);border-radius:6px;padding:3px 9px;font-style:italic}
.note{color:var(--flag);font-size:.82rem;margin-bottom:.6rem;padding:6px 10px;
border-radius:6px;border:1px dashed currentColor}
.d{font-weight:400;box-shadow:inset 0 -.42em 0 var(--gold)}
:root.plain .d{box-shadow:none}
@media (max-width:820px){.row{grid-template-columns:1fr;gap:4px}.ref{font-size:.85rem}}
''')
    ..write('</style></head><body>')
    ..write('<h1>ทานบาลีอักษรโรมันกับหนังสือ</h1>')
    ..write(
      '<div class="lead">'
      '<p><strong>บาลีทั้ง $total บทนี้ AI ถอดจากความจำ ไม่ใช่คัดจากหนังสือ '
      '— ยังเชื่อถือไม่ได้</strong> เป็นตัวบล็อกเดียวที่เหลือของ docs/internationalization.md Phase 2 '
      'เพราะฉบับภาษาอื่นจะใช้บาลีเป็นเนื้อหาหลัก</p>'
      '<p>ซ้ายคือคำอ่านไทยในไฟล์ (ไว้อ้างอิงตำแหน่ง ไม่ต้องทาน) '
      'ขวาคือสิ่งที่ต้องเทียบกับหนังสือ ตัวขีดเส้นใต้ทองคือวรรณยุกต์ — '
      'จุดที่ถอดผิดบ่อยที่สุด</p>'
      '<p>เจอที่ผิด แก้ใน <code>assets/data/prayers-th.json</code> · ทานบทไหนจบ ตั้ง '
      '<code>"paliVerified": true</code> <strong>และ</strong>เติม id ใน '
      '<code>_paliVerifiedIds</code> ที่ <code>test/prayers_data_test.dart</code> '
      '— ต้องแก้ทั้งสองที่ ไม่งั้น CI แดง</p>'
      '<p>แบบแผน: นิคหิตเป็น<strong>จุดล่าง <code>ṃ</code></strong> (U+1E43) ทุกจุด '
      '— เลือกเพราะฟอนต์ที่ bundle ไว้วาดได้ ไม่ได้ถอดจากหนังสือ '
      'หน้านี้ใช้ Sarabun ตัวเดียวกับในแอป สิ่งที่เห็นจึงตรงกับที่ผู้ใช้เห็น</p>'
      '</div>',
    )
    ..write(
      '<div class="bar"><span class="count">ทานแล้ว $done / $total บท</span>'
      '<span class="track"><span class="fill" style="width:'
      '${(done / total * 100).toStringAsFixed(1)}%"></span></span>'
      '<label><input type="checkbox" id="mark" checked> เน้นวรรณยุกต์</label></div>',
    )
    ..write(cards)
    ..write(
      '<script>document.getElementById("mark").addEventListener("change",'
      'e=>document.documentElement.classList.toggle("plain",!e.target.checked));'
      '</script></body></html>',
    );

  Directory('build').createSync(recursive: true);
  final out = File('build/pali-review.html')
    ..writeAsStringSync(html.toString());

  stdout
    ..writeln('เขียน: ${out.path}')
    ..writeln('ขนาด: ${(html.length / 1024).round()} KB')
    ..writeln('บททั้งหมด: $total | ทานแล้ว: $done | เหลือ: ${total - done}');
}
