import 'dart:convert';

/// User-managed prayer set: a name plus an ordered list of prayer IDs.
class Playlist {
  final String id;
  final String name;
  final List<String> prayerIds;

  /// The owner's own line about the set; null when none was written.
  ///
  /// Kept on this device only: share codes carry the name and ids, so a
  /// received set arrives without one.
  final String? description;

  const Playlist({
    required this.id,
    required this.name,
    required this.prayerIds,
    this.description,
  });

  Playlist copyWith({String? name, List<String>? prayerIds}) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      prayerIds: prayerIds ?? this.prayerIds,
      description: description,
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      prayerIds: (json['prayerIds'] as List<dynamic>).cast<String>(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'prayerIds': prayerIds,
      // Absent rather than null, so sets without one keep their stored shape.
      if (description != null) 'description': description,
    };
  }

  /// Encoded shape used in SharedPreferences, one JSON string per playlist.
  factory Playlist.fromJsonString(String raw) =>
      Playlist.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());
}
