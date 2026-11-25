import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/scope.dart';
import '../../core/services.dart';
import '../../ui/site.dart';
import 'original_page.dart';

/// Adresse de l’application pour un lien d’une page d’origine vers [id].
///
/// Un texte du catalogue s’ouvre en lecture quand sa lecture native est à
/// jour ou que la page est son onglet Arabe ; une autre page d’origine
/// s’ouvre seule ; un texte sans page s’ouvre dans sa lecture.
String? locatePage(Services? services, String id, String? anchor) {
  final catalog = services?.devotionalCatalog;
  final pages = services?.originalPages;
  final key = id.toLowerCase();
  final item = catalog?.items.where((item) => item.id == key).firstOrNull;
  return pageLocation(
    key,
    anchor,
    opensText: (_) =>
        item != null && (item.opensUpdatedReading || item.hasOriginalPage),
    hasPage: (id) => pages?[id] != null,
    inCatalog: (_) => item != null,
  );
}

/// Suit un lien d’une page d’origine, depuis un geste (hors construction).
void openPageLink(BuildContext context, PageDestination destination) {
  final services = context
      .getInheritedWidgetOfExactType<ServicesScope>()
      ?.services;
  followPageDestination(
    context,
    destination,
    locate: (id, anchor) => locatePage(services, id, anchor),
  );
}

/// Page d’origine qui n’est pas un texte du catalogue (jours du Ramadhan,
/// nuits de Moharram…), ouverte depuis un lien.
class OriginalPageScreen extends StatefulWidget {
  const OriginalPageScreen({super.key, required this.id, this.anchor});
  final String id;
  final String? anchor;

  @override
  State<OriginalPageScreen> createState() => _OriginalPageScreenState();
}

class _OriginalPageScreenState extends State<OriginalPageScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.maybeOf(context);
    final pages = services?.originalPages;
    if (pages == null) {
      return const SitePage(
        children: [
          SiteGap(height: 44),
          CircularProgressIndicator(color: siteGreenSolid),
          SiteGap(),
          SiteBlackText('Préparation des textes…'),
        ],
      );
    }
    final page = pages[widget.id];
    if (page == null) {
      return SitePage(
        children: [
          const SiteBlackText('Cette page n’est pas dans l’application.'),
          const SiteGap(),
          SiteButton(
            label: 'Retour au sommaire',
            green: true,
            onTap: () => goToSommaire(context),
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: context.site.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SiteReaderHeader(
            title: page.title.isEmpty ? 'Perles Divines' : page.title,
            onBack: () => Navigator.of(context).maybePop(),
            onHome: () => goToSommaire(context),
            onScrollToTop: () {
              if (!_scroll.hasClients) return;
              _scroll.animateTo(
                0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              );
            },
          ),
          Expanded(
            child: OriginalPageView(
              page: page,
              controller: _scroll,
              initialAnchor: widget.anchor,
              onLink: (destination) => openPageLink(context, destination),
            ),
          ),
        ],
      ),
    );
  }
}
