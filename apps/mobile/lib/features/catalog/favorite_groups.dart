import '../../core/track.dart';
import '../duas/dua.dart';
import 'audio_shelves.dart';
import 'sections.dart';

class FavoriteGroup {
  const FavoriteGroup({
    required this.label,
    required this.texts,
    required this.audios,
  });

  final String label;
  final List<DevotionalText> texts;
  final List<Track> audios;
}

/// Classe les favoris de l’application par rubrique, dans l’ordre du sommaire.
List<FavoriteGroup> favoriteGroups({
  required Iterable<DevotionalText> catalog,
  required Iterable<Track> tracks,
  required Set<String> textIds,
  required Set<String> audioIds,
}) {
  final texts = [
    for (final item in catalog)
      if (textIds.contains(item.id)) item,
  ];
  final audios = [
    for (final track in tracks)
      if (audioIds.contains(track.id)) track,
  ]..sort(compareAudioTitles);

  final used = <String>{};
  List<Track> take(AudioShelf shelf) {
    final items = audios.where((track) => shelfOf(track) == shelf).toList();
    used.addAll(items.map((track) => track.id));
    return items;
  }

  FavoriteGroup? group(
    String label,
    List<DevotionalText> sectionTexts,
    List<Track> sectionAudios,
  ) {
    if (sectionTexts.isEmpty && sectionAudios.isEmpty) return null;
    final sorted = [...sectionTexts]
      ..sort((a, b) => a.title.compareTo(b.title));
    return FavoriteGroup(label: label, texts: sorted, audios: sectionAudios);
  }

  final groups = <FavoriteGroup?>[
    group(
      CatalogSection.quran.label,
      texts.where(CatalogSection.quran.matches).toList(),
      const [],
    ),
    group(
      CatalogSection.namaz.label,
      texts.where(CatalogSection.namaz.matches).toList(),
      const [],
    ),
    group(
      CatalogSection.douas.label,
      texts.where(CatalogSection.douas.matches).toList(),
      take(AudioShelf.doua),
    ),
    group(
      CatalogSection.zyaraate.label,
      texts.where(CatalogSection.zyaraate.matches).toList(),
      take(AudioShelf.zyaraate),
    ),
    group(
      CatalogSection.aamalSpecifique.label,
      texts.where(CatalogSection.aamalSpecifique.matches).toList(),
      const [],
    ),
    group(
      CatalogSection.aamalMensuel.label,
      texts.where(CatalogSection.aamalMensuel.matches).toList(),
      const [],
    ),
    group('Aamal', const [], take(AudioShelf.aamal)),
    group('Hadith', const [], take(AudioShelf.hadith)),
    group(
      'Autres',
      const [],
      audios.where((track) => !used.contains(track.id)).toList(),
    ),
  ];
  return [for (final item in groups) ?item];
}
