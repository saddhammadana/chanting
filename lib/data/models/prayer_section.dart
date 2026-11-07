/// One prayer category: the ordered sequence to chant, not just a grouping label.
///
/// Why this is an id list instead of a `category` field on `Prayer` (July 2026):
///
/// 1. The same prayer can appear in multiple categories. `pubbabhaga-namakara`
///    is chanted in both morning and evening chanting. A single field would
///    force one category or duplicate the record, which would create two ids for
///    one prayer and split user favorites.
/// 2. Position differs per category. A single `order` field can only express one
///    position, but `pubbabhaga-namakara` belongs at the beginning of both
///    morning and evening chanting. Changing `category` to `List<String>` still
///    cannot represent that.
///
/// The old shape made this visible: `order` was global across the file while
/// grouping used category names. Morning chanting became order 1, 2, 20, 21, ...
/// 26. The group was right, but the numbers were not any category's chant order.
///
/// [id] is not user-visible text. [title] varies by content language, so routes
/// use [id] rather than names; otherwise the same link could not cross languages.
///
/// Each edition is a whole file: `getSections()` reads `sections-<lang>.json`
/// and nothing is merged with the source. So every field here, [icon]
/// included, comes from the file of the edition on screen — a value missing
/// there is missing for that language alone.
class PrayerSection {
  const PrayerSection({
    required this.id,
    required this.title,
    required this.prayerIds,
    this.icon,
  });

  /// Stable category slug, shared by every content language.
  final String id;

  /// User-visible title; translated per content language.
  final String title;

  /// Prayer ids in chant order. The same prayer may appear in multiple positions.
  final List<String> prayerIds;

  /// Icon name from `kSectionIcons`, carried by every edition's section file.
  ///
  /// It says nothing about language, but it is **not** read from the source
  /// edition: drop it from `sections-en.json` and the English edition draws
  /// the fallback while Thai keeps its icon. Null or unknown names use the
  /// fallback; see `sectionIcon()`.
  final String? icon;

  factory PrayerSection.fromJson(Map<String, dynamic> json) => PrayerSection(
    id: json['id'] as String,
    title: json['title'] as String,
    prayerIds: (json['prayerIds'] as List<dynamic>).cast<String>(),
    icon: json['icon'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (icon != null) 'icon': icon,
    'prayerIds': prayerIds,
  };

  PrayerSection copyWith({
    String? title,
    List<String>? prayerIds,
    String? icon,
  }) => PrayerSection(
    id: id,
    title: title ?? this.title,
    prayerIds: prayerIds ?? this.prayerIds,
    icon: icon ?? this.icon,
  );

  @override
  String toString() => 'PrayerSection($id, ${prayerIds.length} prayers)';
}
