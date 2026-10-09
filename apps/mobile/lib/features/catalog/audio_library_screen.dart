import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/scope.dart';
import '../../core/store.dart';
import '../../core/track.dart';
import '../../ui/site.dart';
import '../downloads/download_controller.dart';
import '../player/audio_card.dart';
import '../player/audio_controller.dart';
import 'audio_shelves.dart';

class AudioLibraryScreen extends StatelessWidget {
  const AudioLibraryScreen({
    super.key,
    this.tracks,
    this.audio,
    this.downloads,
    this.store,
  });

  final List<Track>? tracks;
  final PerlesAudioHandler? audio;
  final DownloadController? downloads;
  final AppStore? store;

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.maybeOf(context);
    final items = List<Track>.of(tracks ?? services?.tracks ?? const []);
    final shelves = [
      for (final shelf in AudioShelf.values)
        if (tracksOf(shelf, items).isNotEmpty)
          (shelf: shelf, count: tracksOf(shelf, items).length),
    ];

    return SitePage(
      header: [
        SiteLogo(onTap: () => context.go('/')),
        const SiteGap(height: 12),
        Text('Audios', textAlign: TextAlign.center, style: siteHeading),
        const SiteGap(height: 12),
      ],
      children: [
        SiteButton(
          key: const Key('favoris-section'),
          label: 'Favoris',
          onTap: () => context.push('/favoris'),
        ),
        const SiteGap(),
        if (shelves.isEmpty)
          const SiteBlackText('Aucun audio n’est encore publié.')
        else
          for (final row in shelves) ...[
            SiteButton(
              key: Key('audio-shelf-${row.shelf.id}'),
              label: '${row.shelf.label} (${row.count})',
              onTap: () => context.push('/audios/${row.shelf.id}'),
            ),
            const SiteGap(),
          ],
        const SiteGap(height: 8),
        SiteButton(
          label: 'Retour au sommaire',
          green: true,
          onTap: () => context.go('/sommaire'),
        ),
      ],
    );
  }
}

class AudioShelfScreen extends StatelessWidget {
  const AudioShelfScreen({
    super.key,
    required this.shelf,
    this.tracks,
    this.audio,
    this.downloads,
    this.store,
  });

  final AudioShelf shelf;
  final List<Track>? tracks;
  final PerlesAudioHandler? audio;
  final DownloadController? downloads;
  final AppStore? store;

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.maybeOf(context);
    final items = tracksOf(shelf, tracks ?? services?.tracks ?? const []);
    final handler = audio ?? services?.audio;
    final downloader = downloads ?? services?.downloads;
    final db = store ?? services?.store;

    return SitePage(
      header: [
        SiteLogo(onTap: () => context.go('/')),
        const SiteGap(height: 12),
        Text(shelf.label, textAlign: TextAlign.center, style: siteHeading),
        const SiteGap(height: 12),
      ],
      children: [
        if (items.isEmpty)
          const SiteBlackText('Aucun audio dans cette rubrique.')
        else
          for (final track in items) ...[
            AudioTrackTile(
              track: track,
              audio: handler,
              downloads: downloader,
              store: db,
            ),
            const SiteGap(),
          ],
        const SiteGap(height: 8),
        SiteButton(
          label: 'Retour aux audios',
          green: true,
          onTap: () => context.go('/audios'),
        ),
      ],
    );
  }
}

class AudioTrackTile extends StatelessWidget {
  const AudioTrackTile({
    super.key,
    required this.track,
    this.audio,
    this.downloads,
    this.store,
  });

  final Track track;
  final PerlesAudioHandler? audio;
  final DownloadController? downloads;
  final AppStore? store;

  @override
  Widget build(BuildContext context) {
    return AudioSessionCard(
      track: track,
      audio: audio,
      downloads: downloads,
      store: store,
    );
  }
}
