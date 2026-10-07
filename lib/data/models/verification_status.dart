/// Verification state for prayer content, split by verified content area.
///
/// See docs/content/verification.md for review rules and AI limits.
library;

/// Verification state for one content area.
enum VerificationState {
  /// No one has verified this content.
  unverified('unverified'),

  /// A person checked this content against a source book.
  verified('verified'),

  /// Previously verified, but the text changed afterwards.
  needsRecheck('needs-recheck');

  const VerificationState(this.key);

  /// JSON key. Do not use enum `name` because `needs-recheck` contains a hyphen.
  final String key;

  /// Unknown values fall back to [unverified]; tests report bad data.
  static VerificationState parse(Object? raw) {
    if (raw is bool) return raw ? verified : unverified;
    if (raw is String) {
      for (final v in values) {
        if (v.key == raw) return v;
      }
    }
    return unverified;
  }
}

/// Verification status for a whole prayer, one value per independently reviewed area.
class VerificationStatus {
  /// Romanized Pali (`PrayerLine.roman`), guarded by `_paliVerifiedIds`.
  final VerificationState pali;

  /// Translation (`PrayerLine.translation`), guarded by `_translationVerifiedIds`.
  final VerificationState translation;

  const VerificationStatus({
    this.pali = VerificationState.unverified,
    this.translation = VerificationState.unverified,
  });

  /// Nothing has been verified; default for new prayers.
  static const none = VerificationStatus();

  /// Parse from JSON, including legacy `"paliVerified": true`.
  ///
  /// [legacyPaliVerified] is used only when the record has not migrated to
  /// `verificationStatus`.
  factory VerificationStatus.fromJson(
    Object? json, {
    Object? legacyPaliVerified,
  }) {
    if (json is Map) {
      return VerificationStatus(
        pali: VerificationState.parse(json['pali']),
        translation: VerificationState.parse(json['translation']),
      );
    }
    // Legacy shape: the old boolean only described Pali.
    return VerificationStatus(
      pali: VerificationState.parse(legacyPaliVerified),
    );
  }

  /// Always write both keys, even when both are `unverified`.
  Map<String, dynamic> toJson() => {
    'pali': pali.key,
    'translation': translation.key,
  };

  VerificationStatus copyWith({
    VerificationState? pali,
    VerificationState? translation,
  }) => VerificationStatus(
    pali: pali ?? this.pali,
    translation: translation ?? this.translation,
  );

  /// Whether this area is trusted. [VerificationState.needsRecheck] is not trusted.
  static bool isVerified(VerificationState s) =>
      s == VerificationState.verified;

  @override
  bool operator ==(Object other) =>
      other is VerificationStatus &&
      other.pali == pali &&
      other.translation == translation;

  @override
  int get hashCode => Object.hash(pali, translation);
}
