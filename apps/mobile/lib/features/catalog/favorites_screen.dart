import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/scope.dart';
import '../../core/store.dart';
import '../../core/track.dart';
import '../../ui/site.dart';
import '../downloads/download_controller.dart';
import '../duas/catalog.dart';
import '../duas/favorites.dart';
import '../player/audio_card.dart';
import '../player/audio_controller.dart';
import 'favorite_groups.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    this.catalog,
    this.tracks,
    this.audio,
    this.downloads,
    this.store,
  });

  final LocalDevotionalCatalog? catalog;
  final List<Track>? tracks;
  final PerlesAudioHandler? audio;
  final DownloadController? downloads;
  final AppStore? store;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  DevotionalFavorites? texts;
  AudioFavorites? audios;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = widget.store ?? ServicesScope.maybeOf(context)?.store;
    if (store == null || texts != null) return;
    texts = DevotionalFavorites(store)..addListener(_changed);
    audios = AudioFavorites(store)..addListener(_changed);
    texts!.read();
    audios!.read();
  }

  @override
  void dispose() {
    texts?.removeListener(_changed);
    audios?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.maybeOf(context);
    final catalog = widget.catalog ?? services?.devotionalCatalog;
    final tracks = widget.tracks ?? services?.tracks ?? const <Track>[];
    final store = widget.store ?? services?.store;
    final ready = texts?.loaded == true && audios?.loaded == true;
    final groups = !ready
        ? const <FavoriteGroup>[]
        : favoriteGroups(
            catalog: catalog?.items ?? const [],
            tracks: tracks,
            textIds: texts!.ids,
            audioIds: audios!.ids,
          );
    final showEmpty = store == null || (ready && groups.isEmpty);

    return SitePage(
      header: [
        SiteLogo(onTap: () => context.go('/')),
        const SiteGap(height: 12),
        Text('Favoris', textAlign: TextAlign.center, style: siteHeading),
        const SiteGap(height: 12),
      ],
      children: [
        if (showEmpty)
          const SiteBlackText(
            'Aucun favori pour le moment.\n'
            'L’étoile d’un audio ou le cœur d’un texte\n'
            'l’ajoute ici.',
          )
        else
          for (final group in groups) ...[
            Text(
              group.label,
              textAlign: TextAlign.center,
              style: siteText(
                color: siteGreen,
                fontSize: 22,
                lineHeight: 26,
                weight: FontWeight.w700,
              ),
            ),
            const SiteGap(height: 12),
            for (final item in group.texts) ...[
              SiteButton(
                label: item.title,
                onTap: () => context.push('/text/${item.id}'),
              ),
              const SiteGap(),
            ],
            for (final track in group.audios) ...[
              AudioSessionCard(
                track: track,
                audio: widget.audio ?? services?.audio,
                downloads: widget.downloads ?? services?.downloads,
                store: widget.store ?? services?.store,
              ),
              const SiteGap(),
            ],
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
