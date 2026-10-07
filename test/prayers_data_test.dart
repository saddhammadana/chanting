import 'dart:convert';
import 'dart:io';

import 'package:chanting/data/models/prayer.dart';
import 'package:chanting/data/repositories/prayer_repository.dart';
import 'package:chanting/features/prayer_list/prayer_list_controller.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// ids of prayers whose `paliText` was **actually checked against a book**.
///
/// **Add an id here only after checking against the real book, and also set
/// `"paliVerified": true` in prayers-th.json**. Tests below force both locations to
/// stay in sync and prevent silent verification. **AI must never fill this list,
/// even if instructed.**
///
/// **Empty since 2026-08-16**. `prayers-th.json` was fully rewritten under
/// docs/content/prayer-schema.md (72 prayers, ids regenerated from Pali roots). The generated
/// file marked 71/72 `verificationStatus.pali` values as `verified` without any
/// `reviewedBy`, violating spec rule 2: newly written prayers must start
/// `unverified`. **The app owner explicitly reset all of them to `unverified`**.
/// This list is empty to match data, not because nobody has ever checked them.
///
/// **The data file always wins in this sync direction**. A list claiming more
/// verified ids than the data certifies text nobody checked, which is what this
/// flag exists to prevent. Removing ids is always safe; adding ids to match data
/// requires a human confirming the book was checked. AI cannot do either direction.
const _paliVerifiedIds = <String>{};

/// ids of prayers whose translation was **actually checked against the source translation**.
///
/// Intentionally empty. There used to be no translation verification tracking,
/// even though many Thai translations were AI-drafted like the Pali. Moving to
/// `verificationStatus` in August 2026 **did not verify any extra translations**;
/// it only made the status expressible.
///
/// Same rules as [_paliVerifiedIds]: **AI must not fill this list**.
const _translationVerifiedIds = <String>{};

/// Non-ASCII characters allowed in `paliText`. **All 8 bundled font files can draw
/// them** (Sarabun x5, Pridi x3), verified directly against cmap.
///
/// The app does not load fonts at runtime, so missing glyphs have poor fallback,
/// especially on web CanvasKit. `ṁ` (U+1E41 dot above) **is not in the fonts; do
/// not use it**. Use `ṃ` (U+1E43 dot below). See CLAUDE.md Romanized Pali.
///
/// Before adding a new character here, check every font file using the CLAUDE.md script.
const _drawablePaliChars = {
  'Ñ',
  'ñ',
  'Ā',
  'ā',
  'ī',
  'Ī',
  'ū',
  'Ū',
  'Ḍ',
  'ḍ',
  'ḷ',
  'ṃ',
  'ṅ',
  'ṇ',
  'ṭ',
  'Ṭ', //
};

/// ids of prayers already released to users. **Do not remove ids from this list**.
///
/// User favorites, playlists, and resume cards store these ids in SharedPreferences
/// on the user's device. Changing or deleting an id in prayers-th.json silently and
/// unrecoverably breaks that user data.
///
/// Adding a new prayer: append the new id to this list.
/// Renaming a prayer: edit `title`, not `id`; ids are not user-facing text.
///
/// **This list was fully rewritten on 2026-08-16** during the docs/content/prayer-schema.md
/// rebuild of `prayers-th.json`. All ids were regenerated from Pali roots; spec rule
/// 4 allowed paying the id-change cost **once** to bring the whole book under one
/// rule, and 14 merged prayers disappeared. **That cost has already been paid**.
/// From now on, "do not remove from this list" is fully enforced again.
const _publishedIds = {
  'ratanattaya-vandana',
  'tisaranagamana-patha',
  'ratanattaya-guna',
  'ratanattaya-puja-yo-so',
  'buddhanussati',
  'buddhabhigiti',
  'dhammanussati',
  'dhammabhigiti',
  'sanghanussati',
  'sanghabhigiti',
  'bucha-phra-rattanatrai',
  'mettapharana',
  'buddha-jaya-mangala-gatha',
  'jaya-paritta',
  'uddisanadhitthanagatha',
  'anumodanarambha-gatha',
  'chinabanchon',
  'phicharana-sangkhan',
  'phatthekaratta-katha',
  'sappapattidana-katha',
  'ratanattayapanama-sangwek',
  'phutthaphithuti',
  'thammaphithuti',
  'sanghaphithuti',
  'thawattingsakan-patha',
  'aphinha-patchawekkhana',
  'khemakhem-sarana-katha',
  'owatpatimokkha-katha',
  'ariyathana-katha',
  'tilakkhanathi-katha',
  'pharasutta-katha',
  'patchima-phutthowat',
  'pathama-phuttha-phasit',
  'thammakharawathi-katha',
  'tirokuddakanda-pacchimabhaga',
  'aggappasada-sutta-gatha',
  'bhojanadananumodana-gatha',
  'kaladanasutta-gatha',
  'bhavatu-sabba-mangala',
  'namakara-siddhi-gatha',
  'sambuddhe',
  'namokaratthaka',
  'mangala-sutta',
  'karaniya-metta-sutta',
  'khandha-paritta',
  'mora-paritta',
  'atanatiya-paritta',
  'angulimala-paritta',
  'bojjhanga-paritta',
  'abhaya-paritta',
  'devata-uyyojana-gatha',
  'tangkhanika-patchawekkhana',
  'atita-patchawekkhana',
  'pappachit-aphinha-patchawekkhana',
  'satchakiriya-katha',
  'siluthet-patha',
  'tayana-katha',
  'owatpatimokkhathi-patha',
  'ariyasacca-katha',
  'karava-katha',
  'dhammuddesa-si',
  'phrommawihan-pharana',
  'parabhava-sut',
  'samana-sanya',
  'dhammapahangsana-patha',
  'vattaka-parit',
  'sangahavatthu-gatha',
  'pubba-bhaga-namakara',
  'samvega-parikittana-patha',
  'samannanumodana-gatha',
  'mangala-cakkavala-noi',
  'dhammacakkappavattana-sutta',
};

/// Check assets/data/prayers-th.json, the file meant to be edited most often and via
/// GitHub web editor without running Flutter. CI is the only gate before users see mistakes.
void main() {
  late List<Prayer> raw;
  late List<Prayer> all;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    all = await PrayerRepository().getAllPrayers();
    raw = all;
  });

  test('ids are unique so one prayer cannot shadow another', () {
    final ids = all.map((p) => p.id).toList();
    final dupes = ids
        .where((id) => ids.where((e) => e == id).length > 1)
        .toSet();
    expect(dupes, isEmpty, reason: 'id ซ้ำ: $dupes');
  });

  test('required fields are not blank', () {
    for (final p in all) {
      expect(p.id.trim(), isNotEmpty, reason: 'มีบทที่ id ว่าง');
      expect(p.title.trim(), isNotEmpty, reason: '${p.id}: title ว่าง');
      expect(p.text.trim(), isNotEmpty, reason: '${p.id}: text ว่าง');
    }
  });

  test(
    'missing nullable string fields decode as null instead of empty string',
    () {
      // Empty strings show the chip but leave an empty card; null hides it.
      for (final p in all) {
        final nullableStringFields = <String, String?>{
          'paliText': p.paliText,
          'meaning': p.meaning,
          'subcategory': p.subcategory,
          'type': p.type,
          'description': p.description,
          'author': p.author,
          'tipitakaNote': p.tipitakaNote,
          'tradition': p.tradition,
          'reviewedBy': p.reviewedBy,
        };
        for (final entry in nullableStringFields.entries) {
          expect(
            entry.value?.trim(),
            anyOf(isNull, isNotEmpty),
            reason: '${p.id}: ${entry.key} เป็นสตริงว่าง ให้ใช้ null แทน',
          );
        }
      }
    },
  );

  test(
    'published ids remain present so favorites and playlists do not break',
    () {
      final current = all.map((p) => p.id).toSet();
      final missing = _publishedIds.difference(current);
      expect(
        missing,
        isEmpty,
        reason:
            'id เหล่านี้หายไปจาก prayers-th.json: $missing\n'
            'ผู้ใช้ที่กด favorite หรือใส่บทนี้ในชุดสวดไว้จะเสียข้อมูลถาวร\n'
            'ถ้าตั้งใจเปลี่ยนชื่อบท ให้แก้ title ไม่ใช่ id\n'
            'ถ้าตั้งใจเลิกใช้บทนี้จริง ๆ ให้ลบออกจาก _publishedIds ด้วย '
            'และรับรู้ว่าข้อมูลผู้ใช้ที่ชี้มาจะหาย',
      );
    },
  );

  test('new prayers are registered in _publishedIds', () {
    // Backup guard: if a new prayer is not added to the golden list, the next id
    // change would go unnoticed.
    final current = all.map((p) => p.id).toSet();
    final unregistered = current.difference(_publishedIds);
    expect(
      unregistered,
      isEmpty,
      reason:
          'บทใหม่ยังไม่ได้ขึ้นทะเบียน: $unregistered\n'
          'เติม id พวกนี้ใน _publishedIds ที่หัวไฟล์ test นี้',
    );
  });

  test('paliText uses only glyphs supported by bundled fonts', () {
    // Fonts are not loaded at runtime, so missing glyphs render wrong or boxed on
    // real devices while tests still pass. `ṁ` once slipped into 255 places.
    for (final p in all) {
      final pali = p.paliText;
      if (pali == null) continue;
      final bad = pali.runes
          .where(
            (r) =>
                r > 127 && !_drawablePaliChars.contains(String.fromCharCode(r)),
          )
          .map(
            (r) =>
                '${String.fromCharCode(r)} (U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')})',
          )
          .toSet();
      expect(
        bad,
        isEmpty,
        reason:
            '${p.id}: paliText มีอักษรที่ฟอนต์วาดไม่ได้: $bad\n'
            'ถ้าเป็น ṁ (U+1E41) ให้ใช้ ṃ (U+1E43) แทน\n'
            'ถ้าตั้งใจเพิ่มตัวใหม่จริง ต้องตรวจกับฟอนต์ทั้ง 8 ไฟล์ก่อน '
            'แล้วเติมใน _drawablePaliChars ที่หัวไฟล์ test นี้',
      );
    }
  });

  test('foldForSearch covers every mark used in real Pali text', () {
    // Characters missing from the fold table silently make words unfindable with
    // a normal keyboard; ḍ and ḷ were once missing with no test coverage.
    for (final p in all) {
      final pali = p.paliText;
      if (pali == null) continue;
      final unfolded = foldForSearch(
        pali,
      ).runes.where((r) => r > 127).map(String.fromCharCode).toSet();
      expect(
        unfolded,
        isEmpty,
        reason:
            '${p.id}: fold แล้วยังเหลืออักษรนอก ASCII: $unfolded\n'
            'เติมตัวพวกนี้ใน _diacriticFolding ใน prayer_list_controller.dart',
      );
    }
  });

  test('paliVerified matches the golden list instead of passing silently', () {
    // prayers-th.json can be edited in GitHub web editor without running Flutter. Without
    // this test, anyone could flip false to true and silently mark unchecked Pali trusted.
    final verified = all.where((p) => p.paliVerified).map((p) => p.id).toSet();
    expect(
      verified,
      _paliVerifiedIds,
      reason:
          'paliVerified ใน prayers-th.json ไม่ตรงกับ _paliVerifiedIds ที่หัวไฟล์นี้\n'
          'ทานบทไหนเสร็จแล้ว ต้องแก้ทั้งสองที่พร้อมกัน — เป็นการยืนยันว่า'
          'มีคนเปิดหนังสือเทียบจริง ไม่ใช่ติ๊กผ่านมา',
    );
  });

  test('every prayer declares verification status in the source file', () async {
    // The model default is unverified, but invisible defaults do not force new
    // prayer authors to decide, so require it explicitly in the file.
    for (final entry in await _rawRecords()) {
      final v = entry['verificationStatus'];
      expect(
        v,
        isA<Map<String, dynamic>>(),
        reason:
            '${entry['id']}: ไม่มี verificationStatus\n'
            'เพิ่มบทใหม่ต้องใส่ {"pali": "unverified", "translation": "unverified"} '
            'ไปด้วยเสมอ (verified ได้ก็ต่อเมื่อมีคนทานกับหนังสือแล้ว)',
      );
      for (final k in const ['pali', 'translation']) {
        expect(
          (v! as Map<String, dynamic>).containsKey(k),
          isTrue,
          reason: '${entry['id']}: verificationStatus ขาด "$k"',
        );
      }
    }
  });

  test('fixed spelling must not regress from the published correction', () {
    // These two points were wrong when compared against a printed edition. Both
    // came from literal Thai pronunciation guides, which are reading aids rather
    // than Pali orthography and split clusters or lengthen vowels for Thai readers.
    //
    // **The Thai pronunciation guides are correct; do not edit them**. Only romanization was wrong.
    const fixed = {
      'davilocane': 'dvilocane', // dvi means two.
      'añjalīkaraṇīyo': 'añjalikaraṇīyo', // Short vowel in Pali.
    };
    final allPali = all.map((p) => p.paliText ?? '').join('\n');
    for (final entry in fixed.entries) {
      expect(
        allPali,
        isNot(contains(entry.key)),
        reason:
            '"${entry.key}" กลับมาแล้ว — ต้องเป็น "${entry.value}"\n'
            'ฉบับตีพิมพ์ 2 แหล่ง (A Chanting Guide ธรรมยุต + Thai Chanting '
            'ของ ancient-buddhist-texts.net) ยืนยันรูปที่ถูก\n'
            'อย่าถอดคำอ่านไทยตรงตัว — มันเป็นคู่มือออกเสียง ไม่ใช่อักขรวิธีบาลี',
      );
      expect(allPali, contains(entry.value));
    }
  });

  test(
    'new-shape prayers must not keep duplicate content shapes in source data',
    () async {
      // `sections`/`lines` are the only source of truth for migrated prayers.
      // `text`/`paliText`/`meaning` are computed from them (`Prayer._joinParts`).
      // If both exist, flat strings shadow structure (`_flat... ?? derived`) and
      // editing `lines` silently has no effect, a real bug once created by the edit page.
      for (final entry in await _rawRecords()) {
        final structured =
            entry.containsKey('sections') || entry.containsKey('lines');
        if (!structured) continue;
        for (final k in const ['text', 'paliText', 'meaning']) {
          expect(
            entry.containsKey(k),
            isFalse,
            reason:
                '${entry['id']}: มีทั้งโครงและ `$k` — ลบ `$k` ออก '
                '(ค่ามันคำนวณมาจากโครงอยู่แล้ว การเก็บไว้ทำให้โครงกลายเป็นของตาย)',
          );
        }
        expect(
          entry.containsKey('sections') && entry.containsKey('lines'),
          isFalse,
          reason:
              '${entry['id']}: มีทั้ง `sections` และ `lines` — เลือกอย่างเดียว',
        );
      }
    },
  );

  test('section type names are known by the code', () async {
    // `PrayerPartType.parse` intentionally falls back to `chant` for unknown values
    // so GitHub web editor typos do not keep the app from opening. Misspellings are silent;
    // this test is what must speak up.
    final known = PrayerPartType.values.map((e) => e.name).toSet();
    for (final entry in await _rawRecords()) {
      for (final s in (entry['sections'] as List<dynamic>? ?? const [])) {
        final type = (s as Map)['type'];
        if (type == null) continue;
        expect(
          known,
          contains(type),
          reason:
              '${entry['id']}/${s['id']}: type "$type" ไม่มีในโค้ด '
              '(ที่มี: ${known.join(", ")}) — มันจะถูกอ่านเป็น chant เงียบ ๆ',
        );
      }
    }
  });

  test('translation verification status matches the golden list', () {
    final verified = all
        .where((p) => VerificationStatus.isVerified(p.verification.translation))
        .map((p) => p.id)
        .toSet();
    expect(
      verified,
      _translationVerifiedIds,
      reason:
          'สถานะ translation ในไฟล์ไม่ตรงกับ _translationVerifiedIds\n'
          'ติ๊กได้ก็ต่อเมื่อมีคนเทียบคำแปลกับฉบับแปลจริงแล้ว — AI ทำแทนไม่ได้',
    );
  });

  test('verification status values are known by the code', () async {
    final known = VerificationState.values.map((e) => e.key).toSet();
    for (final entry in await _rawRecords()) {
      final v = entry['verificationStatus'];
      if (v == null) continue;
      expect(
        v,
        isA<Map<String, dynamic>>(),
        reason: '${entry['id']}: verificationStatus ต้องเป็น object',
      );
      for (final e in (v! as Map<String, dynamic>).entries) {
        expect(
          const {'pali', 'translation'},
          contains(e.key),
          reason: '${entry['id']}: ไม่รู้จักส่วน "${e.key}"',
        );
        expect(
          known,
          contains(e.value),
          reason: '${entry['id']}/${e.key}: สถานะ "${e.value}" ไม่มีในโค้ด',
        );
      }
    }
  });

  test('paliVerified key is no longer used', () async {
    for (final entry in await _rawRecords()) {
      expect(
        entry.containsKey('paliVerified'),
        isFalse,
        reason:
            '${entry['id']}: ยังมี `paliVerified` — ย้ายไป verificationStatus',
      );
    }
  });

  test('prayer type values are known by the code', () async {
    // `type` replaces old `meta.prayerType` labels. The reader does not validate
    // because no code branches on it yet; this test guards typos.
    for (final entry in await _rawRecords()) {
      final type = entry['type'];
      if (type == null) continue;
      expect(
        kPrayerTypes,
        contains(type),
        reason:
            '${entry['id']}: type "\$type" ไม่มีใน kPrayerTypes '
            '(ที่มี: \${kPrayerTypes.join(", ")})',
      );
    }
  });

  test('legacy metadata keys are no longer used', () async {
    // All of these were replaced by spec rule 2 keys: `prayerType` -> `type` at prayer level,
    // `chantDurationMinutes`→`meta.durationMinutes`, `occasion`→`occasions`
    // short labels paired with prose `description`, `source` -> `sources`,
    // `tipitakaReference`→`tipitakaReferences`
    // Leaving old keys means storing the same fact twice, which will drift.
    for (final entry in await _rawRecords()) {
      final meta = (entry['meta'] as Map?) ?? const {};
      for (final k in Prayer.legacyMetaKeys) {
        expect(
          entry.containsKey(k) || meta.containsKey(k),
          isFalse,
          reason: '${entry['id']}: ยังมี `$k` อยู่',
        );
      }
    }
  });

  test('meta uses only keys allowed by spec section 2', () async {
    // Unknown model keys are ignored silently by design, so the reader tolerates
    // typos. This test must speak up or `occasoins` just loses data.
    for (final entry in await _rawRecords()) {
      final meta = (entry['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
      for (final k in meta.keys) {
        expect(
          Prayer.metaKeys,
          contains(k),
          reason:
              '${entry['id']}: meta มีคีย์ "$k" ที่โมเดลไม่รู้จัก '
              '(ที่มี: ${Prayer.metaKeys.join(", ")})',
        );
      }
    }
  });

  group('docs/content/prayer-schema.md section 3 orthography', () {
    // docs/roadmap/todo.md asked for these one rule at a time, "after that rule's data is
    // clean", because switching them all on at once would have failed the whole
    // book. Measured on 23 Aug 2026: four of the five are already clean, so they
    // are switched on here. The fifth — Thai and Roman punctuation matching
    // position for position — is genuinely violated (see the pappachit and
    // tayana entries in the prayer-content TODO) and stays off until a person decides
    // which side to correct.
    List<({String prayer, String line, String value})> lines(String field) => [
      for (final p in _records)
        for (final s
            in (p['sections'] as List? ?? []).cast<Map<String, dynamic>>())
          for (final l in (s['lines'] as List).cast<Map<String, dynamic>>())
            if (l[field] is String && (l[field] as String).trim().isNotEmpty)
              (
                prayer: p['id'] as String,
                line: l['id'] as String,
                value: l[field] as String,
              ),
    ];

    test('roman lines start with a capital', () {
      final bad = [
        for (final l in lines('roman'))
          if (RegExp(r'^[a-zāīūñṅṇṭḍḷṃ]').hasMatch(l.value))
            '${l.prayer}/${l.line}: ${l.value}',
      ];
      expect(bad, isEmpty, reason: bad.join('\n'));
    });

    test('roman lines end with a comma or full stop', () {
      // A closing quote may follow it: two lines quote speech.
      final bad = [
        for (final l in lines('roman'))
          if (!RegExp('[,.]["\u2019]?\$').hasMatch(l.value.trimRight()))
            '${l.prayer}/${l.line}: ${l.value}',
      ];
      expect(bad, isEmpty, reason: bad.join('\n'));
    });

    test(
      'text spells syllables out, with no pinthu/karan/niggahita/maiyamok',
      () {
        // `text` is the reading guide, so it carries no orthographic marks — those
        // belong to Pali written in Thai script, which this field is not.
        final bad = [
          for (final l in lines('text'))
            if (RegExp('[\u0E3A\u0E4C\u0E4D\u0E46]').hasMatch(l.value))
              '${l.prayer}/${l.line}: ${l.value}',
        ];
        expect(bad, isEmpty, reason: bad.join('\n'));
      },
    );

    test('the leader rubric never leaks into the roman field', () {
      // The leader marker belongs to the Thai reading; the Roman side is Pali and
      // carries no stage direction.
      final bad = [
        for (final l in lines('roman'))
          if (l.value.contains('(นำ)') || l.value.contains('(Leader)'))
            '${l.prayer}/${l.line}: ${l.value}',
      ];
      expect(bad, isEmpty, reason: bad.join('\n'));
    });
  });

  test('digits are Thai or Latin, never another numeral system', () {
    // A mixed-script zero shipped in one tipitakaReference: Arabic-Indic zero
    // (U+0660) where Thai zero belonged. The two are visually near-identical, so nothing
    // but a codepoint check finds it, and docs/content/prayer-schema.md section 3's
    // orthography rules had no test behind them.
    final offenders = <String>[];
    void walk(Object? node, String id) {
      if (node is String) {
        for (final rune in node.runes) {
          final ch = String.fromCharCode(rune);
          final isLatin = rune >= 0x30 && rune <= 0x39;
          final isThai = rune >= 0x0E50 && rune <= 0x0E59;
          // Any other decimal digit is a numeral from a script this app does
          // not use, which only ever arrives by a bad copy-paste.
          if (!isLatin && !isThai && _isDecimalDigit(rune)) {
            offenders.add(
              '$id: "$ch" (U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')})',
            );
          }
        }
      } else if (node is Map) {
        for (final v in node.values) {
          walk(v, id);
        }
      } else if (node is List) {
        for (final v in node) {
          walk(v, id);
        }
      }
    }

    for (final p in _records) {
      walk(p, p['id'] as String);
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('every meta source describes what it is', () async {
    // Spec rule 2: every source key is optional, but there must be enough for a
    // reader to identify the source. An empty object cites nothing.
    //
    // **Do not yet enforce literal spec `title`/`urls`**. Legacy prose from single
    // `meta.source` was moved wholesale into `note` during the August 2026 migration.
    // Splitting it into sources with `for`/`urls` requires human reading. Enforcing
    // now would fail the whole book with no one-pass fix.
    for (final p in all) {
      for (final s in p.sources) {
        expect(s.isEmpty, isFalse, reason: '${p.id}: มีแหล่งที่ว่างเปล่า');
        for (final f in s.forFields) {
          expect(
            kSourceFields,
            contains(f),
            reason: '${p.id}: `for` มี "$f" ซึ่งไม่ใช่ชื่อช่องในบรรทัด',
          );
        }
      }
    }
  });

  test('all prayers parse and at least one prayer exists', () {
    // fromJson uses direct `as String` / `as int`; missing fields or order typed
    // as "10" instead of 10 throw here instead of becoming a user-facing white screen.
    expect(raw, isNotEmpty);
    expect(all.length, _publishedIds.length);
  });
}

/// Raw records from the file, **not `raw` above**, which is `List<Prayer>` after
/// `fromJson` (`raw = all`). Tests checking *file shape* must see actual keys,
/// not model-interpreted data.
Future<List<Map<String, dynamic>>> _rawRecords() async {
  final bytes = await rootBundle.load('assets/data/prayers-th.json');
  return (jsonDecode(utf8.decode(bytes.buffer.asUint8List())) as List<dynamic>)
      .cast<Map<String, dynamic>>();
}

/// Whether [rune] is a decimal digit in some numeral system.
///
/// Dart has no Unicode category table, so the ranges that could plausibly reach
/// this file by copy-paste are listed: Arabic-Indic and its extended form,
/// Devanagari, Bengali, Lao, Myanmar and Khmer — the scripts that sit next to
/// Thai and Pali sources.
bool _isDecimalDigit(int rune) {
  const ranges = [
    [0x0660, 0x0669], // Arabic-Indic
    [0x06F0, 0x06F9], // Extended Arabic-Indic
    [0x0966, 0x096F], // Devanagari
    [0x09E6, 0x09EF], // Bengali
    [0x0ED0, 0x0ED9], // Lao
    [0x1040, 0x1049], // Myanmar
    [0x17E0, 0x17E9], // Khmer
  ];
  for (final r in ranges) {
    if (rune >= r[0] && rune <= r[1]) return true;
  }
  return false;
}

/// The raw records, read from the file rather than the parsed models: these
/// checks are about every string in the record, including metadata the model
/// does not expose.
final _records =
    (jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
            as List<dynamic>)
        .cast<Map<String, dynamic>>();
