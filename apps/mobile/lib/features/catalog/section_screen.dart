import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/scope.dart';
import '../../ui/site.dart';
import '../duas/catalog.dart';
import '../duas/dua.dart';
import '../duas/favorites.dart';
import 'sections.dart';
import 'text_screen.dart';

class SectionScreen extends StatefulWidget {
  const SectionScreen({super.key, required this.section, this.catalog});

  final CatalogSection section;
  final LocalDevotionalCatalog? catalog;

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
    final searching = query.trim().isNotEmpty;
    final items = widget.section.itemsOf(catalog?.items ?? const []);
    final filtered = searching
        ? (catalog?.search(query) ?? const <DevotionalText>[])
              .where(widget.section.matches)
              .toList()
        : items;

    return SitePage(
      header: [
        if (!searching) ...[
          SiteLogo(onTap: () => context.go('/')),
          const SiteGap(height: 12),
          Text(
            widget.section.label,
            textAlign: TextAlign.center,
            style: siteHeading,
          ),
          const SiteGap(height: 12),
        ],
        SiteSearchField(
          controller: search,
          hint: 'Rechercher dans ${widget.section.label}',
          onChanged: (value) => setState(() => query = value),
        ),
      ],
      children: [
        if (filtered.isEmpty)
          const SiteBlackText('Aucune prière ne correspond à cette recherche.')
        else
          for (final item in filtered) ...[
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
          tracks: tracks,
          store: services.store,
          onFavorite: () => DevotionalFavorites(services.store).toggle(item.id),
        );
      },
    );
  }
}
