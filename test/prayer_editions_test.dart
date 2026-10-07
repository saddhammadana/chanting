import 'dart:convert';
import 'dart:io';

import 'package:chanting/data/edition_drift.dart';
import 'package:chanting/data/models/prayer.dart';
import 'package:chanting/data/models/prayer_section.dart';
import 'package:chanting/data/repositories/prayer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// CI gate for full prayer-content editions.
///
/// Each language is a full source-shaped content file. This keeps the project
/// open-source friendly: English is not a thin overlay over Thai, and each
/// edition can be inspected, diffed, and attributed on its own.
///
/// Real failure modes remain, all possible from hand-editing files, which is an
/// intended GitHub web editor workflow:
/// 1. An edition is missing an id/category or adds one the others do not have.
/// 2. A prayer belongs to no category, or a category references a missing prayer id.
///
/// **Rule 1 intentionally lives in `lib/data/edition_drift.dart`, not here**.
/// The edit-screen warning banner calls the same [editionDrift], so tooling and
/// CI use one rule set. This file runs it against real files and proves with
/// synthetic data that the gate catches problems.

String _read(String name) => File('assets/data/$name').readAsStringSync();

void main() {
  test('disk files match kContentLanguages', () {
    final langs = <String>{kDefaultContentLanguage};
    for (final f in Directory('assets/data').listSync().whereType<File>()) {
      final m = RegExp(r'prayers-(\w+)\.json$').firstMatch(f.path);
      if (m != null) langs.add(m.group(1)!);
    }
    expect(
      langs,
      kContentLanguages,
      reason:
          'ไฟล์ content edition บนดิสก์ไม่ตรงกับ kContentLanguages ใน '
          'prayer_repository.dart\n'
          'วางไฟล์ไว้แต่ไม่ประกาศ = ไม่มีใครได้ใช้; ประกาศแต่ไม่มีไฟล์ = แอปพัง',
    );
    expect(
      File(
        'assets/data/${PrayerRepository.sourcePath.split('/').last}',
      ).existsSync(),
      isTrue,
      reason: 'ไม่มีไฟล์ต้นฉบับ ซึ่งเป็นที่เดียวที่ id/บาลี/ลำดับอยู่',
    );
  });

  test('every content edition keeps the same prayer and category ids', () {
    final sourceIds = {
      for (final p in PrayerRepository.decodePrayers(_read('prayers-th.json')))
        p.id,
    };
    final sectionIds = {
      for (final s in PrayerRepository.decodeSections(
        _read('sections-th.json'),
      ))
        s.id,
    };
    for (final lang in kContentLanguages) {
      if (lang == kDefaultContentLanguage) continue;
      final editionIds = {
        for (final p in PrayerRepository.decodePrayers(
          _read('prayers-$lang.json'),
        ))
          p.id,
      };
      final editionSectionIds = {
        for (final s in PrayerRepository.decodeSections(
          _read('sections-$lang.json'),
        ))
          s.id,
      };
      expect(
        editionDrift(
          otherLang: lang,
          sourceIds: sourceIds,
          overlayIds: editionIds,
          sourceSectionIds: sectionIds,
          overlaySectionIds: editionSectionIds,
        ),
        isEmpty,
      );
    }
  });

  test('every declared edition has parseable prayers and sections', () {
    for (final lang in kContentLanguages) {
      final prayerFile = lang == kDefaultContentLanguage
          ? 'prayers-th.json'
          : 'prayers-$lang.json';
      final sectionFile = lang == kDefaultContentLanguage
          ? 'sections-th.json'
          : 'sections-$lang.json';
      expect(PrayerRepository.decodePrayers(_read(prayerFile)), isNotEmpty);
      expect(PrayerRepository.decodeSections(_read(sectionFile)), isNotEmpty);
    }
  });

  test('every prayer belongs to at least one category', () {
    final prayers = PrayerRepository.decodePrayers(_read('prayers-th.json'));
    final sections = PrayerRepository.decodeSections(_read('sections-th.json'));
    final inSections = {for (final s in sections) ...s.prayerIds};
    final ids = prayers.map((p) => p.id).toSet();
    expect(
      ids.difference(inSections),
      isEmpty,
      reason:
          'บทพวกนี้ไม่อยู่หมวดไหนเลย จะไม่โผล่ในกล่องหน้าแรก '
          '(ยังเปิดผ่าน /all และ favorites ได้ แต่แทบไม่มีใครเจอ)',
    );
    expect(
      inSections.difference(ids),
      isEmpty,
      reason: 'หมวดอ้าง id ที่ไม่มีบทอยู่จริง',
    );
  });

  // ---- Prove the gate really catches issues ----

  test(
    'validator catches overlay translations for ids missing from the source',
    () {
      expect(
        editionDrift(
          otherLang: 'en',
          sourceIds: {'a1', 'a2'},
          overlayIds: {'a1', 'a9'},
        ),
        contains(predicate<String>((s) => s.contains('a9'))),
      );
    },
  );

  test('validator catches overlay category titles missing from the source', () {
    expect(
      editionDrift(
        otherLang: 'en',
        sourceIds: {'a1'},
        overlayIds: {'a1'},
        sourceSectionIds: {'cat1'},
        overlaySectionIds: {'cat1', 'cat9'},
      ),
      contains(predicate<String>((s) => s.contains('cat9'))),
    );
  });

  test('incomplete overlay translations are allowed as unfinished work', () {
    expect(
      editionDrift(
        otherLang: 'en',
        sourceIds: {'a1', 'a2', 'a3'},
        overlayIds: {'a1'},
        sourceSectionIds: {'cat1', 'cat2'},
        overlaySectionIds: {'cat1'},
      ),
      isEmpty,
    );
  });

  // ---- Source + overlay composition ----

  group('Prayer.withOverlay', () {
    const source = Prayer(
      id: 'x',
      title: 'บทกราบ',
      text: 'อักษรไทย',
      paliText: 'Arahaṃ',
      verification: VerificationStatus(pali: VerificationState.verified),
      meaning: 'คำแปลไทย',
      reviewedBy: 'ผู้ทาน',
    );

    test('missing overlay keys fall back to source values', () {
      // The old structure could not do this: an edition with translated titles
      // but untranslated meanings had to copy the whole Thai record as a placeholder.
      final en = source.withOverlay({'title': 'Homage'});
      expect(en.title, 'Homage');
      expect(en.text, 'อักษรไทย');
      expect(en.meaning, 'คำแปลไทย');
    });

    test('empty or null overlay returns the source exactly', () {
      expect(source.withOverlay(null).title, 'บทกราบ');
      expect(source.withOverlay(const {}).title, 'บทกราบ');
    });

    test('overlay cannot modify shared fields even when provided', () {
      // Overlay files are hand-editable; if someone adds paliText, it must have
      // no effect or Pali gets a second source guarded only by tests above.
      final en = source.withOverlay({
        'id': 'y',
        'paliText': 'Arahang',
        'paliVerified': false,
        'reviewedBy': 'คนอื่น',
        'title': 'Homage',
      });
      expect(en.id, 'x');
      expect(en.paliText, 'Arahaṃ');
      expect(en.paliVerified, isTrue);
      expect(en.reviewedBy, 'ผู้ทาน');
      expect(en.title, 'Homage');
    });

    test(
      'category overlays can only change title while order and icon come from source',
      () {
        const s = PrayerSection(
          id: 'cat1',
          title: 'ทำวัตรเช้า',
          prayerIds: ['a1', 'a2'],
          icon: 'sunny',
        );
        final en = s.copyWith(title: 'Morning Chanting');
        expect(en.prayerIds, ['a1', 'a2']);
        expect(en.icon, 'sunny');
      },
    );
  });

  group(
    'hasDistinctPali covers flipped content in other-language editions',
    () {
      const base = Prayer(
        id: 'x',
        title: 't',
        text: 'อักษรไทย',
        paliText: 'Arahaṃ',
      );

      test(
        'Thai edition with distinct text and Pali shows the extra Pali chip',
        () {
          expect(base.hasDistinctPali, isTrue);
        },
      );

      test('English overlay using text equal to Pali hides the extra Pali chip'
          '(บาลีเป็นเนื้อหาหลัก)', () {
        final en = base.withOverlay({'text': base.paliText});
        expect(en.hasDistinctPali, isFalse);
      });

      test('prayers without Pali show no Pali chip', () {
        const noPali = Prayer(id: 'y', title: 't', text: 'อักษรไทย');
        expect(noPali.hasDistinctPali, isFalse);
      });
    },
  );

  test('real declared editions include every id and no blank fields', () {
    final source = PrayerRepository.decodePrayers(_read('prayers-th.json'));
    for (final lang in kContentLanguages) {
      final edition = PrayerRepository.decodePrayers(
        _read(
          lang == kDefaultContentLanguage
              ? 'prayers-th.json'
              : 'prayers-$lang.json',
        ),
        languageCode: lang,
      );
      expect(
        edition.map((p) => p.id).toSet(),
        source.map((p) => p.id).toSet(),
        reason: 'ทุก edition ต้องมี id ครบเท่าต้นฉบับเสมอ',
      );
      for (final p in edition) {
        expect(p.title.trim(), isNotEmpty, reason: '${p.id}: title ว่าง');
        expect(p.text.trim(), isNotEmpty, reason: '${p.id}: text ว่าง');
      }
    }
  });

  test('English translations are sourced and left unverified', () {
    final raw = (jsonDecode(_read('prayers-en.json')) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    var translatedLines = 0;
    for (final p in raw) {
      expect(
        (p['verificationStatus'] as Map)['translation'],
        'unverified',
        reason:
            '${p['id']}: English translation cannot be marked reviewed until '
            'it is checked against an English source edition',
      );
      for (final source
          in ((p['meta'] as Map)['sources'] as List<dynamic>? ?? const [])) {
        final sourceMap = source as Map;
        if (!((sourceMap['for'] as List<dynamic>? ?? const []).contains(
          'translation',
        ))) {
          continue;
        }
        // A URL is what makes a translation checkable. The licence it came
        // under is tracked with the master copy, not in the export.
        expect(sourceMap['urls'], isNotEmpty);
      }
      for (final section in (p['sections'] as List<dynamic>)) {
        for (final line in ((section as Map)['lines'] as List<dynamic>)) {
          final lineMap = line as Map;
          if (!lineMap.containsKey('translation')) {
            continue;
          }
          translatedLines++;
          expect(lineMap['translation'], isA<String>());
          expect((lineMap['translation'] as String).trim(), isNotEmpty);
        }
      }
    }
    expect(translatedLines, greaterThan(0));
  });

  test('each JSON file type decodes into the shape expected by its reader', () {
    for (final lang in kContentLanguages) {
      if (lang == kDefaultContentLanguage) continue;
      expect(jsonDecode(_read('prayers-$lang.json')), isA<List<dynamic>>());
      expect(jsonDecode(_read('sections-$lang.json')), isA<List<dynamic>>());
    }
    expect(jsonDecode(_read('prayers-th.json')), isA<List<dynamic>>());
    expect(jsonDecode(_read('sections-th.json')), isA<List<dynamic>>());
  });
}
