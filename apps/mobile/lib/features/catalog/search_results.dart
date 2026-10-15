import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/track.dart';
import '../../ui/site.dart';
import '../duas/dua.dart';
import '../player/audio_controller.dart';

/// Résultats de recherche : audios d’abord, puis textes.
/// Chaque ligne reste dans la colonne du site, le titre se replie.
class SearchResults extends StatelessWidget {
  const SearchResults({
    super.key,
    required this.texts,
    required this.tracks,
    this.audio,
  });

  final List<DevotionalText> texts;
  final List<Track> tracks;
  final PerlesAudioHandler? audio;

  @override
  Widget build(BuildContext context) {
    if (texts.isEmpty && tracks.isEmpty) {
      return const SiteBlackText(
        'Aucun texte ni audio ne correspond à cette recherche.',
      );
    }
    return Column(
      children: [
        for (final track in tracks) ...[
          SiteButton(
            key: Key('search-audio-${track.id}'),
            label: track.title,
            caption: 'Audio',
            icon: Icons.play_arrow_rounded,
            maxLines: 2,
            onTap: () {
              final handler = audio;
              if (handler != null) handler.playTracks([track]);
            },
          ),
          const SiteGap(),
        ],
        for (final item in texts) ...[
          SiteButton(
            key: Key('search-text-${item.id}'),
            label: item.title,
            maxLines: 3,
            onTap: () => context.push('/text/${item.id}'),
          ),
          const SiteGap(),
        ],
      ],
    );
  }
}
