import '../core/store.dart';
import '../core/track.dart';
import '../features/downloads/download_controller.dart';
import '../features/duas/catalog.dart';
import '../features/player/audio_controller.dart';
import '../features/reader/original_page.dart';

/// Services de l’app. Le sommaire s’affiche avant qu’ils soient tous prêts :
/// chacun arrive dès qu’il est chargé, et un champ vide veut dire « encore
/// en préparation ».
class Services {
  const Services({
    required this.store,
    this.originalPages,
    this.devotionalCatalog,
    this.downloads,
    this.audio,
    this.tracks = const [],
  });

  final AppStore store;

  /// Pages d’origine du site, affichées en natif.
  final OriginalPages? originalPages;
  final LocalDevotionalCatalog? devotionalCatalog;
  final DownloadController? downloads;
  final PerlesAudioHandler? audio;
  final List<Track> tracks;

  Services copyWith({
    OriginalPages? originalPages,
    LocalDevotionalCatalog? devotionalCatalog,
    DownloadController? downloads,
    PerlesAudioHandler? audio,
    List<Track>? tracks,
  }) => Services(
    store: store,
    originalPages: originalPages ?? this.originalPages,
    devotionalCatalog: devotionalCatalog ?? this.devotionalCatalog,
    downloads: downloads ?? this.downloads,
    audio: audio ?? this.audio,
    tracks: tracks ?? this.tracks,
  );
}
