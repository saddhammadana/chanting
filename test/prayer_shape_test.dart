import 'dart:convert';

import 'package:chanting/data/models/prayer.dart';
import 'package:chanting/data/repositories/prayer_repository.dart';
import 'package:chanting/features/prayer_detail/widgets/prayer_content.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Tests the **new data shape** (`sections` -> `lines` -> text/roman/translation
/// + `meta`) and the "one class, two file shapes" rule.
///
/// These tests pin not the JSON appearance, but the **contract that makes gradual
/// per-prayer migration safe**: migrated prayers must look identical from outside
/// (`text`/`paliText`/`meaning`/metadata still work), and write back in their own shape.
void main() {
  // The "real file" group reads assets through rootBundle, so it needs binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Example new-shape prayer: two blocks, first is the chant leader's introduction.
  Map<String, dynamic> structuredJson() => {
    'id': 'demo',
    'title': 'บททดสอบ',
    'sections': [
      {
        'id': 'part-1',
        'type': 'lead',
        'title': {'th': 'คำนำ', 'en': 'Invitation'},
        'lines': [
          {
            'text': 'หันทะ มะยัง',
            'roman': 'Handa mayaṃ',
            'translation': {'th': 'เชิญเถิด เราทั้งหลาย', 'en': 'Now let us'},
          },
        ],
      },
      {
        'id': 'part-2',
        'type': 'main',
        'lines': [
          {
            'text': 'อะระหัง',
            'roman': 'Arahaṃ',
            'translation': {'th': 'เป็นพระอรหันต์', 'en': 'is worthy'},
          },
          {
            'text': 'สัมมาสัมพุทโธ',
            'roman': 'Sammāsambuddho',
            'translation': {'th': 'ตรัสรู้ชอบเอง'},
          },
        ],
      },
    ],
    'type': 'chant',
    'paliVerified': false,
    'meta': {'durationMinutes': 2},
  };

  group(
    'new-shape prayer appears identical to old-shape prayer from the outside',
    () {
      test('text paliText and meaning compute one paragraph per section', () {
        final p = Prayer.fromJson(structuredJson());

        expect(p.isStructured, isTrue);
        expect(p.text, 'หันทะ มะยัง\n\nอะระหัง\nสัมมาสัมพุทโธ');
        expect(p.paliText, 'Handa mayaṃ\n\nArahaṃ\nSammāsambuddho');
        expect(
          p.meaning,
          'เชิญเถิด เราทั้งหลาย\n\nเป็นพระอรหันต์\nตรัสรู้ชอบเอง',
        );
      });

      test('meta fields remain readable through legacy getters', () {
        final p = Prayer.fromJson(structuredJson());
        expect(p.type, 'chant');
        expect(p.durationMinutes, 2);
        expect(p.metaNested, isTrue);
      });

      test('legacy flat metadata fields remain readable', () {
        final p = Prayer.fromJson({
          'id': 'old',
          'title': 'บทเก่า',
          'text': 'ก\nข',
          'type': 'gatha',
        });
        expect(p.isStructured, isFalse);
        expect(p.metaNested, isFalse);
        expect(p.type, 'gatha');
        expect(p.text, 'ก\nข');
      });
    },
  );

  group('section matching required by PrayerContent is guaranteed by structure', () {
    // This is why `_joinParts` skips blanks instead of preserving blank lines:
    // blanks become paragraph separators, making Pali paragraph count exceed content.
    test('lines without Pali or translation do not skew paragraph count', () {
      final json = structuredJson();
      (json['sections'] as List)[1]['lines'] = [
        {
          'text': 'ก',
          'roman': 'ka',
          'translation': {'th': 'หนึ่ง'},
        },
        // A Thai-only line with no Pali or translation.
        {'text': 'ข'},
        {
          'text': 'ค',
          'roman': 'kha',
          'translation': {'th': 'สาม'},
        },
      ];
      final p = Prayer.fromJson(json);

      expect(PrayerContent.blocks(p.text).length, 2);
      expect(PrayerContent.blocks(p.paliText!).length, 2);
      expect(PrayerContent.blocks(p.meaning!).length, 2);
      expect(PrayerContent.canInlinePali(p), isTrue);
      expect(PrayerContent.canInlineMeaning(p), isTrue);
    });

    test('section without Pali at the beginning still counts as one paragraph', () {
      // A `rubric` block, such as a posture cue or heading, has no Pali, so its
      // paragraph is empty. If it is at the **start** and `blocks` trims the head,
      // the two sides differ by one paragraph and inline Pali silently disables.
      // Middle rubrics did not expose this until one appeared at the start.
      final p = Prayer.fromJson({
        'id': 'x',
        'title': 'x',
        'sections': [
          {
            'id': 'heading',
            'type': 'rubric',
            'lines': [
              {'id': 'heading-line-1', 'text': '(หัวข้อ)'},
            ],
          },
          {
            'id': 'main',
            'lines': [
              {
                'id': 'main-line-1',
                'text': 'ก',
                'roman': 'ka',
                'translation': {'th': 'หนึ่ง'},
              },
            ],
          },
        ],
      });

      expect(PrayerContent.blocks(p.text).length, 2);
      expect(PrayerContent.blocks(p.paliText!).length, 2);
      expect(PrayerContent.blocks(p.paliText!).first, isEmpty);
      expect(PrayerContent.canInlinePali(p), isTrue);
      expect(PrayerContent.canInlineMeaning(p), isTrue);
    });

    test(
      'prayer with no Pali returns null Pali text instead of an empty string',
      () {
        final p = Prayer.fromJson({
          'id': 'x',
          'title': 'x',
          'sections': [
            {
              'id': 'p1',
              'lines': [
                {'text': 'ขอให้ข้าพเจ้ามีความสุข'},
              ],
            },
          ],
        });
        expect(p.paliText, isNull);
        expect(p.meaning, isNull);
        expect(p.hasDistinctPali, isFalse);
      },
    );
  });

  group('editions', () {
    test(
      'Thai edition uses Thai text while English edition uses Pali as main text',
      () {
        final th = Prayer.fromJson(structuredJson());
        final en = th.forLanguage('en');

        expect(th.text, startsWith('หันทะ'));
        expect(en.text, startsWith('Handa'));
        // Pali is the main content of the en edition, so the extra Pali chip must disappear.
        expect(en.hasDistinctPali, isFalse);
        expect(th.hasDistinctPali, isTrue);
      },
    );

    test(
      'translations follow locale and fall back to source when not translated',
      () {
        final en = Prayer.fromJson(structuredJson()).forLanguage('en');
        // A line with only Thai translation must fall back to Thai in en, not blank.
        expect(en.meaning, 'Now let us\n\nis worthy\nตรัสรู้ชอบเอง');
      },
    );

    test('section headings can be localized by edition', () {
      final p = Prayer.fromJson(structuredJson());
      expect(p.parts![0].titleFor('th'), 'คำนำ');
      expect(p.parts![0].titleFor('en'), 'Invitation');
      expect(p.parts![1].titleFor('th'), isNull);
    });

    test(
      'new-shape overlay can override text and meaning with independent English content',
      () {
        // App-owner decision in August 2026: `prayers-en.json` is not just translations.
        // 56/83 prayers had `text` not equal to paliText because rubrics were translated.
        // Overrides must beat computed structure or migrated prayers cannot be translated.
        final p = Prayer.fromJson(structuredJson())
            .forLanguage('en')
            .withOverlay({
              'title': 'Test Prayer',
              'text': 'Handa mayaṃ (bow)',
              'meaning': 'Now let us bow.',
            });
        expect(p.title, 'Test Prayer');
        expect(p.text, 'Handa mayaṃ (bow)');
        expect(p.meaning, 'Now let us bow.');
        // Structure remains intact; Pali still comes from the same single source.
        expect(p.isStructured, isTrue);
        expect(p.paliText, 'Handa mayaṃ\n\nArahaṃ\nSammāsambuddho');
      },
    );

    test('overlay cannot provide its own structure or Pali', () {
      final p = Prayer.fromJson(structuredJson()).withOverlay({
        'paliText': 'ของปลอม',
        'sections': <dynamic>[],
        'lines': <dynamic>[],
      });
      expect(p.paliText, isNot(contains('ของปลอม')));
      expect(p.parts!.length, 2);
    });

    test('overlay can override metadata stored in meta', () {
      final p = Prayer.fromJson(structuredJson()).withOverlay({
        'occasions': ['Daily chanting'],
        'description': 'Opening homage',
      });
      expect(p.occasions, ['Daily chanting']);
      expect(p.description, 'Opening homage');
      expect(p.metaNested, isTrue);
    });
  });

  group('writer preserves the original record shape', () {
    test(
      'new-shape records write sections instead of text paliText and meaning',
      () {
        final json = Prayer.fromJson(structuredJson()).toJson();
        expect(json.containsKey('sections'), isTrue);
        expect(json.containsKey('meta'), isTrue);
        // Writing computed values creates a second source of truth that goes stale.
        expect(json.containsKey('text'), isFalse);
        expect(json.containsKey('paliText'), isFalse);
        expect(json.containsKey('meaning'), isFalse);
      },
    );

    test('read write read round-trip preserves content', () {
      final first = Prayer.fromJson(structuredJson());
      final second = Prayer.fromJson(
        jsonDecode(jsonEncode(first.toJson())) as Map<String, dynamic>,
      );
      expect(second.text, first.text);
      expect(second.paliText, first.paliText);
      expect(second.meaning, first.meaning);
      expect(second.parts!.first.type, PrayerPartType.lead);
    });

    test(
      'old-shape records still write flat fields and are not moved into meta',
      () {
        final json = Prayer.fromJson({
          'id': 'old',
          'title': 'บทเก่า',
          'text': 'ก',
          'type': 'gatha',
          'occasion': 'สวดประจำวัน',
        }).toJson();
        expect(
          json['type'],
          'gatha',
          reason: 'type อยู่บนสุดเสมอ ไม่ใช่ใน meta',
        );
        // Can read the old singular key but **always write the spec shape** so
        // hand-edited files converge one touched record at a time.
        expect(json['occasions'], ['สวดประจำวัน']);
        expect(json.containsKey('occasion'), isFalse);
        expect(json.containsKey('meta'), isFalse);
        expect(json.containsKey('sections'), isFalse);
      },
    );

    test('record key order matches spec section 1', () {
      // Wrong order makes editing one prayer look like the whole record moved in diff.
      final json = Prayer.fromJson(structuredJson()).toJson()
        ..removeWhere((_, v) => v == null);
      expect(json.keys.toList(), [
        'id',
        'title',
        'type',
        'sections',
        'verificationStatus',
        'meta',
      ]);
    });

    test(
      'meta accepts legacy singular values and writes them back as arrays',
      () {
        final p = Prayer.fromJson({
          'id': 'legacy',
          'title': 'บทเก่า',
          'text': 'ก',
          'meta': {
            'occasion': 'ทำวัตรเช้า',
            'source': 'หนังสือสวดมนต์ ก',
            'tipitakaReference': 'AN 6.10',
          },
        });
        expect(p.occasions, ['ทำวัตรเช้า']);
        expect(p.tipitakaReferences, ['AN 6.10']);
        // A single string goes to `note`, not `title`; it is an unsplit note, not
        // a book title. Guessing title would invent data nobody wrote.
        expect(p.sources.single.note, 'หนังสือสวดมนต์ ก');
        expect(p.sources.single.title, isNull);

        final meta = p.toJson()['meta'] as Map<String, dynamic>;
        expect(meta['occasions'], ['ทำวัตรเช้า']);
        expect(meta['sources'], [
          {'note': 'หนังสือสวดมนต์ ก'},
        ]);
        expect(meta.containsKey('occasion'), isFalse);
        expect(meta.containsKey('source'), isFalse);
        expect(meta.containsKey('tipitakaReference'), isFalse);
      },
    );

    test('sources write every key in spec order', () {
      final p = Prayer.fromJson({
        'id': 'x',
        'title': 'บท',
        'text': 'ก',
        'meta': {
          'sources': [
            {
              'for': ['roman'],
              'title': 'A Chanting Guide',
              'urls': ['https://example.org/', 'https://example.com/alt'],
              'note': 'ใช้เฉพาะฉบับคฤหัสถ์',
            },
          ],
        },
      });
      final s = p.sources.single;
      expect(s.forFields, ['roman']);
      expect(s.urls, ['https://example.org/', 'https://example.com/alt']);
      expect(s.toJson().keys.toList(), ['for', 'title', 'urls', 'note']);
    });

    test('sources read legacy single url and write urls', () {
      final p = Prayer.fromJson({
        'id': 'x',
        'title': 'บท',
        'text': 'ก',
        'meta': {
          'sources': [
            {'title': 'เว็บเดิม', 'url': 'https://example.org/'},
          ],
        },
      });

      expect(p.sources.single.urls, ['https://example.org/']);
      expect(p.sources.single.toJson(), {
        'title': 'เว็บเดิม',
        'urls': ['https://example.org/'],
      });
    });
  });

  group('section type', () {
    test('unknown section type falls back to chant instead of throwing', () {
      // Data files can be edited in GitHub web editor; one typo must not keep the app from opening.
      expect(PrayerPartType.parse('leadd'), PrayerPartType.main);
      expect(PrayerPartType.parse(null), PrayerPartType.main);
      expect(PrayerPartType.parse(7), PrayerPartType.main);
      expect(PrayerPartType.parse('rubric'), PrayerPartType.rubric);
    });

    test('every enum value writes to file and reads back correctly', () {
      for (final t in PrayerPartType.values) {
        expect(PrayerPartType.parse(t.name), t);
      }
    });
  });

  group('real file data', () {
    test('converted prayers in real data follow the same rules', () async {
      final bytes = await rootBundle.load('assets/data/prayers-th.json');
      final raw = utf8.decode(bytes.buffer.asUint8List());
      final structured = [
        for (final p in PrayerRepository.decodePrayers(raw))
          if (p.isStructured) p,
      ];
      // If no prayer has migrated yet, this passes without checking anything. That
      // is correct: it catches issues once migration starts, not forces migration.
      for (final p in structured) {
        expect(p.text.trim(), isNotEmpty, reason: '${p.id}: เนื้อบทว่าง');
        expect(
          PrayerContent.blocks(p.text).length,
          p.parts!.length,
          reason: '${p.id}: จำนวนย่อหน้าไม่เท่าจำนวนท่อน',
        );
        for (final part in p.parts!) {
          expect(part.id, isNotEmpty, reason: '${p.id}: ท่อนไม่มี id');
          expect(
            part.lines,
            isNotEmpty,
            reason: '${p.id}/${part.id}: ไม่มีบรรทัด',
          );
        }
        // Every line needs an id unique within the prayer because external data can point to it.
        final lineIds = [
          for (final part in p.parts!)
            for (final l in part.lines) l.id,
        ];
        expect(
          lineIds.any((e) => e.isEmpty),
          isFalse,
          reason: '${p.id}: บรรทัดไม่มี id',
        );
        expect(
          lineIds.toSet().length,
          lineIds.length,
          reason: '${p.id}: id บรรทัดซ้ำ',
        );
        final ids = p.parts!.map((e) => e.id).toList();
        expect(ids.toSet().length, ids.length, reason: '${p.id}: id ท่อนซ้ำ');
        // Pali/translation paragraph counts must match content or the reading page
        // silently stops inline rendering. Blocks with no Pali still count as blanks.
        if (p.hasDistinctPali) {
          expect(
            PrayerContent.blocks(p.paliText!).length,
            PrayerContent.blocks(p.text).length,
            reason: '${p.id}: จำนวนย่อหน้าบาลีไม่เท่าเนื้อบท',
          );
        }
      }
    });
  });
}
