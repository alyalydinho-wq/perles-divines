import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/scope.dart';
import '../../ui/site.dart';
import '../catalog/sections.dart';
import '../duas/catalog.dart';
import '../duas/dua.dart';

class SommaireScreen extends StatefulWidget {
  const SommaireScreen({super.key, this.catalog});

  final LocalDevotionalCatalog? catalog;

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
    final results = query.trim().isEmpty
        ? const <DevotionalText>[]
        : (catalog?.search(query) ?? const <DevotionalText>[]);

    return SitePage(
      header: [
        SiteLogo(onTap: () => context.go('/')),
        const SiteGap(height: 12),
        const SiteBlackText('Version $appVersion', small: true),
        const SiteGap(height: 12),
        SiteSearchField(
          controller: search,
          onChanged: (value) => setState(() => query = value),
        ),
      ],
      children: [
        const SiteBismillah(),
        const SiteGap(),
        if (query.trim().isNotEmpty) ...[
          if (results.isEmpty)
            const SiteBlackText('Aucune prière ne correspond à cette recherche.')
          else
            for (final item in results) ...[
              SiteButton(
                label: item.title,
                onTap: () => context.push('/text/${item.id}'),
              ),
              const SiteGap(),
            ],
        ] else ...[
          for (final section in CatalogSection.values) ...[
            SiteButton(
              label: section.label,
              onTap: () => context.push('/section/${section.id}'),
            ),
            const SiteGap(),
          ],
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
