import '../core/store.dart';
import '../core/track.dart';
import '../features/downloads/download_controller.dart';
import '../features/duas/catalog.dart';
import '../features/player/audio_controller.dart';
import '../features/reader/content_install.dart';

class Services {
  Services(
    this.edition,
    this.devotionalCatalog,
    this.store,
    this.downloads,
    this.audio,
    this.tracks,
  );
  final LocalEdition edition;
  final LocalDevotionalCatalog devotionalCatalog;
  final AppStore store;
  final DownloadController downloads;
  final PerlesAudioHandler audio;
  final List<Track> tracks;
}
