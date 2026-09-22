import '../duas/dua.dart';

enum CatalogSection {
  quran('quran', "Qur'an", DevotionalKind.quran),
  namaz('namaz', 'Namaz', DevotionalKind.namaz),
  douas('douas', 'Doua', DevotionalKind.dua),
  zyaraate('zyaraate', 'Zyaraate', DevotionalKind.ziyarat),
  aamalSpecifique(
    'aamal-specifique',
    'Aamal Specifique',
    DevotionalKind.aamal,
  ),
  aamalMensuel('aamal-mensuel', 'Aamal Mensuel', DevotionalKind.aamal);

  const CatalogSection(this.id, this.label, this.kind);

  final String id;
  final String label;
  final DevotionalKind kind;

  static CatalogSection? byId(String id) {
    for (final section in values) {
      if (section.id == id) return section;
    }
    return null;
  }

  bool matches(DevotionalText item) {
    if (item.kind != kind) return false;
    final monthly = _monthlyAamal(item);
    return switch (this) {
      CatalogSection.aamalMensuel => monthly,
      CatalogSection.aamalSpecifique => !monthly,
      _ => true,
    };
  }

  List<DevotionalText> itemsOf(Iterable<DevotionalText> catalog) =>
      catalog.where(matches).toList();
}

bool _monthlyAamal(DevotionalText item) =>
    item.kind == DevotionalKind.aamal &&
    item.title.toLowerCase().contains('du mois');
