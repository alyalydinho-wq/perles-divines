import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/scope.dart';
import '../../core/track.dart';
import '../../ui/site.dart';
import '../catalog/audio_shelves.dart';
import '../catalog/search_results.dart';
import '../catalog/sections.dart';
import '../duas/catalog.dart';
import '../duas/dua.dart';
import '../player/audio_controller.dart';

class SommaireScreen extends StatefulWidget {
  const SommaireScreen({super.key, this.catalog, this.tracks, this.audio});

  final LocalDevotionalCatalog? catalog;
  final List<Track>? tracks;
  final PerlesAudioHandler? audio;

  @override
  State<SommaireScreen> createState() => _SommaireScreenState();
}

class _SommaireScreenState extends State<SommaireScreen> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  LocalDevotionalCatalog? _catalog(BuildContext context) =>
      widget.catalog ?? ServicesScope.maybeOf(context)?.devotionalCatalog;

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog(context);
    final services = ServicesScope.maybeOf(context);
    final tracks = widget.tracks ?? services?.tracks ?? const <Track>[];
    final audio = widget.audio ?? services?.audio;
    final searching = query.trim().length >= 2;
    final results = searching
        ? (catalog?.search(query) ?? const <DevotionalText>[])
        : const <DevotionalText>[];
    final audios = searching
        ? searchTracks(query, tracks, linkedFrom: results)
        : const <Track>[];

    return SitePage(
      header: [
        Visibility(
          visible: !searching,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SiteLogo(onTap: () => context.go('/')),
              const SiteGap(height: 12),
              const SiteBlackText('Version $appVersion', small: true),
              const SiteGap(height: 12),
            ],
          ),
        ),
        SiteSearchField(
          controller: search,
          hint: 'Rechercher une prière, une invocation ou un audio',
          onChanged: (value) => setState(() => query = value),
        ),
      ],
      children: [
        if (!searching) ...[const SiteBismillah(), const SiteGap()],
        if (searching)
          SearchResults(texts: results, tracks: audios, audio: audio)
        else ...[
          for (final section in CatalogSection.values) ...[
            SiteButton(
              label: section.label,
              onTap: () => context.push('/section/${section.id}'),
            ),
            const SiteGap(),
          ],
          SiteButton(label: 'Audios', onTap: () => context.push('/audios')),
          const SiteGap(),
          SiteButton(
            key: const Key('favoris-section'),
            label: 'Favoris',
            onTap: () => context.push('/favoris'),
          ),
          const SiteGap(),
          SiteButton(
            label: 'A Propos ...',
            green: true,
            onTap: () => context.push('/about'),
          ),
        ],
      ],
    );
  }
}
