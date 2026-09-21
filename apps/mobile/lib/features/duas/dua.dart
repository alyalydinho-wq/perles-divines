enum DevotionalKind { dua, ziyarat, quran, namaz, aamal }

String kindLabel(DevotionalKind kind) => switch (kind) {
  DevotionalKind.dua => 'Duʿā',
  DevotionalKind.ziyarat => 'Ziyārāt',
  DevotionalKind.quran => 'Qurʾan',
  DevotionalKind.namaz => 'Namaz',
  DevotionalKind.aamal => 'Aamal',
};

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
    this.introduction = '',
    this.sourceUrl = '',
    this.pagePath = '',
  });

  final String id;
  final DevotionalKind kind;
  final String title;
  final String arabic;
  final String translation;
  final String transliteration;
  final String introduction;
  final List<String> references;
  final List<String> audioIds;
  final String sourceUrl;
  final String pagePath;

  bool get hasTranslation => translation.trim().isNotEmpty;
  bool get hasTransliteration => transliteration.trim().isNotEmpty;
  bool get hasArabic => arabic.trim().isNotEmpty;
  bool get hasOriginalPage => pagePath.isNotEmpty;

  String get preview {
    for (final value in [translation, introduction, transliteration, arabic]) {
      final text = value.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  factory DevotionalText.fromJson(Map<String, dynamic> json) =>
      DevotionalText(
        id: json['id'] as String,
        kind: DevotionalKind.values.byName(json['kind'] as String),
        title: json['title'] as String,
        arabic: json['arabic'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
        transliteration: json['transliteration'] as String? ?? '',
        introduction: json['introduction'] as String? ?? '',
        references: List<String>.from(json['references'] as List? ?? const []),
        audioIds: List<String>.from(json['audioIds'] as List? ?? const []),
        sourceUrl: json['sourceUrl'] as String? ?? '',
        pagePath: json['pagePath'] as String? ?? '',
      );
}
