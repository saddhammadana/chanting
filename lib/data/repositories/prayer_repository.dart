import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/prayer.dart';
import '../models/prayer_section.dart';

///
export '../models/prayer_part.dart'
    show kContentLanguages, kDefaultContentLanguage;

String contentLanguageFor(String uiLanguageCode) =>
    kContentLanguages.contains(uiLanguageCode)
    ? uiLanguageCode
    : kDefaultContentLanguage;

/// Read-only access to the prayer book the app ships.
///
/// **The app does not edit its prayers.** The master copy is the chant library
/// in the dhamma admin (`/admin/chants`); its export page
/// (`/admin/chants/export`) produces `prayers-<lang>.json` and
/// `sections-<lang>.json`, which are dropped into `assets/data/` as they are.
/// `test/prayers_data_test.dart` and friends are the gate on what arrives.
class PrayerRepository {
  PrayerRepository({this.languageCode = kDefaultContentLanguage});
  final String languageCode;

  List<Prayer>? _cache;
  List<PrayerSection>? _sectionCache;

  /// Every prayer in this edition, in section order, then any not in a section.
  Future<List<Prayer>> getAllPrayers() async {
    if (_cache != null) return _cache!;
    return _cache = _ordered(
      await _readPrayers(languageCode),
      await getSections(),
    );
  }

  static List<Prayer> _ordered(
    Iterable<Prayer> prayers,
    List<PrayerSection> sections,
  ) {
    final byId = {for (final p in prayers) p.id: p};
    final seen = <String>{};
    final ordered = <Prayer>[];
    for (final section in sections) {
      for (final id in section.prayerIds) {
        final p = byId[id];
        if (p != null && seen.add(id)) ordered.add(p);
      }
    }
    for (final p in byId.values) {
      if (seen.add(p.id)) ordered.add(p);
    }
    return ordered;
  }

  Future<List<Prayer>> _readPrayers(String lang) async {
    return decodePrayers(
      await _contentRaw(assetPathFor(lang)),
      languageCode: lang,
    );
  }

  ///
  Future<List<PrayerSection>> getSections() async {
    if (_sectionCache != null) return _sectionCache!;
    return _sectionCache = decodeSections(
      await _contentRaw(sectionsPathFor(languageCode)),
    );
  }

  ///
  static Future<String> _bundleRaw(String path) async {
    final bytes = await rootBundle.load(path);
    return utf8.decode(bytes.buffer.asUint8List());
  }

  Future<String> _contentRaw(String path) => _bundleRaw(path);

  Future<PrayerSection?> getSectionById(String id) async {
    for (final s in await getSections()) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<List<PrayerSection>> sectionsContaining(String prayerId) async => [
    for (final s in await getSections())
      if (s.prayerIds.contains(prayerId)) s,
  ];
  Future<List<Prayer>> prayersOfSection(String sectionId) async {
    final section = await getSectionById(sectionId);
    if (section == null) return const [];
    final byId = {for (final p in await getAllPrayers()) p.id: p};
    return [
      for (final id in section.prayerIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<Prayer?> getPrayerById(String id) async {
    final prayers = await getAllPrayers();
    for (final p in prayers) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<Map<String, List<Prayer>>> getPrayersByCategory() async {
    final byId = {for (final p in await getAllPrayers()) p.id: p};
    return {
      for (final s in await getSections())
        s.id: [
          for (final id in s.prayerIds)
            if (byId[id] != null) byId[id]!,
        ],
    };
  }

  static const sourcePath = 'assets/data/prayers-th.json';
  static const sourceSectionsPath = 'assets/data/sections-th.json';
  static String assetPathFor(String languageCode) =>
      'assets/data/prayers-$languageCode.json';
  static String sectionsPathFor(String languageCode) =>
      'assets/data/sections-$languageCode.json';
  static List<Prayer> decodePrayers(
    String raw, {
    String languageCode = kDefaultContentLanguage,
  }) => (jsonDecode(raw) as List<dynamic>)
      .map(
        (e) => Prayer.fromJson(
          e as Map<String, dynamic>,
          languageCode: languageCode,
        ),
      )
      .toList();
  static List<PrayerSection> decodeSections(String raw) =>
      (jsonDecode(raw) as List<dynamic>)
          .map((e) => PrayerSection.fromJson(e as Map<String, dynamic>))
          .toList();
}
