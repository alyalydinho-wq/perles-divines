enum DevotionalKind { dua, ziyarat, quran, namaz, aamal }

/// Douas réécrites encore liées par les pages d’Aamal mensuel.
const _updatedAamalDuaIds = {
  'aa86b04c-fb45-5c4a-9943-170dddb31104',
  '9bbdc6dc-c3fc-50d3-b79a-45b63216bc69',
  '213aa396-99b9-535f-bf8f-a862abbc66e3',
  // Jawshan-e-Kabir, lié depuis les nuits de Qadr (Aamal de Ramadhan).
  'a6a50d78-0076-5d00-95f2-c3a732c97077',
  // Kumayl, lié depuis l’Aamal du 15 Shabaan.
  'fda4b6e3-5c57-5c03-a292-1981a9768248',
};

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
    this.gujarati = '',
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
  final String gujarati;
  final String introduction;
  final List<String> references;
  final List<String> audioIds;
  final String sourceUrl;
  final String pagePath;

  bool get hasTranslation => translation.trim().isNotEmpty;
  bool get hasTransliteration => transliteration.trim().isNotEmpty;
  bool get hasGujarati => gujarati.trim().isNotEmpty;
  bool get hasArabic => arabic.trim().isNotEmpty;
  bool get hasOriginalPage => pagePath.isNotEmpty;

  /// Seule la page d’origine existe : rien à montrer en traduction,
  /// phonétique ou gujarati.
  bool get onlyOriginalPage =>
      hasOriginalPage && !hasTranslation && !hasTransliteration && !hasGujarati;

  /// Lecture native déjà mise à jour : le lien ne doit plus ouvrir l’ancienne page.
  ///
  /// Les ziyarat de Zyaarate, puis Alqamah, Iftetah et le Doua d’Arafah,
  /// suivent la même règle que les sourates : depuis Aamal mensuel, le bouton
  /// ouvre ce texte, pas l’ancienne page HTML.
  bool get opensUpdatedReading =>
      hasArabic &&
      !hasOriginalPage &&
      (kind == DevotionalKind.quran ||
          kind == DevotionalKind.ziyarat ||
          (kind == DevotionalKind.dua && _updatedAamalDuaIds.contains(id)));

  String get preview {
    for (final value in [translation, introduction, transliteration, arabic]) {
      final text = value.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  factory DevotionalText.fromJson(Map<String, dynamic> json) => DevotionalText(
    id: json['id'] as String,
    kind: DevotionalKind.values.byName(json['kind'] as String),
    title: json['title'] as String,
    arabic: json['arabic'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
    transliteration: json['transliteration'] as String? ?? '',
    gujarati: json['gujarati'] as String? ?? '',
    introduction: json['introduction'] as String? ?? '',
    references: List<String>.from(json['references'] as List? ?? const []),
    audioIds: List<String>.from(json['audioIds'] as List? ?? const []),
    sourceUrl: json['sourceUrl'] as String? ?? '',
    pagePath: json['pagePath'] as String? ?? '',
  );
}
