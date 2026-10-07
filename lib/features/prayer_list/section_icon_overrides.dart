import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_service.dart';
import '../../data/models/prayer_section.dart';
import 'section_icons.dart';

/// User section icon overrides: `{sectionId: iconName}` over shipped values.
///
/// This is separate from the `icon` field in `sections-*.json`, which ships with
/// the app and is edited through the prayer editor. That value changes for every
/// user; this value changes only the current device.
///
/// Stored in prefs key `section_icons` as `["<sectionId>:<iconName>", ...]`.
/// Only changed sections are stored, so untouched sections still receive new
/// shipped icons in future releases instead of freezing a copied value forever.
class SectionIconOverridesController extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    final out = <String, String>{};
    for (final raw in ref.read(prefsServiceProvider).getSectionIconsRaw()) {
      final i = raw.indexOf(':');
      if (i <= 0 || i == raw.length - 1) continue;
      final name = raw.substring(i + 1);
      // Unknown names, either from future data or removed icon names, are ignored
      // so the section falls back to its shipped icon.
      if (!kSectionIcons.containsKey(name)) continue;
      out[raw.substring(0, i)] = name;
    }
    return out;
  }

  void set(String sectionId, String iconName) {
    if (!kSectionIcons.containsKey(iconName)) return;
    state = {...state, sectionId: iconName};
    _persist();
  }

  /// Reverts to the icon shipped with the section.
  void reset(String sectionId) {
    if (!state.containsKey(sectionId)) return;
    state = {...state}..remove(sectionId);
    _persist();
  }

  void _persist() => ref.read(prefsServiceProvider).setSectionIconsRaw([
    for (final e in state.entries) '${e.key}:${e.value}',
  ]);
}

final sectionIconOverridesProvider =
    NotifierProvider<SectionIconOverridesController, Map<String, String>>(
      SectionIconOverridesController.new,
    );

/// Effective icon for a section: user override first, then shipped value.
IconData resolvedSectionIcon(
  PrayerSection section,
  Map<String, String> overrides,
) => sectionIcon(overrides[section.id] ?? section.icon);
