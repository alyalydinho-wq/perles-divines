enum DevotionalKind { dua, ziyarat }

class DevotionalText {
  const DevotionalText({
    required this.id,
    required this.kind,
    required this.title,
    required this.arabic,
    required this.translation,
    required this.transliteration,
    required this.references,
    required this.audioIds,
  });

  final String id;
  final DevotionalKind kind;
  final String title;
  final String arabic;
  final String translation;
  final String transliteration;
  final List<String> references;
  final List<String> audioIds;

  factory DevotionalText.fromJson(Map<String, dynamic> json) =>
      DevotionalText(
        id: json['id'] as String,
        kind: DevotionalKind.values.byName(json['kind'] as String),
        title: json['title'] as String,
        arabic: json['arabic'] as String,
        translation: json['translation'] as String,
        transliteration: json['transliteration'] as String,
        references: List<String>.from(json['references'] as List),
        audioIds: List<String>.from(json['audioIds'] as List),
      );
}
