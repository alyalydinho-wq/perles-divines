import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/scope.dart';
import '../../core/track.dart';
import '../../ui/site.dart';
import '../duas/catalog.dart';
import '../duas/dua.dart';
import '../duas/favorites.dart';
import '../player/audio_controller.dart';
import 'audio_shelves.dart';
import 'search_results.dart';
import 'sections.dart';
import 'text_screen.dart';

class SectionScreen extends StatefulWidget {
  const SectionScreen({
    super.key,
    required this.section,
    this.catalog,
    this.tracks,
    this.audio,
  });

  final CatalogSection section;
  final LocalDevotionalCatalog? catalog;
  final List<Track>? tracks;
  final PerlesAudioHandler? audio;

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
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
    final searching = query.trim().length >= 2;
    final items = widget.section.itemsOf(catalog?.items ?? const []);
    final filtered = searching
        ? (catalog?.search(query) ?? const <DevotionalText>[])
              .where(widget.section.matches)
              .toList()
        : items;
    final audios = searching
        ? searchTracks(
            query,
            tracksForSection(
              widget.section,
              widget.tracks ?? services?.tracks ?? const <Track>[],
            ),
            linkedFrom: filtered,
          )
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
              Text(
                widget.section.label,
                textAlign: TextAlign.center,
                style: siteHeading,
              ),
              const SiteGap(height: 12),
            ],
          ),
        ),
        SiteSearchField(
          controller: search,
          hint: 'Rechercher dans ${widget.section.label}',
          onChanged: (value) => setState(() => query = value),
          onHome: () => context.go('/sommaire'),
        ),
      ],
      children: [
        if (searching)
          SearchResults(
            texts: filtered,
            tracks: audios,
            audio: widget.audio ?? services?.audio,
          )
        else if (items.isEmpty)
          const SiteBlackText('Aucune prière ne correspond à cette recherche.')
        else
          for (final item in items) ...[
            SiteButton(
              label: item.title,
              onTap: () => context.push('/text/${item.id}'),
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

class CatalogTextPage extends StatelessWidget {
  const CatalogTextPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.maybeOf(context);
    if (services == null) {
      return const SitePage(
        children: [SiteBlackText('Catalogue indisponible.')],
      );
    }
    final matches = services.devotionalCatalog.items.where(
      (item) => item.id == id,
    );
    if (matches.isEmpty) {
      return SitePage(
        children: [
          const SiteBlackText('Ce texte n’est pas dans le catalogue embarqué.'),
          const SiteGap(),
          SiteButton(
            label: 'Retour au sommaire',
            green: true,
            onTap: () => context.go('/sommaire'),
          ),
        ],
      );
    }
    final item = matches.first;
    final tracks = services.tracks
        .where((track) => item.audioIds.contains(track.id))
        .toList();
    return FutureBuilder<Set<String>>(
      future: DevotionalFavorites(services.store).read(),
      builder: (context, snapshot) {
        return TextScreen(
          item: item,
          edition: services.edition,
          favorite: snapshot.data?.contains(item.id) ?? false,
          audio: services.audio,
          downloads: services.downloads,
          tracks: tracks,
          store: services.store,
          onFavorite: () => DevotionalFavorites(services.store).toggle(item.id),
          opensUpdatedText: (id) {
            for (final candidate in services.devotionalCatalog.items) {
              if (candidate.id == id) return candidate.opensUpdatedReading;
            }
            return false;
          },
        );
      },
    );
  }
}
